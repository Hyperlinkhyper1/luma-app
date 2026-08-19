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
import 'gallery_people.dart';
import 'gallery_repository.dart';
import 'gallery_scope.dart';
import 'gallery_smart.dart';
import 'gallery_source.dart';
import 'gallery_tile.dart';
import 'gallery_viewer_page.dart';

/// The Gallery plugin. Opens on the albums screen — All, the camera roll,
/// screenshots, GIFs, then a card per folder, then Smart albums — and drills
/// down from there. Smart albums is itself three doors, not one flat grid:
/// People (one folder per person the clustering has found), Memories (date
/// clusters — a trip, a weekend, needing no model and no plan), and
/// Categories (Food, Pets, Ocean, and the rest of what the models recognise).
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  /// The open screen, or null for the albums screen. A single id string
  /// carries the whole navigation stack via prefixes — `people`, `people:3`,
  /// `memories`, `memories:memory:2026-...`, `categories`, `smart:Food` — so
  /// the existing back-button/history model needs nothing new to support a
  /// third level of nesting.
  String? _open;

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

  static const _peopleId = 'people';
  static const _memoriesId = 'memories';
  static const _categoriesId = 'categories';
  static const _peoplePrefix = 'people:';
  static const _memoriesPrefix = 'memories:';
  static const _smartPrefix = 'smart:';

  /// The card Core/Orbit see in place of People and Categories — Memories
  /// needs no model, so it never shows this.
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

  void _openViewer(List<GalleryItem> items, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GalleryViewerPage(items: items, initialIndex: index),
      ),
    );
  }

  Future<void> _renamePerson(GalleryRepository repo, PersonCluster person) async {
    final controller = TextEditingController(text: person.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Name for ${person.displayName}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Mum, Alex…'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        // §1 escape-routes: a clear way out besides the name itself.
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    await repo.renamePerson(person.id, name);
  }

  @override
  Widget build(BuildContext context) {
    final repo = GalleryScope.of(context);
    final isNova = SettingsScope.of(context).selectedPlanId == 'nova';
    final open = _open;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: open == null
          ? _albumsScreen(context, repo, isNova)
          : _routedScreen(context, repo, isNova, open),
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
        if (isNova && repo.isAnalysing)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _ProgressNote(
              label: 'Sorting photos into People and Categories — '
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
        final memories = repo.memories();
        final people = isNova ? repo.peopleClusters() : const <PersonCluster>[];
        final smartCats = isNova
            ? repo.smartGroups().where((g) => g.id != 'people').toList()
            : const <GallerySmartGroup>[];

        return _cardGrid(
          sections: [
            _CardSection(
              title: 'Albums',
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
                    onTap: () => setState(() => _open = category.id),
                  ),
              ],
            ),
            if (folders.isNotEmpty)
              _CardSection(
                title: 'More albums',
                cards: [
                  for (final category in folders)
                    GalleryAlbumCard(
                      key: ValueKey(category.id),
                      label: category.label,
                      icon: category.icon,
                      count: category.count,
                      cover: category.cover,
                      repository: repo,
                      onTap: () => setState(() => _open = category.id),
                    ),
                ],
              ),
            _CardSection(
              title: 'Smart albums',
              cards: [
                // Memories needs no model and costs nothing to compute, so
                // unlike People and Categories it isn't gated behind Nova.
                GalleryAlbumCard(
                  label: 'Memories',
                  icon: Icons.auto_awesome_motion_rounded,
                  count: memories.length,
                  subtitle: memories.isEmpty
                      ? 'None yet'
                      : '${memories.length} '
                          '${memories.length == 1 ? 'trip' : 'trips'}',
                  cover: memories.isEmpty ? null : memories.first.cover,
                  repository: repo,
                  onTap: () => setState(() => _open = _memoriesId),
                ),
                if (isNova) ...[
                  GalleryAlbumCard(
                    label: 'People',
                    icon: Icons.people_alt_rounded,
                    count: people.length,
                    subtitle: people.isEmpty
                        ? 'None found yet'
                        : '${people.length} '
                            '${people.length == 1 ? 'person' : 'people'}',
                    cover: people.isEmpty ? null : repo.coverForPerson(people.first),
                    repository: repo,
                    onTap: () => setState(() => _open = _peopleId),
                  ),
                  GalleryAlbumCard(
                    label: 'Categories',
                    icon: Icons.category_rounded,
                    count: smartCats.length,
                    subtitle: smartCats.isEmpty
                        ? 'None found yet'
                        : '${smartCats.length} categories',
                    cover: smartCats.isEmpty || smartCats.first.items.isEmpty
                        ? null
                        : smartCats.first.items.first,
                    repository: repo,
                    onTap: () => setState(() => _open = _categoriesId),
                  ),
                ] else
                  GalleryAlbumCard(
                    label: 'People & Categories',
                    icon: Icons.auto_awesome_rounded,
                    count: 0,
                    subtitle: 'Included with Nova',
                    badge: 'Nova',
                    repository: repo,
                    onTap: () => setState(() => _open = _smartTeaserId),
                  ),
              ],
            ),
            if (isNova)
              _CardSection(title: null, cards: const [], footer: _SmartPrompt(repo: repo)),
          ],
        );
    }
  }

  /// Lays out a list of card sections at a consistent column count, computed
  /// once from the available width.
  Widget _cardGrid({required List<_CardSection> sections}) {
    final luma = context.luma;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Cards want to be about 150 logical pixels wide; three across is
        // the floor so a phone shows the same three-up grid the system
        // gallery does.
        final columns = (constraints.maxWidth / 172).floor().clamp(3, 8);
        final cardWidth =
            (constraints.maxWidth - 40 - (columns - 1) * 12) / columns;
        // Cover, then two lines of label underneath.
        final extent = cardWidth + 42;

        final slivers = <Widget>[];
        for (final section in sections) {
          if (section.cards.isNotEmpty) {
            slivers.addAll(_albumSection(
              title: section.title,
              columns: columns,
              extent: extent,
              luma: luma,
              first: section.first,
              cards: section.cards,
            ));
          }
          if (section.footer != null) {
            slivers.add(SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: section.footer,
              ),
            ));
          }
        }
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
        return CustomScrollView(slivers: slivers);
      },
    );
  }

  /// A heading and its grid of cards, as the two slivers they have to be.
  List<Widget> _albumSection({
    required String? title,
    required int columns,
    required double extent,
    required LumaPalette luma,
    required List<Widget> cards,
    bool first = false,
  }) =>
      [
        if (title != null)
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

  // ------------------------------------------------------------ routing

  Widget _routedScreen(
    BuildContext context,
    GalleryRepository repo,
    bool isNova,
    String id,
  ) {
    if (id == _smartTeaserId) {
      return _screen(
        title: 'People & Categories',
        subtitle: 'Included with Nova',
        onBack: () => setState(() => _open = null),
        repo: repo,
        child: _SmartUpsell(repo: repo),
      );
    }
    if (id == _peopleId) return _peopleIndexScreen(context, repo);
    if (id == _memoriesId) return _memoriesIndexScreen(context, repo);
    if (id == _categoriesId) return _categoriesIndexScreen(context, repo);

    if (id.startsWith(_peoplePrefix)) {
      final personId = int.tryParse(id.substring(_peoplePrefix.length));
      final person =
          personId == null ? null : repo.peopleClusters().where((p) => p.id == personId).firstOrNull;
      if (person == null) {
        _bounceBackTo(_peopleId);
        return const SizedBox.shrink();
      }
      return _screen(
        title: person.displayName,
        subtitle: '${person.count} items',
        onBack: () => setState(() => _open = _peopleId),
        repo: repo,
        child: _Grid(
          repository: repo,
          items: _itemsFor(
            repo,
            id,
            () => repo.itemsForPerson(person.id),
          ),
          onOpen: _openViewer,
        ),
      );
    }

    if (id.startsWith(_memoriesPrefix)) {
      final memoryId = id.substring(_memoriesPrefix.length);
      final memory =
          repo.memories().where((m) => m.id == memoryId).firstOrNull;
      if (memory == null) {
        _bounceBackTo(_memoriesId);
        return const SizedBox.shrink();
      }
      return _screen(
        title: memory.label,
        subtitle: '${memory.count} items',
        onBack: () => setState(() => _open = _memoriesId),
        repo: repo,
        // Already oldest-first — a trip is relived from its start, unlike
        // every other album in the gallery.
        child: _Grid(repository: repo, items: memory.items, onOpen: _openViewer),
      );
    }

    if (id.startsWith(_smartPrefix)) {
      final groupId = id.substring(_smartPrefix.length);
      final group = repo.smartGroups().where((g) => g.id == groupId).firstOrNull;
      return _screen(
        title: group?.label ?? 'Category',
        subtitle: group == null ? null : '${group.count} items',
        onBack: () => setState(() => _open = _categoriesId),
        repo: repo,
        child: _Grid(
          repository: repo,
          items: group?.items ?? const [],
          onOpen: _openViewer,
        ),
      );
    }

    // A fixed or folder album.
    final category = repo.categories.where((c) => c.id == id).firstOrNull;
    // The album can vanish under us — a rescan after every WhatsApp photo
    // was deleted, say. Falling back to the albums screen beats an empty
    // page with a name on it.
    if (category == null) {
      _bounceBackTo(null);
      return const SizedBox.shrink();
    }
    final items = _itemsFor(repo, id, () => itemsInCategory(category, repo.items));
    return _screen(
      title: category.label,
      subtitle: items.length == 1 ? '1 item' : '${items.length} items',
      onBack: () => setState(() => _open = null),
      repo: repo,
      child: _Grid(repository: repo, items: items, onOpen: _openViewer),
    );
  }

  void _bounceBackTo(String? id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _open = id);
    });
  }

  Widget _screen({
    required String title,
    required String? subtitle,
    required VoidCallback onBack,
    required GalleryRepository repo,
    required Widget child,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: title,
            subtitle: subtitle,
            repository: repo,
            onBack: onBack,
          ),
          Expanded(child: child),
        ],
      );

  // ------------------------------------------------------------- people

  Widget _peopleIndexScreen(BuildContext context, GalleryRepository repo) {
    final people = repo.peopleClusters();
    return _screen(
      title: 'People',
      subtitle: people.isEmpty
          ? null
          : '${people.length} ${people.length == 1 ? 'person' : 'people'}',
      onBack: () => setState(() => _open = null),
      repo: repo,
      child: people.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: LumaEmptyState(
                icon: Icons.people_outline_rounded,
                title: 'No one recognised yet',
                subtitle: repo.isAnalysing
                    ? 'Still sorting the library — people appear here once a '
                        'face has turned up in a few photos.'
                    : 'Sort the library from the albums screen and people who '
                        'appear in a few photos together will show up here.',
              ),
            )
          : _cardGrid(
              sections: [
                _CardSection(
                  title: null,
                  first: true,
                  cards: [
                    for (final person in people)
                      _PersonCard(
                        key: ValueKey(person.id),
                        person: person,
                        cover: repo.coverForPerson(person),
                        repository: repo,
                        onTap: () =>
                            setState(() => _open = '$_peoplePrefix${person.id}'),
                        onRename: () => _renamePerson(repo, person),
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  // ---------------------------------------------------------- memories

  Widget _memoriesIndexScreen(BuildContext context, GalleryRepository repo) {
    final memories = repo.memories();
    return _screen(
      title: 'Memories',
      subtitle: memories.isEmpty
          ? null
          : '${memories.length} ${memories.length == 1 ? 'trip' : 'trips'}',
      onBack: () => setState(() => _open = null),
      repo: repo,
      child: memories.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: LumaEmptyState(
                icon: Icons.auto_awesome_motion_outlined,
                title: 'No trips yet',
                subtitle: 'A run of photos over a few busy days — a weekend '
                    'away, a holiday — shows up here on its own. Nothing to '
                    'set up, and it works without Nova.',
              ),
            )
          : _cardGrid(
              sections: [
                _CardSection(
                  title: null,
                  first: true,
                  cards: [
                    for (final memory in memories)
                      GalleryAlbumCard(
                        key: ValueKey(memory.id),
                        label: memory.label,
                        icon: Icons.auto_awesome_motion_rounded,
                        count: memory.count,
                        cover: memory.cover,
                        repository: repo,
                        onTap: () => setState(
                          () => _open = '$_memoriesPrefix${memory.id}',
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  // -------------------------------------------------------- categories

  Widget _categoriesIndexScreen(BuildContext context, GalleryRepository repo) {
    final groups =
        repo.smartGroups().where((g) => g.id != 'people').toList();
    return _screen(
      title: 'Categories',
      subtitle: groups.isEmpty ? null : '${groups.length} categories',
      onBack: () => setState(() => _open = null),
      repo: repo,
      child: groups.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: LumaEmptyState(
                icon: Icons.category_outlined,
                title: 'Nothing sorted yet',
                subtitle: repo.isAnalysing
                    ? 'Still looking through the library.'
                    : 'Sort the library from the albums screen to fill '
                        'these in.',
              ),
            )
          : _cardGrid(
              sections: [
                _CardSection(
                  title: null,
                  first: true,
                  cards: [
                    for (final group in groups)
                      GalleryAlbumCard(
                        key: ValueKey(group.id),
                        label: group.label,
                        icon: group.icon,
                        count: group.count,
                        cover: group.items.isEmpty ? null : group.items.first,
                        repository: repo,
                        onTap: () => setState(
                          () => _open = '$_smartPrefix${group.id}',
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// One section of the card grid: a heading (or none, for an index screen
/// that is nothing but cards) and its cards, plus an optional block of extra
/// content — the sort-progress card — that follows the last section.
class _CardSection {
  const _CardSection({
    required this.title,
    required this.cards,
    this.first = false,
    this.footer,
  });

  final String? title;
  final List<Widget> cards;
  final bool first;
  final Widget? footer;
}

/// The page header, on every screen: a back arrow when there is somewhere to
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
              tooltip: 'Back',
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

/// One person's card on the People index screen: a circular avatar rather
/// than the square covers everywhere else, so a face-based album reads as
/// visibly different from a folder or a category at a glance.
///
/// The cover is a whole photo, not a crop of just the face — building a real
/// face-cropped thumbnail would mean keeping each detection's box coordinates
/// around after recognition, and they are deliberately discarded once a face
/// has been embedded (see [PersonCluster]) to keep the per-photo cache a
/// couple of integers rather than a float array. A circular frame around the
/// whole photo is the honest middle ground.
class _PersonCard extends StatelessWidget {
  const _PersonCard({
    super.key,
    required this.person,
    required this.cover,
    required this.repository,
    required this.onTap,
    required this.onRename,
  });

  final PersonCluster person;
  final GalleryItem? cover;
  final GalleryRepository repository;
  final VoidCallback onTap;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            // A rename that only a long-press could reach is a rename no one
            // finds — the pencil is a fallback, not the only way in.
            onLongPress: onRename,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipOval(
                  child: Container(
                    color: luma.surface,
                    child: cover == null
                        ? Icon(Icons.person_rounded,
                            color: luma.textMuted, size: 32)
                        : GalleryThumbnail(
                            item: cover!,
                            repository: repository,
                            pixels: 256,
                            placeholderSize: 28,
                          ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _RenameButton(onTap: onRename),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          person.displayName,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          person.count == 1 ? '1 item' : '${person.count} items',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: luma.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

class _RenameButton extends StatelessWidget {
  const _RenameButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Material(
      color: luma.accent,
      shape: const CircleBorder(),
      child: InkWell(
        // §2 touch-target-size: the visible dot is small, the tap area isn't.
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.edit_rounded, size: 13, color: Colors.white),
        ),
      ),
    );
  }
}

/// An album's contents: one section per day, newest first — except a memory,
/// which hands its items in chronologically and stays that way (see
/// [_GalleryPageState._routedScreen]'s memory branch).
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

/// Explains what fills People and Categories, and offers to do it. Memories
/// needs none of this — it has nothing to download and nothing to run.
class _SmartPrompt extends StatelessWidget {
  const _SmartPrompt({required this.repo});

  final GalleryRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final pending = repo.pendingAnalysis;

    if (repo.isAnalysing) {
      final total = repo.analysisTotal;
      return LumaCard(
        child: Row(
          children: [
            Expanded(
              child: _ProgressNote(
                label: repo.analysisStatus ??
                    'Sorting photos — ${repo.analysedCount} of $total',
                progress: repo.analysisStatus != null
                    ? repo.analysisProgress
                    : (total == 0 ? null : repo.analysedCount / total),
              ),
            ),
            const SizedBox(width: 12),
            LumaGhostButton(label: 'Stop', onTap: repo.stopAnalysing),
          ],
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
    if (!repo.smartModelsAvailable) return const SizedBox.shrink();

    // Nothing left to do. Rather than the card simply vanishing — which reads
    // as the button having broken — say what the pass managed, because on a
    // cloud-backed library "skipped" can be most of it.
    if (pending == 0) {
      final examined = repo.examinedAnalysis;
      final skipped = repo.skippedAnalysis;
      if (examined == 0 && skipped == 0) return const SizedBox.shrink();
      return LumaCard(
        child: Row(
          children: [
            LumaIconBadge(
              icon: Icons.done_rounded,
              color: luma.accent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'People and Categories are up to date',
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    skipped == 0
                        ? 'Looked at $examined photos.'
                        : 'Looked at $examined photos. $skipped were skipped '
                            'because they are only in the cloud, or in a '
                            'format that can\'t be read here — make them '
                            'available offline and look again.',
                    style: TextStyle(color: luma.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            LumaGhostButton(label: 'Look again', onTap: repo.reanalyseAll),
          ],
        ),
      );
    }

    final megabytes = (repo.smartModelBytes / (1024 * 1024)).round();
    final body = repo.analysisError ??
        (repo.smartModelsNeedDownload
            // Every platform downloads something for this now — even the
            // phone, which has ML Kit for labels but nothing for matching
            // faces across photos.
            ? repo.usesOnnxAnalysis
                ? '$pending photos to look at. This downloads about '
                    '$megabytes MB of models once (recognition and face '
                    'matching); after that everything happens on this PC, '
                    'offline — no photo is uploaded.'
                : '$pending photos to look at. This downloads a small '
                    '(~$megabytes MB) face-matching model once, so photos of '
                    'the same person can be grouped — offline, and nothing '
                    'is uploaded.'
            : '$pending photos still to look at. Runs on this device, '
                'offline, and picks up where it left off.');

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
                  'People and Categories',
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

/// What Core and Orbit see behind People and Categories. Memories is never
/// behind this — see the albums screen, where it's always its own card.
class _SmartUpsell extends StatelessWidget {
  const _SmartUpsell({required this.repo});

  final GalleryRepository repo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: LumaEmptyState(
        icon: Icons.auto_awesome_rounded,
        title: 'People and Categories are a Nova extra',
        subtitle: repo.smartModelsAvailable
            ? 'Nova groups your photos by who is in them and what is '
                'actually in the picture — food, pets, ocean, and more — '
                'using models that run on this device, offline. Nothing is '
                'uploaded.'
            : 'Nova groups your photos by what is in them. The full set of '
                'categories needs the phone build\'s models; this device '
                'still gets Panoramas and Places for free.',
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
