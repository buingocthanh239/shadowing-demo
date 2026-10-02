// Chấm điểm bằng LCS (Longest Common Subsequence) giữa câu mẫu và text nhận dạng được.
// Cùng cách tiếp cận với tryshadowing: đây là điểm "nói đúng từ", không phải chấm âm vị.

const NUMBERS = { 0: 'zero', 1: 'one', 2: 'two', 3: 'three', 4: 'four', 5: 'five', 6: 'six', 7: 'seven', 8: 'eight', 9: 'nine', 10: 'ten' };

const normalize = (w) =>
  w.toLowerCase().replace(/[’‘]/g, "'").replace(/[^a-z0-9']/g, '').replace(/^'+|'+$/g, '');

// "low-income" -> ["low","income"]; "5" -> ["five"]
const tokens = (text) =>
  text
    .split(/[\s\-–—]+/)
    .map(normalize)
    .filter(Boolean)
    .map((t) => NUMBERS[t] ?? t);

/**
 * @returns {{score:number, words:{word:string, correct:boolean}[], heard:string}}
 */
export function scoreSentence(reference, heard) {
  const refWords = reference.split(/\s+/).filter(Boolean);
  const ref = []; // token
  const owner = []; // token -> index trong refWords
  refWords.forEach((w, i) => tokens(w).forEach((t) => (ref.push(t), owner.push(i))));
  const hyp = tokens(heard || '');

  const n = ref.length, m = hyp.length;
  const dp = Array.from({ length: n + 1 }, () => new Uint16Array(m + 1));
  for (let i = 1; i <= n; i++)
    for (let j = 1; j <= m; j++)
      dp[i][j] = ref[i - 1] === hyp[j - 1] ? dp[i - 1][j - 1] + 1 : Math.max(dp[i - 1][j], dp[i][j - 1]);

  // Truy vết để biết token nào của câu mẫu được khớp
  const matched = new Array(n).fill(false);
  for (let i = n, j = m; i > 0 && j > 0; ) {
    if (ref[i - 1] === hyp[j - 1]) (matched[i - 1] = true), i--, j--;
    else if (dp[i - 1][j] >= dp[i][j - 1]) i--;
    else j--;
  }

  const wordOk = refWords.map(() => true);
  owner.forEach((wi, ti) => { if (!matched[ti]) wordOk[wi] = false; });
  const hits = matched.filter(Boolean).length;

  return {
    score: n === 0 ? 0 : Math.round((hits / n) * 100),
    words: refWords.map((word, i) => ({ word, correct: wordOk[i] })),
    heard: heard || '',
  };
}
