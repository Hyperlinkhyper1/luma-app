// Milestone achievements — evaluated against GameState counters once per day.

import '../../../../../l10n/app_localizations.dart';
import '../../../../../l10n/current_l.dart';

enum AchievementMetric {
  totalMoneyEarned,
  reputation,
  dayCount,
  peakBandwidthServed,
  contractsCompleted,
  uptimeStreakDays,
  rigCount,
  prestigeLevel,
}

class AchievementDef {
  final String id;
  final AchievementMetric metric;
  final double threshold;

  const AchievementDef({
    required this.id,
    required this.metric,
    required this.threshold,
  });

  String get name => _name(currentL);

  String get description => _description(currentL);

  String _name(L t) => switch (id) {
        'FIRST_GRAND' => t.serverTycoonAchFirstGrand,
        'FIVE_FIGURES' => t.serverTycoonAchFiveFigures,
        'SIX_FIGURES' => t.serverTycoonAchSixFigures,
        'MILLIONAIRE' => t.serverTycoonAchMillionaire,
        'TRUSTED_HOST' => t.serverTycoonAchTrustedHost,
        'WELL_REGARDED' => t.serverTycoonAchWellRegarded,
        'INDUSTRY_LEADER' => t.serverTycoonAchIndustryLeader,
        'PERFECT_REPUTATION' => t.serverTycoonAchPerfectReputation,
        'ONE_WEEK_IN' => t.serverTycoonAchOneWeekIn,
        'ONE_MONTH_IN' => t.serverTycoonAchOneMonthIn,
        'CENTURY_CLUB' => t.serverTycoonAchCenturyClub,
        'OLD_GUARD' => t.serverTycoonAchOldGuard,
        'GIGABIT_PIPE' => t.serverTycoonAchGigabitPipe,
        'TEN_GIG_BACKBONE' => t.serverTycoonAchTenGigBackbone,
        'FIRST_DEAL' => t.serverTycoonAchFirstDeal,
        'DEAL_MAKER' => t.serverTycoonAchDealMaker,
        'CONTRACT_MACHINE' => t.serverTycoonAchContractMachine,
        'RELIABLE_HOST' => t.serverTycoonAchReliableHost,
        'ROCK_SOLID' => t.serverTycoonAchRockSolid,
        'GROWING_FLEET' => t.serverTycoonAchGrowingFleet,
        'SCALED_UP' => t.serverTycoonAchScaledUp,
        'MEGA_FLEET' => t.serverTycoonAchMegaFleet,
        'CONTRACT_LEGEND' => t.serverTycoonAchContractLegend,
        'BANDWIDTH_KING' => t.serverTycoonAchBandwidthKing,
        'UNBREAKABLE' => t.serverTycoonAchUnbreakable,
        'PRESTIGE_MASTER' => t.serverTycoonAchPrestigeMaster,
        'TEN_MILLION' => t.serverTycoonAchTenMillion,
        _ => id,
      };

  String _description(L t) => switch (id) {
        'FIRST_GRAND' => t.serverTycoonAchEarnTotalDesc(r'$1,000'),
        'FIVE_FIGURES' => t.serverTycoonAchEarnTotalDesc(r'$10,000'),
        'SIX_FIGURES' => t.serverTycoonAchEarnTotalDesc(r'$100,000'),
        'MILLIONAIRE' => t.serverTycoonAchEarnTotalDesc(r'$1,000,000'),
        'TEN_MILLION' => t.serverTycoonAchEarnTotalDesc(r'$10,000,000'),
        'TRUSTED_HOST' => t.serverTycoonAchReputationDesc(25),
        'WELL_REGARDED' => t.serverTycoonAchReputationDesc(50),
        'INDUSTRY_LEADER' => t.serverTycoonAchReputationDesc(75),
        'PERFECT_REPUTATION' => t.serverTycoonAchReputationDesc(100),
        'ONE_WEEK_IN' => t.serverTycoonAchSurviveDaysDesc(7),
        'ONE_MONTH_IN' => t.serverTycoonAchSurviveDaysDesc(30),
        'CENTURY_CLUB' => t.serverTycoonAchSurviveDaysDesc(100),
        'OLD_GUARD' => t.serverTycoonAchSurviveDaysDesc(365),
        'GIGABIT_PIPE' => t.serverTycoonAchBandwidthDesc('1,000'),
        'TEN_GIG_BACKBONE' => t.serverTycoonAchBandwidthDesc('10,000'),
        'BANDWIDTH_KING' => t.serverTycoonAchBandwidthDesc('100,000'),
        'FIRST_DEAL' => t.serverTycoonAchFirstDealDesc,
        'DEAL_MAKER' => t.serverTycoonAchContractsDesc(10),
        'CONTRACT_MACHINE' => t.serverTycoonAchContractsDesc(50),
        'CONTRACT_LEGEND' => t.serverTycoonAchContractsDesc(100),
        'RELIABLE_HOST' => t.serverTycoonAchUptimeDesc(7),
        'ROCK_SOLID' => t.serverTycoonAchUptimeDesc(30),
        'UNBREAKABLE' => t.serverTycoonAchUptimeDesc(100),
        'GROWING_FLEET' => t.serverTycoonAchRigsDesc(10),
        'MEGA_FLEET' => t.serverTycoonAchRigsDesc(25),
        'SCALED_UP' => t.serverTycoonAchRebirthDesc,
        'PRESTIGE_MASTER' => t.serverTycoonAchPrestigeDesc(5),
        _ => id,
      };
}

const Map<String, AchievementDef> achievementDefsById = {
  'FIRST_GRAND': AchievementDef(
    id: 'FIRST_GRAND',
    metric: AchievementMetric.totalMoneyEarned,
    threshold: 1000,
  ),
  'FIVE_FIGURES': AchievementDef(
    id: 'FIVE_FIGURES',
    metric: AchievementMetric.totalMoneyEarned,
    threshold: 10000,
  ),
  'SIX_FIGURES': AchievementDef(
    id: 'SIX_FIGURES',
    metric: AchievementMetric.totalMoneyEarned,
    threshold: 100000,
  ),
  'MILLIONAIRE': AchievementDef(
    id: 'MILLIONAIRE',
    metric: AchievementMetric.totalMoneyEarned,
    threshold: 1000000,
  ),
  'TRUSTED_HOST': AchievementDef(
    id: 'TRUSTED_HOST',
    metric: AchievementMetric.reputation,
    threshold: 25,
  ),
  'WELL_REGARDED': AchievementDef(
    id: 'WELL_REGARDED',
    metric: AchievementMetric.reputation,
    threshold: 50,
  ),
  'INDUSTRY_LEADER': AchievementDef(
    id: 'INDUSTRY_LEADER',
    metric: AchievementMetric.reputation,
    threshold: 75,
  ),
  'PERFECT_REPUTATION': AchievementDef(
    id: 'PERFECT_REPUTATION',
    metric: AchievementMetric.reputation,
    threshold: 100,
  ),
  'ONE_WEEK_IN': AchievementDef(
    id: 'ONE_WEEK_IN',
    metric: AchievementMetric.dayCount,
    threshold: 7,
  ),
  'ONE_MONTH_IN': AchievementDef(
    id: 'ONE_MONTH_IN',
    metric: AchievementMetric.dayCount,
    threshold: 30,
  ),
  'CENTURY_CLUB': AchievementDef(
    id: 'CENTURY_CLUB',
    metric: AchievementMetric.dayCount,
    threshold: 100,
  ),
  'OLD_GUARD': AchievementDef(
    id: 'OLD_GUARD',
    metric: AchievementMetric.dayCount,
    threshold: 365,
  ),
  'GIGABIT_PIPE': AchievementDef(
    id: 'GIGABIT_PIPE',
    metric: AchievementMetric.peakBandwidthServed,
    threshold: 1000,
  ),
  'TEN_GIG_BACKBONE': AchievementDef(
    id: 'TEN_GIG_BACKBONE',
    metric: AchievementMetric.peakBandwidthServed,
    threshold: 10000,
  ),
  'FIRST_DEAL': AchievementDef(
    id: 'FIRST_DEAL',
    metric: AchievementMetric.contractsCompleted,
    threshold: 1,
  ),
  'DEAL_MAKER': AchievementDef(
    id: 'DEAL_MAKER',
    metric: AchievementMetric.contractsCompleted,
    threshold: 10,
  ),
  'CONTRACT_MACHINE': AchievementDef(
    id: 'CONTRACT_MACHINE',
    metric: AchievementMetric.contractsCompleted,
    threshold: 50,
  ),
  'RELIABLE_HOST': AchievementDef(
    id: 'RELIABLE_HOST',
    metric: AchievementMetric.uptimeStreakDays,
    threshold: 7,
  ),
  'ROCK_SOLID': AchievementDef(
    id: 'ROCK_SOLID',
    metric: AchievementMetric.uptimeStreakDays,
    threshold: 30,
  ),
  'GROWING_FLEET': AchievementDef(
    id: 'GROWING_FLEET',
    metric: AchievementMetric.rigCount,
    threshold: 10,
  ),
  'SCALED_UP': AchievementDef(
    id: 'SCALED_UP',
    metric: AchievementMetric.prestigeLevel,
    threshold: 1,
  ),
  'MEGA_FLEET': AchievementDef(
    id: 'MEGA_FLEET',
    metric: AchievementMetric.rigCount,
    threshold: 25,
  ),
  'CONTRACT_LEGEND': AchievementDef(
    id: 'CONTRACT_LEGEND',
    metric: AchievementMetric.contractsCompleted,
    threshold: 100,
  ),
  'BANDWIDTH_KING': AchievementDef(
    id: 'BANDWIDTH_KING',
    metric: AchievementMetric.peakBandwidthServed,
    threshold: 100000,
  ),
  'UNBREAKABLE': AchievementDef(
    id: 'UNBREAKABLE',
    metric: AchievementMetric.uptimeStreakDays,
    threshold: 100,
  ),
  'PRESTIGE_MASTER': AchievementDef(
    id: 'PRESTIGE_MASTER',
    metric: AchievementMetric.prestigeLevel,
    threshold: 5,
  ),
  'TEN_MILLION': AchievementDef(
    id: 'TEN_MILLION',
    metric: AchievementMetric.totalMoneyEarned,
    threshold: 10000000,
  ),
};

final List<AchievementDef> achievementDefList = achievementDefsById.values.toList()
  ..sort((a, b) {
    if (a.metric != b.metric) return a.metric.index.compareTo(b.metric.index);
    return a.threshold.compareTo(b.threshold);
  });
