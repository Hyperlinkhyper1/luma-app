import 'package:flutter/material.dart';

import '../../../../theme/luma_theme.dart';
import 'gallery_media.dart';
import 'gallery_repository.dart';
import 'gallery_tile.dart';

/// One album on the albums screen: its newest photo as the cover, its name,
/// and how much is in it.
class GalleryAlbumCard extends StatefulWidget {
  const GalleryAlbumCard({
    super.key,
    required this.label,
    required this.icon,
    required this.count,
    required this.repository,
    required this.onTap,
    this.cover,
    this.subtitle,
    this.badge,
  });

  final String label;

  /// Shown in place of a cover while the album is empty, and always as the
  /// small glyph over the corner.
  final IconData icon;

  final int count;
  final GalleryItem? cover;
  final GalleryRepository repository;
  final VoidCallback onTap;

  /// Replaces the item count under the name — the smart teaser uses it.
  final String? subtitle;

  /// Optional word over the cover, e.g. "Nova".
  final String? badge;

  @override
  State<GalleryAlbumCard> createState() => _GalleryAlbumCardState();
}

class _GalleryAlbumCardState extends State<GalleryAlbumCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final cover = widget.cover;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: AnimatedScale(
                scale: _hovered ? 1.02 : 1,
                duration: const Duration(milliseconds: 120),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: luma.surface),
                      if (cover != null)
                        GalleryThumbnail(
                          item: cover,
                          repository: widget.repository,
                          pixels: 384,
                          placeholderSize: 26,
                        )
                      else
                        Center(
                          child: Icon(
                            widget.icon,
                            color: luma.textMuted,
                            size: 26,
                          ),
                        ),
                      if (widget.badge != null)
                        Positioned(
                          left: 6,
                          top: 6,
                          child: _Chip(
                            label: widget.badge!,
                            background: luma.accent,
                            foreground: luma.onAccent,
                          ),
                        ),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: _Chip(
                          icon: widget.icon,
                          background: Colors.black.withValues(alpha: 0.5),
                          foreground: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.label,
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
              widget.subtitle ?? _countLabel(widget.count),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: luma.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

String _countLabel(int count) => count == 1 ? '1 item' : '$count items';

class _Chip extends StatelessWidget {
  const _Chip({
    this.label,
    this.icon,
    required this.background,
    required this.foreground,
  });

  final String? label;
  final IconData? icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: label == null ? 4 : 7,
        vertical: label == null ? 4 : 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: label != null
          ? Text(
              label!,
              style: TextStyle(
                color: foreground,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            )
          : Icon(icon, size: 13, color: foreground),
    );
  }
}
