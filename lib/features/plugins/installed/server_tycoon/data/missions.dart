// Daily objectives. Three are rolled at each day rollover from the pool below,
// with targets that scale as the account grows, and pay out cash + reputation.

import 'dart:math' as math;

import '../../../../../l10n/current_l.dart';

enum MissionMetric {
  /// Net profit banked in a single day.
  dailyNetProfit,

  /// Services installed today.
  servicesInstalled,

  /// Components bought today (from the shop or straight onto a rig).
  componentsBought,

  /// Contracts completed today.
  contractsCompleted,

  /// Incidents mitigated, repaired or cooled down today.
  incidentsResolved,

  /// Research projects finished today.
  researchCompleted,

  /// Peak bandwidth actually served during the day, in Mbps.
  bandwidthServed,

  /// Finish the day with nothing overloaded (target is always 1).
  cleanDay,
}

class MissionDef {
  final String id;
  final MissionMetric metric;
  final double baseTarget;

  /// Multiplied into the target once per 10 elapsed days, compounding.
  final double targetGrowth;
  final int baseCashReward;
  final double repReward;

  /// Days that must have elapsed before this can be rolled.
  final int minDay;

  const MissionDef({
    required this.id,
    required this.metric,
    required this.baseTarget,
    this.targetGrowth = 1.0,
    required this.baseCashReward,
    required this.repReward,
    this.minDay = 0,
  });

  String get name => switch (id) {
        'PROFITABLE_DAY' => currentL.serverTycoonMissionProfitableDay,
        'BIG_DAY' => currentL.serverTycoonMissionBigDay,
        'EXPAND_SERVICES' => currentL.serverTycoonMissionExpandServices,
        'GO_SHOPPING' => currentL.serverTycoonMissionGoShopping,
        'CLOSE_A_CONTRACT' => currentL.serverTycoonMissionCloseAContract,
        'FIREFIGHTER' => currentL.serverTycoonMissionFirefighter,
        'LAB_WORK' => currentL.serverTycoonMissionLabWork,
        'PUSH_TRAFFIC' => currentL.serverTycoonMissionPushTraffic,
        'CLEAN_RUN' => currentL.serverTycoonMissionCleanRun,
        _ => id,
      };

  String get description => switch (id) {
        'PROFITABLE_DAY' => currentL.serverTycoonMissionProfitableDayDesc,
        'BIG_DAY' => currentL.serverTycoonMissionBigDayDesc,
        'EXPAND_SERVICES' => currentL.serverTycoonMissionExpandServicesDesc,
        'GO_SHOPPING' => currentL.serverTycoonMissionGoShoppingDesc,
        'CLOSE_A_CONTRACT' => currentL.serverTycoonMissionCloseAContractDesc,
        'FIREFIGHTER' => currentL.serverTycoonMissionFirefighterDesc,
        'LAB_WORK' => currentL.serverTycoonMissionLabWorkDesc,
        'PUSH_TRAFFIC' => currentL.serverTycoonMissionPushTrafficDesc,
        'CLEAN_RUN' => currentL.serverTycoonMissionCleanRunDesc,
        _ => '',
      };

  /// Targets and rewards both scale with account age so a day-90 objective is
  /// still worth doing, rounded to something readable.
  double targetForDay(int day) {
    if (targetGrowth <= 1.0) return baseTarget;
    final scaled = baseTarget * math.pow(targetGrowth, day / 10);
    if (scaled >= 100) return (scaled / 10).roundToDouble() * 10;
    return scaled.roundToDouble();
  }

  int rewardForDay(int day) {
    final scaled = baseCashReward * (1 + day / 25);
    return (scaled / 5).round() * 5;
  }
}

final Map<String, MissionDef> missionDefsById = {
  'PROFITABLE_DAY': const MissionDef(
    id: 'PROFITABLE_DAY',
    metric: MissionMetric.dailyNetProfit,
    baseTarget: 40,
    targetGrowth: 1.8,
    baseCashReward: 120,
    repReward: 0.5,
  ),
  'BIG_DAY': const MissionDef(
    id: 'BIG_DAY',
    metric: MissionMetric.dailyNetProfit,
    baseTarget: 250,
    targetGrowth: 2.0,
    baseCashReward: 400,
    repReward: 1.0,
    minDay: 8,
  ),
  'EXPAND_SERVICES': const MissionDef(
    id: 'EXPAND_SERVICES',
    metric: MissionMetric.servicesInstalled,
    baseTarget: 2,
    baseCashReward: 200,
    repReward: 0.5,
  ),
  'GO_SHOPPING': const MissionDef(
    id: 'GO_SHOPPING',
    metric: MissionMetric.componentsBought,
    baseTarget: 3,
    baseCashReward: 180,
    repReward: 0.5,
  ),
  'CLOSE_A_CONTRACT': const MissionDef(
    id: 'CLOSE_A_CONTRACT',
    metric: MissionMetric.contractsCompleted,
    baseTarget: 1,
    baseCashReward: 500,
    repReward: 2.0,
    minDay: 5,
  ),
  'FIREFIGHTER': const MissionDef(
    id: 'FIREFIGHTER',
    metric: MissionMetric.incidentsResolved,
    baseTarget: 2,
    baseCashReward: 300,
    repReward: 1.0,
    minDay: 3,
  ),
  'LAB_WORK': const MissionDef(
    id: 'LAB_WORK',
    metric: MissionMetric.researchCompleted,
    baseTarget: 1,
    baseCashReward: 450,
    repReward: 1.5,
    minDay: 6,
  ),
  'PUSH_TRAFFIC': const MissionDef(
    id: 'PUSH_TRAFFIC',
    metric: MissionMetric.bandwidthServed,
    baseTarget: 60,
    targetGrowth: 1.9,
    baseCashReward: 250,
    repReward: 1.0,
    minDay: 4,
  ),
  'CLEAN_RUN': const MissionDef(
    id: 'CLEAN_RUN',
    metric: MissionMetric.cleanDay,
    baseTarget: 1,
    baseCashReward: 220,
    repReward: 1.0,
    minDay: 2,
  ),
};

late final List<MissionDef> missionDefList = missionDefsById.values.toList();

/// One rolled objective, live for a single day. Persisted so closing the app
/// mid-day doesn't wipe the board.
class Mission {
  final String defId;
  final double target;
  final int rewardCash;
  final double rewardRep;
  double progress;
  bool rewarded;

  Mission({
    required this.defId,
    required this.target,
    required this.rewardCash,
    required this.rewardRep,
    this.progress = 0,
    this.rewarded = false,
  });

  MissionDef? get def => missionDefsById[defId];
  bool get complete => progress >= target;
  double get fraction => target <= 0 ? 1 : (progress / target).clamp(0, 1).toDouble();

  Map<String, dynamic> toJson() => {
        'defId': defId,
        'target': target,
        'rewardCash': rewardCash,
        'rewardRep': rewardRep,
        'progress': progress,
        'rewarded': rewarded,
      };

  factory Mission.fromJson(Map<String, dynamic> json) => Mission(
        defId: json['defId'] as String,
        target: (json['target'] as num).toDouble(),
        rewardCash: json['rewardCash'] as int,
        rewardRep: (json['rewardRep'] as num).toDouble(),
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        rewarded: json['rewarded'] as bool? ?? false,
      );
}

/// Rolls a fresh board of [count] distinct objectives eligible on [day].
List<Mission> rollMissions(int day, math.Random rng, {int count = 3}) {
  final eligible = missionDefList.where((m) => day >= m.minDay).toList()..shuffle(rng);
  return [
    for (final def in eligible.take(count))
      Mission(
        defId: def.id,
        target: def.targetForDay(day),
        rewardCash: def.rewardForDay(day),
        rewardRep: def.repReward,
      ),
  ];
}
