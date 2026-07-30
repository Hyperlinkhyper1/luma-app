// Auto-ported from Roblox Server Hosting Tycoon
// The full serializable state for one player's hosting business.

import 'data/boosts.dart';
import 'data/incidents.dart';
import 'data/missions.dart';
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

/// A research project part-way through. Progress is paid in research points
/// accrued at day rollover, so this survives app restarts.
class ResearchProgress {
  final String projectId;

  /// For repeatable projects, the level this run will unlock. 0 otherwise.
  final int level;
  final double rpNeeded;
  double rpAccrued;

  ResearchProgress({
    required this.projectId,
    required this.rpNeeded,
    this.level = 0,
    this.rpAccrued = 0,
  });

  double get fraction => rpNeeded <= 0 ? 1 : (rpAccrued / rpNeeded).clamp(0, 1).toDouble();
  bool get complete => rpAccrued >= rpNeeded;

  Map<String, dynamic> toJson() => {
        'projectId': projectId,
        'level': level,
        'rpNeeded': rpNeeded,
        'rpAccrued': rpAccrued,
      };

  factory ResearchProgress.fromJson(Map<String, dynamic> json) => ResearchProgress(
        projectId: json['projectId'] as String,
        level: json['level'] as int? ?? 0,
        rpNeeded: (json['rpNeeded'] as num).toDouble(),
        rpAccrued: (json['rpAccrued'] as num?)?.toDouble() ?? 0,
      );
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
  final List<String> researchEvents;
  final List<String> missionEvents;
  final List<String> boostEvents;
  final double researchPointsEarned;
  final double missionRewardCash;

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
    this.researchEvents = const [],
    this.missionEvents = const [],
    this.boostEvents = const [],
    this.researchPointsEarned = 0,
    this.missionRewardCash = 0,
  });
}

/// Summary of the days simulated on the player's behalf while the app was
/// closed. Session-only — shown once on the next open, then dropped.
class AwayReport {
  final int daysSimulated;

  /// How many days actually elapsed, before the catch-up cap was applied.
  final int daysElapsed;
  final Duration awayFor;
  final double income;
  final double expenses;
  final double netProfit;

  /// The fraction of normal earnings offline days paid out at.
  final double rate;
  final double researchPointsEarned;
  final List<String> events;

  const AwayReport({
    required this.daysSimulated,
    required this.daysElapsed,
    required this.awayFor,
    required this.income,
    required this.expenses,
    required this.netProfit,
    required this.rate,
    required this.researchPointsEarned,
    this.events = const [],
  });

  bool get capped => daysElapsed > daysSimulated;
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

  // Research pipeline. `research` above stays the owned-set; these drive the
  // accrue-over-time queue on top of it.
  double researchPoints;
  ResearchProgress? activeResearch;
  List<String> researchQueue;
  Map<String, int> researchLevels;
  int researchCompletedCount;

  // Timed boosts and the daily objective board.
  List<ActiveBoost> activeBoosts;
  List<Mission> missions;
  int missionsRolledForDay;

  // Session preferences that belong to the save, not the app settings.
  bool autoConfirmDay;
  int gameSpeed;

  /// Wall-clock of the last day processed, for away earnings. 0 = never seen.
  int lastSeenEpochMs;

  static const int historyLength = 30;
  static const int maxOfflineDays = 12;
  static const double baseOfflineRate = 0.6;
  static const List<int> gameSpeeds = [1, 2, 4];
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
    double? researchPoints,
    this.activeResearch,
    List<String>? researchQueue,
    Map<String, int>? researchLevels,
    int? researchCompletedCount,
    List<ActiveBoost>? activeBoosts,
    List<Mission>? missions,
    int? missionsRolledForDay,
    bool? autoConfirmDay,
    int? gameSpeed,
    int? lastSeenEpochMs,
  }) : inventory = inventory ?? {},
       totalMoneyEverEarned = totalMoneyEverEarned ?? 0,
       contractsCompletedCount = contractsCompletedCount ?? 0,
       uptimeStreakDays = uptimeStreakDays ?? 0,
       peakBandwidthServed = peakBandwidthServed ?? 0,
       unlockedAchievements = unlockedAchievements ?? {},
       prestigeLevel = prestigeLevel ?? 0,
       incomeMultiplier = incomeMultiplier ?? 1.0,
       hiredStaffIds = hiredStaffIds ?? {},
       researchPoints = researchPoints ?? 0,
       researchQueue = researchQueue ?? [],
       researchLevels = researchLevels ?? {},
       researchCompletedCount = researchCompletedCount ?? 0,
       activeBoosts = activeBoosts ?? [],
       missions = missions ?? [],
       missionsRolledForDay = missionsRolledForDay ?? -1,
       autoConfirmDay = autoConfirmDay ?? false,
       // Anything not on the speed dial (an older or hand-edited save) falls
       // back to 1×; a zero here would stall the day timer entirely.
       gameSpeed = (gameSpeed != null && gameSpeeds.contains(gameSpeed)) ? gameSpeed : 1,
       lastSeenEpochMs = lastSeenEpochMs ?? 0;

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
    'researchPoints': researchPoints,
    'activeResearch': activeResearch?.toJson(),
    'researchQueue': researchQueue,
    'researchLevels': researchLevels,
    'researchCompletedCount': researchCompletedCount,
    'activeBoosts': activeBoosts.map((b) => b.toJson()).toList(),
    'missions': missions.map((m) => m.toJson()).toList(),
    'missionsRolledForDay': missionsRolledForDay,
    'autoConfirmDay': autoConfirmDay,
    'gameSpeed': gameSpeed,
    'lastSeenEpochMs': lastSeenEpochMs,
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
    researchPoints: (json['researchPoints'] as num?)?.toDouble() ?? 0,
    activeResearch: json['activeResearch'] == null
        ? null
        : ResearchProgress.fromJson(json['activeResearch'] as Map<String, dynamic>),
    researchQueue: (json['researchQueue'] as List?)?.cast<String>().toList() ?? [],
    researchLevels: (json['researchLevels'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as int)) ?? {},
    researchCompletedCount: json['researchCompletedCount'] as int? ?? 0,
    activeBoosts: (json['activeBoosts'] as List?)
            ?.map((e) => ActiveBoost.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    missions: (json['missions'] as List?)?.map((e) => Mission.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    missionsRolledForDay: json['missionsRolledForDay'] as int? ?? -1,
    autoConfirmDay: json['autoConfirmDay'] as bool? ?? false,
    gameSpeed: json['gameSpeed'] as int? ?? 1,
    lastSeenEpochMs: json['lastSeenEpochMs'] as int? ?? 0,
  );
}
