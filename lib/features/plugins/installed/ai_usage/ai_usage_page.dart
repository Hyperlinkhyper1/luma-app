import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import '../../../chat/ai_key_store.dart';
import '../../../chat/providers/ai_providers.dart';
import 'ai_usage_repository.dart';
import 'ai_usage_scope.dart';
import 'ai_usage_source.dart';
import 'ai_usage_stats.dart';
import 'data/ai_usage_database.dart';

/// How many models get their own pie slice / legend row before the rest are
/// folded into a single "Other" bucket.
const int _kTopModelLimit = 6;

const List<Color> _kPalette = [
  Color(0xFFB49DF5), // lavender
  Color(0xFF57D9A3), // mint
  Color(0xFFFF6B81), // coral
  Color(0xFFFFD166), // gold
  Color(0xFF6ECBF5), // sky
  Color(0xFFBC96E6), // purple
];
const Color _kOtherColor = Color(0xFF8A8A9A);

/// A private, offline dashboard for local AI coding CLI usage — token
/// counts and cost estimates by day and model, read entirely from
/// `~/.claude/projects`, `~/.codex/sessions`, and
/// `~/.gemini/antigravity/brain` on this device. The first two are exact,
/// provider-metered counts; Antigravity's are estimated from message length
/// (it doesn't record token usage locally at all) and are labelled as such
/// everywhere they appear.
class AiUsagePage extends StatefulWidget {
  const AiUsagePage({super.key});

  @override
  State<AiUsagePage> createState() => _AiUsagePageState();
}

class _AiUsagePageState extends State<AiUsagePage> {
  AiUsageRangePreset _preset = AiUsageRangePreset.today;
  AiUsageSource? _sourceFilter; // null = All
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The scope isn't reachable from initState, and the first scan has to
    // wait for it. Only ever kicked off once per page lifetime — the Rescan
    // button covers every case after that.
    if (_started) return;
    _started = true;
    AiUsageScope.of(context).rescan();
  }

  @override
  Widget build(BuildContext context) {
    final repo = AiUsageScope.of(context);

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        if (repo.anyDirFound == null) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          );
        }

        if (repo.anyDirFound == false) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: LumaEmptyState(
              icon: Icons.smart_toy_outlined,
              title: 'No local AI usage logs found',
              subtitle: 'AI Usage reads session logs from Claude Code '
                  '(~/.claude/projects), Codex CLI (~/.codex/sessions), and '
                  'Antigravity (~/.gemini/antigravity) on this device — '
                  'nothing is ever sent anywhere. Use one of these tools '
                  'here, then rescan.',
              action: LumaGhostButton(
                label: repo.scanning ? 'Scanning…' : 'Rescan',
                icon: Icons.refresh_rounded,
                onTap: repo.scanning ? null : repo.rescan,
              ),
            ),
          );
        }

        final (start, end) = resolveAiUsageRange(_preset, DateTime.now());

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                repo: repo,
                preset: _preset,
                onSelectPreset: (p) => setState(() => _preset = p),
              ),
              const SizedBox(height: 10),
              _SourceFilterBar(
                selected: _sourceFilter,
                onSelect: (s) => setState(() => _sourceFilter = s),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamData<List<AiUsageTurn>>(
                  stream: repo.watchRange(start, end),
                  builder: (context, turns) => _AiUsageBody(
                    turns: _sourceFilter == null
                        ? turns
                        : turns.where((t) => t.source == _sourceFilter).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Top bar: range presets, rescan, status ─────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.repo,
    required this.preset,
    required this.onSelectPreset,
  });

  final AiUsageRepository repo;
  final AiUsageRangePreset preset;
  final ValueChanged<AiUsageRangePreset> onSelectPreset;

  String _statusLabel() {
    if (repo.scanning) return 'Scanning…';
    final at = repo.lastScanAt;
    if (at == null) return '';
    if (repo.lastTurnsAdded == 0) {
      return 'Up to date · ${DateFormat('h:mm a').format(at)}';
    }
    return '${repo.lastTurnsAdded} new turns · ${DateFormat('h:mm a').format(at)}';
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Flexible(
          child: LumaSegmentedTabs(
            tabs: [for (final p in AiUsageRangePreset.values) p.label],
            selectedIndex: preset.index,
            onSelect: (i) => onSelectPreset(AiUsageRangePreset.values[i]),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _statusLabel(),
          style: TextStyle(color: luma.textMuted, fontSize: 12),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Rescan local AI usage logs',
          icon: repo.scanning
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(luma.textSecondary),
                  ),
                )
              : Icon(Icons.refresh_rounded, color: luma.textSecondary),
          onPressed: repo.scanning ? null : repo.rescan,
        ),
      ],
    );
  }
}

// ─── Source filter: All / Claude Code / Codex CLI ───────────────────────────

class _SourceFilterBar extends StatelessWidget {
  const _SourceFilterBar({required this.selected, required this.onSelect});

  final AiUsageSource? selected;
  final ValueChanged<AiUsageSource?> onSelect;

  static const _options = <AiUsageSource?>[
    null,
    AiUsageSource.claudeCode,
    AiUsageSource.codexCli,
    AiUsageSource.antigravity,
  ];

  @override
  Widget build(BuildContext context) {
    return LumaSegmentedTabs(
      tabs: const ['All', 'Claude Code', 'Codex CLI', 'Antigravity (est.)'],
      selectedIndex: _options.indexOf(selected),
      onSelect: (i) => onSelect(_options[i]),
    );
  }
}

// ─── Body: stat tiles, charts, table, once turns for the range arrive ──────

class _AiUsageBody extends StatelessWidget {
  const _AiUsageBody({required this.turns});

  final List<AiUsageTurn> turns;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final modelTotals = aggregateByModel(turns);

    if (modelTotals.isEmpty) {
      return const LumaEmptyState(
        icon: Icons.smart_toy_outlined,
        title: 'No usage recorded in this range',
        subtitle: 'Try a wider range, or use one of the supported tools and rescan.',
      );
    }

    final dayBuckets = aggregateByDay(turns);
    final summary = totals(turns);
    final colorByModel = <(AiUsageSource, String), Color>{
      for (var i = 0; i < modelTotals.length && i < _kTopModelLimit; i++)
        (modelTotals[i].source, modelTotals[i].model): _kPalette[i % _kPalette.length],
    };

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryChip(
                label: 'Total tokens',
                value: _formatTokens(summary.totalTokens),
                tooltip: 'New tokens only: input + output + first-time cache writes. '
                    "Doesn't include cache reads (see that tile) — a long session re-reads "
                    "the same growing context on nearly every turn, which would otherwise "
                    'count the same conversation over and over.',
              ),
              if (summary.cacheReadTokens > 0)
                _SummaryChip(
                  label: 'Cache reads',
                  value: _formatTokens(summary.cacheReadTokens),
                  tooltip: 'Cached context re-read across all turns in range — real and '
                      'billed, but at a steep discount, and not counted in "Total tokens" '
                      'since it\'s re-use of content rather than new content.',
                ),
              _SummaryChip(
                label: 'Est. cost',
                value: summary.hasUnbillable
                    ? '${_formatCost(summary.cost)}*'
                    : _formatCost(summary.cost),
                tooltip: 'Estimated cost at API rates, including cache reads/writes at '
                    'their discounted rate — so this reflects more usage than "Total '
                    'tokens" shows on its own. Subscription plans (Max/Pro) bill '
                    'differently than this per-token estimate.',
              ),
              _SummaryChip(label: 'Turns', value: '${summary.turnCount}'),
              _SummaryChip(label: 'Sessions', value: '${summary.sessionCount}'),
              _SummaryChip(
                label: 'Top model',
                value: _displayName(modelTotals.first.source, modelTotals.first.model),
              ),
            ],
          ),
          if (summary.hasUnbillable) ...[
            const SizedBox(height: 6),
            Text(
              '* excludes usage from models outside their provider\'s known pricing',
              style: TextStyle(color: luma.textMuted, fontSize: 11),
            ),
          ],
          if (turns.any((t) => t.source == AiUsageSource.antigravity)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: luma.accentSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: luma.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Antigravity numbers are estimated from message length — it '
                      "doesn't record real token usage locally. They're not exact "
                      'like Claude Code/Codex CLI, and never priced.',
                      style: TextStyle(color: luma.textSecondary, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final pie = LumaCard(
                child: SizedBox(
                  height: 260,
                  child: _ModelPieChart(
                    modelTotals: modelTotals,
                    colorByModel: colorByModel,
                  ),
                ),
              );
              final bars = LumaCard(
                child: SizedBox(
                  height: 260,
                  child: dayBuckets.length <= 1
                      ? Center(
                          child: Text(
                            'Pick a wider range to see a daily breakdown',
                            style: TextStyle(color: luma.textMuted, fontSize: 13),
                          ),
                        )
                      : _DailyBarChart(dayBuckets: dayBuckets),
                ),
              );

              if (constraints.maxWidth < 760) {
                return Column(children: [pie, const SizedBox(height: 16), bars]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: pie),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: bars),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LumaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ModelTableHeader(),
                const SizedBox(height: 8),
                for (var i = 0; i < modelTotals.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _ModelListRow(
                    total: modelTotals[i],
                    color: colorByModel[(modelTotals[i].source, modelTotals[i].model)] ??
                        _kOtherColor,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _OtherAiToolsSection(),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value, this.tooltip});
  final String label;
  final String value;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(color: luma.textMuted, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
                color: luma.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip, child: chip);
  }
}

// ─── Pie chart: share of tokens by model ────────────────────────────────────

class _ModelPieChart extends StatefulWidget {
  const _ModelPieChart({required this.modelTotals, required this.colorByModel});

  final List<ModelUsageTotal> modelTotals;
  final Map<(AiUsageSource, String), Color> colorByModel;

  @override
  State<_ModelPieChart> createState() => _ModelPieChartState();
}

class _ModelPieChartState extends State<_ModelPieChart> {
  int? _touchedIndex;

  List<(String label, int tokens, Color color)> _slices() {
    final top = widget.modelTotals.take(_kTopModelLimit).toList();
    final rest = widget.modelTotals.skip(_kTopModelLimit);
    final otherTokens = rest.fold<int>(0, (a, t) => a + t.totalTokens);
    return [
      for (final t in top)
        (
          _displayName(t.source, t.model),
          t.totalTokens,
          widget.colorByModel[(t.source, t.model)]!,
        ),
      if (otherTokens > 0) ('Other', otherTokens, _kOtherColor),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final slices = _slices();
    final total = slices.fold<int>(0, (a, s) => a + s.$2);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    _touchedIndex = response?.touchedSection?.touchedSectionIndex;
                  });
                },
              ),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                for (var i = 0; i < slices.length; i++)
                  PieChartSectionData(
                    color: slices[i].$3,
                    value: slices[i].$2.toDouble(),
                    title: '',
                    radius: _touchedIndex == i ? 54 : 46,
                    badgeWidget: _touchedIndex == i
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: luma.surfaceHover,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: luma.border),
                            ),
                            child: Text(
                              _formatTokens(slices[i].$2),
                              style: TextStyle(
                                  color: luma.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          )
                        : null,
                    badgePositionPercentageOffset: 1.2,
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in slices) ...[
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration:
                            BoxDecoration(color: s.$3, borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.$1,
                          style: TextStyle(color: luma.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        total == 0 ? '0%' : '${(s.$2 / total * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                            color: luma.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Bar chart: tokens per day ───────────────────────────────────────────────

class _DailyBarChart extends StatelessWidget {
  const _DailyBarChart({required this.dayBuckets});

  final List<AiDayUsageBucket> dayBuckets;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final maxTokens =
        dayBuckets.map((d) => d.totalTokens).fold<int>(0, (a, b) => a > b ? a : b);
    final topY = maxTokens == 0 ? 1000.0 : maxTokens * 1.15;

    return BarChart(
      BarChartData(
        maxY: topY,
        minY: 0,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${DateFormat('MMM d').format(dayBuckets[groupIndex].day)}\n'
              '${_formatTokens(dayBuckets[groupIndex].totalTokens)} tokens\n'
              '${_formatCost(dayBuckets[groupIndex].cost)}',
              TextStyle(color: luma.textPrimary, fontSize: 12),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (dayBuckets.length / 8).ceilToDouble().clamp(1, 999),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= dayBuckets.length || value != idx.toDouble()) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('M/d').format(dayBuckets[idx].day),
                    style: TextStyle(color: luma.textMuted, fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (value, meta) => Text(
                _formatTokens(value.round()),
                style: TextStyle(color: luma.textMuted, fontSize: 10),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: luma.border.withValues(alpha: 0.5), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < dayBuckets.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: dayBuckets[i].totalTokens.toDouble(),
                  color: luma.accent,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Model table header ──────────────────────────────────────────────────────

class _ModelTableHeader extends StatelessWidget {
  const _ModelTableHeader();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final labelStyle = TextStyle(
      color: luma.textMuted,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );

    Widget header(String label, String tooltip, {double? width, int? flex, TextAlign? align}) {
      final text = Text(label, style: labelStyle, textAlign: align, maxLines: 1);
      final tipped = Tooltip(message: tooltip, child: text);
      return width != null ? SizedBox(width: width, child: tipped) : Expanded(flex: flex!, child: tipped);
    }

    return Row(
      children: [
        const SizedBox(width: 20), // lines up with the color-dot + gap in each row below
        header('Model', 'Which model was used, and which local tool it came from', flex: 2),
        const SizedBox(width: 12),
        header(
          'Turns',
          'How many separate AI responses (API calls) were made with this model',
          width: 48,
          align: TextAlign.right,
        ),
        const SizedBox(width: 12),
        header(
          'Tokens',
          'New tokens only: input + output + first-time cache writes. Excludes cache '
              'reads (repeated re-use of prior context) — see the Cache reads stat tile '
              'above for that figure.',
          width: 72,
          align: TextAlign.right,
        ),
        const SizedBox(width: 12),
        header(
          'Cost',
          'Estimated USD cost at this provider\'s API rate — "n/a" if the model isn\'t in the '
              'local pricing table',
          width: 72,
          align: TextAlign.right,
        ),
      ],
    );
  }
}

// ─── Model table row ─────────────────────────────────────────────────────────

class _ModelListRow extends StatelessWidget {
  const _ModelListRow({required this.total, required this.color});

  final ModelUsageTotal total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Text(
            _displayName(total.source, total.model),
            style: TextStyle(color: luma.textPrimary, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 48,
          child: Text(
            '${total.turnCount}',
            textAlign: TextAlign.right,
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 72,
          child: Text(
            total.source == AiUsageSource.antigravity
                ? '~${_formatTokens(total.totalTokens)}'
                : _formatTokens(total.totalTokens),
            textAlign: TextAlign.right,
            style: TextStyle(color: luma.textSecondary, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 72,
          child: Text(
            total.billable ? _formatCost(total.cost) : 'n/a',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: total.billable ? luma.success : luma.textMuted,
              fontSize: 12,
              fontWeight: total.billable ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Other AI tools: informational only, no live fetch ─────────────────────

class _OtherAiToolsSection extends StatefulWidget {
  const _OtherAiToolsSection();

  @override
  State<_OtherAiToolsSection> createState() => _OtherAiToolsSectionState();
}

class _OtherAiToolsSectionState extends State<_OtherAiToolsSection> {
  late final Future<Set<String>> _connectedIds = _loadConnected();

  static Future<Set<String>> _loadConnected() async {
    final store = await AiKeyStore.load();
    final ids = <String>{};
    for (final provider in kAiProviders) {
      final key = await store.readKey(provider.id.name);
      if (key != null && key.isNotEmpty) ids.add(provider.id.name);
    }
    return ids;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Set<String>>(
      future: _connectedIds,
      builder: (context, snapshot) {
        final connected = snapshot.data;
        if (connected == null || connected.isEmpty) return const SizedBox();

        final providers = [
          for (final p in kAiProviders)
            if (connected.contains(p.id.name)) p,
        ];

        return LumaCollapsibleSection(
          icon: Icons.hub_outlined,
          title: 'Other AI tools',
          subtitle: "Informational only — luma can't fetch these automatically",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < providers.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _ProviderRow(provider: providers[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

const Map<AiProviderId, String> _kProviderUsageUrls = {
  AiProviderId.anthropic: 'https://console.anthropic.com/',
  AiProviderId.openai: 'https://platform.openai.com/usage',
  AiProviderId.mistral: 'https://console.mistral.ai/',
  AiProviderId.google: 'https://aistudio.google.com/',
};

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({required this.provider});

  final AiProviderInfo provider;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final url = _kProviderUsageUrls[provider.id];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LumaIconBadge(icon: provider.icon, color: luma.accent, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                provider.displayName,
                style: TextStyle(
                    color: luma.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                "luma can't fetch usage or cost for this provider automatically — "
                'personal API keys don\'t have access to billing endpoints, only '
                "admin-tier keys do. Check the provider's own usage dashboard.",
                style: TextStyle(color: luma.textMuted, fontSize: 11.5),
              ),
            ],
          ),
        ),
        if (url != null)
          IconButton(
            tooltip: 'Open ${provider.displayName} usage dashboard',
            icon: Icon(Icons.open_in_new_rounded, color: luma.textSecondary, size: 18),
            onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          ),
      ],
    );
  }
}

// ─── Formatting helpers ──────────────────────────────────────────────────────

/// Source-prefixed display name, e.g. "claude-opus-4-8" -> "Claude · Opus
/// 4.8", "gpt-5.4-mini" -> "Codex · GPT 5.4 mini". Names outside the
/// recognized families for that source fall back to the raw model string
/// with just the source prefix.
String _displayName(AiUsageSource source, String model) => switch (source) {
      AiUsageSource.claudeCode => 'Claude · ${_shortModelName(model)}',
      AiUsageSource.codexCli => 'Codex · ${_shortOpenAiModelName(model)}',
      // Already a human-readable name extracted from Antigravity's own UI
      // text (e.g. "Claude Opus 4.6 (Thinking)") — no family-name shortening
      // needed the way the other two sources' raw API model IDs require.
      AiUsageSource.antigravity => 'Antigravity · $model',
    };

/// "claude-opus-4-8" -> "Opus 4.8", "claude-fable-5" -> "Fable 5". Names
/// outside the recognized Anthropic families fall back to the raw string.
String _shortModelName(String model) {
  final m = model.toLowerCase();
  String? family;
  if (m.contains('fable')) {
    family = 'Fable';
  } else if (m.contains('mythos')) {
    family = 'Mythos';
  } else if (m.contains('opus')) {
    family = 'Opus';
  } else if (m.contains('sonnet')) {
    family = 'Sonnet';
  } else if (m.contains('haiku')) {
    family = 'Haiku';
  }
  if (family == null) return model;
  final versioned = RegExp(r'(\d+)[._-](\d+)').firstMatch(model);
  if (versioned != null) return '$family ${versioned.group(1)}.${versioned.group(2)}';
  final single = RegExp(r'(\d+)').firstMatch(model);
  return single != null ? '$family ${single.group(1)}' : family;
}

/// "gpt-5.4-mini" -> "GPT 5.4 mini", "gpt-5.5" -> "GPT 5.5". Names outside
/// the "gpt-" naming convention fall back to the raw string.
String _shortOpenAiModelName(String model) {
  final m = model.toLowerCase();
  if (!m.startsWith('gpt-')) return model;
  final rest = model.substring('gpt-'.length); // e.g. "5.4-mini"
  return 'GPT ${rest.replaceAll('-', ' ')}';
}

String _formatTokens(int n) {
  if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(2)}B';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(2)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

String _formatCost(double cost) => '\$${cost.toStringAsFixed(2)}';
