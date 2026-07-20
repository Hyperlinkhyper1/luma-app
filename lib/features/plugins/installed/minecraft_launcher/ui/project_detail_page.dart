import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/minecraft_launcher_database.dart';
import '../logic/mod_dependency_resolver.dart';
import '../logic/mod_installer.dart';
import '../logic/modrinth_api_client.dart';
import '../minecraft_launcher_repository.dart';

class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({
    super.key,
    required this.projectId,
    required this.instance,
    required this.kind,
    required this.repository,
  });

  final String projectId;
  final McInstance instance;
  final String kind;
  final MinecraftLauncherRepository repository;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  ModrinthProject? _project;
  List<ModrinthVersion> _versions = const [];
  String? _error;
  final _installing = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final loaderFilter = widget.kind == 'mod' && widget.instance.loader != 'vanilla'
          ? widget.instance.loader
          : null;
      final project = await ModrinthApiClient.instance.getProject(widget.projectId);
      final versions = await ModrinthApiClient.instance.getProjectVersions(
        widget.projectId,
        gameVersion: widget.instance.versionId,
        loader: loaderFilter,
      );
      if (!mounted) return;
      setState(() {
        _project = project;
        _versions = versions;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _install(ModrinthVersion version) async {
    final project = _project;
    if (project == null) return;
    setState(() => _installing.add(version.id));
    try {
      final alreadyInstalled = <String>{};
      final deps = await ModDependencyResolver.resolveRequired(
        rootVersion: version,
        gameVersion: widget.instance.versionId,
        loader: widget.instance.loader,
        alreadyInstalledProjectIds: alreadyInstalled,
      );

      if (deps.isNotEmpty && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Install required dependencies?'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${project.title} needs these to work:'),
                  const SizedBox(height: 8),
                  for (final d in deps) Text('• ${d.project.title}'),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Install all')),
            ],
          ),
        );
        if (proceed != true) {
          setState(() => _installing.remove(version.id));
          return;
        }
      }

      await ModInstaller.installVersion(
        repository: widget.repository,
        instance: widget.instance,
        project: project,
        version: version,
        kind: widget.kind,
      );
      for (final dep in deps) {
        await ModInstaller.installVersion(
          repository: widget.repository,
          instance: widget.instance,
          project: dep.project,
          version: dep.version,
          kind: widget.kind,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Installed ${project.title}.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _installing.remove(version.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        title: Text(_project?.title ?? 'Loading…'),
        elevation: 0,
      ),
      body: _error != null
          ? Center(
              child: LumaEmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load this project',
                subtitle: _error,
              ),
            )
          : _project == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
              : _buildBody(luma),
    );
  }

  Widget _buildBody(LumaPalette luma) {
    final project = _project!;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (project.iconUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(project.iconUrl!, width: 64, height: 64, fit: BoxFit.cover),
              )
            else
              LumaIconBadge(icon: Icons.extension_rounded, color: luma.accent, size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.title,
                      style: TextStyle(color: luma.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(project.description, style: TextStyle(color: luma.textMuted, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    '${project.downloads} downloads · ${project.followers} followers',
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Versions for ${widget.instance.versionId}',
            style: TextStyle(color: luma.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (_versions.isEmpty)
          Text(
            'No compatible version found for this instance.',
            style: TextStyle(color: luma.textMuted, fontSize: 13),
          )
        else
          for (final v in _versions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LumaCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.name.isEmpty ? v.versionNumber : v.name,
                              style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w600)),
                          Text(v.loaders.join(', '),
                              style: TextStyle(color: luma.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    LumaPrimaryButton(
                      label: 'Install',
                      icon: Icons.download_rounded,
                      loading: _installing.contains(v.id),
                      onTap: () => _install(v),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
