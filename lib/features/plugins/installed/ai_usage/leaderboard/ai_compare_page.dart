import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import 'ai_catalog_scope.dart';
import 'ai_leaderboard_metric.dart';
import 'ai_model.dart';

const int kMaxCompareModels = 4;

const List<Color> _kCompareColors = [
  Color(0xFFC4B5FD),
  Color(0xFF6EE7B7),
  Color(0xFFFCA5A5),
  Color(0xFF93C5FD),
];

/// The five ratings shown on the radar. Fixed rather than user-chosen: a
/// radar with a changing axis set is unreadable, and these five are the ones
/// every model in the catalogue is scored on the same 0–100 scale.
const List<AiMetric> _kRadarMetrics = [
  AiMetric.llmStats,
  AiMetric.reasoning,
  AiMetric.coding,
  AiMetric.agent,
  AiMetric.math,
];

/// Every row shown in the diff table beneath the radar.
const List<AiMetric> _kCompareRows = [
  AiMetric.llmStats,
  AiMetric.reasoning,
  AiMetric.coding,
  AiMetric.agent,
  AiMetric.math,
  AiMetric.codeArena,
  AiMetric.context,
  AiMetric.inputPrice,
  AiMetric.outputPrice,
  AiMetric.blendedPrice,
  AiMetric.speed,
  AiMetric.latency,
];

/// Compares up to [kMaxCompareModels] models side by side: a radar of the
/// five rating axes, then every metric as its own row so the gaps a radar
/// compresses away are still readable.
class AiComparePage extends StatefulWidget {
  const AiComparePage({super.key, this.initialModelIds = const []});

  final List<String> initialModelIds;

  @override
  State<AiComparePage> createState() => _AiComparePageState();
}

class _AiComparePageState extends State<AiComparePage> {
  late List<String> _selected = widget.initialModelIds.take(kMaxCompareModels).toList();

  @override
  Widget build(BuildContext context) {
    final repo = AiCatalogScope.of(context);
    final luma = context.luma;

    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        title: const Text('Compare models'),
      ),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final all = repo.catalog.models;
          final models = [
            for (final id in _selected)
              ?repo.byId(id),
          ];

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _ModelPickerRow(
                  all: all,
                  selected: _selected,
                  onChange: (ids) => setState(() => _selected = ids),
                ),
                const SizedBox(height: 18),
                if (models.length < 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'Pick at least two models to compare.',
                        style: TextStyle(color: luma.textMuted),
                      ),
                    ),
                  )
                else ...[
                  _RadarCard(models: models),
                  const SizedBox(height: 18),
                  _DiffTable(models: models),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ModelPickerRow extends StatelessWidget {
  const _ModelPickerRow({required this.all, required this.selected, required this.onChange});

  final List<AiModel> all;
  final List<String> selected;
  final ValueChanged<List<String>> onChange;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < selected.length; i++)
          _SelectedChip(
            model: all.firstWhere((m) => m.id == selected[i], orElse: () => all.first),
            color: _kCompareColors[i % _kCompareColors.length],
            onRemove: () => onChange([...selected]..removeAt(i)),
          ),
        if (selected.length < kMaxCompareModels)
          _AddModelButton(
            all: all,
            excluded: selected.toSet(),
            onPick: (id) => onChange([...selected, id]),
          ),
        if (selected.isEmpty)
          Text(
            'Add models to compare them side by side.',
            style: TextStyle(color: luma.textMuted, fontSize: 12.5),
          ),
      ],
    );
  }
}

class _SelectedChip extends StatelessWidget {
  const _SelectedChip({required this.model, required this.color, required this.onRemove});

  final AiModel model;
  final Color color;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border.all(color: color, width: 1.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(model.name, style: TextStyle(color: luma.textPrimary, fontSize: 12.5)),
          const SizedBox(width: 2),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 14, color: luma.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddModelButton extends StatelessWidget {
  const _AddModelButton({required this.all, required this.excluded, required this.onPick});

  final List<AiModel> all;
  final Set<String> excluded;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final options = [for (final m in all) if (!excluded.contains(m.id)) m]
      ..sort((a, b) => a.name.compareTo(b.name));
    return PopupMenuButton<String>(
      tooltip: 'Add a model',
      color: luma.surface,
      constraints: const BoxConstraints(maxHeight: 360),
      onSelected: onPick,
      itemBuilder: (context) => [
        for (final m in options) PopupMenuItem(value: m.id, child: Text(m.name)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: luma.border, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 15, color: luma.accent),
            const SizedBox(width: 4),
            Text('Add model', style: TextStyle(color: luma.accent, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class _RadarCard extends StatelessWidget {
  const _RadarCard({required this.models});

  final List<AiModel> models;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    // Metrics no model in the current selection has a value for are dropped
    // rather than drawn as a false zero on the radar — a model that has
    // never been scored on Math is unmeasured there, not a zero.
    final axes = [
      for (final metric in _kRadarMetrics)
        if (models.any((m) => metric.valueOf(m) != null)) metric,
    ];
    if (axes.length < 3) {
      return LumaCard(
        child: SizedBox(
          height: 160,
          child: Center(
            child: Text(
              'Not enough shared ratings to draw a radar for this selection.',
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textMuted),
            ),
          ),
        ),
      );
    }

    return LumaCard(
      child: SizedBox(
        height: 320,
        child: RadarChart(
          RadarChartData(
            radarShape: RadarShape.polygon,
            tickCount: 4,
            ticksTextStyle: TextStyle(color: luma.textMuted, fontSize: 9),
            radarBorderData: BorderSide(color: luma.border),
            gridBorderData: BorderSide(color: luma.border, width: 1),
            tickBorderData: BorderSide(color: luma.border, width: 1),
            titleTextStyle: TextStyle(color: luma.textSecondary, fontSize: 11),
            getTitle: (index, angle) => RadarChartTitle(text: axes[index].label),
            dataSets: [
              for (var i = 0; i < models.length; i++)
                RadarDataSet(
                  fillColor: _kCompareColors[i % _kCompareColors.length]
                      .withValues(alpha: 0.16),
                  borderColor: _kCompareColors[i % _kCompareColors.length],
                  borderWidth: 2,
                  entryRadius: 3,
                  dataEntries: [
                    for (final metric in axes)
                      RadarEntry(value: metric.valueOf(models[i]) ?? 0),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiffTable extends StatelessWidget {
  const _DiffTable({required this.models});

  final List<AiModel> models;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final rows = [
      for (final metric in _kCompareRows)
        if (models.any((m) => metric.valueOf(m) != null)) metric,
    ];

    return LumaCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Expanded(flex: 2, child: SizedBox()),
                for (var i = 0; i < models.length; i++)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _kCompareColors[i % _kCompareColors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            models[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: luma.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Container(height: 1, color: luma.border),
          for (final metric in rows) _DiffRow(metric: metric, models: models),
        ],
      ),
    );
  }
}

class _DiffRow extends StatelessWidget {
  const _DiffRow({required this.metric, required this.models});

  final AiMetric metric;
  final List<AiModel> models;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final values = [for (final m in models) metric.valueOf(m)];
    final known = [for (final v in values) ?v];
    final best = known.isEmpty
        ? null
        : (metric.higherIsBetter ? known.reduce((a, b) => a > b ? a : b) : known.reduce((a, b) => a < b ? a : b));

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: luma.border.withValues(alpha: 0.5))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(metric.axisLabel,
                style: TextStyle(color: luma.textSecondary, fontSize: 12.5)),
          ),
          for (final value in values)
            Expanded(
              child: Center(
                child: value == null
                    ? Text('–', style: TextStyle(color: luma.textMuted, fontSize: 13))
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: value == best
                              ? luma.success.withValues(alpha: 0.14)
                              : null,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          metric.format(value),
                          style: TextStyle(
                            color: value == best ? luma.success : luma.textPrimary,
                            fontSize: 13,
                            fontWeight: value == best ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
