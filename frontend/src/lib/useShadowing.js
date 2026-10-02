import { useCallback, useEffect, useRef, useState } from 'react';
import { startSession } from './recorder.js';
import { scoreSentence } from './scoring.js';
import { getProgress, saveAttempt } from './api.js';

// Điểm kết thúc của câu i: hết duration (+ chút đệm) nhưng không lấn sang câu sau
const segmentEnd = (sentences, i) => {
  const s = sentences[i];
  const next = sentences[i + 1];
  return Math.min(s.start + s.duration + 0.25, next ? next.start : Infinity);
};

const findSentence = (sentences, t) => {
  let found = 0;
  for (let i = 0; i < sentences.length; i++) if (t >= sentences[i].start - 0.2) found = i;
  return found;
};

const findWord = (sentence, t) => {
  if (!sentence?.words?.length || t < sentence.start - 0.15 || t > sentence.start + sentence.duration + 0.15) return -1;
  let found = -1;
  for (let i = 0; i < sentence.words.length; i++) {
    if (t >= sentence.words[i].start - 0.05) found = i;
    else break;
  }
  return found;
};

/**
 * Toàn bộ state + logic của màn shadowing:
 * phát audio theo câu, highlight karaoke, ghi âm, chấm điểm, lưu kết quả.
 */
export function useShadowing(lesson) {
  const sentences = lesson?.sentences ?? [];
  const audioRef = useRef(null);
  const rafRef = useRef(0);
  const stopAtRef = useRef(null); // giây: dừng phát khi tới mốc này
  const onStopRef = useRef(null); // callback khi phát hết đoạn
  const sessionRef = useRef(null);
  const runRef = useRef(0); // tăng lên để huỷ chuỗi auto-shadow đang chạy
  const currentRef = useRef(0);

  const [current, setCurrentState] = useState(0);
  const [wordIdx, setWordIdx] = useState(-1);
  const [time, setTime] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [rate, setRateState] = useState(1);
  const [phase, setPhase] = useState('idle'); // idle | listening | recording | scoring
  const [recordWindow, setRecordWindow] = useState(null); // { ms, startedAt } cho thanh đếm ngược
  const [results, setResults] = useState({}); // idx -> { score, words, heard, audioUrl, best, tries }
  const [continuous, setContinuous] = useState(false);
  const [error, setError] = useState(null);
  const continuousRef = useRef(continuous);
  continuousRef.current = continuous;

  const setCurrent = useCallback((i) => {
    currentRef.current = i;
    setCurrentState(i);
  }, []);

  // Tải tiến độ đã lưu trên server
  useEffect(() => {
    if (!lesson) return;
    setResults({});
    setCurrent(0);
    getProgress(lesson.id)
      .then((rows) => {
        const map = {};
        for (const r of rows) map[r.sentenceIdx] = { score: r.score, heard: r.heard, audioUrl: r.audioUrl, best: r.best, tries: r.tries };
        setResults(map);
      })
      .catch(() => {});
  }, [lesson, setCurrent]);

  // Vòng lặp rAF: đồng bộ câu/từ đang phát với currentTime
  const tick = useCallback(() => {
    const audio = audioRef.current;
    if (!audio) return;
    const t = audio.currentTime;
    setTime(t);

    if (stopAtRef.current == null) {
      const i = findSentence(sentences, t);
      if (i !== currentRef.current) setCurrent(i);
    }
    setWordIdx(findWord(sentences[currentRef.current], t));

    if (stopAtRef.current != null && t >= stopAtRef.current) {
      audio.pause();
      stopAtRef.current = null;
      setWordIdx(-1);
      const cb = onStopRef.current;
      onStopRef.current = null;
      cb?.();
      return;
    }
    if (!audio.paused) rafRef.current = requestAnimationFrame(tick);
  }, [sentences, setCurrent]);

  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;
    const onPlay = () => {
      setPlaying(true);
      cancelAnimationFrame(rafRef.current);
      rafRef.current = requestAnimationFrame(tick);
    };
    const onPause = () => setPlaying(false);
    audio.addEventListener('play', onPlay);
    audio.addEventListener('pause', onPause);
    audio.addEventListener('ended', onPause);
    return () => {
      cancelAnimationFrame(rafRef.current);
      audio.removeEventListener('play', onPlay);
      audio.removeEventListener('pause', onPause);
      audio.removeEventListener('ended', onPause);
    };
  }, [tick, lesson]);

  const playRange = useCallback((start, end, onDone) => {
    const audio = audioRef.current;
    if (!audio) return;
    audio.currentTime = start;
    stopAtRef.current = end;
    onStopRef.current = onDone ?? null;
    audio.play().catch((e) => setError(e.message));
  }, []);

  const cancel = useCallback(() => {
    runRef.current++;
    stopAtRef.current = null;
    onStopRef.current = null;
    audioRef.current?.pause();
    sessionRef.current?.stop();
    setPhase((p) => (p === 'listening' ? 'idle' : p));
  }, []);

  const playSentence = useCallback(
    (i, onDone) => {
      if (!sentences[i]) return;
      setCurrent(i);
      setPhase('listening');
      playRange(sentences[i].start, segmentEnd(sentences, i), () => {
        setPhase('idle');
        onDone?.();
      });
    },
    [sentences, playRange, setCurrent],
  );

  const playWord = useCallback(
    (sIdx, wIdx) => {
      const s = sentences[sIdx];
      const w = s?.words?.[wIdx];
      if (!w) return;
      const end = s.words[wIdx + 1]?.start ?? segmentEnd(sentences, sIdx);
      playRange(w.start, end + 0.05);
    },
    [sentences, playRange],
  );

  const togglePlayAll = useCallback(() => {
    const audio = audioRef.current;
    if (!audio) return;
    if (!audio.paused) return cancel();
    runRef.current++;
    stopAtRef.current = null;
    onStopRef.current = null;
    audio.play().catch((e) => setError(e.message));
  }, [cancel]);

  const seek = useCallback((t) => {
    const audio = audioRef.current;
    if (!audio) return;
    stopAtRef.current = null;
    audio.currentTime = t;
    setTime(t);
    setCurrent(findSentence(sentences, t));
  }, [sentences, setCurrent]);

  const setRate = useCallback((r) => {
    setRateState(r);
    if (audioRef.current) audioRef.current.playbackRate = r;
  }, []);

  /** Ghi âm câu i. autoStopMs: tự dừng sau khoảng thời gian (chế độ shadow tự động). */
  const record = useCallback(
    async (i, { autoStopMs } = {}) => {
      const s = sentences[i];
      if (!s || sessionRef.current) return null;
      setError(null);
      setCurrent(i);
      let session;
      try {
        session = await startSession(lesson.lang);
      } catch (e) {
        setError(e.name === 'NotAllowedError' ? 'Bạn chưa cho phép truy cập micro.' : `Không mở được micro: ${e.message}`);
        return null;
      }
      sessionRef.current = session;
      setPhase('recording');
      let timer;
      if (autoStopMs) {
        setRecordWindow({ ms: autoStopMs, startedAt: performance.now() });
        timer = setTimeout(session.stop, autoStopMs);
      }

      const { blob, transcript, speechError } = await session.done;
      clearTimeout(timer);
      sessionRef.current = null;
      setRecordWindow(null);
      setPhase('scoring');

      const audioUrl = blob ? URL.createObjectURL(blob) : null;
      const scored = speechError ? null : scoreSentence(s.text, transcript);
      if (speechError) {
        setError(
          speechError === 'unsupported'
            ? 'Trình duyệt không hỗ trợ nhận dạng giọng nói (dùng Chrome/Edge để được chấm điểm). Bạn vẫn nghe lại được bản ghi.'
            : `Lỗi nhận dạng giọng nói: ${speechError}`,
        );
      }

      setResults((prev) => {
        const old = prev[i] ?? {};
        return {
          ...prev,
          [i]: {
            ...old,
            ...(scored ?? {}),
            audioUrl,
            best: scored ? Math.max(old.best ?? 0, scored.score) : old.best,
            tries: scored ? (old.tries ?? 0) + 1 : old.tries,
          },
        };
      });
      setPhase('idle');

      if (scored) {
        saveAttempt({ lessonId: lesson.id, sentenceIdx: i, score: scored.score, heard: scored.heard, blob }).catch(() => {});
      }
      return scored;
    },
    [sentences, lesson, setCurrent],
  );

  const stopRecording = useCallback(() => sessionRef.current?.stop(), []);

  /** Shadow tự động: nghe câu mẫu -> ghi âm trong (độ dài câu + 1.5s) -> chấm -> (liên tục) sang câu sau */
  const shadow = useCallback(
    (i) => {
      const run = ++runRef.current;
      const step = (idx) => {
        playSentence(idx, async () => {
          if (run !== runRef.current) return;
          const s = sentences[idx];
          const ms = Math.max(2500, Math.round(((segmentEnd(sentences, idx) - s.start) / rate + 1.5) * 1000));
          await record(idx, { autoStopMs: ms });
          if (run !== runRef.current || !continuousRef.current || idx + 1 >= sentences.length) return;
          setTimeout(() => run === runRef.current && step(idx + 1), 1200);
        });
      };
      step(i);
    },
    [playSentence, record, sentences, rate],
  );

  return {
    audioRef, sentences, current, setCurrent, wordIdx, time, playing, rate, phase, recordWindow, results, error,
    continuous, setContinuous, setError,
    playSentence, playWord, togglePlayAll, seek, setRate, record, stopRecording, shadow, cancel,
  };
}
