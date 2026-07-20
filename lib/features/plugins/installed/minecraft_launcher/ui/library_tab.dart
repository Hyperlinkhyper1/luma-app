import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/minecraft_launcher_database.dart';
import '../logic/active_launch_registry.dart';
import '../logic/mc_paths.dart';
import '../logic/modpack_importer.dart';
import '../minecraft_launcher_repository.dart';
import '../minecraft_launcher_scope.dart';
import 'create_instance_wizard.dart';
import 'download_progress_sheet.dart';
import 'instance_detail_page.dart';

class LibraryTab extends StatelessWidget {
  const LibraryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = MinecraftLauncherScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Instances',
                  style: TextStyle(
                    color: context.luma.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              LumaGhostButton(
                label: 'Open folder',
                icon: Icons.folder_open_rounded,
                onTap: () async {
                  final dir = await McPaths.instancesRoot();
                  await Process.run('explorer', [dir.path]);
                },
              ),
              const SizedBox(width: 10),
              LumaGhostButton(
                label: 'Import modpack',
                icon: Icons.upload_file_rounded,
                onTap: () => _importModpack(context, repository),
              ),
              const SizedBox(width: 10),
              LumaPrimaryButton(
                label: 'New instance',
                icon: Icons.add_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateInstanceWizard()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamData(
              stream: repository.watchInstances(),
              builder: (context, instances) {
                if (instances.isEmpty) {
                  return const LumaEmptyState(
                    icon: Icons.videogame_asset_outlined,
                    title: 'No instances yet',
                    subtitle: 'Create one to install Minecraft and start playing.',
                  );
                }
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisExtent: 150,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: instances.length,
                  itemBuilder: (context, i) => _InstanceCard(
                    instance: instances[i],
                    repository: repository,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importModpack(BuildContext context, MinecraftLauncherRepository repository) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mrpack', 'zip'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    final notifier = ValueNotifier<_ImportStatus>(_ImportStatus('Starting…', null));
    final navigator = Navigator.of(context);
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ImportProgressDialog(notifier: notifier),
    ));

    try {
      await ModpackImporter.importMrpack(
        repository: repository,
        mrpackFile: File(path),
        onStatus: (status, fraction) => notifier.value = _ImportStatus(status, fraction),
      );
      if (navigator.canPop()) navigator.pop();
    } catch (e) {
      if (navigator.canPop()) navigator.pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    // Not disposing the notifier: the dialog's fade-out still holds a
    // listener on it; it's unreferenced after this frame and GC'd.
  }
}

class _ImportStatus {
  _ImportStatus(this.status, this.fraction);
  final String status;
  final double? fraction;
}

class _ImportProgressDialog extends StatelessWidget {
  const _ImportProgressDialog({required this.notifier});
  final ValueNotifier<_ImportStatus> notifier;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AlertDialog(
      title: const Text('Importing modpack'),
      content: SizedBox(
        width: 380,
        child: ValueListenableBuilder<_ImportStatus>(
          valueListenable: notifier,
          builder: (context, state, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.status, style: TextStyle(color: luma.textPrimary, fontSize: 14)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.fraction,
                    minHeight: 6,
                    backgroundColor: luma.border,
                    valueColor: AlwaysStoppedAnimation(luma.accent),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InstanceCard extends StatelessWidget {
  const _InstanceCard({required this.instance, required this.repository});
  final McInstance instance;
  final MinecraftLauncherRepository repository;

  Future<void> _play(BuildContext context) async {
    final account = await repository.watchActiveAccount().first;
    if (account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an account under the Accounts tab first.')),
      );
      return;
    }

    int? launchId;
    try {
      launchId = await repository.recordLaunchStart(instance.id);
      final handle = await showDownloadProgressAndLaunch(context, instance: instance, account: account);
      if (handle == null) {
        await repository.recordLaunchEnd(launchId, exitCode: -1);
        return;
      }
      ActiveLaunchRegistry.instance.register(instance.id, handle);
      await repository.markLaunched(instance.id);
      unawaited(handle.exitCode.then((code) {
        repository.recordLaunchEnd(launchId!, exitCode: code, logFilePath: handle.logFilePath);
      }));
    } catch (e) {
      if (launchId != null) {
        await repository.recordLaunchEnd(launchId, exitCode: -1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => InstanceDetailPage(instanceId: instance.id)),
      ),
      child: LumaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (instance.iconPath != null && File(instance.iconPath!).existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(instance.iconPath!), width: 40, height: 40, fit: BoxFit.cover),
                  )
                else
                  LumaIconBadge(icon: Icons.videogame_asset_rounded, color: luma.accent),
                const Spacer(),
                ListenableBuilder(
                  listenable: ActiveLaunchRegistry.instance,
                  builder: (context, _) {
                    final running = ActiveLaunchRegistry.instance.isRunning(instance.id);
                    return IconButton(
                      icon: Icon(
                        running ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                        color: luma.accent,
                        size: 32,
                      ),
                      onPressed: running
                          ? () => ActiveLaunchRegistry.instance.handleFor(instance.id)?.kill()
                          : () => _play(context),
                    );
                  },
                ),
              ],
            ),
            const Spacer(),
            Text(
              instance.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: luma.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              instance.loader == 'vanilla'
                  ? instance.versionId
                  : '${instance.versionId} · ${instance.loader}',
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
