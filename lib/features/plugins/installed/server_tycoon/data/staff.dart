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
  'SYSADMIN_SENIOR': const StaffDef(
    id: 'SYSADMIN_SENIOR',
    role: StaffRole.sysadmin,
    name: 'Riley the Senior Sysadmin',
    description: 'A seasoned ops veteran who resolves incidents with near-certainty. Stacks with Jordan.',
    dailySalary: 90,
    effectMagnitude: 0.4,
    minReputation: 20,
    requiresResearch: 'SMART_PDU',
    cost: 1200,
  ),
  'ELECTRICIAN_MASTER': const StaffDef(
    id: 'ELECTRICIAN_MASTER',
    role: StaffRole.electrician,
    name: 'Drew the Master Electrician',
    description: 'A licensed industrial electrician who cuts another 12% off your power bill. Stacks with Sam.',
    dailySalary: 80,
    effectMagnitude: 0.12,
    minReputation: 20,
    requiresResearch: 'POWER_TUNING',
    cost: 1100,
  ),
  'SALES_DIRECTOR': const StaffDef(
    id: 'SALES_DIRECTOR',
    role: StaffRole.salesRep,
    name: 'Morgan the Sales Director',
    description: 'A well-connected director who brings another daily offer and negotiates even harder. Stacks with Casey.',
    dailySalary: 120,
    effectMagnitude: 0.20,
    minReputation: 30,
    requiresResearch: 'SALES_TEAM',
    cost: 2000,
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
