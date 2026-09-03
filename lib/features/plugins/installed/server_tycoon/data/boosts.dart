// Timed, cash-bought multipliers. Each ticks down one day at rollover and is
// dropped when it expires; effects of the same kind multiply together.

class BoostDef {
  final String id;
  final String name;
  final String description;
  final int cost;
  final int durationDays;

  /// Multiplier on every rig's usable CPU capacity.
  final double capacityMultiplier;

  /// Multiplier on power draw when billing electricity.
  final double powerMultiplier;

  /// Multiplier on cooling headroom.
  final double coolingMultiplier;

  /// Multiplier on all service income.
  final double incomeMultiplier;

  /// Multiplier on contract payouts.
  final double contractPayoutMultiplier;

  /// Extra contract offers rolled per day.
  final int extraContractOffers;

  /// Fraction by which the per-second incident chance is reduced.
  final double incidentResistance;

  const BoostDef({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.durationDays,
    this.capacityMultiplier = 1.0,
    this.powerMultiplier = 1.0,
    this.coolingMultiplier = 1.0,
    this.incomeMultiplier = 1.0,
    this.contractPayoutMultiplier = 1.0,
    this.extraContractOffers = 0,
    this.incidentResistance = 0,
  });
}

final Map<String, BoostDef> boostDefsById = {
  'OVERCLOCK': const BoostDef(
    id: 'OVERCLOCK',
    name: 'Overclock',
    description: 'Push every rig 25% past spec. Costs you 30% more power and runs hotter.',
    cost: 450,
    durationDays: 3,
    capacityMultiplier: 1.25,
    powerMultiplier: 1.30,
    coolingMultiplier: 0.90,
  ),
  'MARKETING_PUSH': const BoostDef(
    id: 'MARKETING_PUSH',
    name: 'Marketing Push',
    description: 'An ad spend that brings in an extra contract offer a day and 15% better payouts.',
    cost: 700,
    durationDays: 5,
    contractPayoutMultiplier: 1.15,
    extraContractOffers: 1,
  ),
  'COLD_SNAP': const BoostDef(
    id: 'COLD_SNAP',
    name: 'Cold Snap',
    description: 'Rented portable chillers give 20% more cooling headroom and steadier hardware.',
    cost: 380,
    durationDays: 3,
    coolingMultiplier: 1.20,
    incidentResistance: 0.25,
  ),
  'SURGE_PRICING': const BoostDef(
    id: 'SURGE_PRICING',
    name: 'Surge Pricing',
    description: 'Charge peak rates for two days: 35% more service income while it lasts.',
    cost: 900,
    durationDays: 2,
    incomeMultiplier: 1.35,
  ),
};

late final List<BoostDef> boostDefList = boostDefsById.values.toList()
  ..sort((a, b) => a.cost.compareTo(b.cost));

/// A purchased boost with days left on the clock.
class ActiveBoost {
  final String defId;
  int daysRemaining;

  ActiveBoost({required this.defId, required this.daysRemaining});

  BoostDef? get def => boostDefsById[defId];

  Map<String, dynamic> toJson() => {'defId': defId, 'daysRemaining': daysRemaining};

  factory ActiveBoost.fromJson(Map<String, dynamic> json) => ActiveBoost(
        defId: json['defId'] as String,
        daysRemaining: json['daysRemaining'] as int,
      );
}

/// Combined effect of everything currently running.
class BoostEffects {
  final double capacityMultiplier;
  final double powerMultiplier;
  final double coolingMultiplier;
  final double incomeMultiplier;
  final double contractPayoutMultiplier;
  final int extraContractOffers;
  final double incidentResistance;

  const BoostEffects({
    this.capacityMultiplier = 1.0,
    this.powerMultiplier = 1.0,
    this.coolingMultiplier = 1.0,
    this.incomeMultiplier = 1.0,
    this.contractPayoutMultiplier = 1.0,
    this.extraContractOffers = 0,
    this.incidentResistance = 0,
  });

  static const none = BoostEffects();
}

BoostEffects getBoostEffects(List<ActiveBoost> active) {
  var capacity = 1.0;
  var power = 1.0;
  var cooling = 1.0;
  var income = 1.0;
  var payout = 1.0;
  var offers = 0;
  var resistance = 0.0;

  for (final boost in active) {
    final def = boost.def;
    if (def == null || boost.daysRemaining <= 0) continue;
    capacity *= def.capacityMultiplier;
    power *= def.powerMultiplier;
    cooling *= def.coolingMultiplier;
    income *= def.incomeMultiplier;
    payout *= def.contractPayoutMultiplier;
    offers += def.extraContractOffers;
    // Stacking resistances combine multiplicatively rather than summing past 1.
    resistance = 1 - (1 - resistance) * (1 - def.incidentResistance);
  }

  return BoostEffects(
    capacityMultiplier: capacity,
    powerMultiplier: power,
    coolingMultiplier: cooling,
    incomeMultiplier: income,
    contractPayoutMultiplier: payout,
    extraContractOffers: offers,
    incidentResistance: resistance.clamp(0, 0.9),
  );
}
