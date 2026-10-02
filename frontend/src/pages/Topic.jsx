import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { formatTime, getTopic } from '../lib/api.js';

export default function Topic() {
  const { topic: slug } = useParams();
  const [topic, setTopic] = useState(null);
  const [error, setError] = useState(null);
  useEffect(() => {
    getTopic(slug).then(setTopic).catch((e) => setError(e.message));
  }, [slug]);

  if (error) return <p className="notice error">{error}</p>;
  if (!topic) return <p className="muted">Đang tải…</p>;

  return (
    <>
      <nav className="crumbs"><Link to="/">Chủ đề</Link> / {topic.title}</nav>
      <h1>{topic.title} {topic.level && <span className="tag accent">{topic.level}</span>}</h1>
      <p className="muted">{topic.description}</p>
      <div className="grid">
        {topic.lessons.map((l, i) => (
          <Link key={l.slug} to={`/topics/${topic.slug}/${l.slug}`} className="card tile">
            {l.image && <img src={l.image} alt="" loading="lazy" />}
            <div className="tile-body">
              <div className="tags">
                <span className="tag">#{i + 1}</span>
                {l.level && <span className="tag accent">{l.level}</span>}
                {l.type && <span className="tag">{l.type}</span>}
              </div>
              <h3>{l.title}</h3>
              <p className="muted small">{l.sentence_count} câu · {formatTime(l.duration)}</p>
            </div>
          </Link>
        ))}
      </div>
    </>
  );
}
