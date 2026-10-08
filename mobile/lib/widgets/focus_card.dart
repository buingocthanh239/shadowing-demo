import 'package:flutter/material.dart';

import '../core/timeline.dart';
import '../shadowing/shadowing_controller.dart';
import '../shadowing/translations_controller.dart';
import 'common.dart';

class ViewOptions {
  final bool showIpa;
  final String lang;
  final TranslationsController tr;
  const ViewOptions({required this.showIpa, required this.lang, required this.tr});
}

/// Câu đang luyện: karaoke từng từ + IPA, bản dịch, nút Nghe / Ghi âm / Shadow, kết quả chấm.
class FocusCard extends StatelessWidget {
  const FocusCard({super.key, required this.sh, required this.view});
  final ShadowingController sh;
  final ViewOptions view;

  @override
  Widget build(BuildContext context) {
    final i = sh.current;
    final s = sh.sentences.elementAtOrNull(i);
    if (s == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final result = sh.results[i];
    final words = s.displayWords;
    final translation = view.tr.items[s.idx];
    final showResultColors = result?.words != null && sh.phase == Phase.idle && !sh.playing;
    final recording = sh.phase == Phase.recording;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Câu ${i + 1} / ${sh.sentences.length}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            if (s.speaker != null) ...[const SizedBox(width: 8), Tag(s.speaker!, accent: true)],
            const Spacer(),
            Text(formatTime(s.start), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 8, children: [
            for (var wi = 0; wi < words.length; wi++)
              _WordChip(
                text: words[wi].text,
                ipa: view.showIpa ? (words[wi].ipa != null ? '/${words[wi].ipa}/' : ' ') : null,
                active: wi == sh.wordIdx,
                spoken: sh.wordIdx > wi,
                correct: showResultColors ? result!.words!.elementAtOrNull(wi)?.correct : null,
                onTap: () => sh.playWord(i, wi),
              ),
          ]),
          if (view.lang != 'off') ...[
            const SizedBox(height: 10),
            Text(
              translation ?? (view.tr.pending ? '…' : ''),
              style: TextStyle(color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            IconButton.outlined(
              tooltip: 'Câu trước',
              onPressed: i == 0 || sh.busy ? null : () => sh.setCurrent(i - 1),
              icon: const Icon(Icons.skip_previous),
            ),
            OutlinedButton.icon(
              onPressed: recording || !sh.ready ? null : () => sh.playSentence(i),
              icon: const Icon(Icons.volume_up),
              label: const Text('Nghe'),
            ),
            if (recording)
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
                onPressed: sh.stopRecording,
                icon: const Icon(Icons.stop),
                label: const Text('Dừng'),
              )
            else
              OutlinedButton.icon(
                onPressed: sh.busy ? null : () => sh.record(i),
                icon: const Icon(Icons.mic),
                label: const Text('Ghi âm'),
              ),
            FilledButton.icon(
              onPressed: sh.busy || !sh.ready ? null : () => sh.shadow(i),
              icon: const Icon(Icons.bolt),
              label: const Text('Shadow'),
            ),
            IconButton.outlined(
              tooltip: 'Câu sau',
              onPressed: i == sh.sentences.length - 1 || sh.busy ? null : () => sh.setCurrent(i + 1),
              icon: const Icon(Icons.skip_next),
            ),
            FilterChip(
              label: const Text('Liên tục'),
              tooltip: 'Tự chuyển sang câu tiếp theo khi shadow',
              selected: sh.continuous,
              onSelected: sh.setContinuous,
            ),
          ]),
          _Status(sh: sh),
          if (result != null && sh.phase == Phase.idle) _Result(sh: sh, index: i, result: result),
        ]),
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({
    required this.text,
    required this.ipa,
    required this.active,
    required this.spoken,
    required this.correct,
    required this.onTap,
  });
  final String text;
  final String? ipa;
  final bool active, spoken;
  final bool? correct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color fg = cs.onSurface;
    if (correct != null) fg = scoreColor(context, correct! ? 100 : 0);
    if (spoken) fg = cs.primary;
    if (active) fg = cs.onPrimary;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: active ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 20,
              height: 1.3,
              color: fg,
              fontWeight: FontWeight.w500,
              decoration: correct == false ? TextDecoration.underline : null,
              decorationColor: fg,
            ),
          ),
          if (ipa != null)
            Text(ipa!, style: TextStyle(fontSize: 12, color: active ? cs.onPrimary : cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.sh});
  final ShadowingController sh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget line(String text) => Padding(padding: const EdgeInsets.only(top: 12), child: Text(text));
    switch (sh.phase) {
      case Phase.listening:
        return line('🎧 Nghe câu mẫu…');
      case Phase.scoring:
        return line('⏳ Đang chấm điểm…');
      case Phase.idle:
        return const SizedBox.shrink();
      case Phase.recording:
        final w = sh.recordWindow;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.fiber_manual_record, color: cs.error, size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text('Đang ghi âm — hãy nói lại câu trên${w == null ? ', bấm Dừng khi xong' : ''}')),
            ]),
            if (w != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(w.startedAt),
                  tween: Tween(begin: 0, end: 1),
                  duration: w.length,
                  builder: (_, v, _) => LinearProgressIndicator(value: v, color: cs.error),
                ),
              ),
          ]),
        );
    }
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.sh, required this.index, required this.result});
  final ShadowingController sh;
  final int index;
  final SentenceResult result;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (result.score != null) ...[ScoreRing(score: result.score!), const SizedBox(width: 12)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (result.heard != null)
              Text.rich(TextSpan(children: [
                TextSpan(text: 'Bạn nói: ', style: TextStyle(color: cs.onSurfaceVariant)),
                result.heard!.isEmpty
                    ? TextSpan(
                        text: '(không nghe được gì)',
                        style: TextStyle(color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
                      )
                    : TextSpan(text: result.heard),
              ])),
            if ((result.tries ?? 0) > 0)
              Text(
                'Cao nhất ${result.best} · ${result.tries} lần thử',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            if (result.audio != null)
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                onPressed: () => sh.playMine(index),
                icon: const Icon(Icons.play_circle_outline, size: 20),
                label: const Text('Nghe lại giọng mình'),
              ),
          ]),
        ),
      ]),
    );
  }
}

class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(context, score);
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 5,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
        Text('$score', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}
