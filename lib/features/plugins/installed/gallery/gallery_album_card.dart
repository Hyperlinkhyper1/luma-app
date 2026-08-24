import 'package:flutter/material.dart';

import '../../../../theme/luma_theme.dart';
import 'gallery_media.dart';
import 'gallery_repository.dart';
import 'gallery_tile.dart';

/// One album on the albums screen: its newest photo as the cover, its name,
/// and how much is in it.
///
/// The cover can also be a [covers] mosaic — up to four photos in a 2×2
/// grid — which is what the smart categories use: four pictures of dogs say
/// "Pets" faster than any label under an empty-ish single frame would.
class GalleryAlbumCard extends StatefulWidget {
  const GalleryAlbumCard({
    super.key,
    required this.label,
    required this.icon,
    required this.count,
    required this.repository,
    required this.onTap,
    this.cover,
    this.covers = const [],
    this.subtitle,
    this.badge,
    this.spotlight = false,
  });

  final String label;

  /// Shown over an empty cover — the album has nothing in it yet.
  final IconData icon;

  final int count;

  /// The newest item, for a single-photo cover. Ignored when [covers] has
  /// enough to fill a mosaic.
  final GalleryItem? cover;

  /// Up to four photos for a 2×2 mosaic cover.
  final List<GalleryItem> covers;

  final GalleryRepository repository;
  final VoidCallback onTap;

  /// Replaces the item count under the name — the smart teaser uses it.
  final String? subtitle;

  /// Optional word over the cover, e.g. "Nova".
  final String? badge;

  /// Draws the empty-cover state as a gradient with the icon on it, for
  /// cards that are selling something rather than showing something.
  final bool spotlight;

  @override
  State<GalleryAlbumCard> createState() => _GalleryAlbumCardState();
}

class _GalleryAlbumCardState extends State<GalleryAlbumCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final mosaic =
        widget.covers.length >= 4 ? widget.covers.sublist(0, 4) : null;
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
                curve: Curves.easeOut,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: luma.surface),
                      if (mosaic != null)
                        _MosaicCover(
                          items: mosaic,
                          repository: widget.repository,
                        )
                      else if (cover != null)
                        GalleryThumbnail(
                          item: cover,
                          repository: widget.repository,
                          pixels: 384,
                          placeholderSize: 26,
                        )
                      else ...[
                        // A quiet tint behind the icon keeps an empty album
                        // from reading as a broken image; a card that is
                        // selling something gets the louder gradient.
                        Container(
                          decoration: BoxDecoration(
                            gradient: widget.spotlight
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      luma.accent.withValues(alpha: 0.55),
                                      luma.accentSubtle,
                                    ],
                                  )
                                : null,
                            color:
                                widget.spotlight ? null : luma.accentSubtle,
                          ),
                        ),
                        Center(
                          child: Icon(
                            widget.icon,
                            color: widget.spotlight
                                ? luma.onAccent
                                : luma.textMuted,
                            size: 26,
                          ),
                        ),
                      ],
                      // A hairline that lights up on hover gives desktop
                      // keyboards-and-mice users the feedback a tap gives a
                      // finger, without putting chrome on every card.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _hovered
                                    ? luma.accent.withValues(alpha: 0.7)
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                          ),
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

/// Four thumbnails in a two-by-two grid, with hairline gaps so each picture
/// stays its own picture rather than one blurry composite.
class _MosaicCover extends StatelessWidget {
  const _MosaicCover({required this.items, required this.repository});

  final List<GalleryItem> items;
  final GalleryRepository repository;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < 2; row++)
          Expanded(
            child: Row(
              children: [
                for (var column = 0; column < 2; column++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: column == 1 ? 1 : 0,
                        top: row == 1 ? 1 : 0,
                      ),
                      child: GalleryThumbnail(
                        item: items[row * 2 + column],
                        repository: repository,
                        pixels: 192,
                        placeholderSize: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    this.label,
    required this.background,
    required this.foreground,
  });

  final String? label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label!,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
