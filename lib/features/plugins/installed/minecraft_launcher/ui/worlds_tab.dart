import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../sync/sync_scope.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/minecraft_launcher_database.dart';
import '../logic/mc_cloud_backup.dart';
import '../logic/mc_paths.dart';
import '../logic/world_reader.dart';
import 'cloud_backup_section.dart';

class WorldsSection extends StatefulWidget {
  const WorldsSection({super.key, required this.instance});
  final McInstance instance;

  @override
  State<WorldsSection> createState() => _WorldsSectionState();
}

class _WorldsSectionState extends State<WorldsSection> {
  List<McWorldInfo>? _worlds;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final worlds = await WorldReader.listWorlds(widget.instance.id);
      if (!mounted) return;
      setState(() => _worlds = worlds);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _importWorld() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      await WorldReader.importWorldZip(widget.instance.id, File(path));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    if (_error != null) {
      return LumaEmptyState(icon: Icons.error_outline_rounded, title: t.mcLauncherCouldNotReadWorlds, subtitle: _error);
    }
    if (_worlds == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: LumaGhostButton(
            label: t.mcLauncherImportWorld,
            icon: Icons.upload_file_rounded,
            onTap: _importWorld,
          ),
        ),
        const SizedBox(height: 12),
        CloudBackupSection(
          instanceId: widget.instance.id,
          kind: 'world',
          onRestore: (entry, backup) async {
            final tmpDir = await Directory.systemTemp.createTemp('mc_world_restore_');
            // Fixed temp file name — the label is display text, not a path.
            final zipPath = '${tmpDir.path}${Platform.pathSeparator}restore.zip';
            try {
              await backup.downloadToFile(entry, zipPath);
              await WorldReader.importWorldZip(widget.instance.id, File(zipPath));
              await _load();
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
            } finally {
              if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
            }
          },
        ),
        const SizedBox(height: 12),
        if (_worlds!.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: LumaEmptyState(
              icon: Icons.public_off_rounded,
              title: t.mcLauncherNoWorlds,
              subtitle: t.mcLauncherNoWorldsSubtitle,
            ),
          )
        else
          for (final world in _worlds!)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _WorldCard(
                instanceId: widget.instance.id,
                world: world,
                onChanged: _load,
              ),
            ),
      ],
    );
  }
}

class _WorldCard extends StatelessWidget {
  const _WorldCard({required this.instanceId, required this.world, required this.onChanged});
  final String instanceId;
  final McWorldInfo world;
  final VoidCallback onChanged;

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return LumaCard(
      child: Row(
        children: [
          LumaIconBadge(icon: Icons.public_rounded, color: luma.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(world.name, style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700)),
                Text(
                  [
                    world.gameModeLabel,
                    if (world.seed != null) t.mcLauncherWorldSeed('${world.seed}'),
                    _formatSize(world.sizeBytes),
                    if (world.lastPlayed != null) t.mcLauncherLastPlayed('${world.lastPlayed}'),
                  ].join(' · '),
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (action) => _handleAction(context, action),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'open', child: Text(t.mcLauncherOpenFolder)),
              PopupMenuItem(value: 'backup', child: Text(t.mcLauncherBackupToZip)),
              PopupMenuItem(value: 'cloud', child: Text(t.mcLauncherBackupToCloud)),
              PopupMenuItem(value: 'duplicate', child: Text(t.mcLauncherDuplicate)),
              PopupMenuItem(value: 'delete', child: Text(t.commonDelete)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    switch (action) {
      case 'open':
        final dir = await McPaths.instanceSubDir(instanceId, 'saves');
        await Process.run('explorer', ['${dir.path}${Platform.pathSeparator}${world.folderName}']);
      case 'backup':
        try {
          final file = await WorldReader.backupWorld(instanceId, world.folderName);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(L.of(context).mcLauncherBackedUpTo(file.path))));
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      case 'cloud':
        try {
          final zipFile = await WorldReader.backupWorld(instanceId, world.folderName);
          final sync = SyncScope.of(context);
          await McCloudBackup(sync).uploadFile(
            instanceId: instanceId,
            kind: 'world',
            label: world.name,
            file: zipFile,
          );
          await zipFile.delete();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(L.of(context).mcLauncherBackedUpToCloud(world.name))));
          onChanged();
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      case 'duplicate':
        await WorldReader.duplicateWorld(instanceId, world.folderName);
        onChanged();
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(L.of(context).mcLauncherDeleteWorldTitle(world.name)),
            content: Text(L.of(context).mcLauncherDeleteWorldBody),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(L.of(context).commonCancel)),
              TextButton(onPressed: () => Navigator.pop(context, true), child: Text(L.of(context).commonDelete)),
            ],
          ),
        );
        if (confirmed == true) {
          await WorldReader.deleteWorld(instanceId, world.folderName);
          onChanged();
        }
    }
  }
}
