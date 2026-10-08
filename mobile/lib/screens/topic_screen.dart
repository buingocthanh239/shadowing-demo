import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/models.dart';
import '../core/timeline.dart';
import '../widgets/common.dart';
import 'lesson_screen.dart';

class TopicScreen extends StatefulWidget {
  const TopicScreen({super.key, required this.slug, required this.title});
  final String slug;
  final String title;

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  TopicDetail? _topic;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final t = await Api.instance.topic(widget.slug);
      if (mounted) setState(() => _topic = t);
    } catch (e) {
      if (mounted) setState(() => _error = 'Không tải được chủ đề: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _topic;
    return Scaffold(
      appBar: AppBar(title: Text(t?.title ?? widget.title)),
      body: _error != null && t == null
          ? ErrorView(_error!, onRetry: _load)
          : t == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: t.lessons.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Text(
                          t.description ?? '',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        );
                      }
                      return _LessonTile(topic: t.slug, l: t.lessons[i - 1]);
                    },
                  ),
                ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.topic, required this.l});
  final String topic;
  final LessonSummary l;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LessonScreen(topic: topic, lesson: l.slug, title: l.title)),
        ),
        child: Row(children: [
          NetImage(l.image, width: 96, height: 96),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.title, style: Theme.of(context).textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (l.level != null) Tag(l.level!, accent: true),
                  if (l.accent != null) Tag(l.accent!),
                  if (l.type != null) Tag(l.type!),
                  Tag('${l.sentenceCount} câu · ${formatTime(l.duration)}'),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
