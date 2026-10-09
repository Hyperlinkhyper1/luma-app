import 'dart:math' as math;

import '../../../../../../l10n/app_localizations.dart';

/// An enchantment as the anvil sees it. Numbers are Minecraft 26.3's:
/// `anvilCost` is the multiplier for an item sacrifice, halved (minimum 1)
/// for a book.
class McEnchant {
  const McEnchant(
    this.id,
    this.maxLevel,
    this.anvilCost, {
    this.exclusive,
    this.curse = false,
  });

  final String id;
  final int maxLevel;
  final int anvilCost;

  /// The exclusive set this belongs to — two enchantments in the same set
  /// cannot share an item.
  final String? exclusive;
  final bool curse;

  int get bookMultiplier => math.max(1, anvilCost ~/ 2);

  /// Extra pairs the game rules out that are not in one shared set.
  static const _extraConflicts = {
    ('riptide', 'loyalty'),
    ('riptide', 'channeling'),
    ('infinity', 'mending'),
  };

  bool conflictsWith(McEnchant other) {
    if (other.id == id) return false;
    if (exclusive != null && exclusive == other.exclusive) return true;
    return _extraConflicts.contains((id, other.id)) ||
        _extraConflicts.contains((other.id, id));
  }
}

const Map<String, McEnchant> kMcEnchants = {
  'aqua_affinity': McEnchant('aqua_affinity', 1, 4),
  'bane_of_arthropods': McEnchant('bane_of_arthropods', 5, 2, exclusive: 'damage'),
  'binding_curse': McEnchant('binding_curse', 1, 8, curse: true),
  'blast_protection': McEnchant('blast_protection', 4, 4, exclusive: 'armor'),
  'breach': McEnchant('breach', 4, 4, exclusive: 'damage'),
  'channeling': McEnchant('channeling', 1, 8),
  'density': McEnchant('density', 5, 2, exclusive: 'damage'),
  'depth_strider': McEnchant('depth_strider', 3, 4, exclusive: 'boots'),
  'efficiency': McEnchant('efficiency', 5, 1),
  'feather_falling': McEnchant('feather_falling', 4, 2),
  'fire_aspect': McEnchant('fire_aspect', 2, 4),
  'fire_protection': McEnchant('fire_protection', 4, 2, exclusive: 'armor'),
  'flame': McEnchant('flame', 1, 4),
  'fortune': McEnchant('fortune', 3, 4, exclusive: 'mining'),
  'frost_walker': McEnchant('frost_walker', 2, 4, exclusive: 'boots'),
  'impaling': McEnchant('impaling', 5, 4, exclusive: 'damage'),
  'infinity': McEnchant('infinity', 1, 8, exclusive: 'bow'),
  'knockback': McEnchant('knockback', 2, 2),
  'looting': McEnchant('looting', 3, 4),
  'loyalty': McEnchant('loyalty', 3, 2),
  'luck_of_the_sea': McEnchant('luck_of_the_sea', 3, 4),
  'lunge': McEnchant('lunge', 3, 2),
  'lure': McEnchant('lure', 3, 4),
  'mending': McEnchant('mending', 1, 4, exclusive: 'bow'),
  'multishot': McEnchant('multishot', 1, 4, exclusive: 'crossbow'),
  'piercing': McEnchant('piercing', 4, 1, exclusive: 'crossbow'),
  'power': McEnchant('power', 5, 1),
  'projectile_protection': McEnchant('projectile_protection', 4, 2, exclusive: 'armor'),
  'protection': McEnchant('protection', 4, 1, exclusive: 'armor'),
  'punch': McEnchant('punch', 2, 4),
  'quick_charge': McEnchant('quick_charge', 3, 2),
  'respiration': McEnchant('respiration', 3, 4),
  'riptide': McEnchant('riptide', 3, 4, exclusive: 'riptide'),
  'sharpness': McEnchant('sharpness', 5, 1, exclusive: 'damage'),
  'silk_touch': McEnchant('silk_touch', 1, 8, exclusive: 'mining'),
  'smite': McEnchant('smite', 5, 2, exclusive: 'damage'),
  'soul_speed': McEnchant('soul_speed', 3, 8),
  'sweeping_edge': McEnchant('sweeping_edge', 3, 4),
  'swift_sneak': McEnchant('swift_sneak', 3, 8),
  'thorns': McEnchant('thorns', 3, 8),
  'unbreaking': McEnchant('unbreaking', 3, 2),
  'vanishing_curse': McEnchant('vanishing_curse', 1, 8, curse: true),
  'wind_burst': McEnchant('wind_burst', 3, 4),
};

/// Something you can put in the anvil's left slot, with the enchantments its
/// item tags allow.
class McEnchantable {
  const McEnchantable(this.id, this.label, this.enchants);

  /// An item id; `enchanted_book` merges books.
  final String id;
  final String label;
  final List<String> enchants;

  String localLabel(L t) => switch (id) {
    'netherite_sword' => t.mcEnchItemSword,
    'netherite_spear' => t.mcEnchItemSpear,
    'netherite_axe' => t.mcEnchItemAxe,
    'mace' => t.mcEnchItemMace,
    'trident' => t.mcEnchItemTrident,
    'bow' => t.mcEnchItemBow,
    'crossbow' => t.mcEnchItemCrossbow,
    'netherite_pickaxe' => t.mcEnchItemPickaxe,
    'netherite_shovel' => t.mcEnchItemShovel,
    'netherite_hoe' => t.mcEnchItemHoe,
    'netherite_helmet' => t.mcEnchItemHelmet,
    'netherite_chestplate' => t.mcEnchItemChestplate,
    'netherite_leggings' => t.mcEnchItemLeggings,
    'netherite_boots' => t.mcEnchItemBoots,
    'elytra' => t.mcEnchItemElytra,
    'fishing_rod' => t.mcEnchItemFishingRod,
    'shield' => t.mcEnchItemShield,
    'shears' => t.mcEnchItemShears,
    'flint_and_steel' => t.mcEnchItemFlintAndSteel,
    'brush' => t.mcEnchItemBrush,
    'carrot_on_a_stick' => t.mcEnchItemCarrotOnAStick,
    'enchanted_book' => t.mcEnchItemBookMerge,
    _ => label,
  };
}

const _durability = ['unbreaking', 'mending', 'vanishing_curse'];
const _armor = [
  'protection',
  'fire_protection',
  'blast_protection',
  'projectile_protection',
  'thorns',
  ..._durability,
  'binding_curse',
];
const _miningTool = ['efficiency', 'fortune', 'silk_touch', ..._durability];

const List<McEnchantable> kMcEnchantables = [
  McEnchantable('netherite_sword', 'Sword', [
    'sharpness', 'smite', 'bane_of_arthropods', 'knockback', 'fire_aspect',
    'looting', 'sweeping_edge', ..._durability,
  ]),
  McEnchantable('netherite_spear', 'Spear', [
    'sharpness', 'smite', 'bane_of_arthropods', 'knockback', 'fire_aspect',
    'looting', 'lunge', ..._durability,
  ]),
  McEnchantable('netherite_axe', 'Axe', [
    'sharpness', 'smite', 'bane_of_arthropods', ..._miningTool,
  ]),
  McEnchantable('mace', 'Mace', [
    'density', 'breach', 'smite', 'bane_of_arthropods', 'wind_burst',
    'fire_aspect', ..._durability,
  ]),
  McEnchantable('trident', 'Trident', [
    'impaling', 'loyalty', 'riptide', 'channeling', ..._durability,
  ]),
  McEnchantable('bow', 'Bow', [
    'power', 'punch', 'flame', 'infinity', ..._durability,
  ]),
  McEnchantable('crossbow', 'Crossbow', [
    'multishot', 'piercing', 'quick_charge', ..._durability,
  ]),
  McEnchantable('netherite_pickaxe', 'Pickaxe', _miningTool),
  McEnchantable('netherite_shovel', 'Shovel', _miningTool),
  McEnchantable('netherite_hoe', 'Hoe', _miningTool),
  McEnchantable('netherite_helmet', 'Helmet', [
    ..._armor, 'respiration', 'aqua_affinity',
  ]),
  McEnchantable('netherite_chestplate', 'Chestplate', _armor),
  McEnchantable('netherite_leggings', 'Leggings', [..._armor, 'swift_sneak']),
  McEnchantable('netherite_boots', 'Boots', [
    ..._armor, 'feather_falling', 'depth_strider', 'frost_walker', 'soul_speed',
  ]),
  McEnchantable('elytra', 'Elytra', [..._durability, 'binding_curse']),
  McEnchantable('fishing_rod', 'Fishing Rod', [
    'luck_of_the_sea', 'lure', ..._durability,
  ]),
  McEnchantable('shield', 'Shield', _durability),
  McEnchantable('shears', 'Shears', ['efficiency', ..._durability]),
  McEnchantable('flint_and_steel', 'Flint and Steel', _durability),
  McEnchantable('brush', 'Brush', _durability),
  McEnchantable('carrot_on_a_stick', 'Carrot on a Stick', _durability),
  McEnchantable('enchanted_book', 'Book (merge)', [
    'aqua_affinity', 'bane_of_arthropods', 'binding_curse', 'blast_protection',
    'breach', 'channeling', 'density', 'depth_strider', 'efficiency',
    'feather_falling', 'fire_aspect', 'fire_protection', 'flame', 'fortune',
    'frost_walker', 'impaling', 'infinity', 'knockback', 'looting', 'loyalty',
    'luck_of_the_sea', 'lunge', 'lure', 'mending', 'multishot', 'piercing',
    'power', 'projectile_protection', 'protection', 'punch', 'quick_charge',
    'respiration', 'riptide', 'sharpness', 'silk_touch', 'smite', 'soul_speed',
    'sweeping_edge', 'swift_sneak', 'thorns', 'unbreaking', 'vanishing_curse',
    'wind_burst',
  ]),
];

/// One enchanted book going into the anvil.
class McBook {
  const McBook(this.enchant, this.level);
  final McEnchant enchant;
  final int level;

  /// What this book adds to a step's cost when it is the sacrifice.
  int get value => level * enchant.bookMultiplier;

  @override
  String toString() => '${enchant.id} $level';
}

/// A node in the merge tree: a single input, or two merged in the anvil.
sealed class McAnvilNode {
  const McAnvilNode();

  /// Prior work penalty: how many anvil operations went into this.
  int get penalty;

  /// Enchantment value carried, charged again whenever this is a sacrifice.
  int get value;

  List<McBook> get books;
}

class McItemLeaf extends McAnvilNode {
  const McItemLeaf(this.priorWork);
  final int priorWork;
  @override
  int get penalty => priorWork;
  @override
  int get value => 0;
  @override
  List<McBook> get books => const [];
}

class McBookLeaf extends McAnvilNode {
  const McBookLeaf(this.book);
  final McBook book;
  @override
  int get penalty => 0;
  @override
  int get value => book.value;
  @override
  List<McBook> get books => [book];
}

class McMerge extends McAnvilNode {
  McMerge(this.target, this.sacrifice)
    : penalty = math.max(target.penalty, sacrifice.penalty) + 1,
      value = target.value + sacrifice.value,
      cost = sacrifice.value +
          mcPenaltyCost(target.penalty) +
          mcPenaltyCost(sacrifice.penalty);

  final McAnvilNode target;
  final McAnvilNode sacrifice;
  @override
  final int penalty;
  @override
  final int value;

  /// Levels this one anvil use costs.
  final int cost;

  @override
  List<McBook> get books => [...target.books, ...sacrifice.books];
}

/// The level cost an item's prior work adds: 2ⁿ − 1.
int mcPenaltyCost(int priorWork) => (1 << priorWork) - 1;

/// One anvil use, in the order the player makes them.
class McAnvilStep {
  const McAnvilStep(this.target, this.sacrifice, this.cost);
  final McAnvilNode target;
  final McAnvilNode sacrifice;
  final int cost;
}

class McAnvilPlan {
  const McAnvilPlan(this.root, this.steps);

  final McAnvilNode root;
  final List<McAnvilStep> steps;

  int get totalLevels => steps.fold(0, (s, e) => s + e.cost);
  int get maxStep => steps.fold(0, (s, e) => math.max(s, e.cost));
  int get finalPenalty => root.penalty;

  /// Experience points spent, paying each step from exactly that level.
  int get totalXp => steps.fold(0, (s, e) => s + mcXpForLevel(e.cost));
}

/// Points needed to go from level 0 to [level].
int mcXpForLevel(int level) {
  if (level <= 16) return level * level + 6 * level;
  if (level <= 31) return (2.5 * level * level - 40.5 * level + 360).round();
  return (4.5 * level * level - 162.5 * level + 2220).round();
}

class _State {
  const _State(this.node, this.total);
  final McAnvilNode node;
  final int total;
}

/// Finds the cheapest order to apply [books] to an item.
///
/// Exhaustive over merge trees by dynamic programming on subsets: for each
/// set of books it keeps the cheapest way to reach every possible prior-work
/// penalty, since a cheaper tree with a higher penalty can still lose later.
/// With [limit] set (39 in survival) any step costing more is ruled out.
/// [targetIsBook] merges the books into one book instead of an item.
McAnvilPlan? mcOptimizeAnvil(
  List<McBook> books, {
  int itemPriorWork = 0,
  int? limit = 39,
  bool targetIsBook = false,
}) {
  final n = books.length;
  if (n == 0) return null;
  if (n > 14) throw ArgumentError('Too many books to search ($n).');
  final full = (1 << n) - 1;

  // best[mask][penalty] for books only.
  final best = List<Map<int, _State>>.generate(1 << n, (_) => {});
  for (var i = 0; i < n; i++) {
    best[1 << i][0] = _State(McBookLeaf(books[i]), 0);
  }
  bool ok(int cost) => limit == null || cost <= limit;

  void offer(Map<int, _State> into, _State s) {
    final current = into[s.node.penalty];
    if (current == null || s.total < current.total) into[s.node.penalty] = s;
  }

  for (var mask = 1; mask <= full; mask++) {
    if (mask & (mask - 1) == 0) continue;
    // Every ordered split into (target, sacrifice).
    for (var sub = (mask - 1) & mask; sub > 0; sub = (sub - 1) & mask) {
      final other = mask ^ sub;
      for (final a in best[sub].values) {
        for (final b in best[other].values) {
          final merged = McMerge(a.node, b.node);
          if (!ok(merged.cost)) continue;
          offer(best[mask], _State(merged, a.total + b.total + merged.cost));
        }
      }
    }
  }

  _State? pick(Map<int, _State> states) {
    _State? winner;
    for (final s in states.values) {
      if (winner == null ||
          s.total < winner.total ||
          (s.total == winner.total && s.node.penalty < winner.node.penalty)) {
        winner = s;
      }
    }
    return winner;
  }

  if (targetIsBook) {
    final s = pick(best[full]);
    return s == null ? null : McAnvilPlan(s.node, _steps(s.node));
  }

  // The item can only ever be a target; books (or merged books) go onto it.
  final withItem = List<Map<int, _State>>.generate(1 << n, (_) => {});
  withItem[0][itemPriorWork] = _State(McItemLeaf(itemPriorWork), 0);
  for (var mask = 1; mask <= full; mask++) {
    for (var sac = mask; sac > 0; sac = (sac - 1) & mask) {
      final rest = mask ^ sac;
      for (final a in withItem[rest].values) {
        for (final b in best[sac].values) {
          final merged = McMerge(a.node, b.node);
          if (!ok(merged.cost)) continue;
          offer(withItem[mask], _State(merged, a.total + b.total + merged.cost));
        }
      }
    }
  }
  final s = pick(withItem[full]);
  return s == null ? null : McAnvilPlan(s.node, _steps(s.node));
}

List<McAnvilStep> _steps(McAnvilNode root) {
  final out = <McAnvilStep>[];
  void walk(McAnvilNode node) {
    if (node is! McMerge) return;
    // Book-only merges first, so the item sees as few uses as possible.
    walk(node.sacrifice);
    walk(node.target);
    out.add(McAnvilStep(node.target, node.sacrifice, node.cost));
  }

  walk(root);
  return out;
}

/// Roman numerals for enchantment levels.
String mcRoman(int n) => switch (n) {
  1 => 'I',
  2 => 'II',
  3 => 'III',
  4 => 'IV',
  5 => 'V',
  6 => 'VI',
  7 => 'VII',
  8 => 'VIII',
  9 => 'IX',
  10 => 'X',
  _ => '$n',
};
