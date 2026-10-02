import { useState } from 'react';

const TABS = [
  { key: 'vocab', label: 'Từ vựng' },
  { key: 'phrase', label: 'Cụm hữu ích' },
  { key: 'idiom', label: 'Thành ngữ' },
  { key: 'grammar', label: 'Ngữ pháp' },
];

const speak = (text) => {
  try {
    const u = new SpeechSynthesisUtterance(text);
    u.lang = 'en-US';
    speechSynthesis.cancel();
    speechSynthesis.speak(u);
  } catch {}
};

export default function StudyPanel({ study }) {
  const tabs = TABS.filter((t) => study?.[t.key]?.length);
  const [tab, setTab] = useState(tabs[0]?.key);
  if (!tabs.length) return null;
  const items = study[tab] ?? [];

  return (
    <section className="card study">
      <div className="tabs">
        {tabs.map((t) => (
          <button key={t.key} className={`tab ${t.key === tab ? 'on' : ''}`} onClick={() => setTab(t.key)}>
            {t.label} <span className="muted">{study[t.key].length}</span>
          </button>
        ))}
      </div>
      <ul className="study-list">
        {items.map((it, i) => {
          const head = it.term || it.expr || it.idiom || it.point;
          return (
            <li key={i}>
              <div className="study-head">
                <button className="icon" onClick={() => speak(tab === 'grammar' ? it.example : head)} title="Nghe">🔈</button>
                <b>{head}</b>
                {it.pos && <span className="tag">{it.pos}</span>}
                <span className="study-vi">— {it.vi}</span>
              </div>
              <p className="muted small">{it.en}</p>
              {it.example && <p className="example">“{it.example}”</p>}
            </li>
          );
        })}
      </ul>
    </section>
  );
}
