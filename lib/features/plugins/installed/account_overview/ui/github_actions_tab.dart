import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../account_overview_scope.dart';
import '../github_models.dart';
import 'github_overview_tab.dart' show GithubRunRow;
import 'account_shared.dart';

enum _RunFilter {
  all('All runs'),
  failed('Failed'),
  running('In progress'),
  succeeded('Succeeded');

  const _RunFilter(this.label);
  final String label;
}

/// Recent Actions runs across the account's active repositories, with a
/// success-rate summary above them.
class GithubActionsTab extends StatefulWidget {
  const GithubActionsTab({super.key});

  @override
  State<GithubActionsTab> createState() => _GithubActionsTabState();
}

class _GithubActionsTabState extends State<GithubActionsTab> {
  _RunFilter _filter = _RunFilter.all;
  String? _repoFilter;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final snapshot = AccountOverviewScope.of(context).snapshot;
    final runs = snapshot.runs;

    final visible = runs.where((run) {
      if (_repoFilter != null && run.repo != _repoFilter) return false;
      return switch (_filter) {
        _RunFilter.all => true,
        _RunFilter.failed => run.failed,
        _RunFilter.running => run.isRunning,
        _RunFilter.succeeded => run.succeeded,
      };
    }).toList();

    final completed = runs.where((r) => !r.isRunning).toList();
    final successRate = completed.isEmpty
        ? null
        : completed.where((r) => r.succeeded).length / completed.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: _RunSummary(
            runs: runs,
            successRate: successRate,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: LumaSegmentedTabs(
                  tabs: [for (final f in _RunFilter.values) f.label],
                  selectedIndex: _filter.index,
                  onSelect: (index) =>
                      setState(() => _filter = _RunFilter.values[index]),
                  scrollable: true,
                ),
              ),
              const SizedBox(width: 10),
              _RepoMenu(
                repos: {for (final run in runs) run.repo}.toList()..sort(),
                selected: _repoFilter,
                onSelect: (repo) => setState(() => _repoFilter = repo),
              ),
            ],
          ),
        ),
        Expanded(
          child: runs.isEmpty
              ? const LumaEmptyState(
                  icon: Icons.play_disabled_outlined,
                  title: 'No workflow runs',
                  subtitle: 'luma checks your twelve most recently pushed '
                      'repositories. Runs appear here once one of them has '
                      'CI history.',
                )
              : visible.isEmpty
                  ? LumaEmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'No runs match',
                      subtitle: 'Clear the filter to see all '
                          '${runs.length} runs.',
                    )
                  : Container(
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      decoration: BoxDecoration(
                        color: luma.surface,
                        borderRadius: context.lumaDecor.cardBorderRadius,
                        border: Border.all(color: luma.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: visible.length,
                        itemBuilder: (context, index) => GithubRunRow(
                          run: visible[index],
                          isLast: index == visible.length - 1,
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _RunSummary extends StatelessWidget {
  const _RunSummary({required this.runs, required this.successRate});

  final List<GithubWorkflowRun> runs;
  final double? successRate;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final failed = runs.where((r) => r.failed).length;
    final running = runs.where((r) => r.isRunning).length;

    final durations = runs
        .map((r) => r.duration)
        .whereType<Duration>()
        .where((d) => d.inSeconds > 0)
        .toList();
    final averageSeconds = durations.isEmpty
        ? null
        : durations.fold(0, (sum, d) => sum + d.inSeconds) ~/ durations.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 200).floor().clamp(2, 4);
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final tiles = [
          AccountStatTile(
            icon: Icons.percent_rounded,
            label: 'Success rate',
            value: successRate == null
                ? '—'
                : '${(successRate! * 100).round()}%',
            caption: successRate == null
                ? 'no completed runs'
                : 'of recent completed runs',
            tint: successRate == null
                ? null
                : successRate! >= 0.9
                    ? luma.success
                    : successRate! >= 0.6
                        ? luma.warning
                        : luma.danger,
          ),
          AccountStatTile(
            icon: Icons.play_circle_outline_rounded,
            label: 'Runs seen',
            value: formatCount(runs.length),
            caption: 'most recent first',
          ),
          AccountStatTile(
            icon: Icons.cancel_outlined,
            label: 'Failed',
            value: formatCount(failed),
            caption: running > 0 ? '$running in progress' : 'in this window',
            tint: failed > 0 ? luma.danger : null,
          ),
          AccountStatTile(
            icon: Icons.timer_outlined,
            label: 'Average duration',
            value: averageSeconds == null
                ? '—'
                : formatDuration(Duration(seconds: averageSeconds)),
            caption: 'per completed run',
          ),
        ];
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

class _RepoMenu extends StatelessWidget {
  const _RepoMenu({
    required this.repos,
    required this.selected,
    required this.onSelect,
  });

  final List<String> repos;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (repos.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String?>(
      tooltip: 'Filter by repository',
      color: luma.surface,
      onSelected: (value) => onSelect(value == '' ? null : value),
      itemBuilder: (context) => [
        const PopupMenuItem(value: '', child: Text('All repositories')),
        for (final repo in repos)
          PopupMenuItem(
            value: repo,
            child: Text(
              repo,
              style: TextStyle(color: luma.textPrimary, fontSize: 13),
            ),
          ),
      ],
      child: Container(
        height: 44,
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: luma.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected == null ? luma.border : luma.accent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_outlined, size: 15, color: luma.textSecondary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                selected == null
                    ? 'All repositories'
                    : selected!.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
