// Đọc / tạo bản dịch câu theo ngôn ngữ. Bản dịch máy được cache vĩnh viễn trong sentence_translations.
import { query } from './db.js';
import { translator } from './translate/index.js';
import { SOURCE_LANG } from './languages.js';

export class TranslationError extends Error {
  constructor(code, message, status = 400) {
    super(message);
    this.code = code;
    this.status = status;
  }
}

export async function getLanguage(code) {
  const { rows: [lang] } = await query('SELECT code, name, native_name FROM languages WHERE code = $1 AND enabled', [code]);
  return lang ?? null;
}

/** { lang, total, missing, items: { [idx]: text } } */
export async function getLessonTranslations(lessonId, lang) {
  const { rows } = await query(
    `SELECT s.idx, t.text, t.source
       FROM sentences s
       LEFT JOIN sentence_translations t ON t.sentence_id = s.id AND t.lang = $2
      WHERE s.lesson_id = $1 ORDER BY s.idx`,
    [lessonId, lang],
  );
  const items = {};
  for (const r of rows) if (r.text != null) items[r.idx] = r.text;
  return { lang, total: rows.length, missing: rows.length - Object.keys(items).length, items };
}

const inflight = new Map(); // tránh gọi provider 2 lần khi nhiều người cùng mở 1 bài

/** Dịch các câu còn thiếu của 1 bài sang `lang`. Trả về số câu vừa dịch. */
export function translateLesson(lessonId, lang) {
  const key = `${lessonId}:${lang}`;
  if (inflight.has(key)) return inflight.get(key);
  const job = (async () => {
    if (!(await getLanguage(lang))) throw new TranslationError('unsupported_language', `Ngôn ngữ ${lang} chưa được bật`);
    if (!(await translator.supports(lang, SOURCE_LANG))) {
      throw new TranslationError('translator_unavailable', `Provider "${translator.name}" chưa sẵn sàng hoặc không hỗ trợ ${lang}`, 503);
    }
    const { rows } = await query(
      `SELECT s.id, s.text FROM sentences s
        WHERE s.lesson_id = $1
          AND NOT EXISTS (SELECT 1 FROM sentence_translations t WHERE t.sentence_id = s.id AND t.lang = $2)
        ORDER BY s.idx`,
      [lessonId, lang],
    );
    if (!rows.length) return 0;
    const texts = await translator.translate(rows.map((r) => r.text), { source: SOURCE_LANG, target: lang });
    await query(
      `INSERT INTO sentence_translations (sentence_id, lang, text, source)
       SELECT unnest($1::int[]), $2, unnest($3::text[]), $4
       ON CONFLICT DO NOTHING`,
      [rows.map((r) => r.id), lang, texts, `machine:${translator.name}`],
    );
    return rows.length;
  })().finally(() => inflight.delete(key));
  inflight.set(key, job);
  return job;
}
