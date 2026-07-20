import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/minecraft_launcher_database.dart';
import '../logic/modrinth_api_client.dart';
import '../minecraft_launcher_repository.dart';
import '../minecraft_launcher_scope.dart';
import 'instance_detail_page.dart';
import 'project_detail_page.dart';

/// Searches across the user's own instances (client-side, instant) and
/// Modrinth's mod catalog (debounced network search) from one box.
class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<ModrinthSearchHit> _modHits = const [];
  bool _searchingMods = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _modHits = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _searchMods(value.trim()));
  }

  Future<void> _searchMods(String query) async {
    setState(() => _searchingMods = true);
    try {
      final result = await ModrinthApiClient.instance.search(query: query, projectType: 'mod', limit: 15);
      if (!mounted || query != _query.trim()) return;
      setState(() {
        _modHits = result.hits;
        _searchingMods = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searchingMods = false);
    }
  }

  Future<void> _openModHit(ModrinthSearchHit hit, MinecraftLauncherRepository repository) async {
    final instances = await repository.watchInstances().first;
    if (instances.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Create an instance first.')));
      return;
    }
    final instance = instances.length == 1
        ? instances.first
        : await showDialog<McInstance>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text('Install into which instance?'),
              children: [
                for (final i in instances)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, i),
                    child: Text(i.name),
                  ),
              ],
            ),
          );
    if (instance == null || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProjectDetailPage(
        projectId: hit.projectId,
        instance: instance,
        kind: 'mod',
        repository: repository,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final repository = MinecraftLauncherScope.of(context);
    final luma = context.luma;
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search instances and mods…',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          StreamBuilder<List<McInstance>>(
            stream: repository.watchInstances(),
            builder: (context, snapshot) {
              final instances = (snapshot.data ?? const [])
                  .where((i) => _query.isEmpty || i.name.toLowerCase().contains(_query.toLowerCase()))
                  .toList();
              if (instances.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Instances', style: TextStyle(color: luma.textSecondary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (final instance in instances)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LumaCard(
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => InstanceDetailPage(instanceId: instance.id),
                          )),
                          child: Row(
                            children: [
                              LumaIconBadge(icon: Icons.videogame_asset_rounded, color: luma.accent),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(instance.name,
                                        style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700)),
                                    Text(instance.versionId,
                                        style: TextStyle(color: luma.textMuted, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
          if (_query.isNotEmpty) ...[
            Text('Mods', style: TextStyle(color: luma.textSecondary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_searchingMods)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
              )
            else if (_modHits.isEmpty)
              Text('No mods found.', style: TextStyle(color: luma.textMuted, fontSize: 13))
            else
              for (final hit in _modHits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LumaCard(
                    child: InkWell(
                      onTap: () => _openModHit(hit, repository),
                      child: Row(
                        children: [
                          if (hit.iconUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(hit.iconUrl!, width: 36, height: 36, fit: BoxFit.cover),
                            )
                          else
                            LumaIconBadge(icon: Icons.extension_rounded, color: luma.accent, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(hit.title, style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700)),
                                Text(
                                  hit.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
