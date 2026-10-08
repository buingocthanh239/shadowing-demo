import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'common.dart';

const _tabs = [
  ('vocab', 'Từ vựng'),
  ('phrase', 'Cụm hữu ích'),
  ('idiom', 'Thành ngữ'),
  ('grammar', 'Ngữ pháp'),
];

/// Từ vựng / cụm từ / thành ngữ / ngữ pháp của bài, chạm loa để nghe (TTS của máy).
class StudyPanel extends StatefulWidget {
  const StudyPanel({super.key, required this.study});
  final Map<String, List<Map<String, dynamic>>> study;

  @override
  State<StudyPanel> createState() => _StudyPanelState();
}

class _StudyPanelState extends State<StudyPanel> {
  final _tts = FlutterTts();
  String? _tab;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('en-US');
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak(String? text) async {
    if (text == null || text.isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs.where((t) => widget.study[t.$1]?.isNotEmpty ?? false).toList();
    if (tabs.isEmpty) return const Center(child: Text('Bài này chưa có phần học thêm.'));
    final tab = tabs.any((t) => t.$1 == _tab) ? _tab! : tabs.first.$1;
    final items = widget.study[tab]!;
    final cs = Theme.of(context).colorScheme;

    return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 24), children: [
      Wrap(spacing: 6, children: [
        for (final t in tabs)
          ChoiceChip(
            label: Text('${t.$2} ${widget.study[t.$1]!.length}'),
            selected: t.$1 == tab,
            onSelected: (_) => setState(() => _tab = t.$1),
          ),
      ]),
      const SizedBox(height: 8),
      for (final it in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Nghe',
                onPressed: () => _speak(tab == 'grammar' ? it['example'] as String? : _head(it)),
                icon: const Icon(Icons.volume_up_outlined, size: 20),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(_head(it) ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (it['pos'] != null) Tag(it['pos'] as String),
                    if (it['vi'] != null) Text('— ${it['vi']}'),
                  ]),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (it['en'] != null) Text('${it['en']}', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                if (it['example'] != null)
                  Text('“${it['example']}”', style: const TextStyle(fontStyle: FontStyle.italic)),
              ]),
            ),
          ]),
        ),
    ]);
  }

  String? _head(Map<String, dynamic> it) => (it['term'] ?? it['expr'] ?? it['idiom'] ?? it['point']) as String?;
}
