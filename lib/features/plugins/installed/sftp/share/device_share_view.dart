import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../p2p/peer_sync_controller.dart';
import '../../../../../theme/luma_theme.dart';
import '../sftp_file_pane.dart';
import '../sftp_paths.dart';
import 'device_share_repository.dart';

/// The right-hand side of the Devices view: which of your devices are around,
/// what is in the shared folder, and what is moving right now.
class DeviceSharePanel extends StatelessWidget {
  const DeviceSharePanel({
    super.key,
    required this.repository,
    required this.peerSync,
    required this.selection,
    required this.onToggleSelect,
    required this.onAddFiles,
    required this.onOpenFolder,
    required this.onDeleteSelected,
    required this.onOpenFile,
    required this.onDropped,
    this.compact = false,
  });

  final DeviceShareRepository repository;
  final PeerSyncController peerSync;

  final Set<String> selection;
  final ValueChanged<String> onToggleSelect;
  final VoidCallback onAddFiles;
  final VoidCallback onOpenFolder;
  final VoidCallback onDeleteSelected;
  final ValueChanged<String> onOpenFile;

  /// Files dragged in from the local pane.
  final ValueChanged<PaneDragPayload> onDropped;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) {
        return DragTarget<PaneDragPayload>(
          onWillAcceptWithDetails: (details) =>
              details.data.side == PaneSide.local,
          onAcceptWithDetails: (details) => onDropped(details.data),
          builder: (context, candidate, rejected) {
            final active = candidate.isNotEmpty;
            return Container(
              decoration: BoxDecoration(
                color: luma.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active ? luma.accent : luma.border,
                  width: active ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _header(context, luma),
                  _DeviceStrip(
                    repository: repository,
                    peerSync: peerSync,
                  ),
                  Expanded(child: _fileList(context, luma, active)),
                  _TransferStrip(repository: repository),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _header(BuildContext context, LumaPalette luma) {
    final selected = selection.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: luma.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_shared_rounded, size: 16, color: luma.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shared folder',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  selected > 0
                      ? '$selected selected'
                      : '${repository.summary} · on every device',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (selected > 0)
            IconButton(
              onPressed: onDeleteSelected,
              tooltip: 'Delete everywhere',
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              color: luma.danger,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            ),
          IconButton(
            onPressed: onAddFiles,
            tooltip: 'Add files',
            icon: const Icon(Icons.add_rounded, size: 18),
            color: luma.textSecondary,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          ),
          IconButton(
            onPressed: onOpenFolder,
            tooltip: 'Open the folder on this device',
            icon: const Icon(Icons.drive_folder_upload_rounded, size: 18),
            color: luma.textSecondary,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          ),
          IconButton(
            onPressed: repository.refresh,
            tooltip: 'Rescan',
            icon: const Icon(Icons.refresh_rounded, size: 18),
            color: luma.textSecondary,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          ),
        ],
      ),
    );
  }

  Widget _fileList(BuildContext context, LumaPalette luma, bool dropActive) {
    final files = repository.folder.files;
    if (files.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                dropActive
                    ? Icons.file_download_rounded
                    : Icons.folder_open_rounded,
                size: 30,
                color: dropActive ? luma.accent : luma.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                dropActive ? 'Drop to share' : 'Nothing shared yet',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Drag files in from the left, or use +. Anything here shows '
                'up in the same folder on your other devices — sent straight '
                'over your network, never through a luma server.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: luma.textMuted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final entry = files[index];
        final selected = selection.contains(entry.path);
        return _SharedFileRow(
          path: entry.path,
          size: entry.size,
          modifiedMs: entry.modifiedMs,
          selected: selected,
          compact: compact,
          onTap: () => onToggleSelect(entry.path),
          onOpen: () => onOpenFile(entry.path),
        );
      },
    );
  }
}

class _SharedFileRow extends StatefulWidget {
  const _SharedFileRow({
    required this.path,
    required this.size,
    required this.modifiedMs,
    required this.selected,
    required this.compact,
    required this.onTap,
    required this.onOpen,
  });

  final String path;
  final int size;
  final int modifiedMs;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  @override
  State<_SharedFileRow> createState() => _SharedFileRowState();
}

class _SharedFileRowState extends State<_SharedFileRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? luma.accentSubtle
                : (_hovering ? luma.surfaceHover : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                widget.selected
                    ? Icons.check_circle_rounded
                    : Icons.insert_drive_file_rounded,
                size: 17,
                color: widget.selected ? luma.accent : luma.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.textPrimary, fontSize: 13),
                ),
              ),
              if (!widget.compact) ...[
                const SizedBox(width: 8),
                Text(
                  formatFileSize(widget.size),
                  style: TextStyle(color: luma.textSecondary, fontSize: 11),
                ),
              ],
              IconButton(
                onPressed: widget.onOpen,
                tooltip: 'Open',
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                color: luma.textMuted,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The row of your other devices across the top of the shared folder.
class _DeviceStrip extends StatelessWidget {
  const _DeviceStrip({required this.repository, required this.peerSync});

  final DeviceShareRepository repository;
  final PeerSyncController peerSync;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final peers = repository.peers;

    if (peers.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: luma.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              peerSync.isRunning
                  ? Icons.wifi_tethering_rounded
                  : Icons.wifi_tethering_off_rounded,
              size: 16,
              color: peerSync.isRunning ? luma.accent : luma.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                peerSync.isRunning
                    ? 'Looking for your other devices on this network. Open '
                        'luma on one of them, signed in to the same account.'
                    : 'Device sync is off. Turn it on in Settings → Sync & '
                        'account to reach your other devices.',
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 64,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: luma.border)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        itemCount: peers.length,
        itemBuilder: (context, index) => _DeviceChip(peer: peers[index]),
      ),
    );
  }
}

class _DeviceChip extends StatelessWidget {
  const _DeviceChip({required this.peer});

  final SharePeerStatus peer;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final waiting = peer.pendingIn + peer.pendingOut;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: peer.connected ? luma.accentSubtle : luma.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: peer.connected ? luma.accent : luma.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: peer.connected ? luma.success : luma.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                peer.deviceName,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                peer.error ??
                    (peer.connected
                        ? (waiting > 0
                            ? '$waiting ${waiting == 1 ? 'file' : 'files'} to go'
                            : 'Up to date')
                        : (peer.pendingIn > 0
                            ? '${peer.pendingIn} waiting for it to come back'
                            : 'Not on this network')),
                style: TextStyle(
                  color: peer.error != null ? luma.danger : luma.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Live transfers along the bottom of the shared folder. Hidden entirely
/// when nothing has moved, so an idle folder stays quiet.
class _TransferStrip extends StatelessWidget {
  const _TransferStrip({required this.repository});

  final DeviceShareRepository repository;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final active = repository.active;
    final recent = repository.history.take(3).toList();
    if (active.isEmpty && recent.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 148),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: luma.border)),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: [
          for (final transfer in active)
            _TransferRow(transfer: transfer, live: true),
          for (final transfer in recent)
            _TransferRow(transfer: transfer, live: false),
        ],
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({required this.transfer, required this.live});

  final ShareTransfer transfer;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final incoming = transfer.direction == ShareDirection.incoming;
    final failed = transfer.error != null;
    final color = failed
        ? luma.danger
        : (transfer.finished ? luma.success : luma.accent);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(
        children: [
          Icon(
            failed
                ? Icons.error_outline_rounded
                : (incoming ? Icons.south_rounded : Icons.north_rounded),
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
                        transfer.name,
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
                      failed
                          ? 'Failed'
                          : (incoming
                              ? 'from ${transfer.deviceName}'
                              : 'to ${transfer.deviceName}'),
                      style: TextStyle(
                        color: failed ? luma.danger : luma.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                if (live) ...[
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: transfer.progress,
                      minHeight: 4,
                      backgroundColor: luma.border,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
                if (failed) ...[
                  const SizedBox(height: 3),
                  Text(
                    transfer.error!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: luma.danger, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown in place of the whole Devices view when the mirror can't run yet:
/// no account key on this device, so there is nothing to prove two devices
/// belong to the same person.
class DeviceShareUnavailable extends StatelessWidget {
  const DeviceShareUnavailable({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: LumaEmptyState(
        icon: Icons.devices_rounded,
        title: 'Sign in on both devices first',
        subtitle:
            'The shared folder moves files straight between devices signed '
            'in to the same luma account, over your own network. Set up '
            'device sync under Settings → Sync & account on each device, '
            'then come back here.',
        action: LumaPrimaryButton(
          label: 'Open settings',
          icon: Icons.settings_rounded,
          onTap: onOpenSettings,
        ),
      ),
    );
  }
}
