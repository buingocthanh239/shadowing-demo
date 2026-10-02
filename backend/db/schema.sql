DROP TABLE IF EXISTS attempts, study_items, sentence_translations, sentences, lessons, topics, languages, pronunciations CASCADE;

-- Ngôn ngữ dịch hỗ trợ. code theo BCP-47 (vi, ja, zh-Hans...). Thêm ngôn ngữ = thêm 1 dòng.
CREATE TABLE languages (
  code        TEXT PRIMARY KEY,
  name        TEXT NOT NULL,          -- tên tiếng Anh
  native_name TEXT NOT NULL,          -- tên hiển thị: 日本語, 한국어...
  position    INT NOT NULL DEFAULT 0,
  enabled     BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE topics (
  id          SERIAL PRIMARY KEY,
  slug        TEXT UNIQUE NOT NULL,
  title       TEXT NOT NULL,
  level       TEXT,
  description TEXT,
  position    INT NOT NULL DEFAULT 0
);

CREATE TABLE lessons (
  id         SERIAL PRIMARY KEY,
  topic_id   INT NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
  slug       TEXT NOT NULL,
  title      TEXT NOT NULL,
  level      TEXT,
  accent     TEXT,
  type       TEXT,
  lang       TEXT NOT NULL DEFAULT 'en-US',
  duration   REAL,
  audio_path TEXT NOT NULL,   -- tương đối với /media
  image_path TEXT,
  position   INT NOT NULL DEFAULT 0,
  UNIQUE (topic_id, slug)
);

-- Mỗi câu có timestamp + timestamp từng từ (JSONB [{text,start}]) để highlight karaoke
CREATE TABLE sentences (
  id             SERIAL PRIMARY KEY,
  lesson_id      INT NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  idx            INT NOT NULL,
  start_sec      REAL NOT NULL,
  duration_sec   REAL NOT NULL,
  text           TEXT NOT NULL,
  speaker        TEXT,
  words          JSONB NOT NULL DEFAULT '[]',
  UNIQUE (lesson_id, idx)
);

-- Bản dịch câu theo ngôn ngữ. source: original (có sẵn từ nguồn) | machine:<provider> | manual
CREATE TABLE sentence_translations (
  sentence_id INT NOT NULL REFERENCES sentences(id) ON DELETE CASCADE,
  lang        TEXT NOT NULL REFERENCES languages(code) ON UPDATE CASCADE,
  text        TEXT NOT NULL,
  source      TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (sentence_id, lang)
);
CREATE INDEX sentence_translations_lang ON sentence_translations (lang);

-- Từ điển phát âm dùng chung cho mọi bài. word đã chuẩn hoá (lowercase, bỏ dấu câu).
-- accent cho phép thêm giọng khác (en-GB...) sau này.
CREATE TABLE pronunciations (
  word   TEXT NOT NULL,
  accent TEXT NOT NULL DEFAULT 'en-US',
  ipa    TEXT NOT NULL,
  source TEXT NOT NULL,             -- cmudict | manual | ...
  PRIMARY KEY (word, accent)
);

-- vocab | phrase | idiom | grammar
CREATE TABLE study_items (
  id        SERIAL PRIMARY KEY,
  lesson_id INT NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  kind      TEXT NOT NULL,
  position  INT NOT NULL DEFAULT 0,
  data      JSONB NOT NULL
);

-- Một lần người học shadow 1 câu (demo: chưa có user, gom theo client_id)
CREATE TABLE attempts (
  id           SERIAL PRIMARY KEY,
  client_id    TEXT NOT NULL,
  lesson_id    INT NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  sentence_idx INT NOT NULL,
  score        INT NOT NULL,
  heard        TEXT,
  audio_path   TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX attempts_lookup ON attempts (client_id, lesson_id, sentence_idx);
