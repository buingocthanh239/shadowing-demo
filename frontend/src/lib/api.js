// VITE_API_URL="" khi build cho Docker/Traefik (API cùng domain)
export const API_URL = import.meta.env.VITE_API_URL ?? 'http://localhost:4100';

async function request(path, options) {
  const res = await fetch(`${API_URL}${path}`, options);
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
  return res.json();
}

export const getTopics = () => request('/api/topics');
export const getTopic = (slug) => request(`/api/topics/${slug}`);
export const getLesson = (topic, lesson) => request(`/api/topics/${topic}/lessons/${lesson}`);
export const getProgress = (lessonId) => request(`/api/lessons/${lessonId}/progress?clientId=${clientId()}`);

export function saveAttempt({ lessonId, sentenceIdx, score, heard, blob }) {
  const form = new FormData();
  form.append('clientId', clientId());
  form.append('lessonId', lessonId);
  form.append('sentenceIdx', sentenceIdx);
  form.append('score', score);
  form.append('heard', heard || '');
  if (blob?.size) form.append('audio', blob, 'rec.webm');
  return request('/api/attempts', { method: 'POST', body: form });
}

// Demo chưa có đăng nhập: định danh trình duyệt bằng 1 id ngẫu nhiên
export function clientId() {
  try {
    let id = localStorage.getItem('sd.clientId');
    if (!id) localStorage.setItem('sd.clientId', (id = crypto.randomUUID()));
    return id;
  } catch {
    return 'anonymous';
  }
}

export function formatTime(sec = 0) {
  const s = Math.max(0, Math.floor(sec));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

export const getLanguages = () => request('/api/languages');
export const getTranslations = (lessonId, lang) => request(`/api/lessons/${lessonId}/translations?lang=${encodeURIComponent(lang)}`);
export async function translateLesson(lessonId, lang) {
  const res = await fetch(`${API_URL}/api/lessons/${lessonId}/translations`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ lang }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(body.message || body.error || res.statusText);
  return body;
}

// Lưu tuỳ chọn hiển thị của người xem (ngôn ngữ dịch, bật IPA)
export function pref(key, fallback) {
  try {
    const v = localStorage.getItem(`sd.${key}`);
    return v == null ? fallback : JSON.parse(v);
  } catch {
    return fallback;
  }
}
export function setPref(key, value) {
  try {
    localStorage.setItem(`sd.${key}`, JSON.stringify(value));
  } catch {}
}
