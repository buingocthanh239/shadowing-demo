import 'package:flutter_test/flutter_test.dart';
import 'package:shadowing/api/models.dart';
import 'package:shadowing/core/scoring.dart';
import 'package:shadowing/core/timeline.dart';

void main() {
  group('scoreSentence', () {
    test('nói đúng hết -> 100', () {
      final r = scoreSentence('Good morning, and welcome!', 'good morning and welcome');
      expect(r.score, 100);
      expect(r.words.every((w) => w.correct), isTrue);
    });

    test('thiếu từ -> đánh dấu từ sai', () {
      final r = scoreSentence('I want a large latte', 'I want latte');
      expect(r.score, 60);
      expect([for (final w in r.words) w.correct], [true, true, false, false, true]);
    });

    test('gạch nối, số và nháy cong', () {
      final r = scoreSentence('A low-income family has 5 kids, it’s true', "a low income family has five kids it's true");
      expect(r.score, 100);
    });

    test('không nghe được gì -> 0', () {
      expect(scoreSentence('Hello there', '').score, 0);
      expect(scoreSentence('Hello there', null).score, 0);
    });
  });

  group('timeline', () {
    final sentences = [
      Sentence(idx: 0, start: 0.05, duration: 2.0, text: 'Good morning', words: [
        Word(text: 'Good', start: 0.05),
        Word(text: 'morning', start: 0.5),
      ]),
      Sentence(idx: 1, start: 2.1, duration: 3.0, text: 'Second one'),
    ];

    test('segmentEnd không lấn sang câu sau', () {
      expect(segmentEnd(sentences, 0), 2.1);
      expect(segmentEnd(sentences, 1), closeTo(5.35, 1e-9));
    });

    test('findSentence / findWord', () {
      expect(findSentence(sentences, 1.0), 0);
      expect(findSentence(sentences, 2.0), 1); // 0.2s trước khi câu bắt đầu
      expect(findWord(sentences[0], 0.1), 0);
      expect(findWord(sentences[0], 0.6), 1);
      expect(findWord(sentences[0], 3.0), -1);
    });

    test('formatTime', () {
      expect(formatTime(67.6), '1:07');
      expect(formatTime(0), '0:00');
    });
  });
}
