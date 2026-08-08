import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../account/plan.dart';
import '../../../../account/plan_selection_page.dart';
import '../../../../app/widgets.dart';
import '../../../../settings/settings_scope.dart';
import '../../../../theme/luma_theme.dart';
import 'gallery_categories.dart';
import 'gallery_map_page.dart';
import 'gallery_media.dart';
import 'gallery_repository.dart';
import 'gallery_scope.dart';
import 'gallery_smart.dart';
import 'gallery_source.dart';
import 'gallery_tile.dart';
import 'gallery_viewer_page.dart';

/// Everything on this device, in one grid. The tab strip holds the five fixed
/// categories, then a tab per folder the library actually has, then — on Nova
/// — whatever the on-device models have made of the photos.
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  /// Selected tab, held as an id rather than an index: folder tabs come and
  /// go with a rescan, and smart tabs reorder as the models catch up.
  String _selected = GalleryCategoryIds.all;

  bool _started = false;

  /// The pill non-Nova devices see in place of the smart tabs.
  static const _smartTeaserId = 'smart-teaser';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The scope isn't reachable from initState, and the first scan has to
    // wait for it.
    if (_started) return;
    _started = true;
    GalleryScope.of(context).initialise();
  }

  Future<void> _addFolder(GalleryRepository repo) async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Add a folder to the gallery',
    );
    if (path == null) return;
    await repo.addFolder(path);
  }

  void _open(List<GalleryItem> items, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GalleryViewerPage(items: items, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = GalleryScope.of(context);
    final isNova = SettingsScope.of(context).selectedPlanId == 'nova';

    final categories = repo.categories;
    final smartGroups = isNova && repo.status == GalleryStatus.ready
        ? repo.smartGroups()
        : const <GallerySmartGroup>[];

    final tabs = <_Tab>[
      for (final category in categories)
        _Tab(id: category.id, label: category.label, count: category.count),
      for (final group in smartGroups)
        _Tab(
          id: 'smart:${group.id}',
          label: '✦ ${group.label}',
          count: group.count,
          smart: true,
        ),
      if (!isNova && repo.status == GalleryStatus.ready)
        const _Tab(id: _smartTeaserId, label: '✦ Smart', count: 0, smart: true),
    ];

    final selectedIndex = tabs.indexWhere((t) => t.id == _selected);
    final activeIndex = selectedIndex < 0 ? 0 : selectedIndex;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            repository: repo,
            subtitle: _subtitleFor(repo, tabs.isEmpty ? null : tabs[activeIndex]),
            onAddFolder: repo.supportsCustomFolders
                ? () => _addFolder(repo)
                : null,
          ),
          if (tabs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: LumaSegmentedTabs(
                tabs: [for (final tab in tabs) tab.label],
                selectedIndex: activeIndex,
                scrollable: true,
                onSelect: (index) =>
                    setState(() => _selected = tabs[index].id),
              ),
            ),
          if (repo.access == GalleryAccess.limited && repo.canPresentPicker)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _LimitedAccessNote(onSelectMore: repo.presentPicker),
            ),
          if (repo.isAnalysing)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _ProgressNote(
                label: 'Sorting photos into smart categories — '
                    '${repo.analysedCount} done',
              ),
            ),
          Expanded(
            child: _body(
              context,
              repo,
              tabs.isEmpty ? null : tabs[activeIndex],
              smartGroups,
              isNova,
              luma,
            ),
          ),
        ],
      ),
    );
  }

  String? _subtitleFor(GalleryRepository repo, _Tab? tab) {
    if (repo.status == GalleryStatus.scanning) return 'Reading your library…';
    if (repo.status != GalleryStatus.ready) return null;
    if (tab == null) return null;
    final count = tab.id == _smartTeaserId ? repo.items.length : tab.count;
    final noun = count == 1 ? 'item' : 'items';
    if (repo.isLocating) {
      return '$count $noun · reading locations';
    }
    return '$count $noun';
  }

  Widget _body(
    BuildContext context,
    GalleryRepository repo,
    _Tab? tab,
    List<GallerySmartGroup> smartGroups,
    bool isNova,
    LumaPalette luma,
  ) {
    switch (repo.status) {
      case GalleryStatus.idle:
      case GalleryStatus.askingAccess:
      case GalleryStatus.scanning:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: luma.accent, strokeWidth: 2.5),
              const SizedBox(height: 16),
              Text(
                repo.status == GalleryStatus.askingAccess
                    ? 'Waiting for permission…'
                    : 'Finding your photos and videos…',
                style: TextStyle(color: luma.textSecondary, fontSize: 13),
              ),
            ],
          ),
        );

      case GalleryStatus.noAccess:
        return Padding(
          padding: const EdgeInsets.all(24),
          child: LumaEmptyState(
            icon: Icons.no_photography_rounded,
            title: repo.supportsCustomFolders
                ? 'No picture folders found'
                : 'Gallery needs access to your photos',
            subtitle: repo.supportsCustomFolders
                ? 'Nothing was found in Pictures, Videos or Downloads. Point '
                    'the gallery at a folder and it will scan that instead.'
                : 'Photos and videos stay on this device — the gallery only '
                    'reads them to show them here.',
            action: repo.supportsCustomFolders
                ? LumaPrimaryButton(
                    label: 'Add a folder',
                    icon: Icons.create_new_folder_rounded,
                    onTap: () => _addFolder(repo),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LumaPrimaryButton(
                        label: 'Allow access',
                        icon: Icons.lock_open_rounded,
                        onTap: () => repo.initialise(force: true),
                      ),
                      const SizedBox(width: 8),
                      LumaGhostButton(
                        label: 'Open settings',
                        onTap: repo.openSystemSettings,
                      ),
                    ],
                  ),
          ),
        );

      case GalleryStatus.empty:
        return Padding(
          padding: const EdgeInsets.all(24),
          child: LumaEmptyState(
            icon: Icons.photo_library_outlined,
            title: 'No photos or videos yet',
            subtitle: 'Anything you shoot or download shows up here.',
            action: LumaGhostButton(label: 'Rescan', onTap: repo.refresh),
          ),
        );

      case GalleryStatus.ready:
        if (tab == null) return const SizedBox.shrink();
        if (tab.id == _smartTeaserId) return _SmartUpsell(repo: repo);
        if (tab.smart) {
          final id = tab.id.substring('smart:'.length);
          final group = smartGroups.firstWhere(
            (g) => g.id == id,
            orElse: () => const GallerySmartGroup(
              id: '',
              label: '',
              icon: Icons.auto_awesome_rounded,
              items: [],
            ),
          );
          return _Grid(
            repository: repo,
            items: group.items,
            onOpen: _open,
          );
        }
        final category = repo.categories.firstWhere(
          (c) => c.id == tab.id,
          orElse: () => repo.categories.first,
        );
        return _Grid(
          repository: repo,
          items: itemsInCategory(category, repo.items),
          onOpen: _open,
          footer: isNova && repo.pendingAnalysis > 0 && !repo.isAnalysing
              ? _SmartPrompt(repo: repo)
              : null,
        );
    }
  }
}

/// One pill in the strip. Folder and smart tabs both end up here, which is
/// what keeps the strip a single swipeable row.
@immutable
class _Tab {
  const _Tab({
    required this.id,
    required this.label,
    required this.count,
    this.smart = false,
  });

  final String id;
  final String label;
  final int count;
  final bool smart;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.repository,
    required this.subtitle,
    this.onAddFolder,
  });

  final GalleryRepository repository;
  final String? subtitle;
  final VoidCallback? onAddFolder;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final hasPins = repository.hasLocatedItems;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gallery',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(color: luma.textSecondary, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (onAddFolder != null)
            IconButton(
              tooltip: 'Add a folder',
              onPressed: onAddFolder,
              icon: Icon(Icons.create_new_folder_rounded, color: luma.textSecondary),
            ),
          IconButton(
            tooltip: hasPins
                ? 'Photo map'
                : 'Photo map — no photos with a location yet',
            onPressed: hasPins
                ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const GalleryMapPage(),
                      ),
                    )
                : null,
            icon: Icon(
              Icons.map_rounded,
              color: hasPins ? luma.textSecondary : luma.textMuted,
            ),
          ),
          IconButton(
            tooltip: 'Rescan',
            onPressed: repository.status == GalleryStatus.scanning
                ? null
                : repository.refresh,
            icon: Icon(Icons.refresh_rounded, color: luma.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// The grid itself: one section per day, newest first.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.repository,
    required this.items,
    required this.onOpen,
    this.footer,
  });

  final GalleryRepository repository;
  final List<GalleryItem> items;
  final void Function(List<GalleryItem> items, int index) onOpen;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: LumaEmptyState(
          icon: Icons.filter_none_rounded,
          title: 'Nothing in this category',
          subtitle: 'Photos land here as soon as there are any.',
        ),
      );
    }

    final groups = groupByDate(items, DateTime.now());

    return LayoutBuilder(
      builder: (context, constraints) {
        // Tiles want to be about 120 logical pixels; three across is the
        // floor so a phone never shows a wall of stamps.
        final columns = (constraints.maxWidth / 132).floor().clamp(3, 10);
        var offset = 0;
        final slivers = <Widget>[];

        for (final group in groups) {
          final start = offset;
          slivers.add(
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, start == 0 ? 0 : 20, 20, 8),
                child: Text(
                  group.label,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
          slivers.add(
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => GalleryTile(
                    item: group.items[index],
                    repository: repository,
                    onTap: () => onOpen(items, start + index),
                  ),
                  childCount: group.items.length,
                ),
              ),
            ),
          );
          offset += group.items.length;
        }

        if (footer != null) {
          slivers.add(SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: footer,
            ),
          ));
        }
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));

        return CustomScrollView(slivers: slivers);
      },
    );
  }
}

/// Shown on Android 14+ when the user shared only a handful of photos.
class _LimitedAccessNote extends StatelessWidget {
  const _LimitedAccessNote({required this.onSelectMore});

  final VoidCallback onSelectMore;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: luma.accentSubtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.photo_size_select_large_rounded,
              size: 18, color: luma.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Only the photos you picked are shared with luma.',
              style: TextStyle(color: luma.textSecondary, fontSize: 12),
            ),
          ),
          LumaGhostButton(label: 'Select more', onTap: onSelectMore),
        ],
      ),
    );
  }
}

class _ProgressNote extends StatelessWidget {
  const _ProgressNote({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: luma.accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: luma.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// Offer to run the models, shown under the grid once there is something to
/// analyse. Kept opt-in: it reads every photo, and that is the user's battery.
class _SmartPrompt extends StatelessWidget {
  const _SmartPrompt({required this.repo});

  final GalleryRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (!repo.smartModelsAvailable) return const SizedBox.shrink();
    return LumaCard(
      child: Row(
        children: [
          LumaIconBadge(
            icon: Icons.auto_awesome_rounded,
            color: luma.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart categories',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${repo.pendingAnalysis} photos still to look at. Runs on '
                  'this device, offline.',
                  style: TextStyle(color: luma.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          LumaPrimaryButton(
            label: 'Sort them',
            icon: Icons.auto_awesome_rounded,
            onTap: () => repo.analyseSmart(),
          ),
        ],
      ),
    );
  }
}

/// What Core and Orbit see in place of the smart tabs.
class _SmartUpsell extends StatelessWidget {
  const _SmartUpsell({required this.repo});

  final GalleryRepository repo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: LumaEmptyState(
        icon: Icons.auto_awesome_rounded,
        title: 'Smart categories are a Nova extra',
        subtitle: repo.smartModelsAvailable
            ? 'Nova sorts your library by what is actually in the photos — '
                'people, selfies, food, pets, nature, documents — using models '
                'that run on this device, offline. Nothing is uploaded.'
            : 'Nova sorts your library by what is in the photos. The models '
                'run on the phone build; this device gets the panorama and '
                'place groups.',
        action: LumaPrimaryButton(
          label: 'Upgrade to ${planById('nova').name}',
          icon: Icons.auto_awesome_rounded,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PlanSelectionPage()),
          ),
        ),
      ),
    );
  }
}
