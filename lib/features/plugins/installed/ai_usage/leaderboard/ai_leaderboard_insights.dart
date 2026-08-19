import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import 'ai_catalog_scope.dart';
import 'ai_leaderboard_format.dart';
import 'ai_leaderboard_metric.dart';
import 'ai_model.dart';
import 'ai_model_detail_page.dart';
import 'ai_pareto.dart';
import 'ai_vendor_style.dart';

/// The Leaderboard's **Insights** view: a scrollable page of everything that
/// doesn't fit a single table or chart — the price/performance frontier,
/// what's best for each job, and recent releases.
class AiLeaderboardInsightsView extends StatefulWidget {
  const AiLeaderboardInsightsView({super.key});

  @override
  State<AiLeaderboardInsightsView> createState() =>
      _AiLeaderboardInsightsViewState();
}

class _AiLeaderboardInsightsViewState
    extends State<AiLeaderboardInsightsView> {
  AiMetric _frontierMetric = AiMetric.llmStats;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    AiCatalogScope.of(context).load();
  }

  @override
  Widget build(BuildContext context) {
    final repo = AiCatalogScope.of(context);
    final luma = context.luma;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        if (repo.loading) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          );
        }
        final catalog = repo.catalog;
        if (catalog.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: LumaEmptyState(
              icon: Icons.insights_outlined,
              title: 'No model data yet',
              subtitle: 'Insights need the model catalogue to build from.',
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _SectionHeader(
              eyebrow: 'EFFICIENCY',
              title: 'Price vs Performance',
              trailing: _FrontierMetricPicker(
                value: _frontierMetric,
                onChanged: (m) => setState(() => _frontierMetric = m),
              ),
            ),
            Text(
              'Blended cost (8:1 input/output) against ${_frontierMetric.label}. '
              'Models on the line are pareto-efficient — nothing else is both '
              'cheaper and at least as good.',
              style: TextStyle(color: luma.textMuted, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 12),
            _FrontierChart(models: catalog.models, scoreMetric: _frontierMetric),
            const SizedBox(height: 28),
            const _SectionHeader(eyebrow: 'BEST BY TASK', title: 'Category Leaders'),
            const SizedBox(height: 12),
            _BestByTask(models: catalog.models),
            const SizedBox(height: 28),
            if (catalog.news.isNotEmpty) ...[
              const _SectionHeader(eyebrow: 'RESEARCH', title: 'Latest News'),
              const SizedBox(height: 12),
              _NewsList(items: catalog.news),
            ],
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.eyebrow, required this.title, this.trailing});

  final String eyebrow;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: TextStyle(
                    color: luma.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// ─── Price vs performance ───────────────────────────────────────────────────

/// Which score axis the frontier chart is judged on. Kept to the four rating
/// indices — plotting the frontier against price itself would be circular.
const List<AiMetric> _kFrontierMetrics = [
  AiMetric.llmStats,
  AiMetric.reasoning,
  AiMetric.coding,
  AiMetric.math,
  AiMetric.agent,
];

class _FrontierMetricPicker extends StatelessWidget {
  const _FrontierMetricPicker({required this.value, required this.onChanged});

  final AiMetric value;
  final ValueChanged<AiMetric> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return PopupMenuButton<AiMetric>(
      tooltip: 'Score axis',
      color: luma.surface,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final m in _kFrontierMetrics)
          PopupMenuItem(value: m, child: Text(m.label)),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: luma.surface,
          border: Border.all(color: luma.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value.label, style: TextStyle(color: luma.textPrimary, fontSize: 12.5)),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 16, color: luma.textMuted),
          ],
        ),
      ),
    );
  }
}

class _FrontierChart extends StatelessWidget {
  const _FrontierChart({required this.models, required this.scoreMetric});

  final List<AiModel> models;
  final AiMetric scoreMetric;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final all = [
      for (final m in models)
        if (AiMetric.blendedPrice.valueOf(m) case final cost?)
          if (cost > 0)
            if (scoreMetric.valueOf(m) case final score?)
              (model: m, cost: cost, score: score),
    ];

    if (all.length < 2) {
      return LumaCard(
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text(
              'Not enough priced models rate ${scoreMetric.label} yet.',
              style: TextStyle(color: luma.textMuted),
            ),
          ),
        ),
      );
    }

    final frontier = frontierOf(models,
        costMetric: AiMetric.blendedPrice, scoreMetric: scoreMetric);
    final frontierIds = frontier.map((p) => p.model.id).toSet();

    final logCosts = [for (final p in all) math.log(p.cost) / math.ln10];
    final minLogX = logCosts.reduce(math.min) - 0.15;
    final maxLogX = logCosts.reduce(math.max) + 0.15;
    final scores = [for (final p in all) p.score];
    final minY = scores.reduce(math.min);
    final maxY = scores.reduce(math.max);
    final yPad = (maxY - minY) * 0.12 + 1;

    double sx(double cost) => math.log(cost) / math.ln10;

    return LumaCard(
      child: SizedBox(
        height: 340,
        child: ScatterChart(
          ScatterChartData(
            minX: minLogX,
            maxX: maxLogX,
            minY: minY - yPad,
            maxY: maxY + yPad,
            gridData: FlGridData(
              show: true,
              getDrawingHorizontalLine: (_) => FlLine(color: luma.border, strokeWidth: 1),
              getDrawingVerticalLine: (_) => FlLine(color: luma.border, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: true, border: Border.all(color: luma.border)),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                axisNameWidget: Text('Blended cost \$/1M tokens (8:1 input/output)',
                    style: TextStyle(color: luma.textMuted, fontSize: 11)),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) => Text(
                    formatPrice(math.pow(10, value).toDouble()) ?? '',
                    style: TextStyle(color: luma.textMuted, fontSize: 10),
                  ),
                ),
              ),
              leftTitles: AxisTitles(
                axisNameWidget: Text(scoreMetric.label,
                    style: TextStyle(color: luma.textMuted, fontSize: 11)),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  getTitlesWidget: (value, meta) =>
                      Text(value.toStringAsFixed(0),
                          style: TextStyle(color: luma.textMuted, fontSize: 10)),
                ),
              ),
            ),
            scatterSpots: [
              for (final p in all)
                ScatterSpot(
                  sx(p.cost),
                  p.score,
                  dotPainter: FlDotCirclePainter(
                    radius: frontierIds.contains(p.model.id) ? 8 : 5,
                    color: frontierIds.contains(p.model.id)
                        ? luma.success
                        : luma.textMuted.withValues(alpha: 0.6),
                    strokeWidth: frontierIds.contains(p.model.id) ? 1.5 : 0,
                    strokeColor: luma.background,
                  ),
                ),
            ],
            scatterTouchData: ScatterTouchData(
              touchSpotThreshold: 12,
              touchTooltipData: ScatterTouchTooltipData(
                getTooltipColor: (_) => luma.surfaceHover,
                getTooltipItems: (spot) {
                  final match = all.firstWhere(
                    (p) => (sx(p.cost) - spot.x).abs() < 1e-6 &&
                        (p.score - spot.y).abs() < 1e-6,
                    orElse: () => all.first,
                  );
                  return ScatterTooltipItem(
                    '${match.model.name}\n'
                    '${formatPrice(match.cost)}/M · ${scoreMetric.label} '
                    '${match.score.toStringAsFixed(1)}',
                    textStyle: TextStyle(color: luma.textPrimary, fontSize: 12),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Best by task ───────────────────────────────────────────────────────────

class _TaskSpec {
  const _TaskSpec(this.label, this.metric, this.icon);
  final String label;
  final AiMetric metric;
  final IconData icon;
}

const List<_TaskSpec> _kTasks = [
  _TaskSpec('Best for reasoning', AiMetric.reasoning, Icons.psychology_outlined),
  _TaskSpec('Best for coding', AiMetric.coding, Icons.code_rounded),
  _TaskSpec('Best for agents', AiMetric.agent, Icons.smart_toy_outlined),
  _TaskSpec('Fastest', AiMetric.speed, Icons.bolt_rounded),
  _TaskSpec('Cheapest frontier', AiMetric.blendedPrice, Icons.savings_outlined),
  _TaskSpec('Largest context', AiMetric.context, Icons.unfold_more_rounded),
];

class _BestByTask extends StatelessWidget {
  const _BestByTask({required this.models});

  final List<AiModel> models;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final task in _kTasks)
              SizedBox(
                width: (constraints.maxWidth - (columns - 1) * 12) / columns,
                child: _TaskCard(task: task, model: bestAt(models, task.metric)),
              ),
          ],
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.model});

  final _TaskSpec task;
  final AiModel? model;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final value = model == null ? null : task.metric.valueOf(model!);
    return LumaCard(
      child: InkWell(
        onTap: model == null
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AiModelDetailPage(modelId: model!.id),
                )),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: luma.accentSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(task.icon, size: 19, color: luma.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(task.label,
                      style: TextStyle(color: luma.textMuted, fontSize: 11)),
                  Text(
                    model?.name ?? '–',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (value != null)
                    Text(
                      task.metric.format(value),
                      style: TextStyle(color: luma.textSecondary, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── News ───────────────────────────────────────────────────────────────────

/// A responsive card grid, wide cards on a wide window and a single column
/// on a narrow one — the same breakpoint math as [_BestByTask].
class _NewsList extends StatelessWidget {
  const _NewsList({required this.items});

  final List<AiNewsItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 920
            ? 3
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final item in items.take(9))
              SizedBox(width: width, child: _NewsCard(item: item)),
          ],
        );
      },
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});

  final AiNewsItem item;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final badgeColor = newsSourceColor(item.source);
    return LumaCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.lumaDecor.cardRadius),
        child: InkWell(
          onTap: () =>
              launchUrl(Uri.parse(item.url), mode: LaunchMode.externalApplication),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _NewsBanner(item: item, badgeColor: badgeColor),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.source,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (item.publishedAt != null) ...[
                          const SizedBox(width: 6),
                          Text('· ${relativeDay(item.publishedAt!)}',
                              style:
                                  TextStyle(color: luma.textMuted, fontSize: 11)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.3),
                    ),
                    if (item.summary != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        _firstSentence(item.summary!),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: luma.textMuted, fontSize: 12.5, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The card's top banner: the article's own lead image when the feed
/// supplied one, or — since most of the feeds here never do — a tinted
/// gradient in the source's colour with its badge, so a missing photo never
/// reads as a broken one.
class _NewsBanner extends StatelessWidget {
  const _NewsBanner({required this.item, required this.badgeColor});

  final AiNewsItem item;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final placeholder = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            badgeColor.withValues(alpha: 0.28),
            luma.surface,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: VendorBadge(
        vendor: kNewsSourceVendor[item.source] ?? item.source,
        vendorName: item.source,
        size: 44,
      ),
    );

    if (item.imageUrl == null) return placeholder;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          item.imageUrl!,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : placeholder,
          errorBuilder: (context, error, stack) => placeholder,
        ),
        // The badge still shows over a real photo — it's what identifies the
        // source at a glance, not just decoration for the empty case.
        Positioned(
          left: 10,
          bottom: 10,
          child: VendorBadge(
            vendor: kNewsSourceVendor[item.source] ?? item.source,
            vendorName: item.source,
            size: 32,
          ),
        ),
      ],
    );
  }
}

/// The excerpt shown under the title: just the opening sentence rather than
/// a mid-sentence cut wherever the 2-line clamp happens to land.
String _firstSentence(String text) {
  final match = RegExp(r'^.*?[.!?](?=\s|$)').firstMatch(text);
  return match == null ? text : match.group(0)!;
}
