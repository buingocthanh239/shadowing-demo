// Lấy một phần dữ liệu mẫu từ tryshadowing.com về local để demo.
// Chỉ dùng cho mục đích tham khảo / demo nội bộ — không deploy công khai dữ liệu này.
//
// Usage: node scripts/scrape.js [topicSlug ...]
//   mặc định: news-current coffee-shop airport
//   node scripts/scrape.js --all   -> tất cả topic trên trang chủ

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const DATA_DIR = path.join(ROOT, 'data');
const MEDIA_DIR = path.join(ROOT, 'media');
const BASE = 'https://tryshadowing.com';
const UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126 Safari/537.36';

const topics = process.argv.slice(2).length ? process.argv.slice(2) : ['news-current', 'coffee-shop', 'airport'];

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function get(url) {
  const res = await fetch(url, { headers: { 'User-Agent': UA } });
  if (!res.ok) throw new Error(`${res.status} ${url}`);
  return res;
}

const decodeEntities = (s) =>
  s.replace(/&amp;/g, '&').replace(/&#x27;/g, "'").replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>');

// Ghép các mảnh RSC payload (self.__next_f.push([1,"..."])) thành 1 chuỗi
function rscPayload(html) {
  const re = /self\.__next_f\.push\(\[1,"((?:[^"\\]|\\.)*)"\]\)/g;
  let out = '';
  for (const m of html.matchAll(re)) out += JSON.parse(`"${m[1]}"`);
  return out;
}

// Lấy object JSON bắt đầu tại vị trí `start` (ký tự '{'), có xử lý chuỗi
function extractObject(text, start) {
  let depth = 0, inStr = false, esc = false;
  for (let i = start; i < text.length; i++) {
    const c = text[i];
    if (inStr) {
      if (esc) esc = false;
      else if (c === '\\') esc = true;
      else if (c === '"') inStr = false;
      continue;
    }
    if (c === '"') inStr = true;
    else if (c === '{') depth++;
    else if (c === '}' && --depth === 0) return JSON.parse(text.slice(start, i + 1));
  }
  throw new Error('unterminated object');
}

function findObjectWithKey(text, marker) {
  const i = text.indexOf(marker);
  return i < 0 ? null : extractObject(text, i);
}

async function download(url, dest) {
  try {
    await fs.access(dest);
    return; // đã có
  } catch {}
  const res = await get(url);
  await fs.mkdir(path.dirname(dest), { recursive: true });
  await fs.writeFile(dest, Buffer.from(await res.arrayBuffer()));
}

async function scrapeTopic(slug) {
  const html = await (await get(`${BASE}/vi/topics/${slug}`)).text();
  const titleTag = decodeEntities(html.match(/<title>([^<]+)<\/title>/)[1]);
  const title = titleTag.split(' — ')[0].trim();
  const level = (titleTag.match(/\(([ABC][12](?:[–-][ABC][12])?)\)/) || [])[1] || null;
  const description = decodeEntities((html.match(/<meta name="description" content="([^"]+)"/) || [])[1] || '');

  const lessonSlugs = [...new Set([...html.matchAll(new RegExp(`href="/vi/topics/${slug}/([a-z0-9-]+)"`, 'g'))].map((m) => m[1]))];
  console.log(`\n# ${title} (${level}) — ${lessonSlugs.length} bài`);

  const lessons = [];
  for (const [position, lslug] of lessonSlugs.entries()) {
    try {
      lessons.push({ position, ...(await scrapeLesson(slug, lslug)) });
    } catch (e) {
      console.warn(`  ! bỏ qua ${lslug}: ${e.message}`);
    }
    await sleep(400); // lịch sự với server
  }
  // Giữ đúng thứ tự hiển thị trên trang topic
  return { slug, title, level, description, lessons };
}

async function scrapeLesson(topicSlug, slug) {
  const html = await (await get(`${BASE}/vi/topics/${topicSlug}/${slug}`)).text();
  const rsc = rscPayload(html);

  const player = findObjectWithKey(rsc, '{"videoId":');
  if (!player?.initial?.sentences) throw new Error('không tìm thấy dữ liệu câu');
  const study = findObjectWithKey(rsc, '{"study":')?.study ?? {};

  const tags = [...(html.match(/<div class="lesson-tags">([\s\S]*?)<\/div>/)?.[1] ?? '').matchAll(/<span[^>]*>([^<]+)<\/span>/g)].map((m) =>
    decodeEntities(m[1]).trim(),
  );
  const [level = null, accent = null, typeLabel = null] = tags;

  const audioFile = `${topicSlug}/${slug}.mp3`;
  const imageFile = `${topicSlug}/${slug}.jpg`;
  await download(player.audioUrl, path.join(MEDIA_DIR, audioFile));
  if (player.poster) await download(player.poster, path.join(MEDIA_DIR, imageFile)).catch(() => {});

  console.log(`  ✓ ${player.lessonTitle} — ${player.initial.sentences.length} câu`);
  return {
    slug,
    title: player.lessonTitle,
    level,
    accent,
    type: typeLabel,
    lang: player.recLang || 'en-US',
    duration: player.audioDuration,
    audio: audioFile,
    image: imageFile,
    sentences: player.initial.sentences.map((s) => ({
      idx: s.index,
      start: s.start,
      duration: s.duration,
      text: s.text,
      speaker: s.speaker ?? null,
      vi: s.vi ?? null,
      words: s.words ?? [],
    })),
    study: {
      vocab: study.vocab ?? [],
      phrases: study.phrases ?? [],
      idioms: study.idioms ?? [],
      grammar: study.grammar ?? [],
    },
  };
}

async function discoverTopics() {
  const html = await (await get(`${BASE}/vi`)).text();
  return [...new Set([...html.matchAll(/href="\/vi\/topics\/([a-z0-9-]+)"/g)].map((m) => m[1]))];
}

await fs.mkdir(DATA_DIR, { recursive: true });
const outFile = path.join(DATA_DIR, 'topics.json');

// Gộp với dữ liệu đã có: topic scrape lại sẽ được thay thế, topic khác giữ nguyên
let existing = [];
try {
  existing = JSON.parse(await fs.readFile(outFile, 'utf8'));
} catch {}
const bySlug = new Map(existing.map((t) => [t.slug, t]));
const slugs = topics.includes('--all') ? await discoverTopics() : topics;
console.log(`Sẽ lấy ${slugs.length} topic`);

for (const t of slugs) {
  try {
    bySlug.set(t, await scrapeTopic(t));
    await fs.writeFile(outFile, JSON.stringify([...bySlug.values()], null, 2)); // lưu dần
  } catch (e) {
    console.warn(`! topic ${t}: ${e.message}`);
  }
}
const all = [...bySlug.values()];
console.log(`\nĐã lưu data/topics.json: ${all.length} topic, ${all.reduce((n, t) => n + t.lessons.length, 0)} bài`);
