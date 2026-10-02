import { useEffect, useRef, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { formatTime, getLanguages, getLesson, pref, setPref } from '../lib/api.js';
import { useTranslations } from '../lib/useTranslations.js';
import { micSupported, speechSupported } from '../lib/recorder.js';
import { useShadowing } from '../lib/useShadowing.js';
import StudyPanel from '../components/StudyPanel.jsx';

const RATES = [0.5, 0.75, 0.9, 1, 1.25];

export default function Lesson() {
  const { topic, lesson: lessonSlug } = useParams();
  const [lesson, setLesson] = useState(null);
  const [loadError, setLoadError] = useState(null);
  const [languages, setLanguages] = useState([]);
  const [lang, setLangState] = useState(() => pref('lang', 'vi'));
  const [showIpa, setShowIpaState] = useState(() => pref('ipa', true));
  const setLang = (v) => (setLangState(v), setPref('lang', v));
  const setShowIpa = (v) => (setShowIpaState(v), setPref('ipa', v));

  useEffect(() => {
    getLanguages().then(setLanguages).catch(() => {});
  }, []);

  useEffect(() => {
    setLesson(null);
    getLesson(topic, lessonSlug).then(setLesson).catch((e) => setLoadError(e.message));
  }, [topic, lessonSlug]);

  const sh = useShadowing(lesson);
  const tr = useTranslations(lesson?.id, lang);
  const view = { lang, tr, showIpa };
  const langName = languages.find((l) => l.code === lang)?.nativeName ?? lang;
  useKeyboard(sh);

  if (loadError) return <p className="muted">Không tải được bài: {loadError}</p>;
  if (!lesson) return <p className="muted">Đang tải…</p>;

  return (
    <div className="lesson">
      <nav className="crumbs">
        <Link to="/">Chủ đề</Link> / <Link to={`/topics/${lesson.topic.slug}`}>{lesson.topic.title}</Link>
      </nav>
      <header className="lesson-head">
        <div>
          <h1>{lesson.title}</h1>
          <div className="tags">
            {lesson.level && <span className="tag accent">{lesson.level}</span>}
            {lesson.accent && <span className="tag">{lesson.accent}</span>}
            {lesson.type && <span className="tag">{lesson.type}</span>}
            <span className="tag">{lesson.sentences.length} câu</span>
          </div>
        </div>
        <div className="prevnext">
          {lesson.prev && <Link className="btn ghost" to={`/topics/${lesson.topic.slug}/${lesson.prev.slug}`}>‹ Bài trước</Link>}
          {lesson.next && <Link className="btn ghost" to={`/topics/${lesson.topic.slug}/${lesson.next.slug}`}>Bài sau ›</Link>}
        </div>
      </header>

      <audio ref={sh.audioRef} src={lesson.audioUrl} preload="auto" />

      <PlayerBar
        sh={sh}
        duration={lesson.duration}
        languages={languages}
        lang={lang}
        setLang={setLang}
        showIpa={showIpa}
        setShowIpa={setShowIpa}
      />

      {(!speechSupported || !micSupported) && (
        <p className="notice">
          {!micSupported
            ? 'Trình duyệt không hỗ trợ ghi âm.'
            : 'Chấm điểm phát âm chưa hỗ trợ trên trình duyệt này (cần Chrome/Edge) — bạn vẫn ghi âm & nghe lại được.'}
        </p>
      )}
      {tr.status === 'translating' && <p className="notice info">Đang dịch bài sang {langName}… (chỉ lần đầu)</p>}
      {tr.status === 'error' && <p className="notice error">Chưa dịch được sang {langName}: {tr.error}</p>}
      {sh.error && (
        <p className="notice error" onClick={() => sh.setError(null)}>
          {sh.error}
        </p>
      )}

      <div className="lesson-grid">
        <FocusCard sh={sh} view={view} />
        <SentenceList sh={sh} view={view} />
      </div>

      <StudyPanel study={lesson.study} />
    </div>
  );
}

function PlayerBar({ sh, duration, languages, lang, setLang, showIpa, setShowIpa }) {
  const total = sh.audioRef.current?.duration || duration || 0;
  return (
    <div className="player">
      <button className="btn round primary" onClick={sh.togglePlayAll} title="Nghe cả bài">
        {sh.playing ? '❚❚' : '▶'}
      </button>
      <span className="time">{formatTime(sh.time)}</span>
      <input
        className="seek"
        type="range"
        min={0}
        max={total || 1}
        step={0.1}
        value={Math.min(sh.time, total || 1)}
        onChange={(e) => sh.seek(Number(e.target.value))}
      />
      <span className="time">{formatTime(total)}</span>
      <select value={sh.rate} onChange={(e) => sh.setRate(Number(e.target.value))} title="Tốc độ">
        {RATES.map((r) => (
          <option key={r} value={r}>{r}x</option>
        ))}
      </select>
      <label className="toggle">
        Dịch
        <select value={lang} onChange={(e) => setLang(e.target.value)} title="Ngôn ngữ dịch">
          <option value="off">Tắt</option>
          {languages.map((l) => (
            <option key={l.code} value={l.code}>
              {l.nativeName}{!l.original ? ' · máy' : ''}
            </option>
          ))}
          {!languages.some((l) => l.code === lang) && lang !== 'off' && <option value={lang}>{lang}</option>}
        </select>
      </label>
      <label className="toggle" title="Phiên âm IPA (US)">
        <input type="checkbox" checked={showIpa} onChange={(e) => setShowIpa(e.target.checked)} /> IPA
      </label>
      <label className="toggle" title="Tự chuyển sang câu tiếp theo khi shadow">
        <input type="checkbox" checked={sh.continuous} onChange={(e) => sh.setContinuous(e.target.checked)} /> Liên tục
      </label>
    </div>
  );
}

function FocusCard({ sh, view }) {
  const i = sh.current;
  const s = sh.sentences[i];
  const result = sh.results[i];
  if (!s) return null;
  const busy = sh.phase !== 'idle';
  const words = s.words?.length ? s.words : s.text.split(/\s+/).map((text) => ({ text }));
  const translation = view.tr.items[s.idx];
  const showResultColors = result?.words && sh.phase === 'idle' && !sh.playing;

  return (
    <section className="focus card">
      <div className="focus-meta">
        <span>Câu {i + 1} / {sh.sentences.length}</span>
        {s.speaker && <span className="speaker">{s.speaker}</span>}
        <span className="muted">{formatTime(s.start)}</span>
      </div>

      <p className={`focus-text ${view.showIpa ? 'with-ipa' : ''}`}>
        {words.map((w, wi) => {
          const cls = ['word'];
          if (wi === sh.wordIdx) cls.push('active');
          else if (sh.wordIdx > wi) cls.push('spoken');
          if (showResultColors) cls.push(result.words[wi]?.correct === false ? 'wrong' : 'right');
          return (
            <span key={wi} className={cls.join(' ')} onClick={() => sh.playWord(i, wi)} title={w.ipa ? `/${w.ipa}/` : 'Nghe từ này'}>
              <span className="w">{w.text}</span>
              {view.showIpa && <span className="ipa">{w.ipa ? `/${w.ipa}/` : '\u00a0'}</span>}
            </span>
          );
        })}
      </p>
      {view.lang !== 'off' && (
        <p className="focus-vi" lang={view.lang}>
          {translation ?? (view.tr.status === 'loading' || view.tr.status === 'translating' ? '…' : '')}
        </p>
      )}

      <div className="controls">
        <button className="btn" disabled={i === 0 || busy} onClick={() => sh.setCurrent(i - 1)} title="Câu trước (←)">⏮</button>
        <button className="btn" disabled={sh.phase === 'recording'} onClick={() => sh.playSentence(i)} title="Nghe câu (Space)">
          🔊 Nghe
        </button>
        {sh.phase === 'recording' ? (
          <button className="btn danger" onClick={sh.cancel}>■ Dừng</button>
        ) : (
          <button className="btn" disabled={busy || !micSupported} onClick={() => sh.record(i)} title="Tự ghi âm (R)">
            🎙 Ghi âm
          </button>
        )}
        <button className="btn primary" disabled={busy || !micSupported} onClick={() => sh.shadow(i)} title="Nghe rồi nhại lại (S)">
          ⚡ Shadow
        </button>
        <button className="btn" disabled={i === sh.sentences.length - 1 || busy} onClick={() => sh.setCurrent(i + 1)} title="Câu sau (→)">⏭</button>
      </div>

      <Status sh={sh} />

      {result && sh.phase === 'idle' && (
        <div className="result">
          {result.score != null && <ScoreRing score={result.score} />}
          <div className="result-body">
            {result.heard != null && (
              <p>
                <span className="muted">Bạn nói: </span>
                {result.heard || <em className="muted">(không nghe được gì)</em>}
              </p>
            )}
            {result.tries > 0 && (
              <p className="muted small">Cao nhất {result.best} · {result.tries} lần thử</p>
            )}
            {result.audioUrl && <audio className="my-audio" controls src={result.audioUrl} />}
          </div>
        </div>
      )}
    </section>
  );
}

function Status({ sh }) {
  const [, force] = useState(0);
  useEffect(() => {
    if (!sh.recordWindow) return;
    const id = setInterval(() => force((n) => n + 1), 100);
    return () => clearInterval(id);
  }, [sh.recordWindow]);

  if (sh.phase === 'listening') return <p className="status">🎧 Nghe câu mẫu…</p>;
  if (sh.phase === 'scoring') return <p className="status">⏳ Đang chấm điểm…</p>;
  if (sh.phase !== 'recording') return null;
  const w = sh.recordWindow;
  const pct = w ? Math.min(100, ((performance.now() - w.startedAt) / w.ms) * 100) : null;
  return (
    <div className="status recording">
      <span className="dot" /> Đang ghi âm — hãy nói lại câu trên{!w && ', bấm Dừng khi xong'}
      {pct != null && (
        <div className="countdown"><div style={{ width: `${pct}%` }} /></div>
      )}
    </div>
  );
}

function ScoreRing({ score }) {
  const color = score >= 85 ? 'var(--good)' : score >= 60 ? 'var(--warn)' : 'var(--bad)';
  return (
    <div className="ring" style={{ '--p': score, '--c': color }}>
      <span>{score}</span>
    </div>
  );
}

function SentenceList({ sh, view }) {
  const listRef = useRef(null);
  useEffect(() => {
    listRef.current?.querySelector('.active')?.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
  }, [sh.current]);

  return (
    <section className="card list" ref={listRef}>
      <h3>Phụ đề</h3>
      {sh.sentences.map((s, i) => {
        const r = sh.results[i];
        const best = r?.best ?? r?.score;
        return (
          <button
            key={s.idx}
            className={`line ${i === sh.current ? 'active' : ''}`}
            onClick={() => sh.phase !== 'recording' && sh.playSentence(i)}
          >
            <span className="line-time">{formatTime(s.start)}</span>
            <span className="line-body">
              {s.speaker && <b className="speaker">{s.speaker}: </b>}
              {s.text}
              {view.lang !== 'off' && view.tr.items[s.idx] && (
                <span className="line-vi" lang={view.lang}>{view.tr.items[s.idx]}</span>
              )}
            </span>
            {best != null && <span className={`chip ${best >= 85 ? 'good' : best >= 60 ? 'warn' : 'bad'}`}>{best}</span>}
          </button>
        );
      })}
    </section>
  );
}

function useKeyboard(sh) {
  const ref = useRef(sh);
  ref.current = sh;
  useEffect(() => {
    const onKey = (e) => {
      if (e.target.closest('input, select, textarea') || e.metaKey || e.ctrlKey) return;
      const s = ref.current;
      const busy = s.phase !== 'idle';
      if (e.code === 'Space') {
        e.preventDefault();
        if (s.phase === 'recording') s.stopRecording();
        else s.playSentence(s.current);
      } else if (e.key === 'ArrowRight' && !busy) s.setCurrent(Math.min(s.current + 1, s.sentences.length - 1));
      else if (e.key === 'ArrowLeft' && !busy) s.setCurrent(Math.max(s.current - 1, 0));
      else if (e.key.toLowerCase() === 'r') s.phase === 'recording' ? s.stopRecording() : !busy && s.record(s.current);
      else if (e.key.toLowerCase() === 's' && !busy) s.shadow(s.current);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);
}
