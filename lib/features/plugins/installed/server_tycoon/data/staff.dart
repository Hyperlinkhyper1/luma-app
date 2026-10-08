// Hireable staff — daily salary, passive management-layer bonuses.

import '../../../../../l10n/app_localizations.dart';

enum StaffRole { sysadmin, electrician, salesRep }

class StaffDef {
  final String id;
  final StaffRole role;
  final double dailySalary;
  final double effectMagnitude;
  final int minReputation;
  final String? requiresLicense;
  final String? requiresResearch;
  final int cost;

  const StaffDef({
    required this.id,
    required this.role,
    required this.dailySalary,
    required this.effectMagnitude,
    required this.minReputation,
    this.requiresLicense,
    this.requiresResearch,
    required this.cost,
  });

  String name(L t) => switch (id) {
        'SYSADMIN' => t.serverTycoonStaffSysadminName,
        'ELECTRICIAN' => t.serverTycoonStaffElectricianName,
        'SALES_REP' => t.serverTycoonStaffSalesRepName,
        'SYSADMIN_SENIOR' => t.serverTycoonStaffSysadminSeniorName,
        'ELECTRICIAN_MASTER' => t.serverTycoonStaffElectricianMasterName,
        'SALES_DIRECTOR' => t.serverTycoonStaffSalesDirectorName,
        _ => id,
      };

  String description(L t) => switch (id) {
        'SYSADMIN' => t.serverTycoonStaffSysadminDesc,
        'ELECTRICIAN' => t.serverTycoonStaffElectricianDesc,
        'SALES_REP' => t.serverTycoonStaffSalesRepDesc,
        'SYSADMIN_SENIOR' => t.serverTycoonStaffSysadminSeniorDesc,
        'ELECTRICIAN_MASTER' => t.serverTycoonStaffElectricianMasterDesc,
        'SALES_DIRECTOR' => t.serverTycoonStaffSalesDirectorDesc,
        _ => id,
      };
}

final Map<String, StaffDef> staffDefsById = {
  'SYSADMIN': const StaffDef(
    id: 'SYSADMIN',
    role: StaffRole.sysadmin,
    dailySalary: 40,
    effectMagnitude: 0.5,
    minReputation: 0,
    cost: 300,
  ),
  'ELECTRICIAN': const StaffDef(
    id: 'ELECTRICIAN',
    role: StaffRole.electrician,
    dailySalary: 35,
    effectMagnitude: 0.08,
    minReputation: 5,
    cost: 350,
  ),
  'SALES_REP': const StaffDef(
    id: 'SALES_REP',
    role: StaffRole.salesRep,
    dailySalary: 50,
    effectMagnitude: 0.15,
    minReputation: 10,
    cost: 400,
  ),
  'SYSADMIN_SENIOR': const StaffDef(
    id: 'SYSADMIN_SENIOR',
    role: StaffRole.sysadmin,
    dailySalary: 90,
    effectMagnitude: 0.4,
    minReputation: 20,
    requiresResearch: 'SMART_PDU',
    cost: 1200,
  ),
  'ELECTRICIAN_MASTER': const StaffDef(
    id: 'ELECTRICIAN_MASTER',
    role: StaffRole.electrician,
    dailySalary: 80,
    effectMagnitude: 0.12,
    minReputation: 20,
    requiresResearch: 'POWER_TUNING',
    cost: 1100,
  ),
  'SALES_DIRECTOR': const StaffDef(
    id: 'SALES_DIRECTOR',
    role: StaffRole.salesRep,
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
