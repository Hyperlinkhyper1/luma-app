import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/minecraft_launcher_database.dart';
import '../logic/mod_install_flow.dart';
import '../logic/mod_installer.dart';
import '../logic/content_api.dart';
import '../logic/curseforge_api_client.dart';
import '../logic/modrinth_api_client.dart';
import '../minecraft_launcher_repository.dart';
import 'curseforge_key_dialog.dart';
import 'hover_sync_scroll.dart';
import 'modrinth_ui.dart';
import 'project_detail_page.dart';

/// Full-screen Modrinth or CurseForge search for one instance: pick a
/// source and a content kind (mods, resource packs, shader packs), search,
/// and either install straight from a result tile or open the project for
/// its description, screenshots and version list.
class BrowseContentPage extends StatefulWidget {
  const BrowseContentPage({super.key, required this.instance, required this.repository});
  final McInstance instance;
  final MinecraftLauncherRepository repository;

  @override
  State<BrowseContentPage> createState() => _BrowseContentPageState();
}

class _BrowseContentPageState extends State<BrowseContentPage> {
  static const _pageSize = 20;

  ContentSource _source = ContentSource.modrinth;
  String _kind = 'mod';
  String _sort = 'relevance';
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  List<ModrinthSearchHit> _hits = const [];
  int _totalHits = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  /// CurseForge was picked but no API key is stored yet.
  bool _needsKey = false;

  Set<String> _installedProjectIds = {};
  final _installing = <String>{};

  /// Bumped on every new search so a slow response from an abandoned query
  /// can't overwrite the results of the current one.
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _refreshInstalled();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || _loadingMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) _loadMore();
  }

  Future<void> _refreshInstalled() async {
    final ids = await ModInstallFlow.installedProjectIds(
      widget.repository,
      widget.instance.id,
    );
    if (mounted) setState(() => _installedProjectIds = ids);
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    final token = ++_searchToken;
    setState(() {
      _loading = true;
      _error = null;
      _needsKey = false;
    });
    try {
      final result = await _fetch(offset: 0);
      if (!mounted || token != _searchToken) return;
      setState(() {
        _hits = result.hits;
        _totalHits = result.totalHits;
        _loading = false;
      });
    } on CurseForgeKeyMissingException {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _needsKey = true;
        _hits = const [];
        _totalHits = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _setSource(ContentSource source) {
    if (source == _source) return;
    setState(() => _source = source);
    _search();
  }

  Future<void> _addCurseForgeKey() async {
    if (await showCurseForgeKeyDialog(context)) _search();
  }

  Future<void> _loadMore() async {
    if (_hits.length >= _totalHits) return;
    final token = _searchToken;
    setState(() => _loadingMore = true);
    try {
      final result = await _fetch(offset: _hits.length);
      if (!mounted || token != _searchToken) return;
      setState(() {
        _hits = [..._hits, ...result.hits];
        _totalHits = result.totalHits;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || token != _searchToken) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<ModrinthSearchResult> _fetch({required int offset}) {
    final loaderFilter =
        widget.instance.loader != 'vanilla' ? widget.instance.loader : null;
    return ContentApi.search(
      source: _source,
      query: _searchController.text.trim(),
      projectType: _kind,
      gameVersion: widget.instance.versionId,
      loader: loaderFilter,
      index: _sort,
      limit: _pageSize,
      offset: offset,
    );
  }

  Future<void> _quickInstall(ModrinthSearchHit hit) async {
    setState(() => _installing.add(hit.projectId));
    await ModInstallFlow.installLatest(
      context: context,
      repository: widget.repository,
      instance: widget.instance,
      projectId: hit.projectId,
      kind: _kind,
    );
    if (!mounted) return;
    setState(() => _installing.remove(hit.projectId));
    await _refreshInstalled();
  }

  Future<void> _openProject(ModrinthSearchHit hit) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProjectDetailPage(
        projectId: hit.projectId,
        instance: widget.instance,
        kind: _kind,
        repository: widget.repository,
      ),
    ));
    // The detail page can install things, so the "already installed" ticks
    // on these tiles need a refresh on the way back.
    await _refreshInstalled();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        title: Text(t.minecraftLauncherBrowseFor(widget.instance.name)),
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: _controls(luma),
          ),
          const SizedBox(height: 14),
          Expanded(child: _buildResults(luma)),
        ],
      ),
    );
  }

  // ── Controls ──────────────────────────────────────────────────────────

  Widget _controls(LumaPalette luma) {
    final t = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _sourceToggle(luma),
            const SizedBox(width: 4),
            for (final entry in modrinthProjectTypes.entries)
              _kindChip(luma, entry.key, modrinthProjectTypeLabel(entry.key)),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final field = TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: t.minecraftLauncherSearchKindHint(modrinthProjectTypeLabel(_kind).toLowerCase()),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _search();
                        },
                      ),
              ),
              onChanged: (value) {
                setState(() {});
                _onQueryChanged(value);
              },
              onSubmitted: (_) => _search(),
            );
            if (constraints.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [field, const SizedBox(height: 10), _sortMenu(luma)],
              );
            }
            return Row(
              children: [
                Expanded(child: field),
                const SizedBox(width: 12),
                _sortMenu(luma),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        _contextLine(luma),
      ],
    );
  }

  /// Modrinth / CurseForge switch, drawn as one segmented pill so it reads
  /// as "where from" rather than as another content kind.
  Widget _sourceToggle(LumaPalette luma) {
    final radius = BorderRadius.circular(context.lumaDecor.pillRadius);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: radius,
        border: Border.all(color: luma.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final source in ContentSource.values)
            InkWell(
              onTap: () => _setSource(source),
              borderRadius: radius,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: source == _source ? luma.accent : Colors.transparent,
                  borderRadius: radius,
                ),
                child: Text(
                  source.label,
                  style: TextStyle(
                    color: source == _source ? luma.onAccent : luma.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _kindChip(LumaPalette luma, String kind, String label) {
    final selected = _kind == kind;
    return InkWell(
      onTap: () {
        if (selected) return;
        setState(() => _kind = kind);
        _search();
      },
      borderRadius: BorderRadius.circular(context.lumaDecor.pillRadius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? luma.accentSubtle : luma.surface,
          borderRadius: BorderRadius.circular(context.lumaDecor.pillRadius),
          border: Border.all(color: selected ? luma.accent : luma.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              contentKindIcon(kind),
              size: 16,
              color: selected ? luma.accent : luma.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? luma.accent : luma.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sortMenu(LumaPalette luma) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: context.lumaDecor.buttonBorderRadius,
        border: Border.all(color: luma.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sort,
          isDense: true,
          borderRadius: context.lumaDecor.cardBorderRadius,
          dropdownColor: luma.surface,
          icon: Icon(Icons.expand_more_rounded, color: luma.textMuted, size: 18),
          style: TextStyle(color: luma.textSecondary, fontSize: 13),
          items: [
            for (final entry in modrinthSortIndexes.entries)
              DropdownMenuItem(
                value: entry.key,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sort_rounded, size: 15, color: luma.textMuted),
                    const SizedBox(width: 8),
                    Text(modrinthSortLabel(entry.key)),
                  ],
                ),
              ),
          ],
          onChanged: (value) {
            if (value == null || value == _sort) return;
            setState(() => _sort = value);
            _search();
          },
        ),
      ),
    );
  }

  /// Says out loud what the result list is already filtered to, so an empty
  /// list reads as "nothing fits this instance" rather than "search broken".
  Widget _contextLine(LumaPalette luma) {
    final t = L.of(context);
    final loader = widget.instance.loader;
    return Row(
      children: [
        Icon(Icons.filter_alt_rounded, size: 14, color: luma.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            loader == 'vanilla'
                ? t.minecraftLauncherCompatibleWith(widget.instance.versionId)
                : t.minecraftLauncherCompatibleWithLoader(
                    widget.instance.versionId,
                    prettyTag(loader),
                  ),
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
        ),
        if (!_loading && _error == null)
          Text(
            _totalHits == 0
                ? ''
                : t.minecraftLauncherResultCount(
                    _totalHits,
                    formatCompactCount(_totalHits),
                  ),
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
      ],
    );
  }

  // ── Results ───────────────────────────────────────────────────────────

  Widget _buildResults(LumaPalette luma) {
    final t = L.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    if (_needsKey) {
      return LumaEmptyState(
        icon: Icons.key_rounded,
        title: t.minecraftLauncherCurseForgeNeedsKey,
        subtitle: t.minecraftLauncherCurseForgeNeedsKeySubtitle,
        action: LumaPrimaryButton(
          label: t.minecraftLauncherAddApiKey,
          icon: Icons.key_rounded,
          onTap: _addCurseForgeKey,
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: LumaEmptyState(
          icon: Icons.cloud_off_rounded,
          title: t.minecraftLauncherSearchFailed,
          subtitle: _error,
          action: _source == ContentSource.curseforge
              ? LumaGhostButton(
                  label: t.minecraftLauncherChangeApiKey,
                  icon: Icons.key_rounded,
                  onTap: _addCurseForgeKey,
                )
              : null,
        ),
      );
    }
    if (_hits.isEmpty) {
      return LumaEmptyState(
        icon: Icons.search_off_rounded,
        title: t.minecraftLauncherNoResults,
        subtitle: t.minecraftLauncherNoResultsSubtitle,
      );
    }
    return HoverSyncScroll(
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        itemCount: _hits.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i == _hits.length) return _footer(luma);
          final hit = _hits[i];
          return ModrinthProjectTile(
            hit: hit,
            onOpen: () => _openProject(hit),
            onInstall: () => _quickInstall(hit),
            installed: _installedProjectIds.contains(hit.projectId),
            installing: _installing.contains(hit.projectId),
            installTooltip: t.minecraftLauncherInstallInto(widget.instance.name),
          );
        },
      ),
    );
  }

  Widget _footer(LumaPalette luma) {
    final t = L.of(context);
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }
    if (_hits.length >= _totalHits) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            t.minecraftLauncherEndOfResults,
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: LumaGhostButton(label: t.minecraftLauncherLoadMore, onTap: _loadMore),
      ),
    );
  }
}
