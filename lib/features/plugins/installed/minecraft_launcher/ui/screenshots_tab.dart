import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/widgets.dart';
import '../../../../../sync/sync_scope.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/minecraft_launcher_database.dart';
import '../logic/mc_cloud_backup.dart';
import '../logic/mc_paths.dart';
import '../logic/safe_path.dart';
import 'cloud_backup_section.dart';

class ScreenshotsSection extends StatefulWidget {
  const ScreenshotsSection({super.key, required this.instance});
  final McInstance instance;

  @override
  State<ScreenshotsSection> createState() => _ScreenshotsSectionState();
}

class _ScreenshotsSectionState extends State<ScreenshotsSection> {
  List<File>? _files;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dir = await McPaths.instanceSubDir(widget.instance.id, 'screenshots');
    final files = <File>[];
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.png')) {
          files.add(entity);
        }
      }
    }
    files.sort((a, b) => b.path.compareTo(a.path));
    if (!mounted) return;
    setState(() => _files = files);
  }

  @override
  Widget build(BuildContext context) {
    if (_files == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CloudBackupSection(
          instanceId: widget.instance.id,
          kind: 'screenshot',
          onRestore: (entry, backup) async {
            final dir = await McPaths.instanceSubDir(widget.instance.id, 'screenshots');
            final destPath = safeJoin(dir.path, entry.label);
            if (destPath == null) return; // refuse a label that isn't a plain file name
            try {
              await backup.downloadToFile(entry, destPath);
              await _load();
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
            }
          },
        ),
        const SizedBox(height: 12),
        if (_files!.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: LumaEmptyState(
              icon: Icons.image_outlined,
              title: 'No screenshots yet',
              subtitle: 'Screenshots you take in-game (F2) will show up here.',
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisExtent: 150,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _files!.length,
            itemBuilder: (context, i) => _ScreenshotTile(
              instanceId: widget.instance.id,
              file: _files![i],
              onChanged: _load,
            ),
          ),
      ],
    );
  }
}

class _ScreenshotTile extends StatelessWidget {
  const _ScreenshotTile({required this.instanceId, required this.file, required this.onChanged});
  final String instanceId;
  final File file;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(file, fit: BoxFit.cover),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: luma.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 18),
                onSelected: (action) => _handleAction(context, action),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'open', child: Text('Open')),
                  PopupMenuItem(value: 'reveal', child: Text('Reveal in folder')),
                  PopupMenuItem(value: 'copy', child: Text('Copy path')),
                  PopupMenuItem(value: 'cloud', child: Text('Backup to cloud')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    switch (action) {
      case 'open':
        await Process.run('explorer', [file.path]);
      case 'reveal':
        await Process.run('explorer', ['/select,', file.path]);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: file.path));
      case 'cloud':
        try {
          final sync = SyncScope.of(context);
          final label = file.path.split(Platform.pathSeparator).last;
          await McCloudBackup(sync).uploadFile(
            instanceId: instanceId,
            kind: 'screenshot',
            label: label,
            file: file,
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Backed up "$label" to the cloud.')));
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      case 'delete':
        await file.delete();
        onChanged();
    }
  }
}
