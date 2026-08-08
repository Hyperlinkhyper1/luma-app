import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';

import '../../../../theme/luma_theme.dart';
import 'gallery_cache.dart';
import 'gallery_media.dart';
import 'gallery_repository.dart';
import 'gallery_scope.dart';
import 'gallery_smart.dart';
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

  @override
  Widget build(BuildContext context) {
    final repo = GalleryScope.of(context);
    final item = widget.items[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) {
              final current = widget.items[index];
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
            onInfo: () => _showDetails(context, repo, item),
          ),
        ],
      ),
    );
  }
}

void _showDetails(
  BuildContext context,
  GalleryRepository repo,
  GalleryItem item,
) {
  final luma = context.luma;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: luma.surface,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _DetailsSheet(item: item, repository: repo),
  );
}

class _Page extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: path,
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
    required this.onInfo,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final VoidCallback onInfo;

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
              onPressed: onInfo,
              icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Everything known about one file, including what the smart pass found.
class _DetailsSheet extends StatelessWidget {
  const _DetailsSheet({required this.item, required this.repository});

  final GalleryItem item;
  final GalleryRepository repository;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final entry = repository.cacheEntries[item.cacheKey];
    final labels = _readableLabels(entry);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            _Row(label: 'Taken', value: _formatDate(item.takenAt)),
            _Row(
              label: 'Folder',
              value: item.folder.isEmpty ? 'Unknown' : item.folder,
            ),
            if (item.width > 0 && item.height > 0)
              _Row(label: 'Size', value: '${item.width} × ${item.height}'),
            if (item.isVideo)
              _Row(label: 'Length', value: formatDuration(item.duration)),
            FutureBuilder<int?>(
              future: repository.fileSize(item),
              initialData: item.sizeBytes,
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                if (bytes == null) return const SizedBox.shrink();
                return _Row(label: 'On disk', value: formatBytes(bytes));
              },
            ),
            if (item.hasLocation)
              _Row(
                label: 'Location',
                value: '${item.latitude!.toStringAsFixed(5)}, '
                    '${item.longitude!.toStringAsFixed(5)}',
              ),
            if (labels.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final label in labels)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: luma.accentSubtle,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(color: luma.accent, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The model's own labels are raw vocabulary; only show the ones that map
  /// to a category a person would recognise, plus the face count.
  List<String> _readableLabels(GalleryCacheEntry? entry) {
    if (entry == null) return const [];
    final buckets = <String>{
      for (final label in entry.labels)
        if (bucketForLabel(label) != null) bucketForLabel(label)!,
    };
    return [
      if (entry.faceCount == 1) '1 face',
      if (entry.faceCount > 1) '${entry.faceCount} faces',
      ...buckets,
    ];
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: luma.textPrimary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime when) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${when.year}-${two(when.month)}-${two(when.day)} '
      '${two(when.hour)}:${two(when.minute)}';
}
