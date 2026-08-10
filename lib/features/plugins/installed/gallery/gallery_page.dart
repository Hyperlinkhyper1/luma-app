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

  /// The open album's contents, filtered and sorted once. Rebuilding is
  /// cheap; re-sorting a few thousand items on every notification from a
  /// background pass is not, and that is exactly what a repository that
  /// reports progress does.
  List<GalleryItem>? _albumItems;
  String? _albumItemsFor;
  int _albumItemsVersion = -1;

  List<GalleryItem> _itemsFor(
    GalleryRepository repo,
    String albumId,
    List<GalleryItem> Function() build,
  ) {
    if (_albumItemsFor == albumId &&
        _albumItemsVersion == repo.libraryVersion &&
        _albumItems != null) {
      return _albumItems!;
    }
    final items = build();
    _albumItems = items;
    _albumItemsFor = albumId;
    _albumItemsVersion = repo.libraryVersion;
    return items;
  }

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
                if (isNova)
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
      // Smart groups are already memoised and sorted by the repository.
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
      items = _itemsFor(
        repo,
        albumId,
        () => itemsInCategory(category, repo.items),
      );
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
    // Always reachable: the coordinates aren't read until the map is opened,
    // so "no pins yet" is the normal state on a first visit rather than a
    // reason to disable the button.
    final canMap = repository.status == GalleryStatus.ready;

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
            tooltip: 'Photo map',
            onPressed: canMap
                ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const GalleryMapPage(),
                      ),
                    )
                : null,
            icon: Icon(
              Icons.map_rounded,
              color: canMap ? luma.textSecondary : luma.textMuted,
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
class _Grid extends StatefulWidget {
  const _Grid({
    required this.repository,
    required this.items,
    required this.onOpen,
  });

  final GalleryRepository repository;
  final List<GalleryItem> items;
  final void Function(List<GalleryItem> items, int index) onOpen;

  @override
  State<_Grid> createState() => _GridState();
}

class _GridState extends State<_Grid> {
  List<GalleryItem>? _grouped;
  List<GalleryDateGroup> _groups = const [];

  /// The day sections, recomputed only when the album's contents actually
  /// change. The caller hands back the same list instance until then, so
  /// identity is the whole test.
  List<GalleryDateGroup> _groupsFor(List<GalleryItem> items) {
    if (identical(_grouped, items)) return _groups;
    _groups = groupByDate(items, DateTime.now());
    _grouped = items;
    return _groups;
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = widget.repository;
    final items = widget.items;
    final onOpen = widget.onOpen;

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

    final groups = _groupsFor(items);

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
  const _ProgressNote({required this.label, this.progress});

  final String label;

  /// 0..1 where the work reports it — the model download does — and null for
  /// work that can only spin.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: luma.accent,
            value: progress,
          ),
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

/// Explains what fills the smart albums, and offers to do it.
///
/// The two halves of the answer differ by platform, and the difference is
/// worth spelling out rather than leaving someone with 27 000 photos staring
/// at a single Places card wondering what broke. Recognising *what is in* a
/// photo needs Google's on-device models, which exist only on the phone
/// builds. Recognising a photo's shape or where it was taken only needs its
/// header — that works everywhere, but the headers have to be read first.
class _SmartPrompt extends StatelessWidget {
  const _SmartPrompt({required this.repo});

  final GalleryRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final pending = repo.pendingAnalysis;

    if (repo.isAnalysing) {
      return LumaCard(
        child: _ProgressNote(
          label: repo.analysisStatus ??
              'Sorting photos into smart albums — ${repo.analysedCount} done',
          progress: repo.analysisProgress,
        ),
      );
    }
    if (repo.isLocating) {
      return LumaCard(
        child: _ProgressNote(
          label: 'Reading photo details — ${repo.pendingDetails} to go',
        ),
      );
    }
    if (!repo.smartModelsAvailable || pending == 0) {
      return const SizedBox.shrink();
    }

    final megabytes = (repo.smartModelBytes / (1024 * 1024)).round();
    final body = repo.analysisError ??
        (repo.smartModelsNeedDownload
            // Desktop has no ML Kit, so the equivalent models are fetched on
            // first use. Worth saying out loud what is being downloaded and
            // that the photos stay put.
            ? '$pending photos to look at. The first run downloads about '
                '$megabytes MB of models; after that everything happens on '
                'this PC, offline — no photo is uploaded.'
            : '$pending photos still to look at. Runs on this device, '
                'offline.');

    return LumaCard(
      child: Row(
        children: [
          LumaIconBadge(
            icon: repo.analysisError != null
                ? Icons.error_outline_rounded
                : Icons.auto_awesome_rounded,
            color: repo.analysisError != null ? luma.danger : luma.accent,
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
                  body,
                  style: TextStyle(color: luma.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          LumaPrimaryButton(
            label: repo.analysisError != null
                ? 'Try again'
                : repo.smartModelsNeedDownload
                    ? 'Get the models'
                    : 'Sort them',
            icon: repo.smartModelsNeedDownload
                ? Icons.download_rounded
                : Icons.auto_awesome_rounded,
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
