// Hireable staff — daily salary, passive management-layer bonuses.

enum StaffRole { sysadmin, electrician, salesRep }

class StaffDef {
  final String id;
  final StaffRole role;
  final String name;
  final String description;
  final double dailySalary;
  final double effectMagnitude;
  final int minReputation;
  final String? requiresLicense;
  final String? requiresResearch;
  final int cost;

  const StaffDef({
    required this.id,
    required this.role,
    required this.name,
    required this.description,
    required this.dailySalary,
    required this.effectMagnitude,
    required this.minReputation,
    this.requiresLicense,
    this.requiresResearch,
    required this.cost,
  });
}

final Map<String, StaffDef> staffDefsById = {
  'SYSADMIN': const StaffDef(
    id: 'SYSADMIN',
    role: StaffRole.sysadmin,
    name: 'Jordan the Sysadmin',
    description: 'Quietly resolves minor incidents (overheating, cooling leaks, DDoS) before they cost you anything.',
    dailySalary: 40,
    effectMagnitude: 0.5,
    minReputation: 0,
    cost: 300,
  ),
  'ELECTRICIAN': const StaffDef(
    id: 'ELECTRICIAN',
    role: StaffRole.electrician,
    name: 'Sam the Electrician',
    description: 'Keeps your wiring and PDUs efficient, shaving an extra 8% off your electricity bill.',
    dailySalary: 35,
    effectMagnitude: 0.08,
    minReputation: 5,
    cost: 350,
  ),
  'SALES_REP': const StaffDef(
    id: 'SALES_REP',
    role: StaffRole.salesRep,
    name: 'Casey the Sales Rep',
    description: 'Drums up an extra contract offer each day and negotiates better payouts.',
    dailySalary: 50,
    effectMagnitude: 0.15,
    minReputation: 10,
    cost: 400,
  ),
};

late final List<StaffDef> staffDefList = staffDefsById.values.toList()
  ..sort((a, b) => a.cost.compareTo(b.cost));

class StaffEffects {
  final double sysadminAutoResolveChance;
  final double electricityDiscount;
  final int offerSlotBonus;
  final double payoutBonusMultiplier;

  const StaffEffects({
    required this.sysadminAutoResolveChance,
    required this.electricityDiscount,
    required this.offerSlotBonus,
    required this.payoutBonusMultiplier,
  }) : assert(offerSlotBonus >= 0);
}

StaffEffects getStaffEffects(Set<String> hired) {
  double sysadminAutoResolveChance = 0;
  double electricityDiscount = 0;
  int offerSlotBonus = 0;
  double payoutBonusMultiplier = 0;

  for (final id in hired) {
    final def = staffDefsById[id];
    if (def == null) continue;
    switch (def.role) {
      case StaffRole.sysadmin:
        sysadminAutoResolveChance += def.effectMagnitude;
        break;
      case StaffRole.electrician:
        electricityDiscount += def.effectMagnitude;
        break;
      case StaffRole.salesRep:
        offerSlotBonus += 1;
        payoutBonusMultiplier += def.effectMagnitude;
        break;
    }
  }

  return StaffEffects(
    sysadminAutoResolveChance: sysadminAutoResolveChance.clamp(0, 1),
    electricityDiscount: electricityDiscount,
    offerSlotBonus: offerSlotBonus,
    payoutBonusMultiplier: payoutBonusMultiplier,
  );
}
