// Provider dịch máy: LibreTranslate tự host (https://github.com/LibreTranslate/LibreTranslate)
const BASE = (process.env.LIBRETRANSLATE_URL || 'http://localhost:5000').replace(/\/$/, '');
const API_KEY = process.env.LIBRETRANSLATE_API_KEY || undefined;
const BATCH = 20;

// Mã của mình (BCP-47) -> các mã LibreTranslate có thể dùng (bản cũ: zh/zt, bản mới: zh-Hans/zh-Hant)
const ALIASES = { 'zh-Hans': ['zh-Hans', 'zh'], 'zh-Hant': ['zh-Hant', 'zt'] };

let languagesCache = null;
async function targetsOf(source) {
  if (!languagesCache) {
    const res = await fetch(`${BASE}/languages`, { signal: AbortSignal.timeout(5000) });
    if (!res.ok) throw new Error(`libretranslate /languages ${res.status}`);
    languagesCache = await res.json();
    setTimeout(() => (languagesCache = null), 5 * 60_000);
  }
  return new Set(languagesCache.find((l) => l.code === source)?.targets ?? []);
}

async function providerCode(lang, source) {
  const targets = await targetsOf(source);
  return (ALIASES[lang] ?? [lang]).find((c) => targets.has(c)) ?? null;
}

export default {
  name: 'libretranslate',

  async supports(lang, source) {
    try {
      return (await providerCode(lang, source)) != null;
    } catch {
      return false; // server dịch chưa chạy
    }
  },

  /** @returns {Promise<string[]>} cùng thứ tự với texts */
  async translate(texts, { source, target }) {
    const code = await providerCode(target, source);
    if (!code) throw new Error(`libretranslate không hỗ trợ ${source} -> ${target}`);
    const out = [];
    for (let i = 0; i < texts.length; i += BATCH) {
      const res = await fetch(`${BASE}/translate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ q: texts.slice(i, i + BATCH), source, target: code, format: 'text', api_key: API_KEY }),
        signal: AbortSignal.timeout(120_000),
      });
      const body = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(`libretranslate ${res.status}: ${body.error ?? ''}`);
      out.push(...body.translatedText);
    }
    return out;
  },
};
