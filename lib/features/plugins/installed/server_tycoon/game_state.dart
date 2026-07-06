// Auto-ported from Roblox Server Hosting Tycoon
// The full serializable state for one player's hosting business.

import 'data/incidents.dart';
import 'sim/computer_sim.dart';
import 'sim/service_sim.dart';

/// A live, mid-day incident. Deliberately NOT part of GameState/persistence --
/// it's repository-private, session-only state (see ServerTycoonRepository).
class ActiveIncident {
  final String incidentId;
  final IncidentType type;
  final String targetKind; // 'rig' | 'router'
  final String targetId;
  final int spawnedAtSecond;
  final double severity;
  bool acknowledged;
  final String? affectedInstanceId;

  ActiveIncident({
    required this.incidentId,
    required this.type,
    required this.targetKind,
    required this.targetId,
    required this.spawnedAtSecond,
    required this.severity,
    this.acknowledged = false,
    this.affectedInstanceId,
  });
}

class NodePos {
  double x;
  double y;

  NodePos({required this.x, required this.y});

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  factory NodePos.fromJson(Map<String, dynamic> json) => NodePos(
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
  );
}

class Rig {
  String rigId;
  String name;
  RigKind kind;
  Build build;
  List<ServiceInstance> services;
  String routerId;
  NodePos pos;

  Rig({
    required this.rigId,
    required this.name,
    required this.kind,
    required this.build,
    required this.services,
    required this.routerId,
    required this.pos,
  });

  Map<String, dynamic> toJson() => {
    'rigId': rigId,
    'name': name,
    'kind': kind.name,
    'build': build.toJson(),
    'services': services.map((s) => s.toJson()).toList(),
    'routerId': routerId,
    'pos': pos.toJson(),
  };

  factory Rig.fromJson(Map<String, dynamic> json) => Rig(
    rigId: json['rigId'] as String,
    name: json['name'] as String,
    kind: RigKind.values.byName(json['kind'] as String),
    build: Build.fromJson(json['build'] as Map<String, dynamic>),
    services: (json['services'] as List).map((e) => ServiceInstance.fromJson(e as Map<String, dynamic>)).toList(),
    routerId: json['routerId'] as String,
    pos: NodePos.fromJson(json['pos'] as Map<String, dynamic>),
  );
}

class Router {
  String routerId;
  String name;
  String internetPlanId;
  NodePos pos;

  Router({
    required this.routerId,
    required this.name,
    required this.internetPlanId,
    required this.pos,
  });

  Map<String, dynamic> toJson() => {
    'routerId': routerId,
    'name': name,
    'internetPlanId': internetPlanId,
    'pos': pos.toJson(),
  };

  factory Router.fromJson(Map<String, dynamic> json) => Router(
    routerId: json['routerId'] as String,
    name: json['name'] as String,
    internetPlanId: json['internetPlanId'] as String,
    pos: NodePos.fromJson(json['pos'] as Map<String, dynamic>),
  );
}

class Contract {
  String contractId;
  String companyId;
  String serviceTypeId;
  int minCapacity;
  int daysRemaining;
  int totalDays;
  double payoutPerDay;
  double completionBonus;
  int repBonus;
  int repPenalty;

  Contract({
    required this.contractId,
    required this.companyId,
    required this.serviceTypeId,
    required this.minCapacity,
    required this.daysRemaining,
    required this.totalDays,
    required this.payoutPerDay,
    required this.completionBonus,
    required this.repBonus,
    required this.repPenalty,
  });

  Map<String, dynamic> toJson() => {
    'contractId': contractId,
    'companyId': companyId,
    'serviceTypeId': serviceTypeId,
    'minCapacity': minCapacity,
    'daysRemaining': daysRemaining,
    'totalDays': totalDays,
    'payoutPerDay': payoutPerDay,
    'completionBonus': completionBonus,
    'repBonus': repBonus,
    'repPenalty': repPenalty,
  };

  factory Contract.fromJson(Map<String, dynamic> json) => Contract(
    contractId: json['contractId'] as String,
    companyId: json['companyId'] as String,
    serviceTypeId: json['serviceTypeId'] as String,
    minCapacity: json['minCapacity'] as int,
    daysRemaining: json['daysRemaining'] as int,
    totalDays: json['totalDays'] as int,
    payoutPerDay: (json['payoutPerDay'] as num).toDouble(),
    completionBonus: (json['completionBonus'] as num).toDouble(),
    repBonus: json['repBonus'] as int,
    repPenalty: json['repPenalty'] as int,
  );
}

class ContractOffer {
  final String offerId;
  final String companyId;
  final String serviceTypeId;
  final int minCapacity;
  final int durationDays;
  final double payoutPerDay;
  final double completionBonus;
  final int repBonus;
  final int repPenalty;

  const ContractOffer({
    required this.offerId,
    required this.companyId,
    required this.serviceTypeId,
    required this.minCapacity,
    required this.durationDays,
    required this.payoutPerDay,
    required this.completionBonus,
    required this.repBonus,
    required this.repPenalty,
  });
}

class DayReport {
  final int day;
  final double income;
  final double contractIncome;
  final List<String> contractEvents;
  final double electricityCost;
  final double internetCost;
  final double staffSalaryCost;
  final double netProfit;
  final double avgSatisfaction;
  final double reputation;
  final double money;
  final bool overloaded;

  const DayReport({
    required this.day,
    required this.income,
    required this.contractIncome,
    required this.contractEvents,
    required this.electricityCost,
    required this.internetCost,
    this.staffSalaryCost = 0,
    required this.netProfit,
    required this.avgSatisfaction,
    required this.reputation,
    required this.money,
    required this.overloaded,
  });
}

class GameState {
  double money;
  double reputation;
  int dayCount;
  Map<String, Rig> rigs;
  Map<String, Router> routers;
  int nextRigId;
  int nextRouterId;
  int nextInstanceId;
  int nextContractId;
  Set<String> licenses;
  Set<String> research;
  List<Contract> contracts;
  double peakPowerDrawWatts;
  List<double> powerHistory;
  List<double> incomeHistory;
  Map<String, int> inventory;

  // Achievement tracking counters.
  double totalMoneyEverEarned;
  int contractsCompletedCount;
  int uptimeStreakDays;
  double peakBandwidthServed;
  Set<String> unlockedAchievements;

  // Prestige / rebirth — deliberately survives resetGame(), see repository.
  int prestigeLevel;
  double incomeMultiplier;

  // Hired staff.
  Set<String> hiredStaffIds;

  static const int historyLength = 30;
  static const int newRigCost = 300;
  static const int newServerRigCost = 2000;
  static const int newRouterCost = 500;
  static const int baseMaxRouters = 1;
  static const int baseContractSlots = 2;
  static const double canvasMaxX = 6000;
  static const double canvasMaxY = 4000;

  GameState({
    required this.money,
    required this.reputation,
    required this.dayCount,
    required this.rigs,
    required this.routers,
    required this.nextRigId,
    required this.nextRouterId,
    required this.nextInstanceId,
    required this.nextContractId,
    required this.licenses,
    required this.research,
    required this.contracts,
    required this.peakPowerDrawWatts,
    required this.powerHistory,
    required this.incomeHistory,
    Map<String, int>? inventory,
    double? totalMoneyEverEarned,
    int? contractsCompletedCount,
    int? uptimeStreakDays,
    double? peakBandwidthServed,
    Set<String>? unlockedAchievements,
    int? prestigeLevel,
    double? incomeMultiplier,
    Set<String>? hiredStaffIds,
  }) : inventory = inventory ?? {},
       totalMoneyEverEarned = totalMoneyEverEarned ?? 0,
       contractsCompletedCount = contractsCompletedCount ?? 0,
       uptimeStreakDays = uptimeStreakDays ?? 0,
       peakBandwidthServed = peakBandwidthServed ?? 0,
       unlockedAchievements = unlockedAchievements ?? {},
       prestigeLevel = prestigeLevel ?? 0,
       incomeMultiplier = incomeMultiplier ?? 1.0,
       hiredStaffIds = hiredStaffIds ?? {};

  factory GameState.newDefault({
    double totalMoneyEverEarned = 0,
    Set<String>? unlockedAchievements,
    int prestigeLevel = 0,
    double incomeMultiplier = 1.0,
  }) {
    const firstRigId = '1';
    const firstRouterId = '1';
    return GameState(
      money: 250,
      reputation: 0,
      dayCount: 0,
      rigs: {
        firstRigId: Rig(
          rigId: firstRigId,
          name: 'Rig 1',
          kind: RigKind.pc,
          build: newStarterBuild(),
          services: [],
          routerId: firstRouterId,
          pos: NodePos(x: 380, y: 60),
        ),
      },
      routers: {
        firstRouterId: Router(
          routerId: firstRouterId,
          name: 'Router 1',
          internetPlanId: 'HOME_25',
          pos: NodePos(x: 60, y: 60),
        ),
      },
      nextRigId: 2,
      nextRouterId: 2,
      nextInstanceId: 1,
      nextContractId: 1,
      licenses: {},
      research: {},
      contracts: [],
      peakPowerDrawWatts: 0,
      powerHistory: [],
      incomeHistory: [],
      totalMoneyEverEarned: totalMoneyEverEarned,
      unlockedAchievements: unlockedAchievements,
      prestigeLevel: prestigeLevel,
      incomeMultiplier: incomeMultiplier,
    );
  }

  Map<String, dynamic> toJson() => {
    'money': money,
    'reputation': reputation,
    'dayCount': dayCount,
    'rigs': rigs.map((k, v) => MapEntry(k, v.toJson())),
    'routers': routers.map((k, v) => MapEntry(k, v.toJson())),
    'nextRigId': nextRigId,
    'nextRouterId': nextRouterId,
    'nextInstanceId': nextInstanceId,
    'nextContractId': nextContractId,
    'licenses': licenses.toList(),
    'research': research.toList(),
    'contracts': contracts.map((c) => c.toJson()).toList(),
    'peakPowerDrawWatts': peakPowerDrawWatts,
    'powerHistory': powerHistory,
    'incomeHistory': incomeHistory,
    'inventory': inventory,
    'totalMoneyEverEarned': totalMoneyEverEarned,
    'contractsCompletedCount': contractsCompletedCount,
    'uptimeStreakDays': uptimeStreakDays,
    'peakBandwidthServed': peakBandwidthServed,
    'unlockedAchievements': unlockedAchievements.toList(),
    'prestigeLevel': prestigeLevel,
    'incomeMultiplier': incomeMultiplier,
    'hiredStaffIds': hiredStaffIds.toList(),
  };

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
    money: (json['money'] as num).toDouble(),
    reputation: (json['reputation'] as num).toDouble(),
    dayCount: json['dayCount'] as int,
    rigs: (json['rigs'] as Map<String, dynamic>).map((k, v) => MapEntry(k, Rig.fromJson(v as Map<String, dynamic>))),
    routers: (json['routers'] as Map<String, dynamic>).map((k, v) => MapEntry(k, Router.fromJson(v as Map<String, dynamic>))),
    nextRigId: json['nextRigId'] as int,
    nextRouterId: json['nextRouterId'] as int,
    nextInstanceId: json['nextInstanceId'] as int,
    nextContractId: json['nextContractId'] as int,
    licenses: (json['licenses'] as List).cast<String>().toSet(),
    research: (json['research'] as List).cast<String>().toSet(),
    contracts: (json['contracts'] as List).map((e) => Contract.fromJson(e as Map<String, dynamic>)).toList(),
    peakPowerDrawWatts: (json['peakPowerDrawWatts'] as num).toDouble(),
    powerHistory: (json['powerHistory'] as List).map((e) => (e as num).toDouble()).toList(),
    incomeHistory: (json['incomeHistory'] as List).map((e) => (e as num).toDouble()).toList(),
    inventory: (json['inventory'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as int)) ?? {},
    totalMoneyEverEarned: (json['totalMoneyEverEarned'] as num?)?.toDouble() ?? 0,
    contractsCompletedCount: json['contractsCompletedCount'] as int? ?? 0,
    uptimeStreakDays: json['uptimeStreakDays'] as int? ?? 0,
    peakBandwidthServed: (json['peakBandwidthServed'] as num?)?.toDouble() ?? 0,
    unlockedAchievements: (json['unlockedAchievements'] as List?)?.cast<String>().toSet() ?? {},
    prestigeLevel: json['prestigeLevel'] as int? ?? 0,
    incomeMultiplier: (json['incomeMultiplier'] as num?)?.toDouble() ?? 1.0,
    hiredStaffIds: (json['hiredStaffIds'] as List?)?.cast<String>().toSet() ?? {},
  );
}
