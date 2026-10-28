import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import 'ai_benchmark_scope.dart';

class WikiSearchTestPage extends StatefulWidget {
  const WikiSearchTestPage({super.key});

  @override
  State<WikiSearchTestPage> createState() => _WikiSearchTestPageState();
}

class _WikiSearchTestPageState extends State<WikiSearchTestPage> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      AiBenchmarkScope.of(context).loadWikiSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = AiBenchmarkScope.of(context);
    final luma = context.luma;
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        title: const Text('Wiki search test'),
        actions: [
          IconButton(
            onPressed: repo.canRefresh ? repo.loadWikiSearch : null,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final data = repo.wikiSearch;
          final raw = data?['models'];
          final models = raw is List
              ? raw.whereType<Map>().where((m) {
                  final score = m['score'];
                  return m['model'] is String &&
                      score is num &&
                      score.isFinite &&
                      score >= 0 &&
                      score <= 100;
                }).toList()
              : <Map>[];
          models.sort((a, b) {
            final comparison = (b['score'] as num).compareTo(a['score'] as num);
            return comparison != 0
                ? comparison
                : (a['model'] as String).compareTo(b['model'] as String);
          });
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Embedding models rank fictional reference passages with closely related distractors. The score is mean reciprocal rank at 10: a correct first result earns 100%, lower ranks earn less.',
                  style: TextStyle(color: luma.textSecondary),
                ),
                const SizedBox(height: 20),
                if (repo.wikiSearchLoading && data == null)
                  const Center(child: CircularProgressIndicator())
                else if (models.isEmpty)
                  LumaEmptyState(
                    icon: Icons.search,
                    title: 'No wiki search results yet',
                    subtitle:
                        repo.wikiSearchError ??
                        (repo.canRefresh
                            ? 'Run an embedding model from the admin dashboard.'
                            : 'Sign in to an approved account to load results.'),
                  )
                else ...[
                  LumaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Embedding model comparison',
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Retrieval score · ${data?['cases'] ?? 0} queries',
                          style: TextStyle(color: luma.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('0%', style: TextStyle(color: luma.textMuted)),
                            Text(
                              '50%',
                              style: TextStyle(color: luma.textMuted),
                            ),
                            Text(
                              '100%',
                              style: TextStyle(color: luma.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final m in models)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(m['model'] as String)),
                                    Text(
                                      '${(m['score'] as num).toStringAsFixed(1)}%',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: ((m['score'] as num).toDouble() / 100)
                                      .clamp(0.0, 1.0),
                                  minHeight: 10,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Model conclusions',
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final m in models) ...[
                    LumaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m['model'] as String,
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _conclusion(m, models),
                            style: TextStyle(color: luma.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _conclusion(Map model, List<Map> models) {
    final score = (model['score'] as num).toDouble();
    final top = (models.first['score'] as num).toDouble();
    final formatted = score.toStringAsFixed(1);
    if (models.length == 1) {
      return 'Scored $formatted% on this test. Run more models to compare.';
    }
    if (score == top) {
      final tied = models.where((m) => (m['score'] as num) == top).length > 1;
      return tied
          ? 'Scored $formatted%, tied for the highest score on this test.'
          : 'Scored $formatted%, the highest score on this test.';
    }
    final difference = top - score;
    final gap = difference < 0.01
        ? 'less than 0.01'
        : difference < 0.1
        ? difference.toStringAsFixed(2)
        : difference.toStringAsFixed(1);
    return 'Scored $formatted%, $gap percentage points behind '
        '${models.first['model']} on this test.';
  }
}
