import 'package:flutter/material.dart';

/// One brewable potion, Java Edition 26.3. Durations are in seconds for the
/// drinkable potion; 0 means instant. Splash potions last as long, lingering
/// clouds and tipped arrows a quarter and an eighth.
class McPotion {
  const McPotion({
    required this.id,
    required this.name,
    required this.effect,
    required this.color,
    required this.ingredient,
    this.base = 'awkward',
    this.duration = 180,
    this.extended,
    this.strong,
    this.strongDuration,
    this.corruptsInto,
    this.positive = true,
  });

  /// The potion id, as `/give @p potion[potion_contents={potion:"…"}]` uses.
  final String id;
  final String name;
  final String effect;
  final Color color;

  /// The item brewed into [base] to make this.
  final String ingredient;

  /// `awkward`, `water`, or another potion id when made by corruption.
  final String base;
  final int duration;

  /// Redstone-extended duration, when the potion takes redstone.
  final int? extended;

  /// The id of the glowstone-strengthened (level II) version.
  final String? strong;
  final int? strongDuration;

  /// What a fermented spider eye turns this into.
  final String? corruptsInto;
  final bool positive;
}

const kMcPotionGuide = [
  McPotion(
    id: 'swiftness',
    name: 'Swiftness',
    effect: 'speed',
    color: Color(0xFF33EBFF),
    ingredient: 'sugar',
    extended: 480,
    strong: 'strong_swiftness',
    strongDuration: 90,
    corruptsInto: 'slowness',
  ),
  McPotion(
    id: 'leaping',
    name: 'Leaping',
    effect: 'jump_boost',
    color: Color(0xFFFDFF84),
    ingredient: 'rabbit_foot',
    extended: 480,
    strong: 'strong_leaping',
    strongDuration: 90,
    corruptsInto: 'slowness',
  ),
  McPotion(
    id: 'strength',
    name: 'Strength',
    effect: 'strength',
    color: Color(0xFFFFC700),
    ingredient: 'blaze_powder',
    extended: 480,
    strong: 'strong_strength',
    strongDuration: 90,
  ),
  McPotion(
    id: 'healing',
    name: 'Healing',
    effect: 'instant_health',
    color: Color(0xFFF82423),
    ingredient: 'glistering_melon_slice',
    duration: 0,
    strong: 'strong_healing',
    strongDuration: 0,
    corruptsInto: 'harming',
  ),
  McPotion(
    id: 'regeneration',
    name: 'Regeneration',
    effect: 'regeneration',
    color: Color(0xFFCD5CAB),
    ingredient: 'ghast_tear',
    duration: 45,
    extended: 90,
    strong: 'strong_regeneration',
    strongDuration: 22,
  ),
  McPotion(
    id: 'poison',
    name: 'Poison',
    effect: 'poison',
    color: Color(0xFF87A363),
    ingredient: 'spider_eye',
    duration: 45,
    extended: 90,
    strong: 'strong_poison',
    strongDuration: 21,
    corruptsInto: 'harming',
    positive: false,
  ),
  McPotion(
    id: 'fire_resistance',
    name: 'Fire Resistance',
    effect: 'fire_resistance',
    color: Color(0xFFFF9900),
    ingredient: 'magma_cream',
    extended: 480,
  ),
  McPotion(
    id: 'water_breathing',
    name: 'Water Breathing',
    effect: 'water_breathing',
    color: Color(0xFF98DAC0),
    ingredient: 'pufferfish',
    extended: 480,
  ),
  McPotion(
    id: 'night_vision',
    name: 'Night Vision',
    effect: 'night_vision',
    color: Color(0xFFC2FF66),
    ingredient: 'golden_carrot',
    extended: 480,
    corruptsInto: 'invisibility',
  ),
  McPotion(
    id: 'slow_falling',
    name: 'Slow Falling',
    effect: 'slow_falling',
    color: Color(0xFFF3CFB9),
    ingredient: 'phantom_membrane',
    duration: 90,
    extended: 240,
  ),
  McPotion(
    id: 'turtle_master',
    name: 'Turtle Master',
    effect: 'resistance',
    color: Color(0xFF8E9EA2),
    ingredient: 'turtle_helmet',
    duration: 20,
    extended: 40,
    strong: 'strong_turtle_master',
    strongDuration: 20,
  ),
  McPotion(
    id: 'wind_charged',
    name: 'Wind Charging',
    effect: 'wind_charged',
    color: Color(0xFFBDC9FF),
    ingredient: 'breeze_rod',
    positive: false,
  ),
  McPotion(
    id: 'weaving',
    name: 'Weaving',
    effect: 'weaving',
    color: Color(0xFF78695A),
    ingredient: 'cobweb',
    positive: false,
  ),
  McPotion(
    id: 'oozing',
    name: 'Oozing',
    effect: 'oozing',
    color: Color(0xFF99FFA3),
    ingredient: 'slime_block',
    positive: false,
  ),
  McPotion(
    id: 'infested',
    name: 'Infestation',
    effect: 'infested',
    color: Color(0xFF8C9B8C),
    ingredient: 'stone',
    positive: false,
  ),
  McPotion(
    id: 'slowness',
    name: 'Slowness',
    effect: 'slowness',
    color: Color(0xFF8BAFE0),
    ingredient: 'fermented_spider_eye',
    base: 'swiftness',
    duration: 90,
    extended: 240,
    strong: 'strong_slowness',
    strongDuration: 20,
    positive: false,
  ),
  McPotion(
    id: 'harming',
    name: 'Harming',
    effect: 'instant_damage',
    color: Color(0xFFA9656A),
    ingredient: 'fermented_spider_eye',
    base: 'healing',
    duration: 0,
    strong: 'strong_harming',
    strongDuration: 0,
    positive: false,
  ),
  McPotion(
    id: 'invisibility',
    name: 'Invisibility',
    effect: 'invisibility',
    color: Color(0xFFF6F6F6),
    ingredient: 'fermented_spider_eye',
    base: 'night_vision',
    extended: 480,
  ),
  McPotion(
    id: 'weakness',
    name: 'Weakness',
    effect: 'weakness',
    color: Color(0xFF484D48),
    ingredient: 'fermented_spider_eye',
    base: 'water',
    duration: 90,
    extended: 240,
    positive: false,
  ),
];

/// "3:00", or "Instant".
String mcDuration(int seconds, {String instant = '—'}) {
  if (seconds == 0) return instant;
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
