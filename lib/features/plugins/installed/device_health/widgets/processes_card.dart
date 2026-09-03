import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../device_health_models.dart';
import '../device_health_repository.dart';
import '../device_health_scope.dart';
import 'category_card.dart';

/// Background processes, sorted by memory. Ending one is always the user's
/// own manual choice — nothing here is ever closed automatically, including
/// entries flagged against the bundled bloatware list, which are shown only
/// as a suggestion badge.
class ProcessesCard extends StatelessWidget {
  const ProcessesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = DeviceHealthScope.of(context);
    final state = repo.processes;
    final list = state.data;
    final luma = context.luma;

    return CategoryCard(
      icon: Icons.list_alt_rounded,
      title: 'Background Processes',
      loading: state.loading,
      error: state.error,
      onCheck: () => repo.refreshProcesses(),
      checkLabel: list == null ? 'Scan processes' : 'Rescan',
      child: list == null
          ? Text(
              'Not scanned yet — this reads every running process, so it '
              "isn't run automatically.",
              style: TextStyle(color: luma.textMuted, fontSize: 13),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${list.length} processes · sorted by memory',
                  style: TextStyle(color: luma.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 340,
                  child: ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: luma.border),
                    itemBuilder: (context, i) => _ProcessRow(process: list[i], repo: repo),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProcessRow extends StatelessWidget {
  const _ProcessRow({required this.process, required this.repo});
  final ProcessInfo process;
  final DeviceHealthRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final bloat = process.bloatware;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  process.name,
                  style: TextStyle(color: luma.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (bloat != null) ...[
                  const SizedBox(height: 2),
                  Tooltip(
                    message: bloat.reason,
                    child: Text(
                      'Suggested: ${bloat.label}',
                      style: TextStyle(color: luma.warning, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              _formatBytes(process.workingSetBytes),
              textAlign: TextAlign.right,
              style: TextStyle(color: luma.textSecondary, fontSize: 12),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '${process.cpuPercent.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: TextStyle(color: luma.textSecondary, fontSize: 12),
            ),
          ),
          IconButton(
            onPressed: () => _confirmEnd(context),
            icon: const Icon(Icons.close_rounded, size: 16),
            tooltip: 'End process',
            visualDensity: VisualDensity.compact,
            color: luma.textMuted,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmEnd(BuildContext context) async {
    final luma = context.luma;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text('End ${process.name}?', style: TextStyle(color: luma.textPrimary, fontSize: 16)),
        content: Text(
          process.bloatware != null
              ? '${process.bloatware!.reason} Unsaved work in this process will be lost.'
              : 'This closes the process immediately. Unsaved work in it will be lost.',
          style: TextStyle(color: luma.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('End process', style: TextStyle(color: luma.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) await repo.endProcess(process.pid);
  }
}

String _formatBytes(int bytes) {
  final mb = bytes / 1048576;
  if (mb < 1024) return '${mb.toStringAsFixed(0)} MB';
  return '${(mb / 1024).toStringAsFixed(1)} GB';
}
