import { useEffect, useState } from 'react';
import { getTranslations, translateLesson } from './api.js';

/**
 * Bản dịch câu của 1 bài theo ngôn ngữ.
 * Đọc cache trên server trước; nếu còn câu chưa dịch thì gọi server dịch máy (lần đầu có thể mất vài giây).
 * lang = 'off' -> không tải.
 */
export function useTranslations(lessonId, lang) {
  const [state, setState] = useState({ items: {}, status: 'idle', error: null });

  useEffect(() => {
    if (!lessonId || !lang || lang === 'off') return setState({ items: {}, status: 'idle', error: null });
    let alive = true;
    setState({ items: {}, status: 'loading', error: null });
    (async () => {
      try {
        let data = await getTranslations(lessonId, lang);
        if (!alive) return;
        if (data.missing > 0) {
          setState({ items: data.items, status: 'translating', error: null });
          data = await translateLesson(lessonId, lang);
          if (!alive) return;
        }
        setState({ items: data.items, status: 'ready', error: null });
      } catch (e) {
        if (alive) setState((s) => ({ ...s, status: 'error', error: e.message }));
      }
    })();
    return () => {
      alive = false;
    };
  }, [lessonId, lang]);

  return state;
}
