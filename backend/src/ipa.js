// Phiên âm IPA (giọng US) từ CMU Pronouncing Dictionary (ARPAbet -> IPA).
import { dictionary } from 'cmu-pronouncing-dictionary';

const VOWELS = {
  AA: 'ɑ', AE: 'æ', AH: 'ʌ', AO: 'ɔ', AW: 'aʊ', AY: 'aɪ', EH: 'ɛ', ER: 'ɝ',
  EY: 'eɪ', IH: 'ɪ', IY: 'i', OW: 'oʊ', OY: 'ɔɪ', UH: 'ʊ', UW: 'u',
};
const CONSONANTS = {
  B: 'b', CH: 'tʃ', D: 'd', DH: 'ð', F: 'f', G: 'ɡ', HH: 'h', JH: 'dʒ', K: 'k', L: 'l', M: 'm',
  N: 'n', NG: 'ŋ', P: 'p', R: 'r', S: 's', SH: 'ʃ', T: 't', TH: 'θ', V: 'v', W: 'w', Y: 'j', Z: 'z', ZH: 'ʒ',
};
// Cụm phụ âm được phép đứng đầu âm tiết -> đặt dấu trọng âm trước cả cụm
const ONSETS = new Set([
  'pl', 'pr', 'pj', 'bl', 'br', 'bj', 'tr', 'tw', 'tj', 'dr', 'dw', 'dj', 'kl', 'kr', 'kw', 'kj', 'ɡl', 'ɡr', 'ɡw',
  'fl', 'fr', 'fj', 'θr', 'ʃr', 'sl', 'sw', 'sm', 'sn', 'sp', 'st', 'sk', 'sf', 'mj', 'nj', 'hj', 'vj',
  'spr', 'spl', 'str', 'skr', 'skw', 'spj', 'stj', 'skj',
]);

/** "K AH0 N JH EH1 S CH AH0 N" -> "kənˈdʒɛstʃən" */
export function arpabetToIpa(arpabet) {
  const phones = arpabet.trim().split(/\s+/).map((p) => {
    const m = p.match(/^([A-Z]+)([012])?$/);
    const [, base, stress] = m;
    if (VOWELS[base]) {
      // Nguyên âm không nhấn: AH0 -> ə, ER0 -> ɚ
      const ipa = stress === '0' && base === 'AH' ? 'ə' : stress === '0' && base === 'ER' ? 'ɚ' : VOWELS[base];
      return { ipa, vowel: true, stress };
    }
    return { ipa: CONSONANTS[base] ?? '', vowel: false };
  });

  const syllables = phones.filter((p) => p.vowel).length;
  const marks = new Map(); // vị trí chèn -> dấu
  if (syllables > 1) {
    phones.forEach((p, i) => {
      if (!p.vowel || (p.stress !== '1' && p.stress !== '2')) return;
      // Lùi về đầu âm tiết: lấy cụm phụ âm đứng đầu hợp lệ dài nhất
      let start = i;
      while (start > 0 && !phones[start - 1].vowel) {
        const cluster = phones.slice(start - 1, i).map((x) => x.ipa).join('');
        const isFirst = phones.slice(0, start - 1).every((x) => !x.vowel);
        if (start - 1 < i - 1 && !ONSETS.has(cluster) && !isFirst) break;
        start--;
      }
      marks.set(start, p.stress === '1' ? 'ˈ' : 'ˌ');
    });
  }
  return phones.map((p, i) => (marks.get(i) ?? '') + p.ipa).join('');
}

/** Chuẩn hoá 1 từ trong câu để tra từ điển: "Café," -> "cafe", "planners'" -> "planners'" */
export function normalizeWord(text) {
  return text
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[’‘]/g, "'")
    .replace(/[^a-z0-9'-]/g, '')
    .replace(/^['-]+|['-]+$/g, '');
}

function lookup(part) {
  const arpa = dictionary[part] ?? dictionary[part.replace(/'$/, '')] ?? dictionary[part.replace(/'s$/, '')];
  if (arpa) return arpabetToIpa(arpa);
  return null;
}

/** IPA của 1 từ đã chuẩn hoá; từ ghép "low-income" -> ghép từng phần. null nếu không tra được. */
export function ipaFor(word) {
  if (!word || /^\d/.test(word)) return null;
  const parts = word.split('-').filter(Boolean);
  const ipas = parts.map(lookup);
  return ipas.every(Boolean) ? ipas.join('-') : null;
}
