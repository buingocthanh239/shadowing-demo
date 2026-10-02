import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { getTopics } from '../lib/api.js';

const LEVELS = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

export default function Home() {
  const [topics, setTopics] = useState(null);
  const [error, setError] = useState(null);
  const [q, setQ] = useState('');
  const [level, setLevel] = useState(null);
  useEffect(() => {
    getTopics().then(setTopics).catch((e) => setError(e.message));
  }, []);

  const levels = useMemo(() => LEVELS.filter((l) => topics?.some((t) => t.level?.includes(l))), [topics]);
  const shown = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return (topics ?? []).filter(
      (t) =>
        (!level || t.level?.includes(level)) &&
        (!needle || t.title.toLowerCase().includes(needle) || t.description?.toLowerCase().includes(needle)),
    );
  }, [topics, q, level]);

  if (error) return <p className="notice error">Không kết nối được API: {error}</p>;
  if (!topics) return <p className="muted">Đang tải…</p>;

  const totalLessons = topics.reduce((n, t) => n + t.lesson_count, 0);

  return (
    <>
      <h1>Chủ đề</h1>
      <p className="muted">
        {topics.length} chủ đề · {totalLessons} bài. Nghe câu mẫu → nhại lại → được chấm điểm từng từ.
      </p>
      <div className="filters">
        <input className="search" placeholder="Tìm chủ đề…" value={q} onChange={(e) => setQ(e.target.value)} />
        <button className={`tab ${!level ? 'on' : ''}`} onClick={() => setLevel(null)}>Tất cả</button>
        {levels.map((l) => (
          <button key={l} className={`tab ${level === l ? 'on' : ''}`} onClick={() => setLevel(level === l ? null : l)}>
            {l}
          </button>
        ))}
      </div>
      {!shown.length && <p className="muted">Không có chủ đề phù hợp.</p>}
      <div className="grid">
        {shown.map((t) => (
          <Link key={t.slug} to={`/topics/${t.slug}`} className="card tile">
            {t.cover && <img src={t.cover} alt="" loading="lazy" />}
            <div className="tile-body">
              <div className="tags">
                {t.level && <span className="tag accent">{t.level}</span>}
                <span className="tag">{t.lesson_count} bài</span>
              </div>
              <h3>{t.title}</h3>
              <p className="muted small clamp">{t.description}</p>
            </div>
          </Link>
        ))}
      </div>
    </>
  );
}
