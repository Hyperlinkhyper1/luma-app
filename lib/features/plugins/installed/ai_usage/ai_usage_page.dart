import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import '../../../chat/ai_key_store.dart';
import '../../../chat/providers/ai_providers.dart';
import 'ai_usage_format.dart';
import 'ai_usage_repository.dart';
import 'ai_usage_scope.dart';
import 'ai_usage_source.dart';
import 'ai_usage_stats.dart';
import 'data/ai_usage_database.dart';
import 'effort_breakdown_section.dart';

/// How many models get their own pie slice / legend row before the rest are
/// folded into a single "Other" bucket.
const int _kTopModelLimit = 6;

const List<Color> _kPalette = [
  Color(0xFFC4B5FD), // lavender
  Color(0xFF6EE7B7), // mint
  Color(0xFFFCA5A5), // coral
  Color(0xFFFDE68A), // gold
  Color(0xFF93C5FD), // sky
  Color(0xFFD8B4FE), // purple
];
const Color _kOtherColor = Color(0xFF8A8A9A);

// Usage-category colors for the daily stacked chart and its legend.
const Color _kInputColor = Color(0xFFFDE68A); // gold
const Color _kOutputColor = Color(0xFFFCA5A5); // coral
const Color _kCacheReadColor = Color(0xFFC4B5FD); // lavender
const Color _kCacheCreationColor = Color(0xFF93C5FD); // sky

// Input/output colors for the "Top Projects" bars — deliberately separate
// from the daily chart's palette above (rather than reused) since the two
// charts are never compared side by side.
const Color _kProjectInputColor = Color(0xFFC4B5FD); // lavender
const Color _kProjectOutputColor = Color(0xFF6EE7B7); // mint

/// The plugin's **Usage** section: a private, offline dashboard for local AI
/// coding CLI usage — token counts and cost estimates by day and model, read
/// entirely from `~/.claude/projects`, `~/.codex/sessions`,
/// `~/.gemini/antigravity/brain`, and OpenCode's `opencode.db` on this
/// device. All but one are exact, provider-metered counts; Antigravity's are
/// estimated from message length (it doesn't record token usage locally at
/// all) and are labelled as such everywhere they appear.
///
/// Also serves the plugin's OpenCode section, via [fixedSource] — same
/// dashboard, pinned to that one tool.
class AiUsageDashboardTab extends StatefulWidget {
  const AiUsageDashboardTab({super.key, this.fixedSource});

  /// When set, this dashboard covers that one tool instead of all of them:
  /// the All/Claude Code/… filter bar is dropped (there is nothing left to
  /// filter), the empty state speaks about that tool alone, and any
  /// source-specific section it has is shown. Drives the plugin's dedicated
  /// OpenCode section — see `AiUsageSection` in `ai_usage_shell.dart`.
  final AiUsageSource? fixedSource;

  @override
  State<AiUsageDashboardTab> createState() => _AiUsageDashboardTabState();
}

class _AiUsageDashboardTabState extends State<AiUsageDashboardTab> {
  AiUsageRangePreset _preset = AiUsageRangePreset.today;
  AiUsageSource? _sourceFilter; // null = All
  bool _started = false;

  /// The source actually being shown: the fixed one when this dashboard is
  /// pinned to a tool, otherwise whatever the filter bar has selected.
  AiUsageSource? get _source => widget.fixedSource ?? _sourceFilter;

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

    final fixed = widget.fixedSource;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final found =
            fixed == null ? repo.anyDirFound : repo.dirFoundFor(fixed);

        if (found == null) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          );
        }

        if (found == false) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: LumaEmptyState(
              icon: Icons.smart_toy_outlined,
              title: fixed == null
                  ? 'No local AI usage logs found'
                  : 'No ${_sourceLabel(fixed)} logs found',
              subtitle: _notFoundSubtitle(fixed),
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
              if (fixed == null) ...[
                const SizedBox(height: 10),
                _SourceFilterBar(
                  selected: _sourceFilter,
                  onSelect: (s) => setState(() => _sourceFilter = s),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: StreamData<List<AiUsageTurn>>(
                  stream: repo.watchRange(start, end),
                  builder: (context, turns) => _AiUsageBody(
                    turns: _source == null
                        ? turns
                        : turns.where((t) => t.source == _source).toList(),
                    preset: _preset,
                    fixedSource: fixed,
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

/// Plain tool name for [source], for titles and prose. Distinct from
/// `displayName` in ai_usage_format.dart, which names a *model* and always
/// carries a model string with it.
String _sourceLabel(AiUsageSource source) => switch (source) {
      AiUsageSource.claudeCode => 'Claude Code',
      AiUsageSource.codexCli => 'Codex CLI',
      AiUsageSource.antigravity => 'Antigravity',
      AiUsageSource.opencode => 'OpenCode',
    };

/// Where [source]'s logs are expected to live, for the "nothing found"
/// state. A null [source] is the all-tools dashboard, which lists them all.
String _notFoundSubtitle(AiUsageSource? source) => switch (source) {
      null => 'AI Usage reads session logs from Claude Code '
          '(~/.claude/projects), Codex CLI (~/.codex/sessions), '
          'Antigravity (~/.gemini/antigravity), and OpenCode '
          '(~/.local/share/opencode) on this device — nothing is ever sent '
          'anywhere. Use one of these tools here, then rescan.',
      AiUsageSource.claudeCode =>
        'AI Usage reads Claude Code\'s session logs from ~/.claude/projects '
            'on this device — nothing is ever sent anywhere. Use Claude Code '
            'here, then rescan.',
      AiUsageSource.codexCli =>
        'AI Usage reads Codex CLI\'s session logs from ~/.codex/sessions on '
            'this device — nothing is ever sent anywhere. Use Codex CLI here, '
            'then rescan.',
      AiUsageSource.antigravity =>
        'AI Usage reads Antigravity\'s local logs from ~/.gemini/antigravity '
            'on this device — nothing is ever sent anywhere. Use Antigravity '
            'here, then rescan.',
      AiUsageSource.opencode =>
        'AI Usage reads OpenCode\'s own database (opencode.db under '
            'OPENCODE_DATA_DIR, or ~/.local/share/opencode) on this device — '
            'only token counts and the model name, never your prompts, and '
            'nothing is ever sent anywhere. Use OpenCode here, then rescan.',
    };

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

// ─── Source filter: All / Claude Code / Codex CLI / Antigravity / OpenCode ──

class _SourceFilterBar extends StatelessWidget {
  const _SourceFilterBar({required this.selected, required this.onSelect});

  final AiUsageSource? selected;
  final ValueChanged<AiUsageSource?> onSelect;

  static const _options = <AiUsageSource?>[
    null,
    AiUsageSource.claudeCode,
    AiUsageSource.codexCli,
    AiUsageSource.antigravity,
    AiUsageSource.opencode,
  ];

  @override
  Widget build(BuildContext context) {
    return LumaSegmentedTabs(
      tabs: const ['All', 'Claude Code', 'Codex CLI', 'Antigravity (est.)', 'OpenCode'],
      selectedIndex: _options.indexOf(selected),
      onSelect: (i) => onSelect(_options[i]),
    );
  }
}

// ─── Body: stat tiles, charts, table, once turns for the range arrive ──────

class _AiUsageBody extends StatelessWidget {
  const _AiUsageBody({
    required this.turns,
    required this.preset,
    this.fixedSource,
  });

  final List<AiUsageTurn> turns;
  final AiUsageRangePreset preset;

  /// Set when this dashboard is pinned to one tool — see
  /// [AiUsageDashboardTab.fixedSource]. Only used to decide whether that
  /// tool's own section belongs on the page.
  final AiUsageSource? fixedSource;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    // Antigravity turns whose model couldn't be detected are real usage
    // (still counted in the stat tiles and daily/project charts below) but
    // aren't worth a dedicated, uninformative "Unknown model" row here.
    final modelTotals = aggregateByModel(turns)
        .where((m) => !(m.source == AiUsageSource.antigravity && m.model == 'Unknown model'))
        .toList();

    if (modelTotals.isEmpty) {
      return LumaEmptyState(
        icon: Icons.smart_toy_outlined,
        title: 'No usage recorded in this range',
        subtitle: fixedSource == null
            ? 'Try a wider range, or use one of the supported tools and rescan.'
            : 'Try a wider range, or use ${_sourceLabel(fixedSource!)} and rescan.',
      );
    }

    final dayBuckets = aggregateByDay(turns);
    final summary = totals(turns);
    // One pass over every turn in range, kept here rather than repeated as
    // both an emptiness check and the section's own input.
    final effortTiers = aggregateByModelAndEffort(turns);
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
                value: formatTokens(summary.totalTokens),
                tooltip: 'New tokens only: input + output + first-time cache writes. '
                    "Doesn't include cache reads (see that tile) — a long session re-reads "
                    "the same growing context on nearly every turn, which would otherwise "
                    'count the same conversation over and over.',
              ),
              if (summary.cacheReadTokens > 0)
                _SummaryChip(
                  label: 'Cache reads',
                  value: formatTokens(summary.cacheReadTokens),
                  tooltip: 'Cached context re-read across all turns in range — real and '
                      'billed, but at a steep discount, and not counted in "Total tokens" '
                      'since it\'s re-use of content rather than new content.',
                ),
              _SummaryChip(
                label: 'Est. cost',
                value: summary.hasUnbillable
                    ? '${formatCost(summary.cost)}*'
                    : formatCost(summary.cost),
                tooltip: 'Estimated cost at API rates, including cache reads/writes at '
                    'their discounted rate — so this reflects more usage than "Total '
                    'tokens" shows on its own. Subscription plans (Max/Pro) bill '
                    'differently than this per-token estimate.',
              ),
              _SummaryChip(label: 'Turns', value: '${summary.turnCount}'),
              _SummaryChip(label: 'Sessions', value: '${summary.sessionCount}'),
              _SummaryChip(
                label: 'Top model',
                value: displayName(modelTotals.first.source, modelTotals.first.model),
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
                      "like Claude Code/Codex CLI. Cost (marked ~) only shows for "
                      'recognized Gemini/Claude models, and is a rougher estimate '
                      'than the other two sources.',
                      style: TextStyle(color: luma.textSecondary, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _HighlightsSection(turns: turns),
          if (fixedSource == AiUsageSource.opencode) ...[
            const SizedBox(height: 16),
            LumaCard(
              child: _OpencodeProviderSection(
                providers: aggregateOpencodeByProvider(turns),
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
          LumaCard(
            child: SizedBox(
              height: 220,
              child: _HourlyDistributionChart(hourly: aggregateByHour(turns)),
            ),
          ),
          const SizedBox(height: 16),
          LumaCard(child: _ProjectBreakdownSection(projects: aggregateByProject(turns))),
          const SizedBox(height: 16),
          LumaCard(
            child: preset == AiUsageRangePreset.all
                ? _ContributionHeatmap(dayBuckets: dayBuckets)
                : SizedBox(
                    height: 140,
                    child: Center(
                      child: Text(
                        'Switch to "All" to see your yearly contribution heatmap',
                        style: TextStyle(color: luma.textMuted, fontSize: 13),
                      ),
                    ),
                  ),
          ),
          if (effortTiers.isNotEmpty) ...[
            const SizedBox(height: 16),
            LumaCard(child: EffortBreakdownSection(tiers: effortTiers)),
          ],
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

// ─── Highlights: longest/priciest session, longest active-day streak ───────

String _formatDuration(Duration d) {
  if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inMinutes}m';
}

class _HighlightsSection extends StatelessWidget {
  const _HighlightsSection({required this.turns});

  final List<AiUsageTurn> turns;

  @override
  Widget build(BuildContext context) {
    final sessions = aggregateBySession(turns);
    if (sessions.isEmpty) return const SizedBox.shrink();

    SessionUsageTotal? longest;
    SessionUsageTotal? priciest;
    for (final s in sessions) {
      if (longest == null || s.duration > longest.duration) longest = s;
      if (priciest == null || s.cost > priciest.cost) priciest = s;
    }
    final streak = longestActiveDayStreak(turns);
    final dateFmt = DateFormat('MMM d');

    final cards = <_HighlightCard>[
      if (longest != null)
        _HighlightCard(
          icon: Icons.timer_outlined,
          color: _kInputColor,
          label: 'Longest session',
          value: _formatDuration(longest.duration),
          caption:
              '${longest.project ?? kUnknownProject} · ${dateFmt.format(longest.start.toLocal())}',
        ),
      if (priciest != null && priciest.cost > 0)
        _HighlightCard(
          icon: Icons.payments_outlined,
          color: _kOutputColor,
          label: 'Priciest session',
          value: formatCost(priciest.cost),
          caption: '${priciest.project ?? kUnknownProject} · '
              '${dateFmt.format(priciest.start.toLocal())}',
        ),
      if (streak.days > 1)
        _HighlightCard(
          icon: Icons.local_fire_department_rounded,
          color: _kCacheReadColor,
          label: 'Longest streak',
          value: '${streak.days} days',
          caption: '${dateFmt.format(streak.start!)} – ${dateFmt.format(streak.end!)}',
        ),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 640;
        if (narrow) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                cards[i],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LumaCard(
      child: Row(
        children: [
          LumaIconBadge(icon: icon, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: luma.textSecondary, fontSize: 12)),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: luma.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
          displayName(t.source, t.model),
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
                              formatTokens(slices[i].$2),
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

// ─── Bar chart: input/output/cache read/cache creation per day ─────────────

class _DailyBarChart extends StatelessWidget {
  const _DailyBarChart({required this.dayBuckets});

  final List<AiDayUsageBucket> dayBuckets;

  int _stackTotal(AiDayUsageBucket d) =>
      d.inputTokens + d.outputTokens + d.cacheReadTokens + d.cacheCreationTokens;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final maxStack = dayBuckets.map(_stackTotal).fold<int>(0, (a, b) => a > b ? a : b);
    final topY = maxStack == 0 ? 1000.0 : maxStack * 1.15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _UsageCategoryLegend(),
        const SizedBox(height: 10),
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: topY,
              minY: 0,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final d = dayBuckets[groupIndex];
                    return BarTooltipItem(
                      '${DateFormat('MMM d').format(d.day)}\n'
                      'Input: ${formatTokens(d.inputTokens)}\n'
                      'Output: ${formatTokens(d.outputTokens)}\n'
                      'Cache read: ${formatTokens(d.cacheReadTokens)}\n'
                      'Cache write: ${formatTokens(d.cacheCreationTokens)}\n'
                      '${formatCost(d.cost)}',
                      TextStyle(color: luma.textPrimary, fontSize: 12),
                    );
                  },
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
                      formatTokens(value.round()),
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
                for (var i = 0; i < dayBuckets.length; i++) _dayBarGroup(i, dayBuckets[i]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  BarChartGroupData _dayBarGroup(int index, AiDayUsageBucket d) {
    var y = 0.0;
    final segments = <(int tokens, Color color)>[
      (d.inputTokens, _kInputColor),
      (d.outputTokens, _kOutputColor),
      (d.cacheReadTokens, _kCacheReadColor),
      (d.cacheCreationTokens, _kCacheCreationColor),
    ];
    final stackItems = <BarChartRodStackItem>[];
    for (final (tokens, color) in segments) {
      if (tokens <= 0) continue;
      final fromY = y;
      y += tokens.toDouble();
      stackItems.add(BarChartRodStackItem(fromY, y, color));
    }
    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          toY: y,
          rodStackItems: stackItems,
          width: 16,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  }
}

/// Always-visible 4-color legend for the daily stacked chart (and shared by
/// nothing else — the project breakdown has its own, input/output-only,
/// legend).
class _UsageCategoryLegend extends StatelessWidget {
  const _UsageCategoryLegend();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    Widget dot(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: luma.textSecondary, fontSize: 11)),
          ],
        );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        dot(_kInputColor, 'Input'),
        dot(_kOutputColor, 'Output'),
        dot(_kCacheReadColor, 'Cache read'),
        dot(_kCacheCreationColor, 'Cache write'),
      ],
    );
  }
}

// ─── Hourly distribution: tokens by hour, Anthropic peak hours highlighted ─

/// Pacific Time's current UTC offset (US DST: 2nd Sunday of March through
/// the 1st Sunday of November). Hand-rolled because this project has no
/// timezone-database dependency for a single conversion.
Duration _pacificUtcOffset(DateTime utc) {
  int nthSunday(int year, int month, int n) {
    final first = DateTime.utc(year, month, 1);
    return 1 + ((7 - first.weekday) % 7) + (n - 1) * 7;
  }

  final dstStart = DateTime.utc(utc.year, 3, nthSunday(utc.year, 3, 2), 10);
  final dstEnd = DateTime.utc(utc.year, 11, nthSunday(utc.year, 11, 1), 9);
  final isDst = !utc.isBefore(dstStart) && utc.isBefore(dstEnd);
  return Duration(hours: isDst ? -7 : -8);
}

/// Anthropic's published Claude Code peak-hours window — weekdays 5am-11am
/// PT — converted to local hour-of-day. [localStart]/[localEnd] are the raw
/// hour-of-day values (fractional for half-hour-offset zones); [hours] is
/// the set of integer hour-of-day bars that fall inside the window (wraps
/// past midnight correctly), for highlighting on the chart.
typedef _AnthropicPeakWindow = ({double localStart, double localEnd, Set<int> hours});

_AnthropicPeakWindow _anthropicPeakHourWindow() {
  final now = DateTime.now();
  final diffHours = (now.timeZoneOffset - _pacificUtcOffset(now.toUtc())).inMinutes / 60.0;
  var start = (5.0 + diffHours) % 24;
  var end = (11.0 + diffHours) % 24;
  if (start < 0) start += 24;
  if (end < 0) end += 24;

  bool inWindow(int hour) =>
      start <= end ? (hour >= start && hour < end) : (hour >= start || hour < end);
  return (
    localStart: start,
    localEnd: end,
    hours: {for (var h = 0; h < 24; h++) if (inWindow(h)) h},
  );
}

String _formatFractionalHour(double hour) {
  final totalMinutes = (hour * 60).round() % (24 * 60);
  final dt = DateTime(2000, 1, 1, totalMinutes ~/ 60, totalMinutes % 60);
  return DateFormat(totalMinutes % 60 == 0 ? 'ha' : 'h:mma').format(dt).toLowerCase();
}

class _HourlyDistributionChart extends StatelessWidget {
  const _HourlyDistributionChart({required this.hourly});

  final List<AiHourlyUsageBucket> hourly;

  static String _formatHour(int hour) =>
      DateFormat('ha').format(DateTime(2000, 1, 1, hour)).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final maxTokens = hourly.fold<double>(0, (a, b) => b.avgTokens > a ? b.avgTokens : a);
    final topY = maxTokens <= 0 ? 1.0 : maxTokens * 1.2;
    final anthropicPeak = _anthropicPeakHourWindow();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Average Hourly Distribution',
              style: TextStyle(
                  color: luma.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: 'Anthropic published this window for Claude Code in March 2026; the '
                  'rate-limit reduction itself was lifted for Pro/Max on May 6, 2026, but the '
                  'hours are still commonly referenced.',
              child: Text(
                'Anthropic peak: ${_formatFractionalHour(anthropicPeak.localStart)}–'
                '${_formatFractionalHour(anthropicPeak.localEnd)}',
                style: TextStyle(color: luma.accent, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Tokens per hour, averaged across the days in this range — local time. '
          'Highlighted bars fall in the window above (weekdays 5–11am PT).',
          style: TextStyle(color: luma.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: topY,
              minY: 0,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final b = hourly[groupIndex];
                    return BarTooltipItem(
                      '${_formatHour(b.hour)}\n${formatTokens(b.avgTokens.round())} tokens/day avg\n'
                      '${b.avgTurns.toStringAsFixed(1)} turns/day avg',
                      TextStyle(color: luma.textPrimary, fontSize: 12),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 3,
                    getTitlesWidget: (value, meta) {
                      final hour = value.toInt();
                      if (hour < 0 || hour > 23 || value != hour.toDouble()) {
                        return const SizedBox();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _formatHour(hour),
                          style: TextStyle(color: luma.textMuted, fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) => Text(
                      formatTokens(value.round()),
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
                for (final b in hourly)
                  BarChartGroupData(
                    x: b.hour,
                    barRods: [
                      BarChartRodData(
                        toY: b.avgTokens,
                        color: anthropicPeak.hours.contains(b.hour)
                            ? luma.accent
                            : luma.accent.withValues(alpha: 0.35),
                        width: 26,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Project breakdown: top projects by tokens, with cost ──────────────────

const int _kTopProjectLimit = 8;

class _ProjectBreakdownSection extends StatelessWidget {
  const _ProjectBreakdownSection({required this.projects});

  final List<ProjectUsageTotal> projects;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (projects.isEmpty) {
      return const LumaEmptyState(
        icon: Icons.folder_open_outlined,
        title: 'No project data in this range',
      );
    }

    final top = projects.take(_kTopProjectLimit).toList();
    final maxTokens = top.fold<int>(0, (a, p) => p.totalTokens > a ? p.totalTokens : a);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Top Projects by Tokens',
              style: TextStyle(
                  color: luma.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: _kProjectInputColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text('Input', style: TextStyle(color: luma.textSecondary, fontSize: 11)),
                const SizedBox(width: 12),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: _kProjectOutputColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text('Output', style: TextStyle(color: luma.textSecondary, fontSize: 11)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Claude Code, Codex CLI and OpenCode only — Antigravity has no "
          'reliable project source, grouped as "Unknown project" instead.',
          style: TextStyle(color: luma.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < top.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _ProjectBarRow(total: top[i], maxTokens: maxTokens),
        ],
      ],
    );
  }
}

class _ProjectBarRow extends StatelessWidget {
  const _ProjectBarRow({required this.total, required this.maxTokens});

  final ProjectUsageTotal total;
  final int maxTokens;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final fraction = maxTokens == 0 ? 0.0 : total.totalTokens / maxTokens;
    final inputFraction =
        total.totalTokens == 0 ? 0.0 : total.inputTokens / total.totalTokens;

    return Tooltip(
      message: 'Input: ${formatTokens(total.inputTokens)} · '
          'Output: ${formatTokens(total.outputTokens)}\n'
          '${total.turnCount} turns · ${total.sessionCount} sessions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  total.project,
                  style: TextStyle(color: luma.textPrimary, fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatTokens(total.totalTokens),
                style: TextStyle(
                    color: luma.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Text(
                formatCost(total.cost),
                style: TextStyle(color: luma.success, fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth * fraction;
              final inputWidth = barWidth * inputFraction;
              return ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Stack(
                  children: [
                    Container(height: 10, color: luma.border),
                    if (barWidth > 0)
                      Row(
                        children: [
                          Container(width: inputWidth, height: 10, color: _kProjectInputColor),
                          Container(
                            width: (barWidth - inputWidth).clamp(0, constraints.maxWidth),
                            height: 10,
                            color: _kProjectOutputColor,
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── OpenCode: where the spend actually went ─────────────────────────────────

/// OpenCode's own section: totals per underlying provider.
///
/// Every other source is one tool talking to one vendor, so "which provider
/// did this go to" is only a question here — a single OpenCode session can
/// route through Anthropic, MiniMax, OpenRouter or OpenCode's own gateway,
/// and the model table alone doesn't add that up.
class _OpencodeProviderSection extends StatelessWidget {
  const _OpencodeProviderSection({required this.providers});

  final List<ProviderUsageTotal> providers;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (providers.isEmpty) {
      return const LumaEmptyState(
        icon: Icons.hub_outlined,
        title: 'No provider data in this range',
      );
    }

    final maxTokens =
        providers.fold<int>(0, (a, p) => p.totalTokens > a ? p.totalTokens : a);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Providers',
          style: TextStyle(
              color: luma.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Which provider each OpenCode turn was routed to. Cost comes from '
          "this app's own pricing for Anthropic and OpenAI models, and from "
          "OpenCode's own per-turn figure for everything else.",
          style: TextStyle(color: luma.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < providers.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _ProviderBarRow(
            total: providers[i],
            maxTokens: maxTokens,
            color: _kPalette[i % _kPalette.length],
          ),
        ],
      ],
    );
  }
}

class _ProviderBarRow extends StatelessWidget {
  const _ProviderBarRow({
    required this.total,
    required this.maxTokens,
    required this.color,
  });

  final ProviderUsageTotal total;
  final int maxTokens;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final fraction = maxTokens == 0 ? 0.0 : total.totalTokens / maxTokens;
    final models = total.modelCount == 1 ? '1 model' : '${total.modelCount} models';

    return Tooltip(
      message: 'Input: ${formatTokens(total.inputTokens)} · '
          'Output: ${formatTokens(total.outputTokens)}\n'
          'Cache reads: ${formatTokens(total.cacheReadTokens)}\n'
          '${total.turnCount} turns · $models',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  total.provider,
                  style: TextStyle(color: luma.textPrimary, fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                models,
                style: TextStyle(color: luma.textMuted, fontSize: 11),
              ),
              const SizedBox(width: 8),
              Text(
                formatTokens(total.totalTokens),
                style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Text(
                total.billable ? formatCost(total.cost) : 'n/a',
                style: TextStyle(
                  color: total.billable ? luma.success : luma.textMuted,
                  fontSize: 11.5,
                  fontWeight: total.billable ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Stack(
                  children: [
                    Container(height: 10, color: luma.border),
                    Container(
                      width: constraints.maxWidth * fraction,
                      height: 10,
                      color: color,
                    ),
                  ],
                ),
              );
            },
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
            displayName(total.source, total.model),
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
                ? '~${formatTokens(total.totalTokens)}'
                : formatTokens(total.totalTokens),
            textAlign: TextAlign.right,
            style: TextStyle(color: luma.textSecondary, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 72,
          child: Text(
            total.billable
                ? (total.source == AiUsageSource.antigravity
                    ? '~${formatCost(total.cost)}'
                    : formatCost(total.cost))
                : 'n/a',
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

// ─── Contribution heatmap: daily intensity over the trailing year ──────────

class _ContributionHeatmap extends StatelessWidget {
  const _ContributionHeatmap({required this.dayBuckets});

  final List<AiDayUsageBucket> dayBuckets;

  static const _cellSize = 18.0;
  static const _cellGap = 5.0;
  static const _colStep = _cellSize + _cellGap;

  /// The Sunday-of-the-week this [week]'th column starts on carries a month
  /// label when it's the first column containing that month's 1st-7th —
  /// i.e. roughly one label per month, placed on whichever column that
  /// month actually begins in.
  static String? _monthLabelFor(DateTime gridStart, int week) {
    final date = gridStart.add(Duration(days: week * 7));
    return date.day <= 7 ? DateFormat('MMM').format(date) : null;
  }

  static int _levelFor(int tokens, int maxTokens) {
    if (tokens <= 0 || maxTokens <= 0) return 0;
    final frac = tokens / maxTokens;
    if (frac > 0.75) return 4;
    if (frac > 0.5) return 3;
    if (frac > 0.25) return 2;
    return 1;
  }

  static Color _colorForLevel(LumaPalette luma, int level) => switch (level) {
        0 => luma.border.withValues(alpha: 0.4),
        1 => luma.accent.withValues(alpha: 0.25),
        2 => luma.accent.withValues(alpha: 0.5),
        3 => luma.accent.withValues(alpha: 0.75),
        _ => luma.accent,
      };

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (dayBuckets.isEmpty) {
      return const LumaEmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'No usage recorded yet',
      );
    }

    final byDay = {for (final d in dayBuckets) d.day: d};
    final today = DateTime.now();
    final endDate = DateTime(today.year, today.month, today.day);
    final roughStart = endDate.subtract(const Duration(days: 364));
    final gridStart = roughStart.subtract(Duration(days: roughStart.weekday % 7));
    final weekCount = ((endDate.difference(gridStart).inDays + 1) / 7).ceil();
    final maxTokens = dayBuckets.fold<int>(0, (a, d) => d.totalTokens > a ? d.totalTokens : a);

    Widget cellFor(int week, int weekday) {
      final date = gridStart.add(Duration(days: week * 7 + weekday));
      if (date.isAfter(endDate)) {
        return const SizedBox(width: _cellSize, height: _cellSize);
      }
      final bucket = byDay[date];
      final tokens = bucket?.totalTokens ?? 0;
      final message = tokens > 0
          ? '${DateFormat('MMM d, yyyy').format(date)}\n'
              '${formatTokens(tokens)} tokens · ${formatCost(bucket!.cost)}'
          : '${DateFormat('MMM d, yyyy').format(date)}\nNo usage';
      return Tooltip(
        message: message,
        child: Container(
          width: _cellSize,
          height: _cellSize,
          decoration: BoxDecoration(
            color: _colorForLevel(luma, _levelFor(tokens, maxTokens)),
            borderRadius: BorderRadius.circular(3.5),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contribution Heatmap',
          style: TextStyle(color: luma.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Daily token intensity over the last year — hover a day for details',
          style: TextStyle(color: luma.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final gridWidth = weekCount * _colStep;
            final grid = SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: gridWidth,
                    height: 16,
                    child: Stack(
                      children: [
                        for (var w = 0; w < weekCount; w++)
                          if (_monthLabelFor(gridStart, w) case final label?)
                            Positioned(
                              left: w * _colStep,
                              child: Text(
                                label,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.visible,
                                style: TextStyle(color: luma.textMuted, fontSize: 11),
                              ),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var w = 0; w < weekCount; w++)
                        Padding(
                          padding: const EdgeInsets.only(right: _cellGap),
                          child: Column(
                            children: [
                              for (var d = 0; d < 7; d++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: _cellGap),
                                  child: cellFor(w, d),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
            // Only worth centering when it actually fits without scrolling —
            // otherwise let the scroll view own its natural (wider) width.
            return gridWidth < constraints.maxWidth ? Center(child: grid) : grid;
          },
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Less', style: TextStyle(color: luma.textMuted, fontSize: 11)),
            for (var level = 0; level <= 4; level++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  width: _cellSize,
                  height: _cellSize,
                  decoration: BoxDecoration(
                    color: _colorForLevel(luma, level),
                    borderRadius: BorderRadius.circular(3.5),
                  ),
                ),
              ),
            Text('More', style: TextStyle(color: luma.textMuted, fontSize: 11)),
          ],
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

