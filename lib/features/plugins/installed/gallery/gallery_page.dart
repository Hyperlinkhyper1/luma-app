import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../account/plan.dart';
import '../../../../account/plan_selection_page.dart';
import '../../../../app/widgets.dart';
import '../../../../settings/settings_scope.dart';
import '../../../../theme/luma_theme.dart';
import 'gallery_album_card.dart';
import 'gallery_categories.dart';
import 'gallery_map_page.dart';
import 'gallery_media.dart';
import 'gallery_repository.dart';
import 'gallery_scope.dart';
import 'gallery_smart.dart';
import 'gallery_source.dart';
import 'gallery_tile.dart';
import 'gallery_viewer_page.dart';

/// The Gallery plugin. Opens on the albums screen — All, the camera roll,
/// screenshots, GIFs, then a card per folder, then the smart albums on Nova —
/// and drills into one album's grid from there.
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  /// The open album, or null on the albums screen. Held as an id rather than
  /// an object: folder albums come and go with a rescan, and smart albums
  /// grow as the models catch up.
  String? _openAlbum;

  bool _started = false;

  /// The card non-Nova devices see in place of the smart albums.
  static const _smartTeaserId = 'smart-teaser';
  static const _smartPrefix = 'smart:';

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
    final repo = GalleryScope.of(context);
    final isNova = SettingsScope.of(context).selectedPlanId == 'nova';
    final open = _openAlbum;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: open == null
          ? _albumsScreen(context, repo, isNova)
          : _albumScreen(context, repo, isNova, open),
    );
  }

  // ---------------------------------------------------------------- albums

  Widget _albumsScreen(
    BuildContext context,
    GalleryRepository repo,
    bool isNova,
  ) {
    final luma = context.luma;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          title: 'Gallery',
          subtitle: _librarySubtitle(repo),
          repository: repo,
          onAddFolder:
              repo.supportsCustomFolders ? () => _addFolder(repo) : null,
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
              label: 'Sorting photos into smart albums — '
                  '${repo.analysedCount} done',
            ),
          ),
        Expanded(child: _albumsBody(context, repo, isNova, luma)),
      ],
    );
  }

  Widget _albumsBody(
    BuildContext context,
    GalleryRepository repo,
    bool isNova,
    LumaPalette luma,
  ) {
    switch (repo.status) {
      case GalleryStatus.idle:
      case GalleryStatus.askingAccess:
      case GalleryStatus.scanning:
        return _Busy(
          label: repo.status == GalleryStatus.askingAccess
              ? 'Waiting for permission…'
              : 'Finding your photos and videos…',
        );

      case GalleryStatus.noAccess:
        return _NoAccess(repo: repo, onAddFolder: () => _addFolder(repo));

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
        final categories = repo.categories;
        final fixed = [for (final c in categories) if (!c.isFolder) c];
        final folders = [for (final c in categories) if (c.isFolder) c];
        final smart = isNova ? repo.smartGroups() : const <GallerySmartGroup>[];

        return LayoutBuilder(
          builder: (context, constraints) {
            // Cards want to be about 150 logical pixels wide; three across is
            // the floor so a phone shows the same three-up grid the system
            // gallery does.
            final columns = (constraints.maxWidth / 172).floor().clamp(3, 8);
            final cardWidth = (constraints.maxWidth - 40 - (columns - 1) * 12) /
                columns;
            // Cover, then two lines of label underneath.
            final extent = cardWidth + 42;

            return CustomScrollView(
              slivers: [
                ..._albumSection(
                  title: 'Albums',
                  columns: columns,
                  extent: extent,
                  luma: luma,
                  first: true,
                  cards: [
                    for (final category in fixed)
                      GalleryAlbumCard(
                        key: ValueKey(category.id),
                        label: category.label,
                        icon: category.icon,
                        count: category.count,
                        cover: category.cover,
                        repository: repo,
                        onTap: () =>
                            setState(() => _openAlbum = category.id),
                      ),
                  ],
                ),
                if (folders.isNotEmpty)
                  ..._albumSection(
                    title: 'More albums',
                    columns: columns,
                    extent: extent,
                    luma: luma,
                    cards: [
                      for (final category in folders)
                        GalleryAlbumCard(
                          key: ValueKey(category.id),
                          label: category.label,
                          icon: category.icon,
                          count: category.count,
                          cover: category.cover,
                          repository: repo,
                          onTap: () =>
                              setState(() => _openAlbum = category.id),
                        ),
                    ],
                  ),
                if (smart.isNotEmpty)
                  ..._albumSection(
                    title: 'Smart albums',
                    columns: columns,
                    extent: extent,
                    luma: luma,
                    cards: [
                      for (final group in smart)
                        GalleryAlbumCard(
                          key: ValueKey(group.id),
                          label: group.label,
                          icon: group.icon,
                          count: group.count,
                          cover: group.items.isEmpty ? null : group.items.first,
                          repository: repo,
                          onTap: () => setState(
                            () => _openAlbum = '$_smartPrefix${group.id}',
                          ),
                        ),
                    ],
                  ),
                if (!isNova)
                  ..._albumSection(
                    title: 'Smart albums',
                    columns: columns,
                    extent: extent,
                    luma: luma,
                    cards: [
                      GalleryAlbumCard(
                        label: 'Smart albums',
                        icon: Icons.auto_awesome_rounded,
                        count: 0,
                        subtitle: 'Included with Nova',
                        badge: 'Nova',
                        repository: repo,
                        onTap: () =>
                            setState(() => _openAlbum = _smartTeaserId),
                      ),
                    ],
                  ),
                if (isNova && repo.pendingAnalysis > 0 && !repo.isAnalysing)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: _SmartPrompt(repo: repo),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        );
    }
  }

  /// A heading and its grid of cards, as the two slivers they have to be.
  List<Widget> _albumSection({
    required String title,
    required int columns,
    required double extent,
    required LumaPalette luma,
    required List<Widget> cards,
    bool first = false,
  }) =>
      [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, first ? 0 : 24, 20, 10),
            child: Text(
              title,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              mainAxisExtent: extent,
            ),
            delegate: SliverChildListDelegate(cards),
          ),
        ),
      ];

  String? _librarySubtitle(GalleryRepository repo) {
    if (repo.status == GalleryStatus.scanning) return 'Reading your library…';
    if (repo.status != GalleryStatus.ready) return null;
    final count = repo.items.length;
    final noun = count == 1 ? 'item' : 'items';
    if (repo.isLocating) return '$count $noun · reading locations';
    return '$count $noun';
  }

  // ----------------------------------------------------------- one album

  Widget _albumScreen(
    BuildContext context,
    GalleryRepository repo,
    bool isNova,
    String albumId,
  ) {
    if (albumId == _smartTeaserId) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: 'Smart albums',
            subtitle: 'Included with Nova',
            repository: repo,
            onBack: () => setState(() => _openAlbum = null),
          ),
          Expanded(child: _SmartUpsell(repo: repo)),
        ],
      );
    }

    final String label;
    final List<GalleryItem> items;

    if (albumId.startsWith(_smartPrefix)) {
      final id = albumId.substring(_smartPrefix.length);
      final group = repo.smartGroups().where((g) => g.id == id).firstOrNull;
      label = group?.label ?? 'Album';
      items = group?.items ?? const [];
    } else {
      final category =
          repo.categories.where((c) => c.id == albumId).firstOrNull;
      // The album can vanish under us — a rescan after every WhatsApp photo
      // was deleted, say. Falling back to the albums screen beats an empty
      // page with a name on it.
      if (category == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _openAlbum = null);
        });
        return const SizedBox.shrink();
      }
      label = category.label;
      items = itemsInCategory(category, repo.items);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          title: label,
          subtitle: items.length == 1 ? '1 item' : '${items.length} items',
          repository: repo,
          onBack: () => setState(() => _openAlbum = null),
        ),
        Expanded(
          child: _Grid(repository: repo, items: items, onOpen: _open),
        ),
      ],
    );
  }
}

/// The page header, on both screens: a back arrow when there is somewhere to
/// go back to, then the title, then the map and rescan actions.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.repository,
    this.onBack,
    this.onAddFolder,
  });

  final String title;
  final String? subtitle;
  final GalleryRepository repository;
  final VoidCallback? onBack;
  final VoidCallback? onAddFolder;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final hasPins = repository.hasLocatedItems;

    return Padding(
      padding: EdgeInsets.fromLTRB(onBack == null ? 20 : 6, 16, 12, 12),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              tooltip: 'All albums',
              onPressed: onBack,
              icon: Icon(Icons.arrow_back_rounded, color: luma.textSecondary),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
              icon: Icon(
                Icons.create_new_folder_rounded,
                color: luma.textSecondary,
              ),
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

/// An album's contents: one section per day, newest first.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.repository,
    required this.items,
    required this.onOpen,
  });

  final GalleryRepository repository;
  final List<GalleryItem> items;
  final void Function(List<GalleryItem> items, int index) onOpen;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: LumaEmptyState(
          icon: Icons.filter_none_rounded,
          title: 'Nothing in this album',
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

        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
        return CustomScrollView(slivers: slivers);
      },
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: luma.accent, strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(color: luma.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess({required this.repo, required this.onAddFolder});

  final GalleryRepository repo;
  final VoidCallback onAddFolder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: LumaEmptyState(
        icon: Icons.no_photography_rounded,
        title: repo.supportsCustomFolders
            ? 'No picture folders found'
            : 'Gallery needs access to your photos',
        subtitle: repo.supportsCustomFolders
            ? 'Nothing was found in Pictures, Videos or Downloads. Point the '
                'gallery at a folder and it will scan that instead.'
            : 'Photos and videos stay on this device — the gallery only reads '
                'them to show them here.',
        action: repo.supportsCustomFolders
            ? LumaPrimaryButton(
                label: 'Add a folder',
                icon: Icons.create_new_folder_rounded,
                onTap: onAddFolder,
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

/// Offer to run the models, shown under the albums once there is something to
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
                  'Smart albums',
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

/// What Core and Orbit see behind the Smart albums card.
class _SmartUpsell extends StatelessWidget {
  const _SmartUpsell({required this.repo});

  final GalleryRepository repo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: LumaEmptyState(
        icon: Icons.auto_awesome_rounded,
        title: 'Smart albums are a Nova extra',
        subtitle: repo.smartModelsAvailable
            ? 'Nova sorts your library by what is actually in the photos — '
                'people, selfies, food, pets, nature, documents — using models '
                'that run on this device, offline. Nothing is uploaded.'
            : 'Nova sorts your library by what is in the photos. The models '
                'run on the phone build; this device gets the panorama and '
                'place albums.',
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
