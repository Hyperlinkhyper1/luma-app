import 'package:flutter/material.dart';

import '../../../../../sync/sync_scope.dart';
import '../../../../../theme/luma_theme.dart';
import '../../../../../app/widgets.dart';
import '../logic/mc_cloud_backup.dart';

/// Lists this instance's cloud-backed worlds or screenshots (see
/// [McCloudBackup]), with per-entry download/delete. Shown under the Worlds
/// and Screenshots tabs; upload happens from those tabs' own per-item menus
/// (they know how to produce the file to upload — a zip for a world, the
/// PNG itself for a screenshot), this section is just the "what's already
/// backed up" view shared by both.
class CloudBackupSection extends StatefulWidget {
  const CloudBackupSection({
    super.key,
    required this.instanceId,
    required this.kind,
    required this.onRestore,
  });

  final String instanceId;
  final String kind;
  final Future<void> Function(McCloudBackupEntry entry, McCloudBackup backup) onRestore;

  @override
  State<CloudBackupSection> createState() => _CloudBackupSectionState();
}

class _CloudBackupSectionState extends State<CloudBackupSection> {
  List<McCloudBackupEntry>? _entries;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final sync = SyncScope.of(context);
    if (!sync.signedIn) {
      setState(() => _entries = const []);
      return;
    }
    final backup = McCloudBackup(sync);
    final entries = await backup.list(instanceId: widget.instanceId);
    if (!mounted) return;
    setState(() => _entries = entries.where((e) => e.kind == widget.kind).toList());
  }

  Future<void> _delete(McCloudBackupEntry entry) async {
    final backup = McCloudBackup(SyncScope.of(context));
    await backup.delete(entry);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final sync = SyncScope.of(context);
    if (!sync.signedIn) return const SizedBox.shrink();
    if (_entries == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_entries!.isEmpty) return const SizedBox.shrink();

    return LumaCollapsibleSection(
      icon: Icons.cloud_done_rounded,
      title: 'Cloud backups',
      subtitle: '${_entries!.length} backed up',
      child: Column(
        children: [
          for (final entry in _entries!)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.cloud_rounded, size: 18, color: luma.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(entry.label, style: TextStyle(color: luma.textPrimary, fontSize: 13)),
                  ),
                  TextButton(
                    onPressed: () => widget.onRestore(entry, McCloudBackup(SyncScope.of(context))),
                    child: const Text('Restore'),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: luma.textMuted, size: 18),
                    onPressed: () => _delete(entry),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
