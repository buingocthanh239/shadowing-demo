// Tạo schema và nạp data/topics.json vào Postgres.
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { pool } from '../src/db.js';
import { LANGUAGES } from '../src/languages.js';
import { ipaFor, normalizeWord } from '../src/ipa.js';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

const schema = await fs.readFile(path.join(ROOT, 'db/schema.sql'), 'utf8');
const topics = JSON.parse(await fs.readFile(path.join(ROOT, 'data/topics.json'), 'utf8'));

const STUDY_KINDS = { vocab: 'vocab', phrases: 'phrase', idioms: 'idiom', grammar: 'grammar' };

const client = await pool.connect();

// --if-empty: chỉ seed khi DB chưa có dữ liệu (dùng khi container khởi động)
if (process.argv.includes('--if-empty')) {
  const { rows: [r] } = await client.query(
    "SELECT to_regclass('public.topics') IS NOT NULL AS has",
  );
  const seeded = r.has && (await client.query('SELECT count(*)::int AS n FROM topics')).rows[0].n > 0;
  if (seeded) {
    console.log('DB đã có dữ liệu, bỏ qua seed');
    client.release();
    await pool.end();
    process.exit(0);
  }
}

// schema.sql DROP toàn bộ bảng -> không cho reset khi đã có dữ liệu luyện tập của người dùng
if (!process.argv.includes('--force')) {
  const { rows: [r] } = await client.query("SELECT to_regclass('public.attempts') IS NOT NULL AS has");
  const n = r.has ? (await client.query('SELECT count(*)::int AS n FROM attempts')).rows[0].n : 0;
  if (n > 0) {
    console.error(`DB đang có ${n} lần luyện tập (attempts). Seed sẽ xoá hết. Chạy lại với --force nếu chắc chắn.`);
    client.release();
    await pool.end();
    process.exit(1);
  }
}

try {
  await client.query('BEGIN');
  await client.query(schema);

  for (const [pos, l] of LANGUAGES.entries()) {
    await client.query('INSERT INTO languages (code, name, native_name, position) VALUES ($1,$2,$3,$4)', [l.code, l.name, l.nativeName, pos]);
  }
  const words = new Set();

  for (const [tpos, t] of topics.entries()) {
    const { rows: [topic] } = await client.query(
      'INSERT INTO topics (slug, title, level, description, position) VALUES ($1,$2,$3,$4,$5) RETURNING id',
      [t.slug, t.title, t.level, t.description, tpos],
    );
    for (const l of t.lessons) {
      const { rows: [lesson] } = await client.query(
        `INSERT INTO lessons (topic_id, slug, title, level, accent, type, lang, duration, audio_path, image_path, position)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING id`,
        [topic.id, l.slug, l.title, l.level, l.accent, l.type, l.lang, l.duration, l.audio, l.image, l.position],
      );
      for (const s of l.sentences) {
        const { rows: [sentence] } = await client.query(
          `INSERT INTO sentences (lesson_id, idx, start_sec, duration_sec, text, speaker, words)
           VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
          [lesson.id, s.idx, s.start, s.duration, s.text, s.speaker, JSON.stringify(s.words)],
        );
        // Bản dịch tiếng Việt có sẵn từ nguồn
        if (s.vi) {
          await client.query(
            "INSERT INTO sentence_translations (sentence_id, lang, text, source) VALUES ($1, 'vi', $2, 'original')",
            [sentence.id, s.vi],
          );
        }
        for (const w of s.words) words.add(normalizeWord(w.text));
      }
      for (const [key, kind] of Object.entries(STUDY_KINDS)) {
        for (const [pos, item] of (l.study[key] ?? []).entries()) {
          await client.query('INSERT INTO study_items (lesson_id, kind, position, data) VALUES ($1,$2,$3,$4)', [
            lesson.id, kind, pos, JSON.stringify(item),
          ]);
        }
      }
    }
    console.log(`✓ ${t.title}: ${t.lessons.length} bài`);
  }

  // Từ điển phát âm cho mọi từ xuất hiện trong các câu
  const entries = [...words].map((w) => [w, ipaFor(w)]).filter(([, ipa]) => ipa);
  await client.query(
    `INSERT INTO pronunciations (word, accent, ipa, source)
     SELECT unnest($1::text[]), 'en-US', unnest($2::text[]), 'cmudict'`,
    [entries.map((e) => e[0]), entries.map((e) => e[1])],
  );
  console.log(`✓ Phát âm: ${entries.length}/${words.size} từ có IPA`);

  await client.query('COMMIT');
} catch (e) {
  await client.query('ROLLBACK');
  throw e;
} finally {
  client.release();
  await pool.end();
}
