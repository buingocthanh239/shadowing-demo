// Dịch sẵn hàng loạt (để người dùng mở bài là có ngay, không phải chờ dịch máy).
// Usage: node scripts/translate.js ja ko [--topic news-current]
//   Trong Docker: docker compose exec backend node scripts/translate.js ja ko
import { pool, query } from '../src/db.js';
import { translateLesson } from '../src/translations.js';

const args = process.argv.slice(2);
const topicIdx = args.indexOf('--topic');
const topic = topicIdx >= 0 ? args.splice(topicIdx, 2)[1] : null;
const langs = args;
if (!langs.length) {
  console.error('Usage: node scripts/translate.js <lang...> [--topic slug]');
  process.exit(1);
}

const { rows: lessons } = await query(
  `SELECT l.id, t.slug AS topic, l.slug FROM lessons l JOIN topics t ON t.id = l.topic_id
    WHERE $1::text IS NULL OR t.slug = $1 ORDER BY t.position, l.position`,
  [topic],
);

for (const lang of langs) {
  let done = 0, sentences = 0;
  const started = Date.now();
  for (const l of lessons) {
    try {
      sentences += await translateLesson(l.id, lang);
    } catch (e) {
      console.error(`\n! ${lang} ${l.topic}/${l.slug}: ${e.message}`);
      if (e.code) process.exit(1); // lỗi cấu hình (ngôn ngữ / provider) -> dừng
    }
    process.stdout.write(`\r[${lang}] ${++done}/${lessons.length} bài · ${sentences} câu mới`);
  }
  console.log(` · ${((Date.now() - started) / 1000).toFixed(0)}s`);
}
await pool.end();
