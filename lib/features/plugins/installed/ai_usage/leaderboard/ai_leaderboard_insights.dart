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
import 'vendor_logos.dart';

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

class _NewsCard extends StatefulWidget {
  const _NewsCard({required this.item});

  final AiNewsItem item;

  @override
  State<_NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<_NewsCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final luma = context.luma;
    final brand = newsSourceColor(item.source);
    final still = MediaQuery.disableAnimationsOf(context);
    const motion = Duration(milliseconds: 240);
    return LumaCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.lumaDecor.cardRadius),
        child: InkWell(
          onTap: () => launchUrl(
            Uri.parse(item.url),
            mode: LaunchMode.externalApplication,
          ),
          onHover: (hovered) => setState(() => _hovered = hovered),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 2,
                child: ClipRect(
                  child: AnimatedScale(
                    scale: _hovered && !still ? 1.04 : 1,
                    duration: still ? Duration.zero : motion,
                    curve: Curves.easeOutCubic,
                    child: _NewsBanner(item: item, brand: brand),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: still ? Duration.zero : motion,
                height: 2,
                color: brand.withValues(alpha: _hovered ? 0.95 : 0.45),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.publishedAt == null
                                ? item.source
                                : relativeDay(item.publishedAt!),
                            style: TextStyle(
                              color: luma.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.north_east_rounded,
                          size: 15,
                          color: _hovered ? brand : luma.textMuted,
                        ),
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
                        height: 1.3,
                      ),
                    ),
                    if (item.summary != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        _firstSentence(item.summary!),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: luma.textMuted,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
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
/// supplied one, or — since most of the feeds here never do — generated
/// cover art in the source's colour. Either way the source's masthead sits
/// bottom-left, so every card is identifiable at a glance.
class _NewsBanner extends StatelessWidget {
  const _NewsBanner({required this.item, required this.brand});

  final AiNewsItem item;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final art = RepaintBoundary(
      child: CustomPaint(
        painter: _BannerArtPainter(
          brand: brand,
          seed: _stableSeed(item.id.isEmpty ? item.url : item.id),
          dark: dark,
          monogram: newsSourceInitials(item.source),
        ),
      ),
    );
    final hasImage = item.imageUrl != null;
    final published = item.publishedAt;
    final fresh =
        published != null &&
        DateTime.now().difference(published) < const Duration(hours: 48);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasImage)
          Image.network(
            item.imageUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : art,
            errorBuilder: (context, error, stack) => art,
          )
        else
          art,
        if (hasImage)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.45, 1],
                colors: [Color(0x00000000), Color(0x99000000)],
              ),
            ),
          ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 12,
          child: _SourceMasthead(
            source: item.source,
            brand: brand,
            onDark: hasImage || dark,
          ),
        ),
        if (fresh)
          Positioned(top: 12, right: 12, child: _FreshPill(brand: brand)),
      ],
    );
  }
}

/// The source's mark and name, set like a publication masthead.
class _SourceMasthead extends StatelessWidget {
  const _SourceMasthead({
    required this.source,
    required this.brand,
    required this.onDark,
  });

  final String source;
  final Color brand;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final vendor = kNewsSourceVendor[source];
    return Row(
      children: [
        if (vendor != null)
          VendorLogo(vendor: vendor, vendorName: source, size: 26)
        else
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: brand,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: brand.withValues(alpha: 0.45), blurRadius: 10),
              ],
            ),
            child: Text(
              newsSourceInitials(source),
              style: TextStyle(
                color: _inkOn(brand),
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            source,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: onDark ? Colors.white : const Color(0xFF14121A),
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              shadows: onDark
                  ? const [Shadow(color: Color(0x66000000), blurRadius: 6)]
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Flags an article from the last two days.
class _FreshPill extends StatelessWidget {
  const _FreshPill({required this.brand});

  final Color brand;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: brand,
        borderRadius: BorderRadius.circular(context.lumaDecor.pillRadius),
      ),
      child: Text(
        'NEW',
        style: TextStyle(
          color: _inkOn(brand),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Black or white, whichever reads on [fill] — the brand colours run from
/// xAI's near-white to DeepSeek's indigo.
Color _inkOn(Color fill) =>
    fill.computeLuminance() > 0.4 ? const Color(0xFF14121A) : Colors.white;

/// FNV-1a over the key, so an article keeps the same cover art across runs
/// (`String.hashCode` makes no such promise).
int _stableSeed(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

/// Cover art for an article with no image of its own: a wash in the
/// source's colour, two glows, one of four line motifs and an oversized
/// monogram, all placed by [seed] — every card from one source shares a
/// palette but no two look the same.
class _BannerArtPainter extends CustomPainter {
  _BannerArtPainter({
    required this.brand,
    required this.seed,
    required this.dark,
    required this.monogram,
  });

  final Color brand;
  final int seed;
  final bool dark;
  final String monogram;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final hsl = HSLColor.fromColor(brand);
    final sat = math.min(hsl.saturation, 0.8);
    final base = hsl.withSaturation(sat);
    final shifted = base.withHue((hsl.hue + 24 + rnd.nextDouble() * 36) % 360);
    final ink = dark ? Colors.white : Colors.black;

    final angle = rnd.nextDouble() * math.pi;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-math.cos(angle), -math.sin(angle)),
          end: Alignment(math.cos(angle), math.sin(angle)),
          colors: [
            base.withLightness(dark ? 0.20 : 0.84).toColor(),
            shifted
                .withSaturation(sat * 0.7)
                .withLightness(dark ? 0.07 : 0.95)
                .toColor(),
          ],
        ).createShader(rect),
    );

    final hot = Offset(
      w * (0.55 + rnd.nextDouble() * 0.4),
      h * (-0.1 + rnd.nextDouble() * 0.5),
    );
    _glow(
      canvas,
      hot,
      w * 0.6,
      base.withLightness(dark ? 0.55 : 0.62).toColor().withValues(alpha: 0.55),
    );
    _glow(
      canvas,
      Offset(w * rnd.nextDouble() * 0.4, h * (0.7 + rnd.nextDouble() * 0.4)),
      w * 0.45,
      shifted
          .withLightness(dark ? 0.5 : 0.7)
          .toColor()
          .withValues(alpha: dark ? 0.35 : 0.45),
    );

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    switch (seed % 4) {
      case 0:
        final dot = Paint();
        for (var x = 8.0; x < w; x += 16) {
          for (var y = 8.0; y < h; y += 16) {
            dot.color = ink.withValues(alpha: 0.16 * (x / w));
            canvas.drawCircle(Offset(x, y), 1.2, dot);
          }
        }
      case 1:
        for (var r = 20.0; r < w; r += 20) {
          line.color = ink.withValues(alpha: 0.13 * (1 - r / w));
          canvas.drawCircle(hot, r, line);
        }
      case 2:
        line.color = ink.withValues(alpha: 0.07);
        for (var x = -h; x < w; x += 14) {
          canvas.drawLine(Offset(x, h), Offset(x + h, 0), line);
        }
      default:
        final nodes = [
          for (var i = 0; i < 7; i++)
            Offset(
              w * (0.4 + rnd.nextDouble() * 0.56),
              h * (0.08 + rnd.nextDouble() * 0.7),
            ),
        ];
        line.color = ink.withValues(alpha: 0.2);
        for (var i = 0; i < nodes.length; i++) {
          canvas.drawLine(nodes[i], nodes[(i + 1) % nodes.length], line);
          if (i.isEven) {
            canvas.drawLine(nodes[i], nodes[(i + 3) % nodes.length], line);
          }
        }
        final node = Paint()..color = ink.withValues(alpha: 0.45);
        for (final n in nodes) {
          canvas.drawCircle(n, 2.6, node);
        }
        canvas.drawCircle(
          nodes.first,
          7,
          line
            ..color = base.withLightness(dark ? 0.72 : 0.4).toColor()
            ..strokeWidth = 1.6,
        );
    }

    final mark = TextPainter(
      text: TextSpan(
        text: monogram,
        style: TextStyle(
          fontSize: h * 0.9,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: -h * 0.04,
          color: ink.withValues(alpha: dark ? 0.08 : 0.07),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    mark.paint(canvas, Offset(w - mark.width * 0.9, h - mark.height * 0.8));
    mark.dispose();

    // Seats the masthead.
    final shade = dark ? Colors.black : Colors.white;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.45, 1],
          colors: [shade.withValues(alpha: 0), shade.withValues(alpha: 0.35)],
        ).createShader(rect),
    );
  }

  void _glow(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_BannerArtPainter old) =>
      old.brand != brand ||
      old.seed != seed ||
      old.dark != dark ||
      old.monogram != monogram;
}

/// The excerpt shown under the title: just the opening sentence rather than
/// a mid-sentence cut wherever the 2-line clamp happens to land.
String _firstSentence(String text) {
  final match = RegExp(r'^.*?[.!?](?=\s|$)').firstMatch(text);
  return match == null ? text : match.group(0)!;
}
