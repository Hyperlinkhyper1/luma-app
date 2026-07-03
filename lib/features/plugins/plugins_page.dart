import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../theme/luma_theme.dart';
import 'plugin_catalog_service.dart';
import 'plugin_icons.dart';
import 'plugin_repository.dart';
import 'plugin_scope.dart';

enum _SortMode { relevance, nameAsc, nameDesc }

enum _PriceFilter { all, free, paid }

/// The Plugins marketplace: a Modrinth-style browser fetched live from the
/// luma-app GitHub repo's `plugins/` folder. Nothing here is bundled in the
/// app — a plugin only becomes usable (and gets its own nav rail icon) once
/// the user downloads it.
class PluginsPage extends StatefulWidget {
  const PluginsPage({super.key, required this.onOpenPlugin});

  /// Called with a plugin id when the user opens an already-installed plugin.
  final ValueChanged<String> onOpenPlugin;

  @override
  State<PluginsPage> createState() => _PluginsPageState();
}

class _PluginsPageState extends State<PluginsPage> {
  final _service = PluginCatalogService();
  late Future<List<PluginCatalogEntry>> _catalog = _service.fetchCatalog();

  final _searchController = TextEditingController();
  String _query = '';
  _SortMode _sort = _SortMode.relevance;
  _PriceFilter _priceFilter = _PriceFilter.all;
  final Set<String> _selectedTags = {};

  // Non-null while the detail page for a plugin is open, taking priority
  // over the marketplace list.
  PluginCatalogEntry? _detailEntry;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PluginCatalogEntry> _applyFilters(List<PluginCatalogEntry> plugins) {
    var result = plugins.where((entry) {
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final matches =
            entry.name.toLowerCase().contains(q) ||
            entry.description.toLowerCase().contains(q) ||
            entry.tags.any((t) => t.toLowerCase().contains(q));
        if (!matches) return false;
      }
      if (_selectedTags.isNotEmpty &&
          !_selectedTags.any((t) => entry.tags.contains(t))) {
        return false;
      }
      if (_priceFilter == _PriceFilter.free && !entry.free) return false;
      if (_priceFilter == _PriceFilter.paid && entry.free) return false;
      return true;
    }).toList();

    switch (_sort) {
      case _SortMode.relevance:
        break;
      case _SortMode.nameAsc:
        result.sort((a, b) => a.name.compareTo(b.name));
      case _SortMode.nameDesc:
        result.sort((a, b) => b.name.compareTo(a.name));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final repo = PluginScope.of(context);

    return StreamBuilder<List<InstalledPluginRecord>>(
      stream: repo.watchInstalled(),
      builder: (context, installedSnap) {
        final installedIds = (installedSnap.data ?? const [])
            .map((p) => p.pluginId)
            .toSet();

        return FutureBuilder<List<PluginCatalogEntry>>(
          future: _catalog,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              );
            }
            if (snap.hasError) {
              return LumaEmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load the plugin catalog',
                subtitle: '${snap.error}',
                action: LumaGhostButton(
                  label: 'Retry',
                  icon: Icons.refresh_rounded,
                  onTap: () =>
                      setState(() => _catalog = _service.fetchCatalog()),
                ),
              );
            }
            final allPlugins = snap.data ?? const [];
            if (allPlugins.isEmpty) {
              return const LumaEmptyState(
                icon: Icons.extension_rounded,
                title: 'No plugins available yet',
              );
            }

            final allTags = <String>{
              for (final p in allPlugins) ...p.tags,
            }.toList()..sort();

            final plugins = _applyFilters(allPlugins);
            final detailEntry = _detailEntry;

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: detailEntry != null
                  ? _PluginDetailView(
                      key: ValueKey('detail-${detailEntry.id}'),
                      entry: detailEntry,
                      installed: installedIds.contains(detailEntry.id),
                      repo: repo,
                      service: _service,
                      onOpen: () => widget.onOpenPlugin(detailEntry.id),
                      onBack: () => setState(() => _detailEntry = null),
                    )
                  : _buildList(
                      context,
                      plugins: plugins,
                      allTags: allTags,
                      installedIds: installedIds,
                      repo: repo,
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildList(
    BuildContext context, {
    required List<PluginCatalogEntry> plugins,
    required List<String> allTags,
    required Set<String> installedIds,
    required PluginRepository repo,
  }) {
    return Column(
      key: const ValueKey('list'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SearchField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _SortDropdown(
                    value: _sort,
                    onChanged: (v) => setState(() => _sort = v),
                  ),
                  const SizedBox(width: 10),
                  _PriceFilterPills(
                    value: _priceFilter,
                    onChanged: (v) => setState(() => _priceFilter = v),
                  ),
                  const Spacer(),
                  Text(
                    '${plugins.length} plugin${plugins.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: context.luma.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (allTags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in allTags)
                      _TagFilterChip(
                        label: tag,
                        selected: _selectedTags.contains(tag),
                        onTap: () => setState(() {
                          if (!_selectedTags.remove(tag)) {
                            _selectedTags.add(tag);
                          }
                        }),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: plugins.isEmpty
              ? const LumaEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No plugins match your filters',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  itemCount: plugins.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final entry = plugins[i];
                    return _PluginTile(
                      entry: entry,
                      installed: installedIds.contains(entry.id),
                      repo: repo,
                      onOpen: () => widget.onOpenPlugin(entry.id),
                      onOpenDetail: () => setState(() => _detailEntry = entry),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 19, color: luma.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(color: luma.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search plugins...',
                hintStyle: TextStyle(color: luma.textMuted, fontSize: 14),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: Icon(Icons.close_rounded, size: 17, color: luma.textMuted),
            ),
        ],
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.value, required this.onChanged});

  final _SortMode value;
  final ValueChanged<_SortMode> onChanged;

  static const _labels = {
    _SortMode.relevance: 'Relevance',
    _SortMode.nameAsc: 'Name (A-Z)',
    _SortMode.nameDesc: 'Name (Z-A)',
  };

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_SortMode>(
          value: value,
          isDense: true,
          icon: Icon(
            Icons.expand_more_rounded,
            size: 18,
            color: luma.textMuted,
          ),
          dropdownColor: luma.surface,
          borderRadius: BorderRadius.circular(10),
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          items: [
            for (final entry in _labels.entries)
              DropdownMenuItem(
                value: entry.key,
                child: Text('Sort by: ${entry.value}'),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _PriceFilterPills extends StatelessWidget {
  const _PriceFilterPills({required this.value, required this.onChanged});

  final _PriceFilter value;
  final ValueChanged<_PriceFilter> onChanged;

  static const _options = [
    (_PriceFilter.all, 'All'),
    (_PriceFilter.free, 'Free'),
    (_PriceFilter.paid, 'Paid'),
  ];

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (mode, label) in _options)
            GestureDetector(
              onTap: () => onChanged(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                height: 32,
                decoration: BoxDecoration(
                  color: value == mode ? luma.accentSubtle : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: value == mode ? luma.accent : luma.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TagFilterChip extends StatefulWidget {
  const _TagFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TagFilterChip> createState() => _TagFilterChipState();
}

class _TagFilterChipState extends State<_TagFilterChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final selected = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? luma.accentSubtle
                : (_hovering ? luma.surfaceHover : luma.surface),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? luma.accent : luma.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 14, color: luma.accent),
                const SizedBox(width: 4),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: selected ? luma.accent : luma.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PluginTile extends StatefulWidget {
  const _PluginTile({
    required this.entry,
    required this.installed,
    required this.repo,
    required this.onOpen,
    required this.onOpenDetail,
  });

  final PluginCatalogEntry entry;
  final bool installed;
  final PluginRepository repo;
  final VoidCallback onOpen;

  /// Opens the plugin's full detail page (tapping anywhere on the tile
  /// except the action buttons).
  final VoidCallback onOpenDetail;

  @override
  State<_PluginTile> createState() => _PluginTileState();
}

class _PluginTileState extends State<_PluginTile> {
  bool _hovering = false;
  bool _installing = false;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _installing = true;
      _error = null;
    });
    try {
      await widget.repo.install(widget.entry);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final entry = widget.entry;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpenDetail,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: luma.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hovering
                  ? luma.accent.withValues(alpha: 0.5)
                  : luma.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LumaIconBadge(
                icon: pluginIconFor(entry.icon),
                color: luma.accent,
                size: 64,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        for (final tag in entry.tags)
                          _CategoryChip(label: tag, luma: luma),
                        if (!entry.free)
                          _CategoryChip(label: 'Paid', luma: luma),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _error!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: luma.danger, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 140,
                child: widget.installed
                    ? LumaGhostButton(
                        label: 'Open',
                        icon: Icons.open_in_new_rounded,
                        onTap: widget.onOpen,
                      )
                    : LumaPrimaryButton(
                        label: 'Download',
                        icon: Icons.download_rounded,
                        loading: _installing,
                        onTap: _install,
                      ),
              ),
              if (widget.installed) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Remove plugin',
                  child: IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: luma.textMuted,
                      size: 20,
                    ),
                    onPressed: () => widget.repo.uninstall(entry.id),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.luma});
  final String label;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: luma.accentSubtle,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: luma.accent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PLUGIN DETAIL PAGE
// ═══════════════════════════════════════════════════════════════════════════

/// The full write-up for a plugin: long-form details and screenshots, both
/// sourced from that plugin's `manifest.json` (fetched fresh here so authors
/// can add to it any time without shipping a new build).
class _PluginDetailView extends StatefulWidget {
  const _PluginDetailView({
    super.key,
    required this.entry,
    required this.installed,
    required this.repo,
    required this.service,
    required this.onOpen,
    required this.onBack,
  });

  final PluginCatalogEntry entry;
  final bool installed;
  final PluginRepository repo;
  final PluginCatalogService service;
  final VoidCallback onOpen;
  final VoidCallback onBack;

  @override
  State<_PluginDetailView> createState() => _PluginDetailViewState();
}

class _PluginDetailViewState extends State<_PluginDetailView> {
  late final Future<PluginManifest> _manifest = widget.service.fetchManifest(
    widget.entry.id,
  );
  bool _installing = false;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _installing = true;
      _error = null;
    });
    try {
      await widget.repo.install(widget.entry);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final entry = widget.entry;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: widget.onBack,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back_rounded,
                        color: luma.textMuted,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Back',
                        style: TextStyle(color: luma.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LumaIconBadge(
                    icon: pluginIconFor(entry.icon),
                    color: luma.accent,
                    size: 72,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in entry.tags)
                              _CategoryChip(label: tag, luma: luma),
                            if (!entry.free)
                              _CategoryChip(label: 'Paid', luma: luma),
                            _CategoryChip(
                              label: 'v${entry.version}',
                              luma: luma,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 160,
                    child: widget.installed
                        ? LumaGhostButton(
                            label: 'Open',
                            icon: Icons.open_in_new_rounded,
                            onTap: widget.onOpen,
                          )
                        : LumaPrimaryButton(
                            label: 'Download',
                            icon: Icons.download_rounded,
                            loading: _installing,
                            onTap: _install,
                          ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: luma.danger, fontSize: 12),
                ),
              ],
              const SizedBox(height: 28),
              FutureBuilder<PluginManifest>(
                future: _manifest,
                builder: (context, snap) {
                  final details = snap.data?.details ?? entry.description;
                  final screenshots =
                      snap.data?.screenshots ?? const <String>[];
                  final paragraphs = details
                      .split(RegExp(r'\n\s*\n'))
                      .where((p) => p.trim().isNotEmpty)
                      .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'About',
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final p in paragraphs) ...[
                        Text(
                          p.trim(),
                          style: TextStyle(
                            color: luma.textSecondary,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (snap.connectionState != ConnectionState.done)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: luma.textMuted,
                            ),
                          ),
                        ),
                      if (screenshots.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Screenshots',
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 220,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: screenshots.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, i) => _Screenshot(
                              url: PluginCatalogService.screenshotUrl(
                                entry.id,
                                screenshots[i],
                              ),
                              luma: luma,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Screenshot extends StatelessWidget {
  const _Screenshot({required this.url, required this.luma});
  final String url;
  final LumaPalette luma;

  static const _size = Size(340, 220);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            width: _size.width,
            height: _size.height,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: _size.width,
                height: _size.height,
                color: luma.background,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (context, error, stack) => Container(
              width: _size.width,
              height: _size.height,
              color: luma.background,
              alignment: Alignment.center,
              child: Icon(Icons.broken_image_outlined, color: luma.textMuted),
            ),
          ),
        ),
      ),
    );
  }
}
