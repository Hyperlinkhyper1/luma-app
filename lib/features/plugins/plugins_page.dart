import 'package:flutter/material.dart';

import '../../app/update/app_version.dart';
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
        final installedById = {
          for (final p in installedSnap.data ?? const <InstalledPluginRecord>[])
            p.pluginId: p,
        };

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
                      record: installedById[detailEntry.id],
                      repo: repo,
                      service: _service,
                      onOpen: () => widget.onOpenPlugin(detailEntry.id),
                      onBack: () => setState(() => _detailEntry = null),
                    )
                  : _buildList(
                      context,
                      plugins: plugins,
                      allTags: allTags,
                      installedById: installedById,
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
    required Map<String, InstalledPluginRecord> installedById,
    required PluginRepository repo,
  }) {
    // A single scrollable (instead of a pinned header Column next to a
    // separately-scrolling ListView) so the search/filter controls scroll
    // away with the tiles rather than clipping them behind a static bar.
    return CustomScrollView(
      key: const ValueKey('list'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SearchField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 12),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _SortDropdown(
                      value: _sort,
                      onChanged: (v) => setState(() => _sort = v),
                    ),
                    _PriceFilterPills(
                      value: _priceFilter,
                      onChanged: (v) => setState(() => _priceFilter = v),
                    ),
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // A full Wrap of every category tag can run to 5-6
                      // rows on a phone-width screen, burying the actual
                      // plugin list below the fold. Below this width, show
                      // the tags as a single horizontally-scrolling row
                      // instead so filters stay reachable without the
                      // clutter.
                      final compact = constraints.maxWidth < 640;
                      final chips = [
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
                      ];
                      if (!compact) {
                        return Wrap(spacing: 8, runSpacing: 8, children: chips);
                      }
                      return SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: chips.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, i) => chips[i],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        if (plugins.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: LumaEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No plugins match your filters',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            sliver: SliverList.separated(
              itemCount: plugins.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final entry = plugins[i];
                return _PluginTile(
                  entry: entry,
                  record: installedById[entry.id],
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
    required this.record,
    required this.repo,
    required this.onOpen,
    required this.onOpenDetail,
  });

  final PluginCatalogEntry entry;

  /// Non-null when the plugin is installed on this device; carries the
  /// installed version so the tile can offer a per-plugin update.
  final InstalledPluginRecord? record;
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
  bool _actionBusy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final entry = widget.entry;
    final record = widget.record;
    final installed = record != null;
    final hasUpdate =
        installed && AppVersion.compare(entry.version, record.version) > 0;

    final openButton = LumaGhostButton(
      label: 'Open',
      icon: Icons.open_in_new_rounded,
      onTap: widget.onOpen,
    );

    // Present while the plugin needs downloading or updating, and kept
    // mounted while its animation runs even after the install record lands.
    final actionButton = (!installed || hasUpdate || _actionBusy)
        ? _PluginActionButton(
            entry: entry,
            repo: widget.repo,
            isUpdate: installed,
            onError: (e) {
              if (mounted) setState(() => _error = e);
            },
            onBusyChanged: (b) {
              if (mounted) setState(() => _actionBusy = b);
            },
          )
        : null;

    final deleteButton = Tooltip(
      message: 'Remove plugin',
      child: IconButton(
        icon: Icon(
          Icons.delete_outline_rounded,
          color: luma.textMuted,
          size: 20,
        ),
        onPressed: () => widget.repo.uninstall(entry.id),
      ),
    );

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              // A fixed 64px icon + a fixed 152px button leaves almost no
              // room for the name/description on a phone-width card, so
              // below this width the action row drops beneath the text
              // instead of squeezing it.
              final narrow = constraints.maxWidth < 420;

              final header = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LumaIconBadge(
                    icon: pluginIconFor(entry.icon),
                    color: luma.accent,
                    size: narrow ? 48 : 64,
                  ),
                  SizedBox(width: narrow ? 14 : 20),
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
                            if (hasUpdate)
                              _CategoryChip(
                                label: 'Update available',
                                luma: luma,
                              ),
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
                  if (!narrow) ...[
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 152,
                      child: actionButton == null
                          ? openButton
                          : (installed && !_actionBusy
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      actionButton,
                                      const SizedBox(height: 8),
                                      openButton,
                                    ],
                                  )
                                : actionButton),
                    ),
                    if (installed) ...[const SizedBox(width: 8), deleteButton],
                  ],
                ],
              );

              if (!narrow) return header;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: actionButton ?? openButton),
                      if (actionButton != null &&
                          installed &&
                          !_actionBusy) ...[
                        const SizedBox(width: 8),
                        Expanded(child: openButton),
                      ],
                      if (installed) ...[
                        const SizedBox(width: 8),
                        deleteButton,
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

enum _ActionPhase { idle, busy, done }

/// The Download / Update button on a plugin tile and detail page.
///
/// Runs the actual install/update, but always holds an animated in-progress
/// state on screen for at least 3 seconds (even when the network round trip
/// is faster) so the action reads as deliberate work, then flashes a success
/// check before settling. While it runs, [onBusyChanged] lets the parent keep
/// this button mounted even after the installed record has already landed.
class _PluginActionButton extends StatefulWidget {
  const _PluginActionButton({
    required this.entry,
    required this.repo,
    required this.isUpdate,
    required this.onError,
    required this.onBusyChanged,
  });

  final PluginCatalogEntry entry;
  final PluginRepository repo;

  /// True when the plugin is already installed, making this an update.
  final bool isUpdate;
  final ValueChanged<String?> onError;
  final ValueChanged<bool> onBusyChanged;

  @override
  State<_PluginActionButton> createState() => _PluginActionButtonState();
}

class _PluginActionButtonState extends State<_PluginActionButton>
    with SingleTickerProviderStateMixin {
  static const _minBusyTime = Duration(seconds: 3);

  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  _ActionPhase _phase = _ActionPhase.idle;
  bool _hovering = false;

  // Latched when a run starts so the label doesn't flip from "Downloading"
  // to "Updating" mid-animation once the installed record lands.
  late bool _runIsUpdate = widget.isUpdate;

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_phase != _ActionPhase.idle) return;
    widget.onError(null);
    widget.onBusyChanged(true);
    setState(() {
      _runIsUpdate = widget.isUpdate;
      _phase = _ActionPhase.busy;
    });
    _loop.repeat();
    try {
      await Future.wait([
        widget.repo.install(widget.entry),
        Future<void>.delayed(_minBusyTime),
      ]);
      if (mounted) {
        _loop.stop();
        setState(() => _phase = _ActionPhase.done);
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
    } catch (e) {
      widget.onError('$e');
    } finally {
      _loop.stop();
      if (mounted) setState(() => _phase = _ActionPhase.idle);
      widget.onBusyChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final idle = _phase == _ActionPhase.idle;
    final isUpdate = idle ? widget.isUpdate : _runIsUpdate;

    final textStyle = TextStyle(
      color: luma.onAccent,
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
    );

    final Widget content = switch (_phase) {
      _ActionPhase.idle => Row(
        key: ValueKey('idle-$isUpdate'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUpdate ? Icons.autorenew_rounded : Icons.download_rounded,
            color: luma.onAccent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(isUpdate ? 'Update' : 'Download', style: textStyle),
        ],
      ),
      _ActionPhase.busy => Row(
        key: const ValueKey('busy'),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isUpdate)
            RotationTransition(
              turns: _loop,
              child: Icon(Icons.sync_rounded, color: luma.onAccent, size: 17),
            )
          else
            _DownloadingIcon(loop: _loop, color: luma.onAccent),
          const SizedBox(width: 8),
          Text(isUpdate ? 'Updating…' : 'Downloading…', style: textStyle),
        ],
      ),
      _ActionPhase.done => Row(
        key: const ValueKey('done'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: luma.onAccent, size: 18),
          const SizedBox(width: 8),
          Text(isUpdate ? 'Updated' : 'Installed', style: textStyle),
        ],
      ),
    };

    return MouseRegion(
      cursor: idle ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: idle ? _run : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: idle && _hovering ? luma.accentHover : luma.accent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween(begin: 0.85, end: 1.0).animate(anim),
                  child: child,
                ),
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// A download arrow that repeatedly drops toward a baseline "tray" and fades
/// out, driven by the button's looping controller.
class _DownloadingIcon extends StatelessWidget {
  const _DownloadingIcon({required this.loop, required this.color});

  final Animation<double> loop;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          ClipRect(
            child: AnimatedBuilder(
              animation: loop,
              builder: (context, _) {
                final t = loop.value;
                final opacity = t < 0.2
                    ? t / 0.2
                    : (t > 0.75 ? ((1 - t) / 0.25).clamp(0.0, 1.0) : 1.0);
                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, -9 + 12 * Curves.easeIn.transform(t)),
                    child: Icon(
                      Icons.arrow_downward_rounded,
                      size: 14,
                      color: color,
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            width: 12,
            height: 2,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
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
    required this.record,
    required this.repo,
    required this.service,
    required this.onOpen,
    required this.onBack,
  });

  final PluginCatalogEntry entry;

  /// Non-null when the plugin is installed; carries the installed version so
  /// the detail page can offer a per-plugin update.
  final InstalledPluginRecord? record;
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
  bool _actionBusy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final entry = widget.entry;
    final record = widget.record;
    final installed = record != null;
    final hasUpdate =
        installed && AppVersion.compare(entry.version, record.version) > 0;

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
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 420;
                  final openButton = LumaGhostButton(
                    label: 'Open',
                    icon: Icons.open_in_new_rounded,
                    onTap: widget.onOpen,
                  );
                  final installButton = (!installed || hasUpdate || _actionBusy)
                      ? _PluginActionButton(
                          entry: entry,
                          repo: widget.repo,
                          isUpdate: installed,
                          onError: (e) {
                            if (mounted) setState(() => _error = e);
                          },
                          onBusyChanged: (b) {
                            if (mounted) setState(() => _actionBusy = b);
                          },
                        )
                      : null;
                  final actionButton = installButton == null
                      ? openButton
                      : (installed && !_actionBusy
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  installButton,
                                  const SizedBox(height: 8),
                                  openButton,
                                ],
                              )
                            : installButton);

                  final header = Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LumaIconBadge(
                        icon: pluginIconFor(entry.icon),
                        color: luma.accent,
                        size: narrow ? 56 : 72,
                      ),
                      SizedBox(width: narrow ? 14 : 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.name,
                              style: TextStyle(
                                color: luma.textPrimary,
                                fontSize: narrow ? 20 : 24,
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
                                  label: hasUpdate
                                      ? 'v${record.version} → v${entry.version}'
                                      : 'v${entry.version}',
                                  luma: luma,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!narrow) ...[
                        const SizedBox(width: 20),
                        SizedBox(width: 160, child: actionButton),
                      ],
                    ],
                  );

                  if (!narrow) return header;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      const SizedBox(height: 14),
                      actionButton,
                    ],
                  );
                },
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
