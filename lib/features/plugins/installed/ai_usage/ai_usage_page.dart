import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'ai_usage_format.dart';
import 'ai_usage_repository.dart';
import 'ai_usage_scope.dart';
import 'ai_usage_source.dart';
import 'ai_usage_stats.dart';
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
/// Narrowing to one tool is done with the All/Claude Code/… filter bar, not
/// by giving each tool its own page — a source is a lens on this dashboard,
/// not a separate destination.
class AiUsageDashboardTab extends StatefulWidget {
  const AiUsageDashboardTab({super.key});

  @override
  State<AiUsageDashboardTab> createState() => _AiUsageDashboardTabState();
}

class _AiUsageDashboardTabState extends State<AiUsageDashboardTab> {
  AiUsageRangePreset _preset = AiUsageRangePreset.today;
  AiUsageSource? _sourceFilter; // null = All
  bool _started = false;
  AiUsageSortMetric _modelSort = AiUsageSortMetric.tokens;
  AiUsageSortMetric _projectSort = AiUsageSortMetric.tokens;
  AiUsageSortMetric _providerSort = AiUsageSortMetric.tokens;
  bool _combineByCompany = false;

  AiUsageRepository? _repo;
  StreamSubscription<void>? _changes;
  Timer? _changeDebounce;

  /// Snapshots already computed since the stored turns last changed, so
  /// flipping back to a range or source seen before is instant. Each one
  /// also ages out after a few minutes, so a rolling window ("Today", "7d")
  /// still moves along when nothing new is written.
  final Map<(AiUsageRangePreset, AiUsageSource?), (AiUsageDashboardSnapshot, DateTime)>
      _cache = {};
  static const Duration _cacheLifetime = Duration(minutes: 5);
  AiUsageDashboardSnapshot? _shown;
  (AiUsageRangePreset, AiUsageSource?)? _shownKey;
  bool _loading = false;
  Object? _loadError;
  int _generation = 0;

  /// Starts computing the selected range's snapshot on a worker isolate. The
  /// previous snapshot stays on screen, under a thin progress bar, until the
  /// new one lands; an answer for a selection the user has since moved past
  /// is dropped. Callers that are not mid-build wrap this in setState.
  void _load() {
    final repo = _repo;
    if (repo == null) return;
    final key = (_preset, _sourceFilter);
    final now = DateTime.now();
    final entry = _cache[key];
    final cached =
        entry != null && now.difference(entry.$2) < _cacheLifetime ? entry.$1 : null;
    final generation = ++_generation;
    if (cached != null) {
      _shown = cached;
      _shownKey = key;
      _loading = false;
      return;
    }
    _loading = true;
    final (start, _) = resolveAiUsageRange(_preset, now);
    repo.loadDashboard(start, source: _sourceFilter).then(
      (snapshot) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _cache[key] = (snapshot, now);
          _shown = snapshot;
          _shownKey = key;
          _loading = false;
          _loadError = null;
        });
      },
      onError: (Object error) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _loading = false;
          _loadError = error;
        });
      },
    );
  }

  void _onTurnsChanged() {
    _changeDebounce?.cancel();
    _changeDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _cache.clear();
        _load();
      });
    });
  }

  @override
  void dispose() {
    _changeDebounce?.cancel();
    _changes?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = AiUsageScope.of(context);
    if (!identical(repo, _repo)) {
      _repo = repo;
      _changes?.cancel();
      _changes = repo.turnsChanged.listen((_) => _onTurnsChanged());
      _cache.clear();
      _load();
    }
    // The scope isn't reachable from initState, and the first scan has to
    // wait for it. Only ever kicked off once per page lifetime — the Rescan
    // button covers every case after that.
    if (_started) return;
    _started = true;
    // Deferred a frame: `of(context)` registers this element as a dependent
    // of the InheritedNotifier, and `refresh()` notifies synchronously —
    // notifying *during* this build pass would dirty an element that is
    // still building (a '!_dirty' assert in debug).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AiUsageScope.of(context).refresh();
    });
  }

  Future<void> _openSettings() async {
    final result = await showAiUsageSettingsDialog(
      context,
      AiUsageViewSettings(
        modelSort: _modelSort,
        projectSort: _projectSort,
        providerSort: _providerSort,
        combineByCompany: _combineByCompany,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _modelSort = result.modelSort;
        _projectSort = result.projectSort;
        _providerSort = result.providerSort;
        _combineByCompany = result.combineByCompany;
      });
    }
  }

  Widget _buildBody(BuildContext context) {
    final snapshot = _shown;
    final key = _shownKey;
    if (snapshot == null || key == null) {
      if (_loadError != null) {
        return Center(
          child: LumaEmptyState(
            icon: Icons.error_outline_rounded,
            title: L.of(context).commonSomethingWentWrong,
            subtitle: '$_loadError',
            action: LumaGhostButton(
              label: L.of(context).commonRetry,
              icon: Icons.refresh_rounded,
              onTap: () => setState(_load),
            ),
          ),
        );
      }
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    return _AiUsageBody(
      snapshot: snapshot,
      preset: key.$1,
      selectedSource: key.$2,
      modelSort: _modelSort,
      projectSort: _projectSort,
      providerSort: _providerSort,
      combineByCompany: _combineByCompany,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = AiUsageScope.of(context);
    final t = L.of(context);

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final found = repo.anyDirFound;

        if (found == null) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          );
        }

        if (found == false && repo.remoteDevices.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: LumaEmptyState(
              icon: Icons.smart_toy_outlined,
              title: t.aiUsageNoLogsTitle,
              subtitle: t.aiUsageNoLogsSubtitle,
              action: LumaGhostButton(
                label: repo.scanning ? t.homeAiUsageScanning : t.aiUsageRescan,
                icon: Icons.refresh_rounded,
                onTap: repo.scanning ? null : repo.refresh,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                repo: repo,
                preset: _preset,
                onSelectPreset: (p) => setState(() {
                  _preset = p;
                  _load();
                }),
                onOpenSettings: _openSettings,
              ),
              const SizedBox(height: 10),
              _SourceFilterBar(
                selected: _sourceFilter,
                onSelect: (s) => setState(() {
                  _sourceFilter = s;
                  _load();
                }),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 2,
                child: _loading && _shown != null
                    ? LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        color: context.luma.accent,
                      )
                    : null,
              ),
              Expanded(child: _buildBody(context)),
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
      AiUsageSource.freebuff => 'Freebuff',
      AiUsageSource.luma => 'Luma',
    };

// ─── View settings: sorting + company grouping ─────────────────────────────

/// In-memory view settings for the Usage dashboard, edited through the
/// cogwheel in the top bar. Sorting defaults to tokens everywhere to match
/// the historical ordering.
class AiUsageViewSettings {
  const AiUsageViewSettings({
    required this.modelSort,
    required this.projectSort,
    required this.providerSort,
    required this.combineByCompany,
  });

  final AiUsageSortMetric modelSort;
  final AiUsageSortMetric projectSort;
  final AiUsageSortMetric providerSort;
  final bool combineByCompany;
}

Future<AiUsageViewSettings?> showAiUsageSettingsDialog(
  BuildContext context,
  AiUsageViewSettings initial,
) {
  return showDialog<AiUsageViewSettings>(
    context: context,
    builder: (dialogContext) => _AiUsageSettingsDialog(initial: initial),
  );
}

class _AiUsageSettingsDialog extends StatefulWidget {
  const _AiUsageSettingsDialog({required this.initial});

  final AiUsageViewSettings initial;

  @override
  State<_AiUsageSettingsDialog> createState() => _AiUsageSettingsDialogState();
}

class _AiUsageSettingsDialogState extends State<_AiUsageSettingsDialog> {
  late AiUsageSortMetric _modelSort = widget.initial.modelSort;
  late AiUsageSortMetric _projectSort = widget.initial.projectSort;
  late AiUsageSortMetric _providerSort = widget.initial.providerSort;
  late bool _combineByCompany = widget.initial.combineByCompany;

  void _reset() {
    setState(() {
      _modelSort = AiUsageSortMetric.tokens;
      _projectSort = AiUsageSortMetric.tokens;
      _providerSort = AiUsageSortMetric.tokens;
      _combineByCompany = false;
    });
  }

  AiUsageViewSettings _current() => AiUsageViewSettings(
        modelSort: _modelSort,
        projectSort: _projectSort,
        providerSort: _providerSort,
        combineByCompany: _combineByCompany,
      );

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.settings_rounded, color: luma.accent, size: 20),
          const SizedBox(width: 10),
          Text(t.aiUsageSettingsTitle),
        ],
      ),
      content: SizedBox(
        width: lumaDialogWidth(context, 380),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingsToggleRow(
                title: t.aiUsageCombineByCompany,
                subtitle: t.aiUsageCombineByCompanyHint,
                value: _combineByCompany,
                onChanged: (v) => setState(() => _combineByCompany = v),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sort_rounded, color: luma.accent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.aiUsageSorting,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          t.aiUsageSortingHint,
                          style: TextStyle(color: luma.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SortDropdown(
                label: t.aiUsageSortModels,
                value: _modelSort,
                onChanged: (v) => setState(() => _modelSort = v),
              ),
              const SizedBox(height: 8),
              _SortDropdown(
                label: t.aiUsageSortProjects,
                value: _projectSort,
                onChanged: (v) => setState(() => _projectSort = v),
              ),
              const SizedBox(height: 8),
              _SortDropdown(
                label: t.aiUsageSortProviders,
                value: _providerSort,
                onChanged: (v) => setState(() => _providerSort = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _reset, child: Text(t.commonReset)),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_current()),
          child: Text(t.commonDone),
        ),
      ],
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: luma.onAccent,
          activeTrackColor: luma.accent,
          inactiveThumbColor: luma.textSecondary,
          inactiveTrackColor: luma.surfaceHover,
        ),
      ],
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final AiUsageSortMetric value;
  final ValueChanged<AiUsageSortMetric> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<AiUsageSortMetric>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final metric in AiUsageSortMetric.values)
          DropdownMenuItem(value: metric, child: Text(metric.label)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ─── Top bar: range presets, rescan, settings, status ───────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.repo,
    required this.preset,
    required this.onSelectPreset,
    required this.onOpenSettings,
  });

  final AiUsageRepository repo;
  final AiUsageRangePreset preset;
  final ValueChanged<AiUsageRangePreset> onSelectPreset;
  final VoidCallback onOpenSettings;

  String _statusLabel(L t) {
    if (repo.scanning) return t.homeAiUsageScanning;
    final at = repo.lastScanAt;
    if (at == null) return '';
    final synced = repo.remoteDevices.isEmpty
        ? ''
        : t.aiUsageStatusSyncedDevices(repo.remoteDevices.length);
    final time = DateFormat('h:mm a', t.localeName).format(at);
    if (repo.lastTurnsAdded == 0) {
      return t.aiUsageStatusUpToDate(time, synced);
    }
    return t.aiUsageStatusNewTurns(repo.lastTurnsAdded, time, synced);
  }

  String _devicesTooltip(L t) => [
    t.aiUsageDevicesTooltipHeader,
    t.aiUsageThisDevice,
    for (final d in repo.remoteDevices)
      t.aiUsageDeviceLine(
        d.name,
        d.turnCount,
        DateFormat('MMM d, h:mm a', t.localeName).format(d.uploadedAt.toLocal()),
      ),
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    if (context.isPhoneWidth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LumaSegmentedTabs(
            tabs: [for (final p in AiUsageRangePreset.values) p.label],
            selectedIndex: preset.index,
            scrollable: true,
            onSelect: (i) => onSelectPreset(AiUsageRangePreset.values[i]),
          ),
          Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: repo.remoteDevices.isEmpty ? '' : _devicesTooltip(t),
                  child: Text(
                    _statusLabel(t),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                ),
              ),
              IconButton(
                tooltip: t.aiUsageRescanTooltip,
                icon: repo.scanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.refresh_rounded, color: luma.textSecondary),
                onPressed: repo.scanning ? null : repo.refresh,
              ),
              IconButton(
                tooltip: t.aiUsageDisplaySettingsTooltip,
                icon: Icon(Icons.settings_rounded, color: luma.textSecondary),
                onPressed: onOpenSettings,
              ),
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: LumaSegmentedTabs(
            tabs: [for (final p in AiUsageRangePreset.values) p.label],
            selectedIndex: preset.index,
            onSelect: (i) => onSelectPreset(AiUsageRangePreset.values[i]),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Tooltip(
            message: repo.remoteDevices.isEmpty ? '' : _devicesTooltip(t),
            child: Text(
              _statusLabel(t),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ),
        ),
        IconButton(
          tooltip: t.aiUsageRescanTooltip,
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
          onPressed: repo.scanning ? null : repo.refresh,
        ),
        IconButton(
          tooltip: t.aiUsageDisplaySettingsTooltip,
          icon: Icon(Icons.settings_rounded, color: luma.textSecondary),
          onPressed: onOpenSettings,
        ),
      ],
    );
  }
}

// ─ Source filter: All / Claude Code / Codex CLI / Antigravity / OpenCode / Freebuff ─

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
    AiUsageSource.freebuff,
    AiUsageSource.luma,
  ];

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return LumaSegmentedTabs(
      tabs: [
        t.commonAll,
        'Claude Code',
        'Codex CLI',
        t.aiUsageSourceAntigravityEst,
        'OpenCode',
        'Freebuff',
        'Luma',
      ],
      selectedIndex: _options.indexOf(selected),
      onSelect: (i) => onSelect(_options[i]),
      scrollable: context.isPhoneWidth,
    );
  }
}

// ─── Body: stat tiles, charts, table, once turns for the range arrive ──────

class _AiUsageBody extends StatelessWidget {
  const _AiUsageBody({
    required this.snapshot,
    required this.preset,
    this.selectedSource,
    this.modelSort = AiUsageSortMetric.tokens,
    this.projectSort = AiUsageSortMetric.tokens,
    this.providerSort = AiUsageSortMetric.tokens,
    this.combineByCompany = false,
  });

  final AiUsageDashboardSnapshot snapshot;
  final AiUsageRangePreset preset;

  /// Which source the filter bar has narrowed to, or null for "All". Decides
  /// whether a source's own section belongs on the page — currently just
  /// OpenCode's provider breakdown.
  final AiUsageSource? selectedSource;

  final AiUsageSortMetric modelSort;
  final AiUsageSortMetric projectSort;
  final AiUsageSortMetric providerSort;
  final bool combineByCompany;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    // Everything heavy was summed on a worker isolate; only the re-sorting
    // to the chosen metrics happens here, on copies of a few dozen rows.
    final modelTotals = [...snapshot.modelTotals];
    sortModelTotals(modelTotals, modelSort);
    final companyTotals = combineByCompany
        ? [...snapshot.companyTotals]
        : <CompanyUsageTotal>[];
    sortCompanyTotals(companyTotals, modelSort);

    if (modelTotals.isEmpty) {
      return LumaEmptyState(
        icon: Icons.smart_toy_outlined,
        title: t.aiUsageNoUsageTitle,
        subtitle: selectedSource == null
            ? t.aiUsageNoUsageSubtitle
            : t.aiUsageNoUsageSourceSubtitle(_sourceLabel(selectedSource!)),
      );
    }

    final dayBuckets = snapshot.dayBuckets;
    final now = DateTime.now();
    final chartLastDay = DateTime(now.year, now.month, now.day);
    final (rangeStart, _) = resolveAiUsageRange(preset, now);
    final chartFirstDay = rangeStart != null
        ? DateTime(rangeStart.year, rangeStart.month, rangeStart.day)
        : dayBuckets.isEmpty
            ? chartLastDay
            : dayBuckets.first.day;
    final summary = snapshot.summary;
    final effortTiers = snapshot.effortTiers;
    final projectTotals = [...snapshot.projectTotals];
    sortProjectTotals(projectTotals, projectSort);
    final providerTotals = [...snapshot.providerTotals];
    sortProviderTotals(providerTotals, providerSort);
    final colorByModel = <(AiUsageSource, String), Color>{
      for (var i = 0; i < modelTotals.length && i < _kTopModelLimit; i++)
        (modelTotals[i].source, modelTotals[i].model): _kPalette[i % _kPalette.length],
    };
    final colorByCompany = <String, Color>{
      for (var i = 0; i < companyTotals.length && i < _kTopModelLimit; i++)
        companyTotals[i].company: _kPalette[i % _kPalette.length],
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
                label: t.aiUsageTotalTokens,
                value: formatTokens(summary.totalTokens),
                tooltip: t.aiUsageTotalTokensTooltip,
              ),
              if (summary.cacheReadTokens > 0)
                _SummaryChip(
                  label: t.aiUsageCacheReads,
                  value: formatTokens(summary.cacheReadTokens),
                  tooltip: t.aiUsageCacheReadsTooltip,
                ),
              _SummaryChip(
                label: t.aiUsageEstCost,
                value: summary.hasUnbillable
                    ? '${formatCost(summary.cost)}*'
                    : formatCost(summary.cost),
                tooltip: t.aiUsageEstCostTooltip,
              ),
              _SummaryChip(label: t.aiUsageTurns, value: '${summary.turnCount}'),
              _SummaryChip(label: t.aiUsageSessions, value: '${summary.sessionCount}'),
              _SummaryChip(
                label: combineByCompany ? t.aiUsageTopCompany : t.aiUsageTopModel,
                value: combineByCompany
                    ? companyTotals.first.company
                    : displayName(modelTotals.first.source, modelTotals.first.model),
              ),
            ],
          ),
          if (summary.hasUnbillable) ...[
            const SizedBox(height: 6),
            Text(
              t.aiUsageUnbillableNote,
              style: TextStyle(color: luma.textMuted, fontSize: 11),
            ),
          ],
          if (snapshot.hasAntigravity) ...[
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
                      t.aiUsageAntigravityNote,
                      style: TextStyle(color: luma.textSecondary, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _HighlightsSection(snapshot: snapshot),
          if (selectedSource == AiUsageSource.opencode) ...[
            const SizedBox(height: 16),
            LumaCard(
              child: _OpencodeProviderSection(
                providers: providerTotals,
                sort: providerSort,
              ),
            ),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final pie = LumaCard(
                child: SizedBox(
                  height: 300,
                  child: combineByCompany
                      ? _CompanyPieChart(
                          companyTotals: companyTotals,
                          colorByCompany: colorByCompany,
                        )
                      : _ModelPieChart(
                          modelTotals: modelTotals,
                          colorByModel: colorByModel,
                        ),
                ),
              );
              final bars = LumaCard(
                child: SizedBox(
                  height: 300,
                  child: preset == AiUsageRangePreset.today
                      ? Center(
                          child: Text(
                            t.aiUsagePickWiderRange,
                            style: TextStyle(color: luma.textMuted, fontSize: 13),
                          ),
                        )
                      : _UsageOverTimeChart(
                          dayBuckets: dayBuckets,
                          firstDay: chartFirstDay,
                          lastDay: chartLastDay,
                        ),
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
                _ModelTableTitle(
                  grouped: combineByCompany,
                  sort: modelSort,
                ),
                const SizedBox(height: 8),
                _ModelTableHeader(grouped: combineByCompany),
                const SizedBox(height: 8),
                if (combineByCompany)
                  for (var i = 0; i < companyTotals.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _CompanyListRow(
                      total: companyTotals[i],
                      color: colorByCompany[companyTotals[i].company] ?? _kOtherColor,
                    ),
                  ]
                else
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
              child: _HourlyDistributionChart(hourly: snapshot.hourly),
            ),
          ),
          const SizedBox(height: 16),
          LumaCard(
              child: _ProjectBreakdownSection(
            projects: projectTotals,
            sort: projectSort,
          )),
          const SizedBox(height: 16),
          LumaCard(
            child: preset == AiUsageRangePreset.all
                ? _ContributionHeatmap(dayBuckets: dayBuckets)
                : SizedBox(
                    height: 140,
                    child: Center(
                      child: Text(
                        t.aiUsageSwitchToAllHeatmap,
                        style: TextStyle(color: luma.textMuted, fontSize: 13),
                      ),
                    ),
                  ),
          ),
          if (effortTiers.isNotEmpty) ...[
            const SizedBox(height: 16),
            LumaCard(
                child: EffortBreakdownSection(
              tiers: effortTiers,
              sort: modelSort,
            )),
          ],
        ],
      ),
    );
  }
}

class _ModelTableTitle extends StatelessWidget {
  const _ModelTableTitle({required this.grouped, required this.sort});

  final bool grouped;
  final AiUsageSortMetric sort;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Row(
      children: [
        Text(
          grouped ? t.aiUsageCompanies : t.aiUsageModels,
          style: TextStyle(
              color: luma.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        Text(
          t.aiUsageSortedBy(sort.label.toLowerCase()),
          style: TextStyle(color: luma.textMuted, fontSize: 11),
        ),
      ],
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

String _formatDuration(L t, Duration d) {
  if (d.inDays > 0) return t.aiUsageDurationDaysHours(d.inDays, d.inHours % 24);
  if (d.inHours > 0) return t.aiUsageDurationHoursMinutes(d.inHours, d.inMinutes % 60);
  return t.aiUsageDurationMinutes(d.inMinutes);
}

class _HighlightsSection extends StatelessWidget {
  const _HighlightsSection({required this.snapshot});

  final AiUsageDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final longest = snapshot.longestSession;
    final priciest = snapshot.priciestSession;
    if (longest == null) return const SizedBox.shrink();
    final streak = snapshot.streak;
    final dateFmt = DateFormat('MMM d', t.localeName);

    final cards = <_HighlightCard>[
      _HighlightCard(
          icon: Icons.timer_outlined,
          color: _kInputColor,
          label: t.aiUsageLongestSession,
          value: _formatDuration(t, longest.duration),
          caption:
              '${longest.project ?? t.aiUsageUnknownProject} · ${dateFmt.format(longest.start.toLocal())}',
        ),
      if (priciest != null && priciest.cost > 0)
        _HighlightCard(
          icon: Icons.payments_outlined,
          color: _kOutputColor,
          label: t.aiUsagePriciestSession,
          value: formatCost(priciest.cost),
          caption: '${priciest.project ?? t.aiUsageUnknownProject} · '
              '${dateFmt.format(priciest.start.toLocal())}',
        ),
      if (streak.days > 1)
        _HighlightCard(
          icon: Icons.local_fire_department_rounded,
          color: _kCacheReadColor,
          label: t.aiUsageLongestStreak,
          value: t.aiUsageStreakDays(streak.days),
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

  List<(String label, int tokens, Color color)> _slices(L t) {
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
      if (otherTokens > 0) (t.aiUsageOther, otherTokens, _kOtherColor),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final slices = _slices(t);
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

class _CompanyPieChart extends StatefulWidget {
  const _CompanyPieChart({
    required this.companyTotals,
    required this.colorByCompany,
  });

  final List<CompanyUsageTotal> companyTotals;
  final Map<String, Color> colorByCompany;

  @override
  State<_CompanyPieChart> createState() => _CompanyPieChartState();
}

class _CompanyPieChartState extends State<_CompanyPieChart> {
  int? _touchedIndex;

  List<(String label, int tokens, Color color)> _slices(L t) {
    final top = widget.companyTotals.take(_kTopModelLimit).toList();
    final rest = widget.companyTotals.skip(_kTopModelLimit);
    final otherTokens = rest.fold<int>(0, (a, t) => a + t.totalTokens);
    return [
      for (final t in top)
        (
          t.company,
          t.totalTokens,
          widget.colorByCompany[t.company]!,
        ),
      if (otherTokens > 0) (t.aiUsageOther, otherTokens, _kOtherColor),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final slices = _slices(t);
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

// ─── Usage over time: stacked tokens (or cost) per day / week / month ──────

enum _TimeBucket { day, week, month }

enum _UsageSeries { input, output, cacheWrite, cacheRead }

/// One bar of the usage-over-time chart: a day, a Monday-started week or a
/// calendar month. Every bucket between the first and last day exists, so
/// the x axis is real time and quiet stretches show as gaps.
class _UsagePoint {
  _UsagePoint(this.start, this.end);

  final DateTime start;

  /// The last calendar day this bucket covers.
  final DateTime end;
  int input = 0;
  int output = 0;
  int cacheWrite = 0;
  int cacheRead = 0;
  double cost = 0;

  int tokens(_UsageSeries series) => switch (series) {
        _UsageSeries.input => input,
        _UsageSeries.output => output,
        _UsageSeries.cacheWrite => cacheWrite,
        _UsageSeries.cacheRead => cacheRead,
      };
}

DateTime _bucketStart(DateTime day, _TimeBucket bucket) => switch (bucket) {
      _TimeBucket.day => DateTime(day.year, day.month, day.day),
      _TimeBucket.week => DateTime(day.year, day.month, day.day - (day.weekday - 1)),
      _TimeBucket.month => DateTime(day.year, day.month),
    };

DateTime _nextBucket(DateTime start, _TimeBucket bucket) => switch (bucket) {
      _TimeBucket.day => DateTime(start.year, start.month, start.day + 1),
      _TimeBucket.week => DateTime(start.year, start.month, start.day + 7),
      _TimeBucket.month => DateTime(start.year, start.month + 1),
    };

/// Folds [days] into continuous [bucket]-sized points spanning
/// [firstDay]..[lastDay] inclusive.
List<_UsagePoint> _bucketUsage(
  List<AiDayUsageBucket> days,
  DateTime firstDay,
  DateTime lastDay,
  _TimeBucket bucket,
) {
  final points = <_UsagePoint>[];
  final byStart = <DateTime, _UsagePoint>{};
  for (var s = _bucketStart(firstDay, bucket);
      !s.isAfter(lastDay);
      s = _nextBucket(s, bucket)) {
    final next = _nextBucket(s, bucket);
    final point = _UsagePoint(s, DateTime(next.year, next.month, next.day - 1));
    points.add(point);
    byStart[s] = point;
  }
  for (final d in days) {
    final point = byStart[_bucketStart(d.day, bucket)];
    if (point == null) continue;
    point.input += d.inputTokens;
    point.output += d.outputTokens;
    point.cacheWrite += d.cacheCreationTokens;
    point.cacheRead += d.cacheReadTokens;
    point.cost += d.cost;
  }
  return points;
}

/// Day bars up to two months, week bars up to about a year, months beyond:
/// enough bars to show a shape, few enough that each is wide enough to read
/// and hover.
_TimeBucket _autoBucket(int spanDays) => spanDays <= 62
    ? _TimeBucket.day
    : spanDays <= 400
        ? _TimeBucket.week
        : _TimeBucket.month;

/// A round axis step (1, 2, 2.5 or 5 × 10ⁿ) giving about [ticks] gridlines
/// up to [max].
double _niceStep(double max, {int ticks = 4}) {
  if (max <= 0) return 1;
  final raw = max / ticks;
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final norm = raw / magnitude;
  final nice = norm <= 1
      ? 1.0
      : norm <= 2
          ? 2.0
          : norm <= 2.5
              ? 2.5
              : norm <= 5
                  ? 5.0
                  : 10.0;
  return nice * magnitude;
}

String _trimZero(String s) =>
    s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;

/// Axis-label token counts: "0", "250K", "1.5M", "2B". Shorter than
/// [formatTokens], which keeps two decimals for the tables.
String _compactTokens(double v) {
  String scaled(double x) => _trimZero(x.toStringAsFixed(x >= 10 ? 0 : 1));
  if (v >= 1e9) return '${scaled(v / 1e9)}B';
  if (v >= 1e6) return '${scaled(v / 1e6)}M';
  if (v >= 1e3) return '${scaled(v / 1e3)}K';
  return v.round().toString();
}

String _compactCost(double v) {
  if (v == 0) return '\$0';
  if (v >= 10) return '\$${v.round()}';
  if (v >= 1) return '\$${_trimZero(v.toStringAsFixed(1))}';
  return '\$${_trimZero(v.toStringAsFixed(2))}';
}

/// Tokens (stacked by kind) or cost over the selected range, one bar per
/// day, week or month. Cache reads start hidden: they are re-read context,
/// usually tens of times everything else combined, and left in they flatten
/// the other series into an invisible sliver. "Total tokens" leaves them out
/// for the same reason; one click on the legend brings them back.
class _UsageOverTimeChart extends StatefulWidget {
  const _UsageOverTimeChart({
    required this.dayBuckets,
    required this.firstDay,
    required this.lastDay,
  });

  final List<AiDayUsageBucket> dayBuckets;
  final DateTime firstDay;
  final DateTime lastDay;

  @override
  State<_UsageOverTimeChart> createState() => _UsageOverTimeChartState();
}

class _UsageOverTimeChartState extends State<_UsageOverTimeChart> {
  /// The user's pick, or null to follow the range length.
  _TimeBucket? _bucket;
  bool _showCost = false;
  final Set<_UsageSeries> _hidden = {_UsageSeries.cacheRead};

  static const Map<_UsageSeries, Color> _seriesColor = {
    _UsageSeries.input: _kInputColor,
    _UsageSeries.output: _kOutputColor,
    _UsageSeries.cacheWrite: _kCacheCreationColor,
    _UsageSeries.cacheRead: _kCacheReadColor,
  };

  String _seriesLabel(L t, _UsageSeries s) => switch (s) {
        _UsageSeries.input => t.aiUsageInput,
        _UsageSeries.output => t.aiUsageOutput,
        _UsageSeries.cacheWrite => t.aiUsageCacheWrite,
        _UsageSeries.cacheRead => t.aiUsageCacheReads,
      };

  void _toggleSeries(_UsageSeries s) {
    setState(() {
      if (_hidden.contains(s)) {
        _hidden.remove(s);
      } else if (_hidden.length < _UsageSeries.values.length - 1) {
        _hidden.add(s);
      }
    });
  }

  String _axisLabel(_UsagePoint p, _TimeBucket bucket, bool spansYears, String locale) =>
      switch (bucket) {
        _TimeBucket.month =>
          DateFormat(spansYears ? "MMM ''yy" : 'MMM', locale).format(p.start),
        _ => DateFormat('MMM d', locale).format(p.start),
      };

  String _tooltipTitle(_UsagePoint p, _TimeBucket bucket, String locale) {
    switch (bucket) {
      case _TimeBucket.day:
        return DateFormat('EEE, MMM d', locale).format(p.start);
      case _TimeBucket.week:
        final from = DateFormat('MMM d', locale).format(p.start);
        final to = DateFormat(
          p.end.month == p.start.month ? 'd' : 'MMM d',
          locale,
        ).format(p.end);
        return '$from – $to';
      case _TimeBucket.month:
        return DateFormat('MMMM yyyy', locale).format(p.start);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final locale = t.localeName;

    final span = widget.lastDay.difference(widget.firstDay).inHours ~/ 24 + 1;
    final bucket = _bucket ?? _autoBucket(span);
    final points = _bucketUsage(widget.dayBuckets, widget.firstDay, widget.lastDay, bucket);
    final visible = [
      for (final s in _UsageSeries.values)
        if (!_hidden.contains(s)) s,
    ];

    double valueOf(_UsagePoint p) => _showCost
        ? p.cost
        : visible.fold<int>(0, (a, s) => a + p.tokens(s)).toDouble();
    final values = [for (final p in points) valueOf(p)];
    final maxValue = values.fold<double>(0, math.max);
    final step = _niceStep(maxValue);
    final topY = maxValue <= 0 ? step : (maxValue / step).ceil() * step;
    final average =
        values.isEmpty ? 0.0 : values.fold<double>(0, (a, b) => a + b) / values.length;
    final formatAxis = _showCost ? _compactCost : _compactTokens;
    final spansYears = widget.firstDay.year != widget.lastDay.year;

    final header = Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Text(
          t.aiUsageChartTitle,
          style: TextStyle(color: luma.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _MiniToggle(
              labels: [t.aiUsageTokens, t.aiUsageCost],
              selected: _showCost ? 1 : 0,
              onSelect: (i) => setState(() => _showCost = i == 1),
            ),
            _MiniToggle(
              labels: [t.aiUsageChartDay, t.aiUsageChartWeek, t.aiUsageChartMonth],
              selected: bucket.index,
              onSelect: (i) => setState(() => _bucket = _TimeBucket.values[i]),
            ),
          ],
        ),
      ],
    );

    final legend = Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _showCost
                ? [_SeriesChip(color: luma.accent, label: t.aiUsageCost, on: true)]
                : [
                    for (final s in _UsageSeries.values)
                      _SeriesChip(
                        color: _seriesColor[s]!,
                        label: _seriesLabel(t, s),
                        on: !_hidden.contains(s),
                        tooltip: t.aiUsageChartToggleSeries,
                        onTap: () => _toggleSeries(s),
                      ),
                  ],
          ),
        ),
        if (average > 0) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 14,
            child: CustomPaint(
              size: const Size(14, 1),
              painter: _DashPainter(luma.textMuted),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            t.aiUsageChartAverage(formatAxis(average)),
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 8),
        legend,
        const SizedBox(height: 12),
        Expanded(
          child: points.isEmpty || maxValue <= 0
              ? Center(
                  child: Text(
                    t.aiUsageChartNoData,
                    style: TextStyle(color: luma.textMuted, fontSize: 13),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    const leftReserved = 44.0;
                    final plotWidth = math.max(1.0, constraints.maxWidth - leftReserved);
                    final slot = plotWidth / points.length;
                    final barWidth = (slot * 0.68).clamp(1.5, 28.0);
                    final maxLabels = math.max(2, (plotWidth / 64).floor());
                    final labelEvery = math.max(1, (points.length / maxLabels).ceil());
                    final radius = Radius.circular(math.min(4.0, barWidth / 2));

                    return BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: topY,
                        minY: 0,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            maxContentWidth: 220,
                            tooltipRoundedRadius: 8,
                            tooltipPadding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            tooltipBorder: BorderSide(color: luma.border),
                            getTooltipColor: (_) => luma.surface,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final p = points[groupIndex];
                              final row = TextStyle(color: luma.textSecondary, fontSize: 11.5);
                              final strong = TextStyle(
                                color: luma.textPrimary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              );
                              return BarTooltipItem(
                                _tooltipTitle(p, bucket, locale),
                                TextStyle(
                                  color: luma.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.left,
                                children: [
                                  for (final s in _UsageSeries.values.reversed) ...[
                                    TextSpan(
                                      text: '\n${_seriesLabel(t, s)}  ',
                                      style: row.copyWith(
                                        color: _hidden.contains(s)
                                            ? luma.textMuted
                                            : _seriesColor[s],
                                      ),
                                    ),
                                    TextSpan(text: formatTokens(p.tokens(s)), style: strong),
                                  ],
                                  TextSpan(text: '\n${t.aiUsageEstCost}  ', style: row),
                                  TextSpan(text: formatCost(p.cost), style: strong),
                                ],
                              );
                            },
                          ),
                        ),
                        extraLinesData: average > 0
                            ? ExtraLinesData(
                                horizontalLines: [
                                  HorizontalLine(
                                    y: average,
                                    color: luma.textMuted.withValues(alpha: 0.7),
                                    strokeWidth: 1,
                                    dashArray: const [4, 4],
                                  ),
                                ],
                              )
                            : null,
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 ||
                                    idx >= points.length ||
                                    value != idx.toDouble() ||
                                    (points.length - 1 - idx) % labelEvery != 0) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    _axisLabel(points[idx], bucket, spansYears, locale),
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.visible,
                                    style: TextStyle(color: luma.textMuted, fontSize: 10),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: leftReserved,
                              interval: step,
                              getTitlesWidget: (value, meta) {
                                final ticks = value / step;
                                if ((ticks - ticks.round()).abs() > 1e-6) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Text(
                                    formatAxis(value),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(color: luma.textMuted, fontSize: 10),
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles:
                              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: step,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: luma.border.withValues(alpha: 0.5),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(bottom: BorderSide(color: luma.border)),
                        ),
                        barGroups: [
                          for (var i = 0; i < points.length; i++)
                            _barGroup(i, points[i], visible, barWidth, radius, luma),
                        ],
                      ),
                      duration: Duration.zero,
                    );
                  },
                ),
        ),
      ],
    );
  }

  BarChartGroupData _barGroup(
    int index,
    _UsagePoint p,
    List<_UsageSeries> visible,
    double width,
    Radius radius,
    LumaPalette luma,
  ) {
    if (_showCost) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: p.cost,
            color: luma.accent,
            width: width,
            borderRadius: BorderRadius.vertical(top: radius),
          ),
        ],
      );
    }
    var y = 0.0;
    final stack = <BarChartRodStackItem>[];
    for (final s in visible) {
      final tokens = p.tokens(s);
      if (tokens <= 0) continue;
      final from = y;
      y += tokens;
      stack.add(BarChartRodStackItem(from, y, _seriesColor[s]!));
    }
    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          toY: y,
          rodStackItems: stack,
          color: Colors.transparent,
          width: width,
          borderRadius: BorderRadius.vertical(top: radius),
        ),
      ],
    );
  }
}

/// The legend's sample of the chart's dashed average line.
class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => oldDelegate.color != color;
}

/// A compact segmented switch for chart options: small enough to sit in a
/// card header, unlike the page-level [LumaSegmentedTabs].
class _MiniToggle extends StatelessWidget {
  const _MiniToggle({
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: i == selected ? luma.accentSubtle : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: i == selected ? luma.accent : luma.textSecondary,
                      fontSize: 11.5,
                      fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500,
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

/// A legend entry that doubles as a show/hide switch for its series.
class _SeriesChip extends StatelessWidget {
  const _SeriesChip({
    required this.color,
    required this.label,
    required this.on,
    this.tooltip,
    this.onTap,
  });

  final Color color;
  final String label;
  final bool on;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    Widget chip = AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: on ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: on ? color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 11,
                decoration: on ? null : TextDecoration.lineThrough,
                decorationColor: luma.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap != null) {
      chip = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: chip,
        ),
      );
    }
    if (tooltip != null) chip = Tooltip(message: tooltip!, child: chip);
    return chip;
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

String _formatFractionalHour(double hour, String localeName) {
  final totalMinutes = (hour * 60).round() % (24 * 60);
  final dt = DateTime(2000, 1, 1, totalMinutes ~/ 60, totalMinutes % 60);
  return DateFormat(totalMinutes % 60 == 0 ? 'ha' : 'h:mma', localeName).format(dt).toLowerCase();
}

class _HourlyDistributionChart extends StatelessWidget {
  const _HourlyDistributionChart({required this.hourly});

  final List<AiHourlyUsageBucket> hourly;

  static String _formatHour(int hour, String localeName) =>
      DateFormat('ha', localeName).format(DateTime(2000, 1, 1, hour)).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final maxTokens = hourly.fold<double>(0, (a, b) => b.avgTokens > a ? b.avgTokens : a);
    final topY = maxTokens <= 0 ? 1.0 : maxTokens * 1.2;
    final anthropicPeak = _anthropicPeakHourWindow();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              t.aiUsageAvgHourly,
              style: TextStyle(
                  color: luma.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: t.aiUsageAnthropicPeakTooltip,
              child: Text(
                t.aiUsageAnthropicPeak(
                  _formatFractionalHour(anthropicPeak.localStart, t.localeName),
                  _formatFractionalHour(anthropicPeak.localEnd, t.localeName),
                ),
                style: TextStyle(color: luma.accent, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          t.aiUsageHourlyHint,
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
                      t.aiUsageHourlyTooltip(
                        _formatHour(b.hour, t.localeName),
                        formatTokens(b.avgTokens.round()),
                        b.avgTurns.toStringAsFixed(1),
                      ),
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
                          _formatHour(hour, t.localeName),
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
  const _ProjectBreakdownSection({
    required this.projects,
    this.sort = AiUsageSortMetric.tokens,
  });

  final List<ProjectUsageTotal> projects;
  final AiUsageSortMetric sort;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    if (projects.isEmpty) {
      return LumaEmptyState(
        icon: Icons.folder_open_outlined,
        title: t.aiUsageNoProjectData,
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
              t.aiUsageTopProjectsBy(sort.label),
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
                Text(t.aiUsageInput, style: TextStyle(color: luma.textSecondary, fontSize: 11)),
                const SizedBox(width: 12),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: _kProjectOutputColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(t.aiUsageOutput, style: TextStyle(color: luma.textSecondary, fontSize: 11)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          t.aiUsageProjectSourceNote,
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
    final t = L.of(context);
    final fraction = maxTokens == 0 ? 0.0 : total.totalTokens / maxTokens;
    final inputFraction =
        total.totalTokens == 0 ? 0.0 : total.inputTokens / total.totalTokens;

    return Tooltip(
      message: t.aiUsageProjectTooltip(
        formatTokens(total.inputTokens),
        formatTokens(total.outputTokens),
        total.turnCount,
        total.sessionCount,
      ),
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
  const _OpencodeProviderSection({
    required this.providers,
    this.sort = AiUsageSortMetric.tokens,
  });

  final List<ProviderUsageTotal> providers;
  final AiUsageSortMetric sort;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    if (providers.isEmpty) {
      return LumaEmptyState(
        icon: Icons.hub_outlined,
        title: t.aiUsageNoProviderData,
      );
    }

    final maxTokens =
        providers.fold<int>(0, (a, p) => p.totalTokens > a ? p.totalTokens : a);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.aiUsageProvidersBy(sort.label),
          style: TextStyle(
              color: luma.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          t.aiUsageProvidersHint,
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
    final t = L.of(context);
    final fraction = maxTokens == 0 ? 0.0 : total.totalTokens / maxTokens;
    final models = t.aiUsageModelCount(total.modelCount);

    return Tooltip(
      message: t.aiUsageProviderTooltip(
        formatTokens(total.inputTokens),
        formatTokens(total.outputTokens),
        formatTokens(total.cacheReadTokens),
        total.turnCount,
        models,
      ),
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
                total.billable ? formatCost(total.cost) : t.aiUsageNotApplicable,
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
  const _ModelTableHeader({this.grouped = false});

  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
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
        header(
          grouped ? t.aiUsageCompany : t.aiUsageModel,
          grouped ? t.aiUsageCompanyHeaderTip : t.aiUsageModelHeaderTip,
          flex: 2,
        ),
        const SizedBox(width: 12),
        header(
          t.aiUsageTurns,
          t.aiUsageTurnsHeaderTip,
          width: 48,
          align: TextAlign.right,
        ),
        const SizedBox(width: 12),
        header(
          t.aiUsageTokens,
          t.aiUsageTokensHeaderTip,
          width: 72,
          align: TextAlign.right,
        ),
        const SizedBox(width: 12),
        header(
          t.aiUsageCost,
          t.aiUsageCostHeaderTip,
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
    final t = L.of(context);
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
                : t.aiUsageNotApplicable,
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

class _CompanyListRow extends StatelessWidget {
  const _CompanyListRow({required this.total, required this.color});

  final CompanyUsageTotal total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final modelsLabel = t.aiUsageModelCount(total.modelCount);
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                total.company,
                style: TextStyle(color: luma.textPrimary, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                modelsLabel,
                style: TextStyle(color: luma.textMuted, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
            total.estimated
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
                ? (total.estimated
                    ? '~${formatCost(total.cost)}'
                    : formatCost(total.cost))
                : t.aiUsageNotApplicable,
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
  static String? _monthLabelFor(DateTime gridStart, int week, String localeName) {
    final date = _addDays(gridStart, week * 7);
    return date.day <= 7 ? DateFormat('MMM', localeName).format(date) : null;
  }

  /// Calendar-day arithmetic on a local midnight. `add(Duration(days: n))`
  /// adds n×24h, which lands on 01:00 or 23:00 once the span crosses a DST
  /// change — and then no longer matches the midnight-keyed day buckets.
  static DateTime _addDays(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);

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
    final t = L.of(context);
    if (dayBuckets.isEmpty) {
      return LumaEmptyState(
        icon: Icons.calendar_month_outlined,
        title: t.aiUsageNoUsageYet,
      );
    }

    final byDay = {for (final d in dayBuckets) d.day: d};
    final today = DateTime.now();
    final endDate = DateTime(today.year, today.month, today.day);
    final roughStart = _addDays(endDate, -364);
    final gridStart = _addDays(roughStart, -(roughStart.weekday % 7));
    final spanDays = DateTime.utc(endDate.year, endDate.month, endDate.day)
        .difference(DateTime.utc(gridStart.year, gridStart.month, gridStart.day))
        .inDays;
    final weekCount = ((spanDays + 1) / 7).ceil();
    final maxTokens = dayBuckets
        .where((d) => !d.day.isBefore(gridStart))
        .fold<int>(0, (a, d) => d.totalTokens > a ? d.totalTokens : a);

    Widget cellFor(int week, int weekday) {
      final date = _addDays(gridStart, week * 7 + weekday);
      if (date.isAfter(endDate)) {
        return const SizedBox(width: _cellSize, height: _cellSize);
      }
      final bucket = byDay[date];
      final tokens = bucket?.totalTokens ?? 0;
      final dateLabel = DateFormat('MMM d, yyyy', t.localeName).format(date);
      final message = tokens > 0
          ? t.aiUsageHeatmapCellTooltip(
              dateLabel,
              formatTokens(tokens),
              formatCost(bucket!.cost),
            )
          : t.aiUsageHeatmapEmptyTooltip(dateLabel);
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
          t.aiUsageHeatmapTitle,
          style: TextStyle(color: luma.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          t.aiUsageHeatmapHint,
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
                          if (_monthLabelFor(gridStart, w, t.localeName) case final label?)
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
            Text(t.aiUsageLess, style: TextStyle(color: luma.textMuted, fontSize: 11)),
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
            Text(t.commonMore, style: TextStyle(color: luma.textMuted, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

// ─── Formatting helpers ──────────────────────────────────────────────────────
