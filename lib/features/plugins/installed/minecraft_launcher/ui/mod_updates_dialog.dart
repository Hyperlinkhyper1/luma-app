import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../data/minecraft_launcher_database.dart';
import '../logic/mod_installer.dart';
import '../logic/mod_update_checker.dart';
import '../logic/modrinth_api_client.dart';
import '../minecraft_launcher_repository.dart';

/// Runs [ModUpdateChecker] against an instance's installed content and shows
/// the results (available updates + declared incompatibilities) in a dialog,
/// with a one-tap "Update" per item.
Future<void> showModUpdatesDialog(
  BuildContext context, {
  required McInstance instance,
  required MinecraftLauncherRepository repository,
}) async {
  final content = await repository.watchInstalledContent(instance.id).first;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (context) => _ModUpdatesDialog(instance: instance, repository: repository, content: content),
  );
}

class _ModUpdatesDialog extends StatefulWidget {
  const _ModUpdatesDialog({required this.instance, required this.repository, required this.content});
  final McInstance instance;
  final MinecraftLauncherRepository repository;
  final List<McInstalledMod> content;

  @override
  State<_ModUpdatesDialog> createState() => _ModUpdatesDialogState();
}

class _ModUpdatesDialogState extends State<_ModUpdatesDialog> {
  bool _loading = true;
  List<ModUpdateInfo> _updates = const [];
  List<ModConflict> _conflicts = const [];
  final _updating = <int>{};

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final updates = await ModUpdateChecker.checkUpdates(
      installed: widget.content,
      gameVersion: widget.instance.versionId,
      loader: widget.instance.loader,
    );
    final conflicts = await ModUpdateChecker.checkConflicts(installed: widget.content);
    if (!mounted) return;
    setState(() {
      _updates = updates;
      _conflicts = conflicts;
      _loading = false;
    });
  }

  Future<void> _applyUpdate(ModUpdateInfo info) async {
    setState(() => _updating.add(info.installed.id));
    try {
      final project = await ModrinthApiClient.instance.getProject(info.installed.projectId!);
      await ModInstaller.updateToVersion(
        repository: widget.repository,
        instance: widget.instance,
        current: info.installed,
        project: project,
        newVersion: info.latestVersion,
      );
      if (!mounted) return;
      setState(() => _updates = _updates.where((u) => u != info).toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _updating.remove(info.installed.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AlertDialog(
      title: const Text('Updates & conflicts'),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_conflicts.isNotEmpty) ...[
                      Text('Conflicts', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      for (final c in _conflicts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(c.reason, style: TextStyle(color: Colors.red.shade400, fontSize: 13)),
                        ),
                      const SizedBox(height: 12),
                    ],
                    Text('Updates', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    if (_updates.isEmpty)
                      Text('Everything is up to date.', style: TextStyle(color: luma.textMuted, fontSize: 13))
                    else
                      for (final u in _updates)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  u.installed.projectName ?? u.installed.fileName,
                                  style: TextStyle(color: luma.textPrimary, fontSize: 13),
                                ),
                              ),
                              TextButton(
                                onPressed: _updating.contains(u.installed.id) ? null : () => _applyUpdate(u),
                                child: Text(_updating.contains(u.installed.id) ? 'Updating…' : 'Update'),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}
