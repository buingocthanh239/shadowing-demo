import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/models.dart';
import '../widgets/common.dart';
import 'topic_screen.dart';

const _levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Topic>? _topics;
  String? _error;
  String _q = '';
  String? _level;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final t = await Api.instance.topics();
      if (mounted) setState(() => _topics = t);
    } catch (e) {
      if (mounted) setState(() => _error = 'Không kết nối được API: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🎧 Shadowing')),
      body: _body(),
    );
  }

  Widget _body() {
    if (_error != null && _topics == null) return ErrorView(_error!, onRetry: _load);
    final topics = _topics;
    if (topics == null) return const Center(child: CircularProgressIndicator());

    final levels = _levels.where((l) => topics.any((t) => t.level?.contains(l) ?? false)).toList();
    final needle = _q.trim().toLowerCase();
    final shown = topics
        .where((t) =>
            (_level == null || (t.level?.contains(_level!) ?? false)) &&
            (needle.isEmpty ||
                t.title.toLowerCase().contains(needle) ||
                (t.description?.toLowerCase().contains(needle) ?? false)))
        .toList();
    final totalLessons = topics.fold<int>(0, (n, t) => n + t.lessonCount);

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          sliver: SliverList.list(children: [
            Text(
              '${topics.length} chủ đề · $totalLessons bài. Nghe câu mẫu → nhại lại → được chấm điểm từng từ.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm chủ đề…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _chip('Tất cả', _level == null, () => setState(() => _level = null)),
                for (final l in levels) _chip(l, _level == l, () => setState(() => _level = _level == l ? null : l)),
              ]),
            ),
          ]),
        ),
        if (shown.isEmpty)
          const SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('Không có chủ đề phù hợp.'))),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: 250,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: shown.length,
            itemBuilder: (_, i) => _TopicCard(shown[i]),
          ),
        ),
      ]),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(label: Text(label), selected: on, onSelected: (_) => onTap()),
      );
}

class _TopicCard extends StatelessWidget {
  const _TopicCard(this.t);
  final Topic t;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TopicScreen(slug: t.slug, title: t.title))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(height: 120, child: NetImage(t.cover)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, children: [
                if (t.level != null) Tag(t.level!, accent: true),
                Tag('${t.lessonCount} bài'),
              ]),
              const SizedBox(height: 6),
              Text(t.title, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (t.description != null)
                Text(
                  t.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
