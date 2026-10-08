// Tính câu/từ đang phát theo thời gian (port từ frontend/src/lib/useShadowing.js).
import '../api/models.dart';

/// Điểm kết thúc của câu i: hết duration (+ chút đệm) nhưng không lấn sang câu sau.
double segmentEnd(List<Sentence> sentences, int i) {
  final s = sentences[i];
  final end = s.start + s.duration + 0.25;
  return i + 1 < sentences.length && sentences[i + 1].start < end ? sentences[i + 1].start : end;
}

int findSentence(List<Sentence> sentences, double t) {
  var found = 0;
  for (var i = 0; i < sentences.length; i++) {
    if (t >= sentences[i].start - 0.2) found = i;
  }
  return found;
}

int findWord(Sentence? s, double t) {
  if (s == null || s.words.isEmpty || t < s.start - 0.15 || t > s.start + s.duration + 0.15) return -1;
  var found = -1;
  for (var i = 0; i < s.words.length; i++) {
    final start = s.words[i].start;
    if (start == null) continue;
    if (t >= start - 0.05) {
      found = i;
    } else {
      break;
    }
  }
  return found;
}

String formatTime(double sec) {
  final s = sec.isFinite && sec > 0 ? sec.floor() : 0;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
