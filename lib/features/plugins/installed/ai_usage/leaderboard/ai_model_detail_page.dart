import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import 'ai_catalog_scope.dart';
import 'ai_compare_page.dart';
import 'ai_leaderboard_format.dart';
import 'ai_model.dart';

/// Full detail on one model: every rating, its pricing, and — when the
/// provider supports it — how much smarter each reasoning-effort tier gets
/// and how many tokens that costs.
///
/// Looked up by id from the repository already in the widget tree rather than
/// carrying its own copy of the model, so it always reflects the latest
/// catalogue even if the page was opened before a background refresh landed.
class AiModelDetailPage extends StatelessWidget {
  const AiModelDetailPage({super.key, required this.modelId});

  final String modelId;

  @override
  Widget build(BuildContext context) {
    final repo = AiCatalogScope.of(context);
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final model = repo.byId(modelId);
        final luma = context.luma;
        return Scaffold(
          backgroundColor: luma.background,
          appBar: AppBar(
            backgroundColor: luma.background,
            elevation: 0,
            title: Text(model?.name ?? 'Model'),
            actions: [
              if (model != null)
                IconButton(
                  tooltip: 'Compare with other models',
                  icon: const Icon(Icons.compare_arrows_rounded),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AiComparePage(initialModelIds: [model.id]),
                  )),
                ),
            ],
          ),
          body: model == null
              ? const Center(child: Text('This model is no longer listed.'))
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      _Header(model: model),
                      const SizedBox(height: 20),
                      _RatingsGrid(model: model),
                      const SizedBox(height: 20),
                      _SpecsCard(model: model),
                      if (model.hasEffortGraph) ...[
                        const SizedBox(height: 20),
                        _EffortSection(model: model),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.model});

  final AiModel model;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(model.vendorName,
                        style: TextStyle(color: luma.textMuted, fontSize: 12.5)),
                    Text(
                      model.name,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: model.openWeights
                    ? 'Open weights${model.licenseName == null ? "" : " · ${model.licenseName}"}'
                    : 'Proprietary — API access only',
                child: Icon(
                  model.openWeights ? Icons.lock_open_rounded : Icons.lock_rounded,
                  color: model.openWeights ? luma.success : luma.textMuted,
                ),
              ),
            ],
          ),
          if (model.description != null) ...[
            const SizedBox(height: 10),
            Text(model.description!,
                style: TextStyle(color: luma.textSecondary, fontSize: 13, height: 1.5)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (model.releasedAt != null)
                _Tag(icon: Icons.event_rounded,
                    text: 'Released ${relativeDay(model.releasedAt!)}'),
              if (model.knowledgeCutoff != null)
                _Tag(icon: Icons.schedule_rounded,
                    text: 'Knowledge cutoff ${model.knowledgeCutoff}'),
              if (model.parametersB != null)
                _Tag(icon: Icons.memory_rounded,
                    text: '${model.parametersB!.toStringAsFixed(model.parametersB! >= 100 ? 0 : 1)}B params'),
              for (final modality in model.inputModalities)
                _Tag(icon: Icons.input_rounded, text: modality),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: luma.textMuted),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: luma.textSecondary, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _RatingsGrid extends StatelessWidget {
  const _RatingsGrid({required this.model});

  final AiModel model;

  @override
  Widget build(BuildContext context) {
    final ratings = <(String, double?, String)>[
      ('LLM Stats', model.llmStatsIndex, 'Overall composite rating'),
      ('Reasoning', model.reasoningIndex, 'Graduate-level reasoning & knowledge'),
      ('Coding', model.codingIndex, 'Code generation and repair'),
      ('Agent', model.agentIndex, 'Long-horizon tool use'),
      ('Code Arena', model.codeArena, 'Head-to-head coding preference Elo'),
      ('Math', model.mathIndex, 'Competition-level mathematics'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 3 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (label, value, help) in ratings)
              SizedBox(width: width, child: _RatingTile(label: label, value: value, help: help)),
          ],
        );
      },
    );
  }
}

class _RatingTile extends StatelessWidget {
  const _RatingTile({required this.label, required this.value, required this.help});

  final String label;
  final double? value;
  final String help;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Tooltip(
      message: help,
      child: LumaCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: TextStyle(
                    color: luma.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6)),
            const SizedBox(height: 4),
            Text(
              value == null ? '–' : value!.toStringAsFixed(1),
              style: TextStyle(
                  color: luma.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecsCard extends StatelessWidget {
  const _SpecsCard({required this.model});

  final AiModel model;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final rows = <(String, String)>[
      if (model.contextTokens != null)
        ('Context window', '${formatExactTokens(model.contextTokens!)} tokens'),
      if (model.maxOutputTokens != null)
        ('Max output', '${formatExactTokens(model.maxOutputTokens!)} tokens'),
      if (model.inputPricePerM != null)
        ('Input price', '${formatPrice(model.inputPricePerM)}/M tokens'),
      if (model.outputPricePerM != null)
        ('Output price', '${formatPrice(model.outputPricePerM)}/M tokens'),
      if (model.cacheReadPerM != null)
        ('Cache read', '${formatPrice(model.cacheReadPerM)}/M tokens'),
      if (model.speedTokensPerSec != null)
        ('Speed', '${model.speedTokensPerSec!.round()} tok/s'),
      if (model.latencyMs != null)
        ('Time to first token', '${(model.latencyMs! / 1000).toStringAsFixed(2)}s'),
      if (model.hasEffortLevels)
        ('Effort levels', model.supportedEfforts.join(', ')),
      if (model.licenseName != null) ('Licence', model.licenseName!),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SPECIFICATIONS',
              style: TextStyle(
                  color: luma.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 10),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: TextStyle(color: luma.textSecondary, fontSize: 13)),
                  ),
                  Text(value,
                      style: TextStyle(
                          color: luma.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The effort-level trade-off: how much smarter (X axis) each tier gets for
/// how many more tokens it burns (Y axis) doing it.
///
/// Only shown when the provider both exposes effort levels *and* Artificial
/// Analysis has measured more than one tier — one point can't draw a trend,
/// and a provider with no effort levels has nothing to trade off.
class _EffortSection extends StatelessWidget {
  const _EffortSection({required this.model});

  final AiModel model;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final points = [
      for (final e in model.effortProfiles)
        if (e.intelligenceIndex != null) e,
    ];
    // Artificial Analysis doesn't publish a token count for every tier it
    // rates — the intelligence trend is the point of this chart, so it draws
    // with or without that second dimension.
    final tokenPoints = [
      for (final p in points)
        if (p.medianOutputTokens != null) p,
    ];

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EFFORT VS TOKENS USED',
              style: TextStyle(
                  color: luma.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(
            'How much smarter each reasoning-effort tier gets, and how many '
            'tokens it spends thinking to get there.',
            style: TextStyle(color: luma.textMuted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) => FlLine(color: luma.border, strokeWidth: 1),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: true, border: Border.all(color: luma.border)),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i < 0 || i >= points.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(points[i].label,
                              style: TextStyle(color: luma.textMuted, fontSize: 10)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: Text('Intelligence index',
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
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < points.length; i++)
                        FlSpot(i.toDouble(), points[i].intelligenceIndex!),
                    ],
                    isCurved: true,
                    color: luma.accent,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(radius: 5, color: luma.accent),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: luma.accent.withValues(alpha: 0.12),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => luma.surfaceHover,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          () {
                            final p = points[s.x.round()];
                            final index = 'Index ${s.y.toStringAsFixed(1)}';
                            final tokens = p.medianOutputTokens == null
                                ? ''
                                : ' · ${formatExactTokens(p.medianOutputTokens!)} tok';
                            return '${p.label}\n$index$tokens';
                          }(),
                          TextStyle(color: luma.textPrimary, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (tokenPoints.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final p in tokenPoints)
                  Text(
                    '${p.label}: ${formatExactTokens(p.medianOutputTokens!)} tok',
                    style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
