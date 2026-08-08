import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../theme/luma_theme.dart';
import 'gallery_media.dart';
import 'gallery_repository.dart';

/// One square in the grid. Asks the repository for a thumbnail when it first
/// appears and holds on to the request, so a tile scrolled off and back on
/// doesn't start a second decode.
class GalleryTile extends StatefulWidget {
  const GalleryTile({
    super.key,
    required this.item,
    required this.repository,
    required this.onTap,
    this.pixels = 256,
  });

  final GalleryItem item;
  final GalleryRepository repository;
  final VoidCallback onTap;

  /// Long edge of the thumbnail to request, in pixels.
  final int pixels;

  @override
  State<GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends State<GalleryTile> {
  Future<Uint8List?>? _thumbnail;

  @override
  void initState() {
    super.initState();
    _request();
  }

  @override
  void didUpdateWidget(GalleryTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) _request();
  }

  void _request() {
    _thumbnail = widget.repository.thumbnail(widget.item, widget.pixels);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final item = widget.item;

    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: luma.surface),
            FutureBuilder<Uint8List?>(
              future: _thumbnail,
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                if (bytes == null) {
                  return Center(
                    child: Icon(
                      item.isVideo
                          ? Icons.movie_rounded
                          : Icons.image_rounded,
                      color: luma.textMuted,
                      size: 22,
                    ),
                  );
                }
                return Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  cacheWidth: widget.pixels,
                  errorBuilder: (context, error, stack) => Center(
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: luma.textMuted,
                      size: 22,
                    ),
                  ),
                );
              },
            ),
            if (item.isVideo)
              Positioned(
                right: 4,
                bottom: 4,
                child: _Badge(
                  label: formatDuration(item.duration),
                  icon: Icons.play_arrow_rounded,
                ),
              )
            else if (item.isGif)
              const Positioned(
                right: 4,
                bottom: 4,
                child: _Badge(label: 'GIF'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small dark chip over the bottom corner of a tile.
class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: Colors.white),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// `4:07`, or `1:02:11` once a video runs past the hour.
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  final paddedSeconds = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$paddedSeconds';
  }
  return '$minutes:$paddedSeconds';
}

/// `4.2 MB`, for the detail sheet.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[unit]}';
}
