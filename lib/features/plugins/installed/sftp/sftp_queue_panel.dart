import 'package:flutter/material.dart';

import '../../../../theme/luma_theme.dart';
import 'sftp_paths.dart';
import 'sftp_transfer_queue.dart';

/// The transfer queue, as a strip under the panes on desktop and as its own
/// tab on a phone. Every row can be stopped, and anything that failed can be
/// put back on the queue without rebuilding it by hand.
class SftpQueuePanel extends StatelessWidget {
  const SftpQueuePanel({
    super.key,
    required this.queue,
    required this.expanded,
    required this.onToggleExpanded,
    this.showHeader = true,
  });

  final SftpTransferQueue queue;

  /// Desktop only: whether the list under the summary row is showing.
  final bool expanded;
  final VoidCallback onToggleExpanded;

  /// The phone's Queue tab drops the summary row's expand affordance, since
  /// the whole tab is the queue.
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AnimatedBuilder(
      animation: queue,
      builder: (context, _) {
        final items = queue.items;
        return Container(
          decoration: BoxDecoration(
            color: luma.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: luma.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHeader) _summary(context, luma),
              if (expanded || !showHeader)
                Flexible(
                  child: items.isEmpty
                      ? _empty(luma)
                      : ListView.builder(
                          shrinkWrap: showHeader,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: items.length,
                          itemBuilder: (context, index) => _TransferRow(
                            item: items[index],
                            onCancel: () => queue.cancel(items[index].id),
                            onRetry: () => queue.retry(items[index].id),
                          ),
                        ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _empty(LumaPalette luma) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Center(
          child: Text(
            'Nothing queued. Drag files between the two sides, or select some '
            'and use the transfer arrows.',
            textAlign: TextAlign.center,
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
        ),
      );

  Widget _summary(BuildContext context, LumaPalette luma) {
    final pending = queue.pendingCount;
    final failed = queue.failedCount;
    final progress = queue.overallProgress;

    return InkWell(
      onTap: onToggleExpanded,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: expanded ? luma.border : Colors.transparent,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              pending > 0
                  ? Icons.swap_vert_rounded
                  : Icons.checklist_rtl_rounded,
              size: 17,
              color: pending > 0 ? luma.accent : luma.textSecondary,
            ),
            const SizedBox(width: 10),
            Text(
              pending > 0 ? 'Transferring' : 'Transfer queue',
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            if (pending > 0)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: luma.border,
                    valueColor: AlwaysStoppedAnimation(luma.accent),
                  ),
                ),
              )
            else
              const Spacer(),
            const SizedBox(width: 10),
            Text(
              _statusLabel(pending, failed),
              style: TextStyle(
                color: failed > 0 ? luma.danger : luma.textSecondary,
                fontSize: 12,
              ),
            ),
            if (failed > 0)
              TextButton(
                onPressed: queue.retryFailed,
                child: Text('Retry all', style: TextStyle(color: luma.accent)),
              ),
            if (pending > 0)
              TextButton(
                onPressed: queue.cancelAll,
                child: Text('Stop', style: TextStyle(color: luma.danger)),
              ),
            if (queue.hasFinished && pending == 0)
              TextButton(
                onPressed: queue.clearFinished,
                child: Text(
                  'Clear',
                  style: TextStyle(color: luma.textSecondary),
                ),
              ),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
              size: 20,
              color: luma.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(int pending, int failed) {
    if (pending > 0) {
      return '$pending ${pending == 1 ? 'file' : 'files'} left';
    }
    if (failed > 0) return '$failed failed';
    if (queue.isEmpty) return 'Empty';
    return 'All done';
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({
    required this.item,
    required this.onCancel,
    required this.onRetry,
  });

  final TransferItem item;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final upload = item.direction == TransferDirection.upload;
    final color = switch (item.state) {
      TransferState.done => luma.success,
      TransferState.failed => luma.danger,
      TransferState.cancelled => luma.textMuted,
      _ => luma.accent,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(
            upload ? Icons.north_rounded : Icons.south_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _detail(item),
                      style: TextStyle(
                        color: item.state == TransferState.failed
                            ? luma.danger
                            : luma.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: item.state == TransferState.running
                        ? item.progress
                        : (item.state == TransferState.done ? 1 : 0),
                    minHeight: 4,
                    backgroundColor: luma.border,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                if (item.error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.error!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: luma.danger, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (item.state == TransferState.failed ||
              item.state == TransferState.cancelled)
            IconButton(
              onPressed: onRetry,
              tooltip: 'Retry',
              icon: const Icon(Icons.refresh_rounded, size: 17),
              color: luma.textSecondary,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              padding: EdgeInsets.zero,
            )
          else if (!item.isFinished)
            IconButton(
              onPressed: onCancel,
              tooltip: 'Stop',
              icon: const Icon(Icons.close_rounded, size: 17),
              color: luma.textSecondary,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              padding: EdgeInsets.zero,
            )
          else
            SizedBox(
              width: 34,
              height: 34,
              child: Icon(Icons.check_rounded, size: 17, color: luma.success),
            ),
        ],
      ),
    );
  }

  static String _detail(TransferItem item) => switch (item.state) {
        TransferState.queued => 'Waiting',
        TransferState.running =>
          '${formatFileSize(item.transferredBytes)} of '
              '${formatFileSize(item.totalBytes)} · ${item.rateLabel}',
        TransferState.done => formatFileSize(item.totalBytes),
        TransferState.cancelled => 'Stopped',
        TransferState.failed => 'Failed',
      };
}
