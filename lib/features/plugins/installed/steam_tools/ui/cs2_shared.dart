import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../steam_price_history.dart' show formatSteamPrice;

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

/// A currency delta shown as a signed, coloured figure with its percent
/// underneath — "+$12.34" / "+5.2%" in [LumaPalette.success] for a gain,
/// "-$3.00" / "-1.1%" in [LumaPalette.danger] for a loss. Shared between the
/// item detail page's starting-price card and the Tracked tab's portfolio
/// total, since both are "current minus some baseline" figures.
class Cs2GainLossBadge extends StatelessWidget {
  const Cs2GainLossBadge({
    super.key,
    required this.deltaCents,
    required this.startingCents,
    required this.currency,
  });

  final int deltaCents;

  /// The baseline the percent is computed against — zero means no percent
  /// is shown at all, since a percentage change from nothing is undefined,
  /// not zero.
  final int startingCents;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final flat = deltaCents == 0;
    final gain = deltaCents > 0;
    final color = flat ? luma.textSecondary : (gain ? luma.success : luma.danger);
    final percent = startingCents == 0 ? null : deltaCents / startingCents * 100;
    final sign = flat ? '' : (gain ? '+' : '-');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$sign${formatSteamPrice(deltaCents.abs(), currency)}',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (percent != null) ...[
          const SizedBox(height: 2),
          Text(
            '$sign${percent.abs().toStringAsFixed(1)}%',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
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
