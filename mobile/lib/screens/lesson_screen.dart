import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/models.dart';
import '../core/prefs.dart';
import '../core/timeline.dart';
import '../shadowing/shadowing_controller.dart';
import '../shadowing/translations_controller.dart';
import '../widgets/common.dart';
import '../widgets/focus_card.dart';
import '../widgets/sentence_list.dart';
import '../widgets/study_panel.dart';

const _rates = [0.5, 0.75, 0.9, 1.0, 1.25];

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.topic, required this.lesson, required this.title});
  final String topic;
  final String lesson;
  final String title;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  Lesson? _lesson;
  String? _error;
  ShadowingController? _sh;
  TranslationsController? _tr;
  List<Language> _languages = const [];
  String _lang = 'vi';
  bool _showIpa = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    Api.instance.languages().then((l) => mounted ? setState(() => _languages = l) : null, onError: (_) {});
    try {
      final results = await Future.wait([
        Api.instance.lesson(widget.topic, widget.lesson),
        Prefs.lang(),
        Prefs.showIpa(),
      ]);
      if (!mounted) return;
      final lesson = results[0] as Lesson;
      final sh = ShadowingController(lesson)..init();
      final tr = TranslationsController(lesson.id)..load(results[1] as String);
      setState(() {
        _lesson = lesson;
        _lang = results[1] as String;
        _showIpa = results[2] as bool;
        _sh = sh;
        _tr = tr;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Không tải được bài: $e');
    }
  }

  @override
  void dispose() {
    _sh?.dispose();
    _tr?.dispose();
    super.dispose();
  }

  void _setLang(String v) {
    setState(() => _lang = v);
    Prefs.setLang(v);
    _tr?.load(v);
  }

  void _setIpa(bool v) {
    setState(() => _showIpa = v);
    Prefs.setShowIpa(v);
  }

  void _openSibling(LessonRef ref) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LessonScreen(topic: widget.topic, lesson: ref.slug, title: ref.title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lesson = _lesson;
    return Scaffold(
      appBar: AppBar(
        title: Text(lesson?.title ?? widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: lesson == null ? null : _actions(lesson),
      ),
      body: _error != null
          ? ErrorView(_error!, onRetry: _load)
          : lesson == null
              ? const Center(child: CircularProgressIndicator())
              : _body(lesson),
    );
  }

  List<Widget> _actions(Lesson lesson) => [
        IconButton(
          tooltip: 'Phiên âm IPA (US)',
          isSelected: _showIpa,
          onPressed: () => _setIpa(!_showIpa),
          icon: const Text('IPA', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        PopupMenuButton<String>(
          tooltip: 'Ngôn ngữ dịch',
          icon: const Icon(Icons.translate),
          initialValue: _lang,
          onSelected: _setLang,
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'off', child: Text('Tắt dịch')),
            for (final l in _languages)
              PopupMenuItem(value: l.code, child: Text('${l.nativeName}${l.original ? '' : ' · máy'}')),
          ],
        ),
        if (lesson.prev != null || lesson.next != null)
          PopupMenuButton<LessonRef>(
            onSelected: _openSibling,
            itemBuilder: (_) => [
              if (lesson.prev != null) PopupMenuItem(value: lesson.prev, child: Text('‹ Bài trước: ${lesson.prev!.title}')),
              if (lesson.next != null) PopupMenuItem(value: lesson.next, child: Text('Bài sau ›: ${lesson.next!.title}')),
            ],
          ),
      ];

  Widget _body(Lesson lesson) {
    final sh = _sh!, tr = _tr!;
    final langName = _languages.where((l) => l.code == _lang).firstOrNull?.nativeName ?? _lang;
    return ListenableBuilder(
      listenable: Listenable.merge([sh, tr]),
      builder: (context, _) {
        final view = ViewOptions(showIpa: _showIpa, lang: _lang, tr: tr);
        return DefaultTabController(
          length: 2,
          child: Column(children: [
            _PlayerBar(sh: sh, fallbackDuration: lesson.duration),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(children: [
                if (tr.status == TrStatus.translating)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Notice('Đang dịch bài sang $langName… (chỉ lần đầu)'),
                  ),
                if (tr.status == TrStatus.error)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Notice('Chưa dịch được sang $langName: ${tr.error}', error: true),
                  ),
                if (sh.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Notice(sh.error!, error: true, onTap: sh.clearError),
                  ),
              ]),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: FocusCard(sh: sh, view: view),
              ),
            ),
            const TabBar(tabs: [Tab(text: 'Phụ đề'), Tab(text: 'Từ vựng & ngữ pháp')]),
            Expanded(
              child: TabBarView(children: [
                SentenceList(sh: sh, view: view),
                StudyPanel(study: lesson.study),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({required this.sh, required this.fallbackDuration});
  final ShadowingController sh;
  final double fallbackDuration;

  @override
  Widget build(BuildContext context) {
    final total = sh.totalDuration ?? fallbackDuration;
    final max = total > 0 ? total : 1.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 4, 4),
      child: Row(children: [
        IconButton.filled(
          tooltip: 'Nghe cả bài',
          onPressed: sh.ready && sh.phase != Phase.recording ? sh.togglePlayAll : null,
          icon: Icon(sh.playing ? Icons.pause : Icons.play_arrow),
        ),
        const SizedBox(width: 4),
        Text(formatTime(sh.time), style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
        Expanded(
          child: Slider(
            value: sh.time.clamp(0, max).toDouble(),
            max: max,
            onChanged: sh.ready && !sh.busy ? sh.seek : null,
          ),
        ),
        Text(formatTime(total), style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
        PopupMenuButton<double>(
          tooltip: 'Tốc độ',
          initialValue: sh.rate,
          onSelected: sh.setRate,
          itemBuilder: (_) => [for (final r in _rates) PopupMenuItem(value: r, child: Text('${r}x'))],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Text('${sh.rate}x', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}
