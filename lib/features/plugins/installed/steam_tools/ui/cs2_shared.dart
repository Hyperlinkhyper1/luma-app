import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';

/// Parses the dataset's "#eb4b4b" rarity colour. Falls back to Steam's own
/// Consumer Grade grey on anything unparseable, rather than crashing a tile
/// over a malformed catalog entry.
Color parseCs2RarityColor(String hex) {
  final cleaned = hex.replaceAll('#', '');
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return const Color(0xffb0c3d9);
  return Color(0xff000000 | value);
}

/// Rarity as a coloured dot plus its name — colour alone is never the only
/// way this is conveyed, since colourblind users get the exact same tile
/// otherwise.
class Cs2RarityChip extends StatelessWidget {
  const Cs2RarityChip({super.key, required this.name, required this.colorHex});

  final String name;
  final String colorHex;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = parseCs2RarityColor(colorHex);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: luma.textSecondary, fontSize: 11.5),
          ),
        ),
      ],
    );
  }
}

/// The item's render on a themed backdrop, with a placeholder that holds the
/// same box so tiles don't reflow as images arrive.
class Cs2ItemImage extends StatelessWidget {
  const Cs2ItemImage({super.key, required this.url, this.padding = 10});

  final String url;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (url.isEmpty) {
      return ColoredBox(
        color: luma.background,
        child: Icon(Icons.inventory_2_outlined, color: luma.textMuted),
      );
    }
    return ColoredBox(
      color: luma.background,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : const SizedBox.shrink(),
          errorBuilder: (context, _, _) => Icon(
            Icons.inventory_2_outlined,
            color: luma.textMuted,
          ),
        ),
      ),
    );
  }
}
