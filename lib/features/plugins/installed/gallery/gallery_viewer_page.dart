import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';

import 'gallery_details_panel.dart';
import 'gallery_media.dart';
import 'gallery_repository.dart';
import 'gallery_scope.dart';
import 'gallery_tile.dart';

/// Full-screen photo and video viewer. Swipes through whatever list it was
/// opened from, so the order matches the grid behind it.
class GalleryViewerPage extends StatefulWidget {
  const GalleryViewerPage({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  final List<GalleryItem> items;
  final int initialIndex;

  @override
  State<GalleryViewerPage> createState() => _GalleryViewerPageState();
}

class _GalleryViewerPageState extends State<GalleryViewerPage> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  /// Resolved file paths, kept so a rebuild (or a swipe back) doesn't ask the
  /// platform to materialise the same asset twice.
  final Map<String, Future<String?>> _paths = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String?> _pathFor(GalleryRepository repo, GalleryItem item) =>
      _paths.putIfAbsent(item.id, () => repo.resolvePath(item));

  Future<void> _play(GalleryRepository repo, GalleryItem item) async {
    final path = await _pathFor(repo, item);
    if (path == null || !mounted) return;
    final result = await OpenFile.open(path);
    if (result.type == ResultType.done || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open the video: ${result.message}')),
    );
  }

  /// Local overrides for files renamed or re-dated from the panel, so the
  /// viewer shows the new name immediately without the caller having to
  /// rebuild the list it handed us.
  final Map<String, GalleryItem> _edited = {};

  bool _detailsOpen = false;

  GalleryItem _itemAt(int index) {
    final original = widget.items[index];
    return _edited[original.id] ?? original;
  }

  @override
  Widget build(BuildContext context) {
    final repo = GalleryScope.of(context);
    final item = _itemAt(_index);
    // Below this the drawer would leave no room for the picture, so it
    // becomes a sheet instead (§5 content-priority).
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: widget.items.length,
                  onPageChanged: (index) => setState(() => _index = index),
                  itemBuilder: (context, index) {
                    final current = _itemAt(index);
                    return _Page(
                      item: current,
                      repository: repo,
                      path: _pathFor(repo, current),
                      onPlay: () => _play(repo, current),
                    );
                  },
                ),
                _TopBar(
                  title: item.name,
                  subtitle: '${_index + 1} of ${widget.items.length}',
                  onClose: () => Navigator.of(context).pop(),
                  detailsOpen: _detailsOpen,
                  onDetails: () {
                    if (wide) {
                      setState(() => _detailsOpen = !_detailsOpen);
                    } else {
                      _showDetailsSheet(context, repo, item);
                    }
                  },
                ),
              ],
            ),
          ),
          // §7: enters over 200ms with an ease-out curve, leaves faster —
          // AnimatedSize handles both, and honours reduced-motion because
          // Flutter scales animation durations from the platform setting.
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: wide && _detailsOpen
                ? GalleryDetailsPanel(
                    key: ValueKey(item.id),
                    item: item,
                    repository: repo,
                    onClose: () => setState(() => _detailsOpen = false),
                    onEdited: (updated) => setState(() {
                      _edited[widget.items[_index].id] = updated;
                    }),
                  )
                : const SizedBox(height: double.infinity),
          ),
        ],
      ),
    );
  }

  /// On a narrow window the same panel arrives as a sheet from the bottom.
  void _showDetailsSheet(
    BuildContext context,
    GalleryRepository repo,
    GalleryItem item,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.85,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: GalleryDetailsPanel(
            item: item,
            repository: repo,
            onClose: () => Navigator.of(sheetContext).pop(),
            onEdited: (updated) {
              setState(() => _edited[item.id] = updated);
              Navigator.of(sheetContext).pop();
            },
          ),
        ),
      ),
    );
  }
}

class _Page extends StatefulWidget {
  const _Page({
    required this.item,
    required this.repository,
    required this.path,
    required this.onPlay,
  });

  final GalleryItem item;
  final GalleryRepository repository;
  final Future<String?> path;
  final VoidCallback onPlay;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  /// Set once the user has asked for a cloud placeholder to be fetched.
  /// Rendering the file is what triggers the download, so nothing reads it
  /// until this is true.
  bool _fetchApproved = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final repository = widget.repository;
    final onPlay = widget.onPlay;

    if (item.cloudOnly && !_fetchApproved) {
      return _CloudOnlyNotice(
        item: item,
        onFetch: () => setState(() => _fetchApproved = true),
      );
    }

    return FutureBuilder<String?>(
      future: widget.path,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white70,
              ),
            ),
          );
        }
        final file = snapshot.data;
        if (file == null) {
          return const Center(
            child: Text(
              'This file could not be opened.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          );
        }

        if (item.isVideo) {
          // No video player is bundled; the system's own handles playback,
          // which also means codecs the app would never carry.
          return _VideoPoster(
            item: item,
            repository: repository,
            onPlay: onPlay,
          );
        }

        return InteractiveViewer(
          maxScale: 6,
          child: Center(
            child: Image.file(
              File(file),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => const Center(
                child: Text(
                  'This image could not be decoded.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// What stands in for a photo that lives in the cloud. Opening it is a
/// download, and a download is the user's call — the gallery will happily
/// list a 40 GB OneDrive library, but it won't put it on their disk for them.
class _CloudOnlyNotice extends StatelessWidget {
  const _CloudOnlyNotice({required this.item, required this.onFetch});

  final GalleryItem item;
  final VoidCallback onFetch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_outlined, color: Colors.white54, size: 44),
            const SizedBox(height: 16),
            const Text(
              'This one is only in the cloud',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${item.name} is stored online and isn\'t on this PC. Showing '
              'it downloads it${item.sizeBytes == null ? '' : ' '
                  '(${formatBytes(item.sizeBytes!)})'} and keeps it here '
              'until your cloud app frees it up again.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onFetch,
              icon: const Icon(Icons.cloud_download_rounded, size: 18),
              label: const Text('Download and show'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPoster extends StatelessWidget {
  const _VideoPoster({
    required this.item,
    required this.repository,
    required this.onPlay,
  });

  final GalleryItem item;
  final GalleryRepository repository;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FutureBuilder(
          future: repository.thumbnail(item, 720),
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes == null) return const SizedBox.shrink();
            return Image.memory(bytes, fit: BoxFit.contain);
          },
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filled(
                onPressed: onPlay,
                iconSize: 38,
                padding: const EdgeInsets.all(18),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                ),
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                'Play ${formatDuration(item.duration)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.onClose,
    required this.onDetails,
    required this.detailsOpen,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final VoidCallback onDetails;
  final bool detailsOpen;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + 6,
          left: 4,
          right: 4,
          bottom: 10,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.65),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              // §1 aria-labels / §4 state-clarity: named, and the label says
              // which way the toggle will go.
              tooltip: detailsOpen ? 'Hide details' : 'Show details',
              isSelected: detailsOpen,
              onPressed: onDetails,
              icon: Icon(
                Icons.more_vert_rounded,
                color: detailsOpen ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

