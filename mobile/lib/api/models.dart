// Model khớp với response của backend (xem README mục 6. API).
// Các URL media (`cover`, `image`, `audioUrl`) được đổi sang URL tuyệt đối qua `resolve`.

typedef UrlResolver = String? Function(String? path);

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
double? _dn(Object? v) => (v as num?)?.toDouble();
int _i(Object? v) => (v as num?)?.toInt() ?? 0;

class Topic {
  final String slug;
  final String title;
  final String? level;
  final String? description;
  final int lessonCount;
  final String? cover;

  Topic.fromJson(Map<String, dynamic> j, UrlResolver resolve)
      : slug = j['slug'] as String,
        title = j['title'] as String,
        level = j['level'] as String?,
        description = j['description'] as String?,
        lessonCount = _i(j['lesson_count']),
        cover = resolve(j['cover'] as String?);
}

class LessonSummary {
  final String slug;
  final String title;
  final String? level;
  final String? accent;
  final String? type;
  final double duration;
  final int sentenceCount;
  final String? image;

  LessonSummary.fromJson(Map<String, dynamic> j, UrlResolver resolve)
      : slug = j['slug'] as String,
        title = j['title'] as String,
        level = j['level'] as String?,
        accent = j['accent'] as String?,
        type = j['type'] as String?,
        duration = _d(j['duration']),
        sentenceCount = _i(j['sentence_count']),
        image = resolve(j['image'] as String?);
}

class TopicDetail {
  final String slug;
  final String title;
  final String? level;
  final String? description;
  final List<LessonSummary> lessons;

  TopicDetail.fromJson(Map<String, dynamic> j, UrlResolver resolve)
      : slug = j['slug'] as String,
        title = j['title'] as String,
        level = j['level'] as String?,
        description = j['description'] as String?,
        lessons = [
          for (final l in (j['lessons'] as List? ?? const [])) LessonSummary.fromJson(l as Map<String, dynamic>, resolve),
        ];
}

class Word {
  final String text;
  final double? start;
  final String? ipa;

  Word({required this.text, this.start, this.ipa});

  Word.fromJson(Map<String, dynamic> j)
      : text = j['text'] as String,
        start = _dn(j['start']),
        ipa = j['ipa'] as String?;
}

class Sentence {
  final int idx;
  final double start;
  final double duration;
  final String text;
  final String? speaker;
  final List<Word> words;

  Sentence({
    required this.idx,
    required this.start,
    required this.duration,
    required this.text,
    this.speaker,
    this.words = const [],
  });

  Sentence.fromJson(Map<String, dynamic> j)
      : idx = _i(j['idx']),
        start = _d(j['start']),
        duration = _d(j['duration']),
        text = j['text'] as String,
        speaker = j['speaker'] as String?,
        words = [for (final w in (j['words'] as List? ?? const [])) Word.fromJson(w as Map<String, dynamic>)];

  /// Từ để hiển thị: có timing thì dùng `words`, không thì tách theo khoảng trắng.
  List<Word> get displayWords =>
      words.isNotEmpty ? words : [for (final t in text.split(RegExp(r'\s+'))) if (t.isNotEmpty) Word(text: t)];
}

class LessonRef {
  final String slug;
  final String title;
  LessonRef.fromJson(Map<String, dynamic> j)
      : slug = j['slug'] as String,
        title = j['title'] as String;
}

class Lesson {
  final int id;
  final String slug;
  final String title;
  final String? level;
  final String? accent;
  final String? type;
  final String lang;
  final double duration;
  final String? audioUrl;
  final String? image;
  final String topicSlug;
  final String topicTitle;
  final LessonRef? prev;
  final LessonRef? next;
  final List<Sentence> sentences;

  /// kind (vocab | phrase | idiom | grammar) -> danh sách mục
  final Map<String, List<Map<String, dynamic>>> study;

  Lesson.fromJson(Map<String, dynamic> j, UrlResolver resolve)
      : id = _i(j['id']),
        slug = j['slug'] as String,
        title = j['title'] as String,
        level = j['level'] as String?,
        accent = j['accent'] as String?,
        type = j['type'] as String?,
        lang = (j['lang'] as String?) ?? 'en-US',
        duration = _d(j['duration']),
        audioUrl = resolve(j['audioUrl'] as String?),
        image = resolve(j['image'] as String?),
        topicSlug = (j['topic'] as Map)['slug'] as String,
        topicTitle = (j['topic'] as Map)['title'] as String,
        prev = j['prev'] == null ? null : LessonRef.fromJson(j['prev'] as Map<String, dynamic>),
        next = j['next'] == null ? null : LessonRef.fromJson(j['next'] as Map<String, dynamic>),
        sentences = [for (final s in (j['sentences'] as List? ?? const [])) Sentence.fromJson(s as Map<String, dynamic>)],
        study = {
          for (final e in ((j['study'] as Map?) ?? const {}).entries)
            e.key as String: [for (final it in (e.value as List)) Map<String, dynamic>.from(it as Map)],
        };
}

class Language {
  final String code;
  final String name;
  final String nativeName;
  final bool original;
  final bool autoTranslate;

  Language.fromJson(Map<String, dynamic> j)
      : code = j['code'] as String,
        name = j['name'] as String,
        nativeName = (j['nativeName'] as String?) ?? j['name'] as String,
        original = j['original'] == true,
        autoTranslate = j['autoTranslate'] == true;
}

class Translations {
  final String lang;
  final int total;
  final int missing;

  /// sentence idx -> bản dịch
  final Map<int, String> items;

  Translations.fromJson(Map<String, dynamic> j)
      : lang = j['lang'] as String,
        total = _i(j['total']),
        missing = _i(j['missing']),
        items = {
          for (final e in ((j['items'] as Map?) ?? const {}).entries)
            if (e.value != null) int.parse(e.key as String): e.value as String,
        };
}

/// Một lần shadow đã lưu trên server (từ /progress hoặc POST /attempts).
class Attempt {
  final int sentenceIdx;
  final int score;
  final String? heard;
  final String? audioUrl;
  final int? best;
  final int? tries;

  Attempt.fromJson(Map<String, dynamic> j, UrlResolver resolve)
      : sentenceIdx = _i(j['sentenceIdx']),
        score = _d(j['score']).round(),
        heard = j['heard'] as String?,
        audioUrl = resolve(j['audioUrl'] as String?),
        best = _dn(j['best'])?.round(),
        tries = (j['tries'] as num?)?.toInt();
}
