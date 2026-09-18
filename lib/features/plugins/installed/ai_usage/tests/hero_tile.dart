import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';

/// The purple wash that fills the bottom third of a [LumaHeroTile] and hazes
/// up into the artwork above it.
///
/// The full recipe — why these numbers are what they are, and how to keep a
/// new tile matching the old ones — is written down in `HERO_TILE.md` next to
/// this file. Change the numbers there and here together, or the next tile
/// will not match this one.
class HeroTileWash {
  const HeroTileWash._();

  /// Where the solid band begins: the bottom third of the tile, exactly.
  static const double solidStart = 2 / 3;

  /// Top of the purple band, and the colour the haze above it is made of.
  static const Color purple = Color(0xFF7E43C9);

  /// Bottom of the purple band. A little deeper than [purple] so the band has
  /// a floor and does not read as a flat sticker pasted over the artwork.
  static const Color purpleDeep = Color(0xFF6B31B0);

  /// Painted over the artwork, top to bottom.
  ///
  /// Fully transparent through the upper half, then four steps of rising
  /// alpha across the middle — that ramp is the transition, and it is what
  /// makes the artwork dissolve into the purple instead of being cut off by
  /// it. The band is opaque from [solidStart] down.
  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x007E43C9),
      Color(0x387E43C9),
      Color(0x9E7E43C9),
      Color(0xEB7E43C9),
      purple,
      purpleDeep,
    ],
    stops: [0.40, 0.52, 0.60, 0.655, solidStart, 1.0],
  );

  /// The stand-in painted when [LumaHeroTile.imageAsset] is missing, so a tile
  /// whose artwork has not been dropped in yet still looks deliberate rather
  /// than broken.
  static const LinearGradient fallback = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF2B3CB), Color(0xFFE3A0C6), Color(0xFFC98BC0)],
  );
}

/// A large artwork tile that acts as a single button.
///
/// The artwork fills the tile, a purple wash owns the bottom third, and the
/// label sits inside that band — so the text always lands on a solid colour
/// and stays readable whatever the image behind it is doing.
///
/// The wash is painted at runtime by [HeroTileWash]. The image behind it must
/// always be the untouched artwork: baking the purple into the PNG would
/// freeze it at one aspect ratio and drift away from every other tile the
/// first time the palette moves.
class LumaHeroTile extends StatefulWidget {
  const LumaHeroTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageAsset,
    this.imageFile,
    required this.fallbackIcon,
    required this.onTap,
    this.width = 340,
    this.aspectRatio = 1,
  });

  final String title;
  final String subtitle;

  /// Bundled artwork. Prefer [imageFile] for anything downloaded at runtime —
  /// benchmark tile art lives on the luma server now, not in the bundle.
  final String? imageAsset;

  /// A downloaded artwork file (server-cached tile art). Wins over
  /// [imageAsset] when both are set; when neither resolves, the tile shows
  /// the gradient stand-in with [fallbackIcon].
  final File? imageFile;
  final IconData fallbackIcon;
  final VoidCallback onTap;
  final double width;
  final double aspectRatio;

  @override
  State<LumaHeroTile> createState() => _LumaHeroTileState();
}

class _LumaHeroTileState extends State<LumaHeroTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final radius = context.lumaDecor.cardBorderRadius;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: widget.width,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: HeroTileWash.purpleDeep.withValues(
                alpha: _hovered ? 0.34 : 0.16,
              ),
              blurRadius: _hovered ? 26 : 14,
              offset: Offset(0, _hovered ? 12 : 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The artwork. It creeps closer on hover, which reads as the
                // whole tile lifting rather than as a separate animation.
                AnimatedScale(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  scale: _hovered ? 1.04 : 1,
                  child: _TileArtwork(
                    imageAsset: widget.imageAsset,
                    imageFile: widget.imageFile,
                    fallbackIcon: widget.fallbackIcon,
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: HeroTileWash.gradient),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 12.5,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedSlide(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              offset: Offset(_hovered ? 0.25 : 0, 0),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Kept last so the ripple and the focus ring land on top of
                // the artwork instead of underneath it.
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: widget.onTap,
                    focusColor: Colors.white.withValues(alpha: 0.12),
                    highlightColor: Colors.white.withValues(alpha: 0.06),
                    splashColor: Colors.white.withValues(alpha: 0.14),
                    child: Semantics(
                      label: '${widget.title} — ${widget.subtitle}',
                      button: true,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The artwork layer of a [LumaHeroTile]: a downloaded file first, then a
/// bundled asset, then the gradient stand-in — so a tile whose artwork hasn't
/// downloaded (or was never made) still looks deliberate rather than broken.
class _TileArtwork extends StatelessWidget {
  const _TileArtwork({
    this.imageAsset,
    this.imageFile,
    required this.fallbackIcon,
  });

  final String? imageAsset;
  final File? imageFile;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => DecoratedBox(
          decoration: const BoxDecoration(
            gradient: HeroTileWash.fallback,
          ),
          child: Align(
            alignment: const Alignment(0, -0.35),
            child: Icon(
              fallbackIcon,
              size: 56,
              color: Colors.white.withValues(alpha: 0.62),
            ),
          ),
        );

    final file = imageFile;
    if (file != null) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (context, error, stack) => fallback(),
      );
    }
    final asset = imageAsset;
    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (context, error, stack) => fallback(),
      );
    }
    return fallback();
  }
}
