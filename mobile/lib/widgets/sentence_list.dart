import 'package:flutter/material.dart';

import '../core/timeline.dart';
import '../shadowing/shadowing_controller.dart';
import 'common.dart';
import 'focus_card.dart';

/// Danh sách phụ đề: chạm để nghe câu, tự cuộn tới câu đang phát.
class SentenceList extends StatefulWidget {
  const SentenceList({super.key, required this.sh, required this.view});
  final ShadowingController sh;
  final ViewOptions view;

  @override
  State<SentenceList> createState() => _SentenceListState();
}

class _SentenceListState extends State<SentenceList> {
  final _keys = <int, GlobalKey>{};
  int _shown = -1;

  @override
  void didUpdateWidget(covariant SentenceList old) {
    super.didUpdateWidget(old);
    final cur = widget.sh.current;
    if (cur != _shown) {
      _shown = cur;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[cur]?.currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(ctx, alignment: 0.3, duration: const Duration(milliseconds: 250));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sh = widget.sh;
    final cs = Theme.of(context).colorScheme;
    // Bài chỉ vài chục câu -> dựng hết để ensureVisible luôn tìm được câu đang phát
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
      child: Column(children: [
        for (var i = 0; i < sh.sentences.length; i++) _line(context, cs, i),
      ]),
    );
  }

  Widget _line(BuildContext context, ColorScheme cs, int i) {
    final sh = widget.sh;
    final s = sh.sentences[i];
    final r = sh.results[i];
    final best = r?.best ?? r?.score;
    final active = i == sh.current;
    final tr = widget.view.lang != 'off' ? widget.view.tr.items[s.idx] : null;
    return Material(
      key: _keys.putIfAbsent(i, GlobalKey.new),
      color: active ? cs.primaryContainer.withValues(alpha: 0.5) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: sh.phase == Phase.recording ? null : () => sh.playSentence(i),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 40,
              child: Text(formatTime(s.start), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(TextSpan(children: [
                  if (s.speaker != null) TextSpan(text: '${s.speaker}: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: s.text),
                ])),
                if (tr != null)
                  Text(tr, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)),
              ]),
            ),
            if (best != null)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scoreColor(context, best).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$best',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scoreColor(context, best)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
