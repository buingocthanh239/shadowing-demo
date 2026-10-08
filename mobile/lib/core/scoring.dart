// Chấm điểm bằng LCS (Longest Common Subsequence) giữa câu mẫu và text nhận dạng được.
// Port 1-1 từ frontend/src/lib/scoring.js: điểm "nói đúng từ", không phải chấm âm vị.
import 'dart:math';

const _numbers = {
  '0': 'zero', '1': 'one', '2': 'two', '3': 'three', '4': 'four', '5': 'five',
  '6': 'six', '7': 'seven', '8': 'eight', '9': 'nine', '10': 'ten',
};

String _normalize(String w) => w
    .toLowerCase()
    .replaceAll(RegExp('[’‘]'), "'")
    .replaceAll(RegExp(r"[^a-z0-9']"), '')
    .replaceAll(RegExp(r"^'+|'+$"), '');

// "low-income" -> ["low","income"]; "5" -> ["five"]
List<String> _tokens(String text) => [
      for (final t in text.split(RegExp(r'[\s\-–—]+')).map(_normalize))
        if (t.isNotEmpty) _numbers[t] ?? t,
    ];

class WordMark {
  final String word;
  final bool correct;
  const WordMark(this.word, this.correct);
}

class ScoreResult {
  final int score;
  final List<WordMark> words;
  final String heard;
  const ScoreResult(this.score, this.words, this.heard);
}

ScoreResult scoreSentence(String reference, String? heard) {
  final refWords = reference.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final ref = <String>[];
  final owner = <int>[]; // token -> index trong refWords
  for (var i = 0; i < refWords.length; i++) {
    for (final t in _tokens(refWords[i])) {
      ref.add(t);
      owner.add(i);
    }
  }
  final hyp = _tokens(heard ?? '');

  final n = ref.length, m = hyp.length;
  final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      dp[i][j] = ref[i - 1] == hyp[j - 1] ? dp[i - 1][j - 1] + 1 : max(dp[i - 1][j], dp[i][j - 1]);
    }
  }

  // Truy vết để biết token nào của câu mẫu được khớp
  final matched = List<bool>.filled(n, false);
  for (var i = n, j = m; i > 0 && j > 0;) {
    if (ref[i - 1] == hyp[j - 1]) {
      matched[i - 1] = true;
      i--;
      j--;
    } else if (dp[i - 1][j] >= dp[i][j - 1]) {
      i--;
    } else {
      j--;
    }
  }

  final wordOk = List<bool>.filled(refWords.length, true);
  for (var ti = 0; ti < owner.length; ti++) {
    if (!matched[ti]) wordOk[owner[ti]] = false;
  }
  final hits = matched.where((x) => x).length;

  return ScoreResult(
    n == 0 ? 0 : (hits / n * 100).round(),
    [for (var i = 0; i < refWords.length; i++) WordMark(refWords[i], wordOk[i])],
    heard ?? '',
  );
}
