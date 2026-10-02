import express from 'express';
import cors from 'cors';
import multer from 'multer';
import path from 'node:path';
import fs from 'node:fs';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { query } from './db.js';
import { normalizeWord } from './ipa.js';
import { translator } from './translate/index.js';
import { SOURCE_LANG } from './languages.js';
import { getLanguage, getLessonTranslations, translateLesson, TranslationError } from './translations.js';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const MEDIA_DIR = path.join(ROOT, 'media');
const UPLOAD_DIR = path.join(ROOT, 'uploads');
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const PORT = Number(process.env.PORT) || 4100;
// Để trống ("") khi chạy sau reverse proxy cùng domain -> URL tương đối /media/...
const PUBLIC_URL = process.env.PUBLIC_URL ?? `http://localhost:${PORT}`;
const mediaUrl = (p) => (p ? `${PUBLIC_URL}/media/${p}` : null);

const app = express();
app.use(cors());
app.use(express.json());
// Phục vụ mp3 (express.static hỗ trợ Range request → <audio> seek được)
app.use('/media', express.static(MEDIA_DIR, { maxAge: '7d' }));
app.use('/uploads', express.static(UPLOAD_DIR));

const upload = multer({
  storage: multer.diskStorage({
    destination: UPLOAD_DIR,
    filename: (_req, file, cb) => {
      const ext = file.mimetype.includes('mp4') ? '.m4a' : file.mimetype.includes('ogg') ? '.ogg' : '.webm';
      cb(null, `${Date.now()}-${crypto.randomUUID()}${ext}`);
    },
  }),
  limits: { fileSize: 10 * 1024 * 1024 },
});

app.get('/api/health', (_req, res) => res.json({ ok: true }));

app.get('/api/topics', async (_req, res) => {
  const { rows } = await query(
    `SELECT t.slug, t.title, t.level, t.description, count(l.id)::int AS lesson_count,
            (array_agg(l.image_path ORDER BY l.position))[1] AS cover
       FROM topics t LEFT JOIN lessons l ON l.topic_id = t.id
      GROUP BY t.id ORDER BY t.position`,
  );
  res.json(rows.map((r) => ({ ...r, cover: mediaUrl(r.cover) })));
});

app.get('/api/topics/:slug', async (req, res) => {
  const { rows: [topic] } = await query('SELECT id, slug, title, level, description FROM topics WHERE slug = $1', [req.params.slug]);
  if (!topic) return res.status(404).json({ error: 'not_found' });
  const { rows: lessons } = await query(
    `SELECT l.slug, l.title, l.level, l.accent, l.type, l.duration, l.image_path,
            (SELECT count(*)::int FROM sentences s WHERE s.lesson_id = l.id) AS sentence_count
       FROM lessons l WHERE l.topic_id = $1 ORDER BY l.position`,
    [topic.id],
  );
  const { id, ...rest } = topic;
  res.json({ ...rest, lessons: lessons.map(({ image_path, ...l }) => ({ ...l, image: mediaUrl(image_path) })) });
});

// Ngôn ngữ dịch đang bật. autoTranslate = provider dịch máy hỗ trợ ngôn ngữ này
app.get('/api/languages', async (_req, res) => {
  const { rows } = await query(
    `SELECT l.code, l.name, l.native_name AS "nativeName",
            EXISTS (SELECT 1 FROM sentence_translations t WHERE t.lang = l.code AND t.source = 'original') AS original
       FROM languages l WHERE l.enabled ORDER BY l.position`,
  );
  const support = await Promise.all(rows.map((l) => translator.supports(l.code, SOURCE_LANG)));
  res.json(rows.map((l, i) => ({ ...l, autoTranslate: support[i] })));
});

app.get('/api/topics/:topic/lessons/:lesson', async (req, res) => {
  const { rows: [lesson] } = await query(
    `SELECT l.*, t.slug AS topic_slug, t.title AS topic_title
       FROM lessons l JOIN topics t ON t.id = l.topic_id
      WHERE t.slug = $1 AND l.slug = $2`,
    [req.params.topic, req.params.lesson],
  );
  if (!lesson) return res.status(404).json({ error: 'not_found' });

  const [sentences, study, siblings] = await Promise.all([
    query(
      // ?lang=xx: kèm bản dịch (null nếu chưa có — gọi POST /api/lessons/:id/translations để dịch)
      `SELECT s.idx, s.start_sec AS start, s.duration_sec AS duration, s.text, s.speaker, s.words, t.text AS translation
         FROM sentences s
         LEFT JOIN sentence_translations t ON t.sentence_id = s.id AND t.lang = $2
        WHERE s.lesson_id = $1 ORDER BY s.idx`,
      [lesson.id, req.query.lang ?? null],
    ),
    query('SELECT kind, data FROM study_items WHERE lesson_id = $1 ORDER BY kind, position', [lesson.id]),
    query('SELECT slug, title FROM lessons WHERE topic_id = $1 ORDER BY position', [lesson.topic_id]),
  ]);

  // Gắn IPA vào từng từ (tra bảng pronunciations theo từ đã chuẩn hoá)
  const keys = [...new Set(sentences.rows.flatMap((s) => s.words.map((w) => normalizeWord(w.text))))];
  const { rows: prons } = await query(
    "SELECT word, ipa FROM pronunciations WHERE accent = 'en-US' AND word = ANY($1)",
    [keys],
  );
  const ipa = new Map(prons.map((p) => [p.word, p.ipa]));
  for (const s of sentences.rows) {
    s.words = s.words.map((w) => ({ ...w, ipa: ipa.get(normalizeWord(w.text)) ?? null }));
    if (!req.query.lang) delete s.translation;
  }

  const pos = siblings.rows.findIndex((s) => s.slug === lesson.slug);
  const studyGrouped = { vocab: [], phrase: [], idiom: [], grammar: [] };
  for (const s of study.rows) (studyGrouped[s.kind] ??= []).push(s.data);

  res.json({
    id: lesson.id,
    slug: lesson.slug,
    title: lesson.title,
    level: lesson.level,
    accent: lesson.accent,
    type: lesson.type,
    lang: lesson.lang,
    duration: lesson.duration,
    audioUrl: mediaUrl(lesson.audio_path),
    image: mediaUrl(lesson.image_path),
    topic: { slug: lesson.topic_slug, title: lesson.topic_title },
    prev: siblings.rows[pos - 1] ?? null,
    next: siblings.rows[pos + 1] ?? null,
    sentences: sentences.rows,
    study: studyGrouped,
  });
});

async function findLessonId(id) {
  const { rows: [l] } = await query('SELECT id FROM lessons WHERE id = $1', [Number(id) || 0]);
  return l?.id ?? null;
}

// Bản dịch các câu của 1 bài theo ngôn ngữ (chỉ đọc cache)
app.get('/api/lessons/:id/translations', async (req, res) => {
  const lang = req.query.lang;
  if (!lang) return res.status(400).json({ error: 'missing_lang' });
  if (!(await getLanguage(lang))) return res.status(400).json({ error: 'unsupported_language' });
  const id = await findLessonId(req.params.id);
  if (!id) return res.status(404).json({ error: 'not_found' });
  res.json(await getLessonTranslations(id, lang));
});

// Dịch máy các câu còn thiếu rồi trả về toàn bộ bản dịch
app.post('/api/lessons/:id/translations', async (req, res) => {
  const lang = req.body?.lang ?? req.query.lang;
  if (!lang) return res.status(400).json({ error: 'missing_lang' });
  const id = await findLessonId(req.params.id);
  if (!id) return res.status(404).json({ error: 'not_found' });
  try {
    const translated = await translateLesson(id, lang);
    res.json({ ...(await getLessonTranslations(id, lang)), translated });
  } catch (e) {
    if (e instanceof TranslationError) return res.status(e.status).json({ error: e.code, message: e.message });
    throw e;
  }
});

// Lưu một lần shadow: điểm (chấm ở client), text nhận dạng được, file ghi âm (tuỳ chọn)
app.post('/api/attempts', upload.single('audio'), async (req, res) => {
  const { clientId, lessonId, sentenceIdx, score, heard } = req.body;
  if (!clientId || !lessonId || sentenceIdx == null || score == null) {
    return res.status(400).json({ error: 'missing_fields' });
  }
  const audioPath = req.file ? req.file.filename : null;
  const { rows: [row] } = await query(
    `INSERT INTO attempts (client_id, lesson_id, sentence_idx, score, heard, audio_path)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING id, sentence_idx, score, heard, audio_path, created_at`,
    [clientId, Number(lessonId), Number(sentenceIdx), Math.max(0, Math.min(100, Number(score))), heard || null, audioPath],
  );
  res.status(201).json(formatAttempt(row));
});

// Lần gần nhất + điểm cao nhất mỗi câu của 1 client trong 1 bài
app.get('/api/lessons/:id/progress', async (req, res) => {
  const clientId = req.query.clientId;
  if (!clientId) return res.status(400).json({ error: 'missing_client' });
  const { rows } = await query(
    `SELECT DISTINCT ON (sentence_idx) sentence_idx, score, heard, audio_path, created_at,
            max(score) OVER (PARTITION BY sentence_idx) AS best, count(*) OVER (PARTITION BY sentence_idx)::int AS tries
       FROM attempts WHERE client_id = $1 AND lesson_id = $2
      ORDER BY sentence_idx, created_at DESC`,
    [clientId, Number(req.params.id)],
  );
  res.json(rows.map(formatAttempt));
});

function formatAttempt({ audio_path, sentence_idx, created_at, ...r }) {
  return { ...r, sentenceIdx: sentence_idx, createdAt: created_at, audioUrl: audio_path ? `${PUBLIC_URL}/uploads/${audio_path}` : null };
}

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'internal', message: err.message });
});

app.listen(PORT, () => console.log(`API listening on :${PORT}`));
