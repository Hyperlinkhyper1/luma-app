/// Shapes for the tables `tool/mc_data/generate.dart` writes. Kept by hand so
/// the generated files are nothing but `const` data.
library;

/// One villager trade: what the villager wants and what it gives back.
class McTrade {
  const McTrade({
    required this.id,
    required this.wants,
    this.wantsCount = 1,
    this.extra,
    this.extraCount = 1,
    required this.gives,
    this.givesCount = 1,
    this.maxUses,
    this.xp,
    this.notes = const [],
  });

  final String id;
  final String wants;

  /// Zero for the librarian's books, whose price is rolled from the
  /// enchantment level rather than fixed.
  final int wantsCount;
  final String? extra;
  final int extraCount;
  final String gives;
  final int givesCount;
  final int? maxUses;
  final int? xp;
  final List<String> notes;
}

/// The trades one level (or one wandering-trader list) draws from.
class McTradePool {
  const McTradePool({
    required this.id,
    required this.picks,
    required this.trades,
  });

  /// `level_1` … `level_5`, or `common`, `uncommon`, `buying`.
  final String id;

  /// How many of [trades] a villager reaching this level is given.
  final int picks;
  final List<McTrade> trades;

  /// The chance any one trade in this pool is among those picked.
  double get chance =>
      trades.isEmpty ? 0 : (picks / trades.length).clamp(0, 1).toDouble();
}

class McTradeOwner {
  const McTradeOwner({required this.id, required this.pools});

  /// A profession id, or `wandering_trader`.
  final String id;
  final List<McTradePool> pools;
}

/// A behaviour a sulfur cube takes on while holding a block.
class McCubeArchetype {
  const McCubeArchetype({
    required this.id,
    required this.buoyant,
    required this.knockbackResistance,
    required this.bounciness,
    required this.friction,
    required this.airDrag,
    required this.knockbackHorizontal,
    required this.knockbackVertical,
    required this.pushCooldown,
    this.explosionPower,
    this.explosionFuse,
    this.explosionFire = false,
    this.contactDamage,
    required this.groups,
    required this.blocks,
  });

  final String id;
  final bool buoyant;

  /// Added to the knockback_resistance attribute; negative means easier to
  /// shove.
  final double knockbackResistance;
  final double bounciness;

  /// Multiplier offsets (add_multiplied_total) on friction and air drag.
  final double friction;
  final double airDrag;
  final double knockbackHorizontal;
  final double knockbackVertical;

  /// Seconds between push sounds — how often a shove "lands".
  final double pushCooldown;
  final double? explosionPower;

  /// Fuse in ticks.
  final int? explosionFuse;
  final bool explosionFire;
  final double? contactDamage;

  /// The item tags that feed this archetype, e.g. `logs`.
  final List<String> groups;

  /// Every block item that triggers it, tags expanded.
  final List<String> blocks;
}

class McFlatLayer {
  const McFlatLayer(this.block, this.height);
  final String block;
  final int height;
}

class McFlatPreset {
  const McFlatPreset({
    required this.id,
    required this.icon,
    required this.biome,
    required this.features,
    required this.lakes,
    required this.structures,
    required this.layers,
  });

  final String id;
  final String icon;
  final String biome;
  final bool features;
  final bool lakes;
  final List<String> structures;

  /// Bottom to top.
  final List<McFlatLayer> layers;
}

/// One placed ore feature: how many attempts a chunk makes and over which
/// heights they are spread.
class McOrePlacement {
  const McOrePlacement({
    required this.feature,
    required this.perChunk,
    required this.trapezoid,
    required this.minY,
    required this.maxY,
    required this.size,
    required this.airDiscard,
    this.biome,
  });

  final String feature;

  /// Attempts per chunk; below 1 for rarity-filtered features.
  final double perChunk;

  /// Triangular when true (peaking halfway between [minY] and [maxY]),
  /// uniform otherwise.
  final bool trapezoid;
  final int minY;
  final int maxY;

  /// The vein size the feature is configured with.
  final int size;

  /// Chance a block touching air is skipped — why diamonds are scarce in
  /// cave walls.
  final double airDiscard;

  /// Set when the feature only runs in one biome.
  final String? biome;

  /// Relative attempt density at [y]: the share of this feature's attempts
  /// landing on that layer, times attempts per chunk.
  double densityAt(int y) {
    if (y < minY || y > maxY) return 0;
    final span = (maxY - minY + 1).toDouble();
    if (!trapezoid) return perChunk / span;
    final mid = (minY + maxY) / 2;
    final half = span / 2;
    final weight = (1 - (y - mid).abs() / half).clamp(0, 1).toDouble();
    return perChunk * weight / half;
  }
}

class McOre {
  const McOre({
    required this.id,
    required this.nether,
    required this.placements,
  });

  final String id;
  final bool nether;
  final List<McOrePlacement> placements;
}
