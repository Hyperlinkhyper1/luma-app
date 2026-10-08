import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/minecraft_launcher_database.dart';
import '../logic/active_launch_registry.dart';
import '../logic/ai_crash_analyzer.dart';
import '../logic/game_process_manager.dart';
import '../logic/mc_paths.dart';
import '../logic/mod_icon_extractor.dart';
import '../logic/mod_installer.dart';
import '../logic/modpack_exporter.dart';
import '../minecraft_launcher_repository.dart';
import '../minecraft_launcher_scope.dart';
import 'browse_content_tab.dart';
import 'download_progress_sheet.dart';
import 'hover_sync_scroll.dart';
import 'mod_updates_dialog.dart';
import 'modrinth_ui.dart';
import 'screenshots_tab.dart';
import 'worlds_tab.dart';

class InstanceDetailPage extends StatefulWidget {
  const InstanceDetailPage({super.key, required this.instanceId});
  final String instanceId;

  @override
  State<InstanceDetailPage> createState() => _InstanceDetailPageState();
}

class _InstanceDetailPageState extends State<InstanceDetailPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final repository = MinecraftLauncherScope.of(context);
    final luma = context.luma;
    final t = L.of(context);
    return Scaffold(
      backgroundColor: luma.background,
      body: StreamData<McInstance?>(
        stream: repository.watchInstance(widget.instanceId),
        builder: (context, instance) {
          if (instance == null) {
            return Center(child: Text(t.mcLauncherInstanceNotFound));
          }
          return HoverSyncScroll(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: luma.background,
                  pinned: true,
                  title: Text(instance.name),
                  actions: [
                    IconButton(
                      tooltip: t.mcLauncherExportModpack,
                      icon: const Icon(Icons.ios_share_rounded),
                      onPressed: () => _exportModpack(context, repository, instance),
                    ),
                    IconButton(
                      tooltip: t.mcLauncherDeleteInstance,
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => _confirmDelete(context, repository, instance),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LumaSegmentedTabs(
                          tabs: [
                            t.commonOverview,
                            t.mcLauncherTabContent,
                            t.mcLauncherTabWorlds,
                            t.mcLauncherTabScreenshots,
                            t.mcLauncherTabLogs,
                            t.commonSettings,
                          ],
                          selectedIndex: _tab,
                          onSelect: (i) => setState(() => _tab = i),
                        ),
                        const SizedBox(height: 16),
                        switch (_tab) {
                          0 => _OverviewSection(instance: instance, repository: repository),
                          1 => _ContentSection(instance: instance, repository: repository),
                          2 => WorldsSection(instance: instance),
                          3 => ScreenshotsSection(instance: instance),
                          4 => _LogsSection(instance: instance, repository: repository),
                          _ => _SettingsSection(instance: instance, repository: repository),
                        },
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _exportModpack(
    BuildContext context,
    MinecraftLauncherRepository repository,
    McInstance instance,
  ) async {
    final t = L.of(context);
    final path = await FilePicker.saveFile(
      dialogTitle: t.mcLauncherExportModpackTitle,
      fileName: '${instance.name}.mrpack',
      type: FileType.custom,
      allowedExtensions: ['mrpack'],
    );
    if (path == null) return;
    try {
      await ModpackExporter.exportInstance(repository: repository, instance: instance, destPath: path);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.mcLauncherExportedTo(path))));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MinecraftLauncherRepository repository,
    McInstance instance,
  ) async {
    final t = L.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.mcLauncherDeleteInstanceTitle(instance.name)),
        content: Text(t.mcLauncherDeleteInstanceBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.commonCancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t.commonDelete)),
        ],
      ),
    );
    if (confirmed == true) {
      await repository.deleteInstance(instance.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.instance, required this.repository});
  final McInstance instance;
  final MinecraftLauncherRepository repository;

  Future<void> _play(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final addAccountFirst = L.of(context).mcLauncherAddAccountFirst;
    final account = await repository.watchActiveAccount().first;
    if (account == null) {
      messenger.showSnackBar(SnackBar(content: Text(addAccountFirst)));
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
      if (launchId != null) await repository.recordLaunchEnd(launchId, exitCode: -1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final hours = instance.totalPlayTimeSeconds ~/ 3600;
    final minutes = (instance.totalPlayTimeSeconds % 3600) ~/ 60;
    return LumaCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(instance.loader == 'vanilla'
                    ? 'Minecraft ${instance.versionId}'
                    : 'Minecraft ${instance.versionId} · ${instance.loader}'),
                const SizedBox(height: 8),
                Text(
                  instance.lastPlayedAt == null
                      ? t.mcLauncherNeverPlayed
                      : t.mcLauncherLastPlayed('${instance.lastPlayedAt}'),
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
                Text(
                  t.mcLauncherTotalPlaytime(hours, minutes),
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                LumaGhostButton(
                  label: t.mcLauncherOpenFolder,
                  icon: Icons.folder_open_rounded,
                  onTap: () async {
                    final dir = await McPaths.instanceDir(instance.id);
                    await Process.run('explorer', [dir.path]);
                  },
                ),
              ],
            ),
          ),
          ListenableBuilder(
            listenable: ActiveLaunchRegistry.instance,
            builder: (context, _) {
              final running = ActiveLaunchRegistry.instance.isRunning(instance.id);
              return LumaPrimaryButton(
                label: running ? t.commonStop : t.mcLauncherPlay,
                icon: running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                onTap: running
                    ? () => ActiveLaunchRegistry.instance.handleFor(instance.id)?.kill()
                    : () => _play(context),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ContentSection extends StatelessWidget {
  const _ContentSection({required this.instance, required this.repository});
  final McInstance instance;
  final MinecraftLauncherRepository repository;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            LumaGhostButton(
              label: t.mcLauncherCheckUpdates,
              icon: Icons.system_update_alt_rounded,
              onTap: () => showModUpdatesDialog(context, instance: instance, repository: repository),
            ),
            const SizedBox(width: 10),
            LumaPrimaryButton(
              label: t.commonBrowse,
              icon: Icons.travel_explore_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BrowseContentPage(instance: instance, repository: repository),
              )),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamData(
          stream: repository.watchInstalledContent(instance.id),
          builder: (context, content) {
            if (content.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 40),
                child: LumaEmptyState(
                  icon: Icons.extension_off_rounded,
                  title: t.mcLauncherNothingInstalled,
                  subtitle: t.mcLauncherNothingInstalledSubtitle,
                ),
              );
            }
            return Column(
              children: [
                for (final item in content)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LumaCard(
                      child: Row(
                        children: [
                          _ContentIcon(instance: instance, item: item, luma: luma),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.projectName ?? item.fileName,
                                    style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w600)),
                                Text(contentKindLabel(t, item.kind),
                                    style: TextStyle(color: luma.textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                          Switch(
                            value: item.enabled,
                            onChanged: (v) => ModInstaller.setEnabled(
                              repository: repository,
                              instanceId: instance.id,
                              content: item,
                              enabled: v,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline_rounded, color: luma.textMuted),
                            onPressed: () => ModInstaller.deleteInstalled(
                              repository: repository,
                              instanceId: instance.id,
                              content: item,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Shows the project's icon from Modrinth when it's known (anything
/// installed through the in-app browser); otherwise tries to pull the real
/// icon out of the jar itself (see [ModIconExtractor] — covers manually
/// dropped files and modpack imports, which never get a `projectIconUrl`),
/// falling back to the generic puzzle badge only if neither source has one.
class _ContentIcon extends StatelessWidget {
  const _ContentIcon({required this.instance, required this.item, required this.luma});
  final McInstance instance;
  final McInstalledMod item;
  final LumaPalette luma;

  Widget _fallback() => LumaIconBadge(icon: Icons.extension_rounded, color: luma.accent, size: 36);

  @override
  Widget build(BuildContext context) {
    if (item.projectIconUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          item.projectIconUrl!,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallback(),
        ),
      );
    }
    return FutureBuilder<File?>(
      future: ModIconExtractor.iconFor(
        instanceId: instance.id,
        kind: item.kind,
        fileName: item.fileName,
      ),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) return _fallback();
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(file, width: 36, height: 36, fit: BoxFit.cover),
        );
      },
    );
  }
}

class _LogsSection extends StatelessWidget {
  const _LogsSection({required this.instance, required this.repository});
  final McInstance instance;
  final MinecraftLauncherRepository repository;

  @override
  Widget build(BuildContext context) {
    final handle = ActiveLaunchRegistry.instance.handleFor(instance.id);
    if (handle != null) return _LiveLog(handle: handle);
    return _PastLog(instance: instance, repository: repository);
  }
}

/// Sends the last ~200 lines to `analyzeCrashLog` and shows the answer in a
/// dialog — shared by both the live and past-log views.
class _AnalyzeWithAiButton extends StatefulWidget {
  const _AnalyzeWithAiButton({required this.logTail});
  final String logTail;

  @override
  State<_AnalyzeWithAiButton> createState() => _AnalyzeWithAiButtonState();
}

class _AnalyzeWithAiButtonState extends State<_AnalyzeWithAiButton> {
  bool _loading = false;

  Future<void> _analyze() async {
    setState(() => _loading = true);
    try {
      final answer = await analyzeCrashLog(context, widget.logTail);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(L.of(context).mcLauncherAiAnalysis),
          content: SizedBox(width: lumaDialogWidth(context, 420), child: SingleChildScrollView(child: Text(answer))),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(L.of(context).commonClose))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return LumaGhostButton(
      label: _loading ? t.mcLauncherAnalyzing : t.mcLauncherAnalyzeWithAi,
      icon: Icons.auto_awesome_rounded,
      onTap: widget.logTail.trim().isEmpty || _loading ? () {} : _analyze,
    );
  }
}

class _LiveLog extends StatefulWidget {
  const _LiveLog({required this.handle});
  final GameProcessHandle handle;

  @override
  State<_LiveLog> createState() => _LiveLogState();
}

class _LiveLogState extends State<_LiveLog> {
  final _lines = <String>[];
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.handle.logLines.listen((line) {
      setState(() => _lines.add(line));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: _AnalyzeWithAiButton(logTail: _lines.skip(_lines.length > 200 ? _lines.length - 200 : 0).join('\n')),
        ),
        const SizedBox(height: 8),
        Container(
          height: 420,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: luma.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: luma.border),
          ),
          child: _lines.isEmpty
              ? Center(
                  child: Text(t.mcLauncherWaitingForOutput, style: TextStyle(color: luma.textMuted)),
                )
              : ListView.builder(
                  itemCount: _lines.length,
                  itemBuilder: (context, i) => Text(
                    _lines[i],
                    style: TextStyle(
                      color: luma.textSecondary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _PastLog extends StatefulWidget {
  const _PastLog({required this.instance, required this.repository});
  final McInstance instance;
  final MinecraftLauncherRepository repository;

  @override
  State<_PastLog> createState() => _PastLogState();
}

class _PastLogState extends State<_PastLog> {
  String? _content;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final history = await widget.repository.watchLaunchHistory(widget.instance.id).first;
    final withLog = history.where((h) => h.logFilePath != null).toList();
    if (withLog.isEmpty) {
      if (!mounted) return;
      setState(() => _loaded = true);
      return;
    }
    final file = File(withLog.first.logFilePath!);
    final content = await file.exists() ? await file.readAsString() : null;
    if (!mounted) return;
    setState(() {
      _content = content;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    if (!_loaded) return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    if (_content == null) {
      return LumaEmptyState(
        icon: Icons.terminal_rounded,
        title: t.mcLauncherNotRunning,
        subtitle: t.mcLauncherNotRunningSubtitle,
      );
    }
    final lines = _content!.split('\n');
    final tail = lines.skip(lines.length > 200 ? lines.length - 200 : 0).join('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(alignment: Alignment.centerRight, child: _AnalyzeWithAiButton(logTail: tail)),
        const SizedBox(height: 8),
        Container(
          height: 420,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: luma.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: luma.border),
          ),
          child: SingleChildScrollView(
            child: Text(
              _content!,
              style: TextStyle(color: luma.textSecondary, fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatefulWidget {
  const _SettingsSection({required this.instance, required this.repository});
  final McInstance instance;
  final MinecraftLauncherRepository repository;

  @override
  State<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<_SettingsSection> {
  late double _minMemory = widget.instance.minMemoryMb.toDouble();
  late double _maxMemory = widget.instance.maxMemoryMb.toDouble();
  late final _jvmArgsController = TextEditingController(text: widget.instance.jvmArgs ?? '');
  late final _javaPathController = TextEditingController(text: widget.instance.javaPath ?? '');

  @override
  void dispose() {
    _jvmArgsController.dispose();
    _javaPathController.dispose();
    super.dispose();
  }

  void _save() {
    widget.repository.updateInstanceSettings(
      widget.instance.id,
      minMemoryMb: _minMemory.round(),
      maxMemoryMb: _maxMemory.round(),
      jvmArgs: _jvmArgsController.text.trim().isEmpty ? null : _jvmArgsController.text.trim(),
      javaPath: _javaPathController.text.trim().isEmpty ? null : _javaPathController.text.trim(),
    );
  }

  Future<void> _pickIcon() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path == null) return;
    final instanceDir = await McPaths.instanceDir(widget.instance.id);
    final ext = path.split('.').last;
    final destPath = '${instanceDir.path}${Platform.pathSeparator}icon.$ext';
    await File(path).copy(destPath);
    await widget.repository.updateInstanceSettings(widget.instance.id, iconPath: destPath);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LumaCard(
          child: Row(
            children: [
              if (widget.instance.iconPath != null && File(widget.instance.iconPath!).existsSync())
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(widget.instance.iconPath!), width: 48, height: 48, fit: BoxFit.cover),
                )
              else
                LumaIconBadge(icon: Icons.videogame_asset_rounded, color: luma.accent, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Text(t.mcLauncherInstanceIcon,
                    style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700)),
              ),
              LumaGhostButton(label: t.converterChange, icon: Icons.image_outlined, onTap: _pickIcon),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LumaCard(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.mcLauncherMemory, style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700)),
          Text(
            t.mcLauncherMemoryRange(_minMemory.round(), _maxMemory.round()),
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
          RangeSlider(
            values: RangeValues(_minMemory, _maxMemory),
            min: 512,
            max: 16384,
            divisions: 62,
            labels: RangeLabels('${_minMemory.round()}', '${_maxMemory.round()}'),
            onChanged: (v) => setState(() {
              _minMemory = v.start;
              _maxMemory = v.end;
            }),
            onChangeEnd: (_) => _save(),
          ),
          const SizedBox(height: 12),
          Text(t.mcLauncherJavaOverride, style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            controller: _javaPathController,
            decoration: InputDecoration(hintText: t.mcLauncherJavaOverrideHint),
            onChanged: (_) => _save(),
          ),
          const SizedBox(height: 12),
          Text(t.mcLauncherJvmArgs, style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            controller: _jvmArgsController,
            decoration: InputDecoration(hintText: t.mcLauncherJvmArgsHint),
            onChanged: (_) => _save(),
          ),
        ],
          ),
        ),
      ],
    );
  }
}
