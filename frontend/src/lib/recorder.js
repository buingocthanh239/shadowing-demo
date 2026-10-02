// Ghi âm (MediaRecorder) + nhận dạng giọng nói (Web Speech API) chạy song song.

const SpeechRecognition = typeof window !== 'undefined' && (window.SpeechRecognition || window.webkitSpeechRecognition);

export const speechSupported = Boolean(SpeechRecognition);
export const micSupported = typeof navigator !== 'undefined' && Boolean(navigator.mediaDevices?.getUserMedia);

/**
 * Bắt đầu một phiên ghi. Trả về { stop, done }:
 *  - stop(): dừng ghi
 *  - done: Promise<{ blob: Blob|null, transcript: string, speechError: string|null }>
 */
export async function startSession(lang = 'en-US') {
  const stream = await navigator.mediaDevices.getUserMedia({ audio: true });

  // 1) MediaRecorder -> Blob để nghe lại / upload
  const chunks = [];
  const recorder = new MediaRecorder(stream);
  recorder.ondataavailable = (e) => e.data.size > 0 && chunks.push(e.data);
  const recorded = new Promise((resolve) => {
    recorder.onstop = () => {
      stream.getTracks().forEach((t) => t.stop());
      resolve(chunks.length ? new Blob(chunks, { type: recorder.mimeType || 'audio/webm' }) : null);
    };
  });
  recorder.start();

  // 2) SpeechRecognition -> transcript để chấm điểm
  let recognition = null;
  let transcript = '';
  let speechError = null;
  let finish = () => {};
  const recognized = new Promise((resolve) => {
    if (!SpeechRecognition) return resolve({ transcript: '', speechError: 'unsupported' });
    finish = () => resolve({ transcript, speechError });
    recognition = new SpeechRecognition();
    recognition.lang = lang;
    recognition.continuous = true;
    recognition.interimResults = false;
    recognition.maxAlternatives = 1;
    recognition.onresult = (e) => {
      transcript = Array.from(e.results, (r) => r[0].transcript).join(' ').trim();
    };
    recognition.onerror = (e) => {
      if (e.error !== 'no-speech' && e.error !== 'aborted') speechError = e.error;
    };
    recognition.onend = finish;
    try {
      recognition.start();
    } catch (err) {
      resolve({ transcript: '', speechError: err.message });
    }
  });

  let stopped = false;
  const stop = () => {
    if (stopped) return;
    stopped = true;
    if (recorder.state !== 'inactive') recorder.stop();
    try { recognition?.stop(); } catch {}
    // Một số trình duyệt không bắn onend sau stop() -> tự kết thúc sau 3s
    setTimeout(finish, 3000);
  };

  const done = Promise.all([recorded, recognized]).then(([blob, r]) => ({ blob, ...r }));
  return { stop, done };
}
