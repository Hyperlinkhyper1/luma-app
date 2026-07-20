import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/minecraft_launcher_database.dart';
import '../logic/mod_installer.dart';
import '../logic/modrinth_api_client.dart';
import '../minecraft_launcher_repository.dart';
import 'project_detail_page.dart';

/// Full-screen Modrinth search for one instance: pick a content kind (mods,
/// resource packs, shader packs), search, tap through to install a version.
class BrowseContentPage extends StatefulWidget {
  const BrowseContentPage({super.key, required this.instance, required this.repository});
  final McInstance instance;
  final MinecraftLauncherRepository repository;

  @override
  State<BrowseContentPage> createState() => _BrowseContentPageState();
}

class _BrowseContentPageState extends State<BrowseContentPage> {
  String _kind = 'mod';
  final _searchController = TextEditingController();
  List<ModrinthSearchHit> _hits = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loaderFilter = widget.instance.loader != 'vanilla' ? widget.instance.loader : null;
      final result = await ModrinthApiClient.instance.search(
        query: _searchController.text.trim(),
        projectType: _kind,
        gameVersion: widget.instance.versionId,
        loader: loaderFilter,
      );
      if (!mounted) return;
      setState(() {
        _hits = result.hits;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        title: Text('Browse for ${widget.instance.name}'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final entry in modrinthProjectTypes.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _kind == entry.key,
                    onSelected: (_) {
                      setState(() => _kind = entry.key);
                      _search();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(hintText: 'Search…', prefixIcon: Icon(Icons.search_rounded)),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildResults(luma)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(LumaPalette luma) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    if (_error != null) {
      return Center(
        child: LumaEmptyState(icon: Icons.cloud_off_rounded, title: 'Search failed', subtitle: _error),
      );
    }
    if (_hits.isEmpty) {
      return const LumaEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results',
        subtitle: 'Try a different search or content type.',
      );
    }
    return ListView.builder(
      itemCount: _hits.length,
      itemBuilder: (context, i) {
        final hit = _hits[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: LumaCard(
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProjectDetailPage(
                  projectId: hit.projectId,
                  instance: widget.instance,
                  kind: _kind,
                  repository: widget.repository,
                ),
              )),
              child: Row(
                children: [
                  if (hit.iconUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(hit.iconUrl!, width: 48, height: 48, fit: BoxFit.cover),
                    )
                  else
                    LumaIconBadge(icon: Icons.extension_rounded, color: luma.accent),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(hit.title,
                            style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700)),
                        Text(
                          hit.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: luma.textMuted, fontSize: 12),
                        ),
                        Text('${hit.downloads} downloads',
                            style: TextStyle(color: luma.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
