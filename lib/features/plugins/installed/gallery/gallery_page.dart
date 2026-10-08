import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../account/plan.dart';
import '../../../../account/plan_selection_page.dart';
import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../settings/settings_scope.dart';
import '../sftp/share/send_to_devices.dart';
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

  /// The picked items, keyed by id and kept in the order they were picked.
  /// Holding the items themselves — not just ids — is what lets the send
  /// sheet resolve their files without asking the repository to find them
  /// again.
  final Map<String, GalleryItem> _selected = {};

  /// Which grid the selection belongs to, so walking into another album
  /// doesn't carry a stale pick along with it.
  String? _selectionScreen;

  bool _selecting = false;

  void _toggleSelect(GalleryItem item) {
    setState(() {
      _selecting = true;
      if (_selected.remove(item.id) == null) _selected[item.id] = item;
    });
  }

  void _endSelecting() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  /// A grid plus, while anything is picked, the bar that acts on it.
  Widget _gridFor(
    GalleryRepository repo,
    String screenId,
    List<GalleryItem> items,
  ) {
    if (_selectionScreen != screenId) {
      _selectionScreen = screenId;
      _selected.clear();
      _selecting = false;
    }
    return Stack(
      children: [
        Positioned.fill(
          child: _Grid(
            repository: repo,
            items: items,
            onOpen: _openViewer,
            selection: _selected.keys.toSet(),
            onToggleSelect: _toggleSelect,
            selecting: _selecting,
          ),
        ),
        if (_selecting)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SelectionBar(
              count: _selected.length,
              onSelectAll: () => setState(() {
                for (final item in items) {
                  _selected[item.id] = item;
                }
              }),
              onSend: _selected.isEmpty ? null : () => _sendSelection(repo),
              onCancel: _endSelecting,
            ),
          ),
      ],
    );
  }

  /// Hands the picked photos to the user's other devices. The gallery knows
  /// nothing about how they get there — the shared folder's mirror carries
  /// them over the LAN.
  Future<void> _sendSelection(GalleryRepository repo) async {
    final picked = _selected.values.toList();
    if (picked.isEmpty) return;
    final folder = picked.first.folderName;
    await showSendToDevices(
      context,
      items: [
        for (final item in picked)
          SendCandidate(
            name: item.name,
            resolvePath: () => repo.resolvePath(item),
          ),
      ],
      suggestedFolder: picked.every((i) => i.folderName == folder) && folder.isNotEmpty
          ? folder
          : 'Photos',
    );
    if (mounted) _endSelecting();
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
      dialogTitle: L.of(context).galleryPageAddFolderDialogTitle,
    );
    if (path == null) return;
    await repo.addFolder(path);
  }

  /// Points the scan at one folder and nothing else, everything nested below
  /// it included.
  ///
  /// The two platforms pick a folder in different ways because only one of
  /// them has a directory to browse. On desktop that is the system chooser.
  /// On the phone there are no paths to browse — MediaStore hands out
  /// library-relative names — so the choice is made from the folders the last
  /// scan actually saw.
  Future<void> _chooseScanRoot(GalleryRepository repo) async {
    if (!repo.supportsScanRoot) return;
    final picked = repo.supportsCustomFolders
        ? await FilePicker.getDirectoryPath(
            dialogTitle: L.of(context).galleryPageScanOneFolderDialogTitle,
          )
        : await _pickKnownFolder(repo);
    if (picked == null || !mounted) return;
    await repo.setScanRoot(picked.isEmpty ? null : picked);
  }

  /// The phone's folder chooser: the folders the library already contains,
  /// plus the way back out. Returns an empty string for "the whole library",
  /// which the repository reads as no confinement at all.
  Future<String?> _pickKnownFolder(GalleryRepository repo) async {
    final folders = [
      for (final folder in repo.knownFolders)
        if (folder.trim().isNotEmpty) folder,
    ];
    final t = L.of(context);
    if (folders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.galleryPageNoFoldersYet)),
      );
      return null;
    }

    final current = repo.scanRoot;
    return showDialog<String>(
      context: context,
      builder: (context) {
        final luma = context.luma;
        return AlertDialog(
          title: Text(t.galleryPageScanOneFolder),
          content: SizedBox(
            width: double.maxFinite,
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    t.galleryPageScanOneFolderBody,
                    style: TextStyle(color: luma.textSecondary, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: folders.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return ListTile(
                          leading: Icon(
                            Icons.photo_library_outlined,
                            color: luma.textSecondary,
                          ),
                          title: Text(t.galleryPageWholeLibrary),
                          selected: current == null,
                          onTap: () => Navigator.of(context).pop(''),
                        );
                      }
                      final folder = folders[index - 1];
                      return ListTile(
                        leading: Icon(
                          Icons.folder_rounded,
                          color: luma.textSecondary,
                        ),
                        title: Text(folder),
                        selected: folder == current,
                        onTap: () => Navigator.of(context).pop(folder),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // §1 escape-routes: a way out that isn't picking something.
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.commonCancel),
            ),
          ],
        );
      },
    );
  }

  void _openViewer(List<GalleryItem> items, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GalleryViewerPage(items: items, initialIndex: index),
      ),
    );
  }

  Future<void> _renamePerson(GalleryRepository repo, PersonCluster person) async {
    final t = L.of(context);
    final controller = TextEditingController(text: person.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.galleryPageRenamePersonTitle(person.displayName)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: t.galleryPageRenameHint),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        // §1 escape-routes: a clear way out besides the name itself.
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(t.commonSave),
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
    final t = L.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          title: t.pluginNameGallery,
          subtitle: _librarySubtitle(repo),
          repository: repo,
          onAddFolder:
              repo.supportsCustomFolders ? () => _addFolder(repo) : null,
          onChooseScanRoot:
              repo.supportsScanRoot ? () => _chooseScanRoot(repo) : null,
        ),
        if (repo.scanRoot != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _ScanRootNote(
              root: repo.scanRoot!,
              onChange: () => _chooseScanRoot(repo),
              onClear: () => repo.setScanRoot(null),
            ),
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
              label: repo.analysisTotal > 0
                  ? t.galleryPageSortingProgress(
                      repo.analysedCount,
                      repo.analysisTotal,
                    )
                  : t.galleryPageSortingStarting,
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
    final t = L.of(context);
    switch (repo.status) {
      case GalleryStatus.idle:
      case GalleryStatus.askingAccess:
      case GalleryStatus.scanning:
        return _Busy(
          label: repo.status == GalleryStatus.askingAccess
              ? t.galleryPageWaitingPermission
              : t.galleryPageFindingPhotos,
          progress: repo.status == GalleryStatus.scanning
              ? repo.scanProgress
              : null,
          detail: repo.status == GalleryStatus.scanning
              ? _scanDetail(repo)
              : null,
        );

      case GalleryStatus.noAccess:
        return _NoAccess(
          repo: repo,
          onAddFolder: () => _addFolder(repo),
          onScanEverything:
              repo.scanRoot == null ? null : () => repo.setScanRoot(null),
        );

      case GalleryStatus.empty:
        return Padding(
          padding: const EdgeInsets.all(24),
          child: LumaEmptyState(
            icon: Icons.photo_library_outlined,
            title: repo.scanError != null
                ? t.galleryPageLibraryUnreadable
                : t.galleryPageNoMediaYet,
            subtitle: repo.scanError ??
                (repo.scanRoot != null
                    ? t.galleryPageNothingInRoot(repo.scanRoot!)
                    : t.galleryPageAnythingShowsHere),
            action: LumaGhostButton(
              label: t.galleryPageRescan,
              onTap: repo.refresh,
            ),
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

        // One photo from each of the first few smart categories makes the
        // Categories card a preview of what the models actually found, in the
        // same way a folder card previews its newest picture.
        final categoryPreview = [
          for (final group in smartCats.take(4))
            if (group.items.isNotEmpty) group.items.first,
        ];
        final peoplePreview = <GalleryItem>[
          for (final person in people.take(4))
            ?repo.coverForPerson(person),
        ];

        return _cardGrid(
          sections: [
            _CardSection(
              title: t.galleryPageSectionAlbums,
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
                title: t.galleryPageSectionMoreAlbums,
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
              title: t.galleryPageSectionSmartAlbums,
              cards: [
                // Memories needs no model and costs nothing to compute, so
                // unlike People and Categories it isn't gated behind Nova.
                GalleryAlbumCard(
                  label: t.galleryPageMemories,
                  icon: Icons.auto_awesome_motion_rounded,
                  count: memories.length,
                  subtitle: memories.isEmpty
                      ? t.galleryPageNoneYet
                      : t.galleryPageTripCount(memories.length),
                  cover: memories.isEmpty ? null : memories.first.cover,
                  covers: memories.isEmpty
                      ? const []
                      : memories.first.items.take(4).toList(),
                  repository: repo,
                  onTap: () => setState(() => _open = _memoriesId),
                ),
                if (isNova) ...[
                  GalleryAlbumCard(
                    label: t.galleryPagePeople,
                    icon: Icons.people_alt_rounded,
                    count: people.length,
                    subtitle: people.isEmpty
                        ? t.galleryPageNoneFoundYet
                        : t.galleryPagePersonCount(people.length),
                    cover: people.isEmpty
                        ? null
                        : repo.coverForPerson(people.first),
                    covers: peoplePreview,
                    repository: repo,
                    onTap: () => setState(() => _open = _peopleId),
                  ),
                  GalleryAlbumCard(
                    label: t.galleryPageCategories,
                    icon: Icons.category_rounded,
                    count: smartCats.length,
                    subtitle: smartCats.isEmpty
                        ? t.galleryPageNoneFoundYet
                        : t.galleryPageCategoryCount(smartCats.length),
                    cover:
                        smartCats.isEmpty || smartCats.first.items.isEmpty
                            ? null
                            : smartCats.first.items.first,
                    covers: categoryPreview,
                    repository: repo,
                    onTap: () => setState(() => _open = _categoriesId),
                  ),
                ] else
                  GalleryAlbumCard(
                    label: t.galleryPagePeopleAndCategories,
                    icon: Icons.auto_awesome_rounded,
                    count: 0,
                    subtitle: t.galleryPageIncludedWithNova,
                    badge: 'Nova',
                    spotlight: true,
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

  /// The "1 204 of 5 309" line under the scan bar, or null before the scan
  /// has anything to report.
  String? _scanDetail(GalleryRepository repo) {
    final t = L.of(context);
    final total = repo.scanTotal;
    if (total != null && total > 0) {
      return t.galleryPageScanCountOf(repo.scannedCount, total);
    }
    if (repo.scannedCount == 0) return null;
    return t.galleryPageItemsFound(repo.scannedCount);
  }

  String? _librarySubtitle(GalleryRepository repo) {
    final t = L.of(context);
    if (repo.status == GalleryStatus.scanning) {
      return _scanDetail(repo) ?? t.galleryPageReadingLibrary;
    }
    if (repo.status != GalleryStatus.ready) return null;
    final count = repo.items.length;
    if (repo.isLocating) return t.galleryPageItemCountReadingLocations(count);
    return t.galleryItemCount(count);
  }

  // ------------------------------------------------------------ routing

  Widget _routedScreen(
    BuildContext context,
    GalleryRepository repo,
    bool isNova,
    String id,
  ) {
    final t = L.of(context);
    if (id == _smartTeaserId) {
      return _screen(
        title: t.galleryPagePeopleAndCategories,
        subtitle: t.galleryPageIncludedWithNova,
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
        subtitle: t.galleryItemCount(person.count),
        onBack: () => setState(() => _open = _peopleId),
        repo: repo,
        selectable: true,
        child: _gridFor(
          repo,
          id,
          _itemsFor(repo, id, () => repo.itemsForPerson(person.id)),
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
        subtitle: t.galleryItemCount(memory.count),
        onBack: () => setState(() => _open = _memoriesId),
        repo: repo,
        // Already oldest-first — a trip is relived from its start, unlike
        // every other album in the gallery.
        selectable: true,
        child: _gridFor(repo, id, memory.items),
      );
    }

    if (id.startsWith(_smartPrefix)) {
      final groupId = id.substring(_smartPrefix.length);
      final group = repo.smartGroups().where((g) => g.id == groupId).firstOrNull;
      return _screen(
        title: group?.labelFor(t) ?? t.galleryPageCategoryFallback,
        subtitle: group == null ? null : t.galleryItemCount(group.count),
        onBack: () => setState(() => _open = _categoriesId),
        repo: repo,
        selectable: true,
        child: _gridFor(repo, id, group?.items ?? const []),
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
      subtitle: t.galleryItemCount(items.length),
      onBack: () => setState(() => _open = null),
      repo: repo,
      selectable: true,
      child: _gridFor(repo, id, items),
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
    bool selectable = false,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: title,
            subtitle: subtitle,
            repository: repo,
            onBack: onBack,
            onSelect: !selectable || _selecting
                ? null
                : () => setState(() => _selecting = true),
          ),
          Expanded(child: child),
        ],
      );

  // ------------------------------------------------------------- people

  Widget _peopleIndexScreen(BuildContext context, GalleryRepository repo) {
    final t = L.of(context);
    final people = repo.peopleClusters();
    return _screen(
      title: t.galleryPagePeople,
      subtitle: people.isEmpty ? null : t.galleryPagePersonCount(people.length),
      onBack: () => setState(() => _open = null),
      repo: repo,
      child: people.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: LumaEmptyState(
                icon: Icons.people_outline_rounded,
                title: t.galleryPageNoOneRecognised,
                subtitle: repo.isAnalysing
                    ? t.galleryPagePeopleStillSorting
                    : t.galleryPagePeopleSortHint,
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
    final t = L.of(context);
    final memories = repo.memories();
    return _screen(
      title: t.galleryPageMemories,
      subtitle: memories.isEmpty ? null : t.galleryPageTripCount(memories.length),
      onBack: () => setState(() => _open = null),
      repo: repo,
      child: memories.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: LumaEmptyState(
                icon: Icons.auto_awesome_motion_outlined,
                title: t.galleryPageNoTripsYet,
                subtitle: t.galleryPageNoTripsBody,
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
                        covers: memory.items.take(4).toList(),
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
    final t = L.of(context);
    final groups =
        repo.smartGroups().where((g) => g.id != 'people').toList();
    return _screen(
      title: t.galleryPageCategories,
      subtitle: groups.isEmpty ? null : t.galleryPageCategoryCount(groups.length),
      onBack: () => setState(() => _open = null),
      repo: repo,
      child: groups.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: LumaEmptyState(
                icon: Icons.category_outlined,
                title: t.galleryPageNothingSortedYet,
                subtitle: repo.isAnalysing
                    ? t.galleryPageStillLooking
                    : t.galleryPageSortToFill,
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
                        label: group.labelFor(t),
                        icon: group.icon,
                        count: group.count,
                        cover:
                            group.items.isEmpty ? null : group.items.first,
                        covers: group.items.take(4).toList(),
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
    this.onChooseScanRoot,
    this.onSelect,
  });

  final String title;
  final String? subtitle;
  final GalleryRepository repository;
  final VoidCallback? onBack;
  final VoidCallback? onAddFolder;
  final VoidCallback? onChooseScanRoot;

  /// Starts selection mode. Null on screens that have no grid to pick from,
  /// and while a selection is already running.
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
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
              tooltip: t.commonBack,
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
          if (onSelect != null)
            IconButton(
              tooltip: t.galleryPageSelectToSend,
              onPressed: onSelect,
              icon: Icon(Icons.checklist_rounded, color: luma.textSecondary),
            ),
          if (onAddFolder != null)
            IconButton(
              tooltip: t.galleryPageAddFolder,
              onPressed: onAddFolder,
              icon: Icon(
                Icons.create_new_folder_rounded,
                color: luma.textSecondary,
              ),
            ),
          if (onChooseScanRoot != null)
            IconButton(
              tooltip: t.galleryPageScanOneFolderOnly,
              onPressed: onChooseScanRoot,
              icon: Icon(
                Icons.folder_special_rounded,
                color: repository.scanRoot == null
                    ? luma.textSecondary
                    : luma.accent,
              ),
            ),
          IconButton(
            tooltip: t.galleryPagePhotoMap,
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
            tooltip: t.galleryPageRescan,
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
    final t = L.of(context);
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
          t.galleryItemCount(person.count),
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
    required this.selection,
    required this.onToggleSelect,
    required this.selecting,
  });

  final GalleryRepository repository;
  final List<GalleryItem> items;
  final void Function(List<GalleryItem> items, int index) onOpen;

  /// Ids of the picked items, and the tap that adds or removes one.
  final Set<String> selection;
  final ValueChanged<GalleryItem> onToggleSelect;
  final bool selecting;

  @override
  State<_Grid> createState() => _GridState();
}

class _GridState extends State<_Grid> {
  List<GalleryItem>? _rowsFor;
  int _rowsColumns = -1;
  List<_GridRow> _rows = const [];

  /// The album flattened into one row per line of the grid, with the day
  /// headings as rows of their own.
  ///
  /// This used to be two slivers per day inside a [CustomScrollView], which is
  /// fine for a desktop Pictures folder and fatal on a phone: a camera roll
  /// covering five years is close to two thousand days, so opening All built
  /// four thousand slivers before it could draw a single frame. A sliver list
  /// is lazy in its children but never in the list of slivers itself — every
  /// one of them was laid out and kept alive, and on a phone that is the
  /// memory the OS kills the app over.
  ///
  /// One [SliverList] over rows means the number of days costs nothing beyond
  /// the rows themselves, and only the visible handful are ever built.
  ///
  /// Recomputed only when the contents or the column count actually change.
  /// The caller hands back the same list instance until then, so identity is
  /// the whole test.
  List<_GridRow> _rowsIn(List<GalleryItem> items, int columns) {
    if (identical(_rowsFor, items) && _rowsColumns == columns) return _rows;

    final rows = <_GridRow>[];
    var offset = 0;
    for (final group in groupByDate(items, DateTime.now())) {
      rows.add(_GridRow.heading(group.label, first: rows.isEmpty));
      for (var start = 0; start < group.items.length; start += columns) {
        final end = start + columns > group.items.length
            ? group.items.length
            : start + columns;
        rows.add(
          _GridRow.tiles(group.items, start, end - start, offset + start),
        );
      }
      offset += group.items.length;
    }

    _rows = rows;
    _rowsFor = items;
    _rowsColumns = columns;
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = widget.repository;
    final items = widget.items;
    final onOpen = widget.onOpen;

    if (items.isEmpty) {
      final t = L.of(context);
      return Padding(
        padding: const EdgeInsets.all(24),
        child: LumaEmptyState(
          icon: Icons.filter_none_rounded,
          title: t.galleryPageNothingInAlbum,
          subtitle: t.galleryPageLandHere,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Tiles want to be about 120 logical pixels; three across is the
        // floor so a phone never shows a wall of stamps.
        final columns = (constraints.maxWidth / 132).floor().clamp(3, 10);
        // A grid delegate worked the tile size out on its own; a row of plain
        // boxes has to be told, so it comes from the same three numbers.
        final tile =
            (constraints.maxWidth - 40 - (columns - 1) * _tileGap) / columns;
        final rows = _rowsIn(items, columns);

        return CustomScrollView(
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final row = rows[index];
                  final label = row.label;
                  if (label != null) {
                    return Padding(
                      padding:
                          EdgeInsets.fromLTRB(20, row.first ? 0 : 20, 20, 8),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, _tileGap),
                    child: SizedBox(
                      height: tile,
                      child: Row(
                        children: [
                          for (var column = 0; column < row.count; column++)
                            Padding(
                              padding: EdgeInsets.only(
                                right: column == columns - 1 ? 0 : _tileGap,
                              ),
                              child: SizedBox(
                                width: tile,
                                height: tile,
                                child: Builder(
                                  builder: (context) {
                                    final item = row.items[row.from + column];
                                    return GalleryTile(
                                      item: item,
                                      repository: repository,
                                      selecting: widget.selecting,
                                      selected:
                                          widget.selection.contains(item.id),
                                      onLongPress: () =>
                                          widget.onToggleSelect(item),
                                      onTap: () => widget.selecting
                                          ? widget.onToggleSelect(item)
                                          : onOpen(items, row.offset + column),
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: rows.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }
}

/// What the picked photos can have done to them, floating over the bottom of
/// the grid.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onSelectAll,
    required this.onSend,
    required this.onCancel,
  });

  final int count;
  final VoidCallback onSelectAll;
  final VoidCallback? onSend;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            color: luma.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: luma.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  count == 0
                      ? t.galleryPageTapToPick
                      : t.galleryPageSelectedCount(count),
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onSelectAll,
                child: Text(t.commonAll),
              ),
              const SizedBox(width: 4),
              LumaPrimaryButton(
                label: t.commonSend,
                icon: Icons.devices_rounded,
                onTap: onSend,
              ),
              IconButton(
                tooltip: t.commonCancel,
                onPressed: onCancel,
                icon: Icon(Icons.close_rounded, color: luma.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gap between one tile and the next, across and down.
const double _tileGap = 4;

/// One line of an album: either a day heading or a run of tiles.
///
/// A run points into the day's own list rather than copying a slice of it —
/// an album of 20 000 photos is 6 000-odd rows, and 6 000 three-element lists
/// is memory spent for nothing.
@immutable
class _GridRow {
  const _GridRow.heading(this.label, {required this.first})
      : items = const [],
        from = 0,
        count = 0,
        offset = 0;

  const _GridRow.tiles(this.items, this.from, this.count, this.offset)
      : label = null,
        first = false;

  /// The heading's text, or null on a row of tiles.
  final String? label;

  /// Whether this is the album's first heading, which needs no gap above it.
  final bool first;

  /// The day's items, of which this row shows [count] starting at [from].
  final List<GalleryItem> items;
  final int from;
  final int count;

  /// Index of this row's first tile in the whole album, which is what the
  /// viewer is opened at.
  final int offset;
}

/// The whole-page waiting state, with the scan's progress bar on it.
class _Busy extends StatelessWidget {
  const _Busy({required this.label, this.progress, this.detail});

  final String label;

  /// 0..1 where the work knows how much there is — MediaStore says up front —
  /// and null where it can only count as it goes, which is what a folder walk
  /// does. The bar is indeterminate in that case and [detail] carries the
  /// running count instead.
  final double? progress;

  final String? detail;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                color: luma.accent,
                backgroundColor: luma.accentSubtle,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(color: luma.textSecondary, fontSize: 13),
          ),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(
              detail!,
              style: TextStyle(
                color: luma.textMuted,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess({
    required this.repo,
    required this.onAddFolder,
    this.onScanEverything,
  });

  final GalleryRepository repo;
  final VoidCallback onAddFolder;

  /// Offered only while the scan is confined to a folder that has since
  /// stopped existing — otherwise this screen has no way back.
  final VoidCallback? onScanEverything;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: LumaEmptyState(
        icon: Icons.no_photography_rounded,
        title: repo.scanRoot != null
            ? t.galleryPageFolderGone
            : repo.supportsCustomFolders
                ? t.galleryPageNoPictureFolders
                : t.galleryPageNeedsAccess,
        subtitle: repo.scanRoot != null
            ? t.galleryPageScanRootUnreadable(repo.scanRoot!)
            : repo.supportsCustomFolders
                ? t.galleryPageNothingFoundPoint
                : t.galleryPageStaysOnDevice,
        action: onScanEverything != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LumaPrimaryButton(
                    label: t.galleryPageScanEverything,
                    icon: Icons.photo_library_rounded,
                    onTap: onScanEverything!,
                  ),
                  const SizedBox(width: 8),
                  LumaGhostButton(
                    label: t.galleryPagePickAnotherFolder,
                    onTap: onAddFolder,
                  ),
                ],
              )
            : repo.supportsCustomFolders
                ? LumaPrimaryButton(
                    label: t.galleryPageAddFolder,
                    icon: Icons.create_new_folder_rounded,
                    onTap: onAddFolder,
                  )
                : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LumaPrimaryButton(
                    label: t.galleryPageAllowAccess,
                    icon: Icons.lock_open_rounded,
                    onTap: () => repo.initialise(force: true),
                  ),
                  const SizedBox(width: 8),
                  LumaGhostButton(
                    label: t.galleryPageOpenSettings,
                    onTap: repo.openSystemSettings,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Shown while the scan is confined to one folder. Standing in the way of
/// "where are the rest of my photos?" is the whole job: the confinement
/// survives restarts, so it has to say so, and say how to undo it.
class _ScanRootNote extends StatelessWidget {
  const _ScanRootNote({
    required this.root,
    required this.onChange,
    required this.onClear,
  });

  final String root;
  final VoidCallback onChange;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: luma.accentSubtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.folder_special_rounded, size: 18, color: luma.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.galleryPageOnlyScanningRoot(root),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Wrapped rather than laid beside the sentence: a phone is not wide
          // enough for a folder path and two buttons on one line.
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 6,
            runSpacing: 6,
            children: [
              LumaGhostButton(label: t.galleryPageChange, onTap: onChange),
              LumaGhostButton(label: t.galleryPageScanEverything, onTap: onClear),
            ],
          ),
        ],
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
    final t = L.of(context);
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
              t.galleryPageLimitedAccess,
              style: TextStyle(color: luma.textSecondary, fontSize: 12),
            ),
          ),
          LumaGhostButton(label: t.galleryPageSelectMore, onTap: onSelectMore),
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
    final t = L.of(context);
    final pending = repo.pendingAnalysis;

    if (repo.isAnalysing) {
      final total = repo.analysisTotal;
      return LumaCard(
        child: Row(
          children: [
            Expanded(
              child: _ProgressNote(
                label: repo.analysisStatus ??
                    t.galleryPageSortingPhotosProgress(
                      repo.analysedCount,
                      total,
                    ),
                progress: repo.analysisStatus != null
                    ? repo.analysisProgress
                    : (total == 0 ? null : repo.analysedCount / total),
              ),
            ),
            const SizedBox(width: 12),
            LumaGhostButton(label: t.commonStop, onTap: repo.stopAnalysing),
          ],
        ),
      );
    }
    if (repo.isLocating) {
      return LumaCard(
        child: _ProgressNote(
          label: t.galleryPageReadingDetails(repo.pendingDetails),
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
                    t.galleryPageUpToDate,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    skipped == 0
                        ? t.galleryPageLookedAt(examined)
                        : t.galleryPageLookedAtSkipped(examined, skipped),
                    style: TextStyle(color: luma.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            LumaGhostButton(label: t.galleryPageLookAgain, onTap: repo.reanalyseAll),
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
                ? t.galleryPageSmartDownloadDesktop(pending, megabytes)
                : t.galleryPageSmartDownloadPhone(pending, megabytes)
            : t.galleryPageSmartRemaining(pending));

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
                  t.galleryPagePeopleAndCategories,
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
                ? t.galleryPageTryAgain
                : repo.smartModelsNeedDownload
                    ? t.galleryPageGetModels
                    : t.galleryPageSortThem,
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
    final t = L.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: LumaEmptyState(
        icon: Icons.auto_awesome_rounded,
        title: t.galleryPageSmartUpsellTitle,
        subtitle: repo.smartModelsAvailable
            ? t.galleryPageSmartUpsellBodyModels
            : t.galleryPageSmartUpsellBodyPhone,
        action: LumaPrimaryButton(
          label: t.galleryPageUpgradeTo(planById('nova').name),
          icon: Icons.auto_awesome_rounded,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PlanSelectionPage()),
          ),
        ),
      ),
    );
  }
}
