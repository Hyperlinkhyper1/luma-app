// Milestone achievements — evaluated against GameState counters once per day.

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
  final String name;
  final String description;
  final AchievementMetric metric;
  final double threshold;

  const AchievementDef({
    required this.id,
    required this.name,
    required this.description,
    required this.metric,
    required this.threshold,
  });
}

final Map<String, AchievementDef> achievementDefsById = {
  'FIRST_GRAND': const AchievementDef(
    id: 'FIRST_GRAND',
    name: 'First Grand',
    description: 'Earn a lifetime total of \$1,000.',
    metric: AchievementMetric.totalMoneyEarned,
    threshold: 1000,
  ),
  'FIVE_FIGURES': const AchievementDef(
    id: 'FIVE_FIGURES',
    name: 'Five Figures',
    description: 'Earn a lifetime total of \$10,000.',
    metric: AchievementMetric.totalMoneyEarned,
    threshold: 10000,
  ),
  'SIX_FIGURES': const AchievementDef(
    id: 'SIX_FIGURES',
    name: 'Six Figures',
    description: 'Earn a lifetime total of \$100,000.',
    metric: AchievementMetric.totalMoneyEarned,
    threshold: 100000,
  ),
  'MILLIONAIRE': const AchievementDef(
    id: 'MILLIONAIRE',
    name: 'Data Center Millionaire',
    description: 'Earn a lifetime total of \$1,000,000.',
    metric: AchievementMetric.totalMoneyEarned,
    threshold: 1000000,
  ),
  'TRUSTED_HOST': const AchievementDef(
    id: 'TRUSTED_HOST',
    name: 'Trusted Host',
    description: 'Reach 25 reputation.',
    metric: AchievementMetric.reputation,
    threshold: 25,
  ),
  'WELL_REGARDED': const AchievementDef(
    id: 'WELL_REGARDED',
    name: 'Well Regarded',
    description: 'Reach 50 reputation.',
    metric: AchievementMetric.reputation,
    threshold: 50,
  ),
  'INDUSTRY_LEADER': const AchievementDef(
    id: 'INDUSTRY_LEADER',
    name: 'Industry Leader',
    description: 'Reach 75 reputation.',
    metric: AchievementMetric.reputation,
    threshold: 75,
  ),
  'PERFECT_REPUTATION': const AchievementDef(
    id: 'PERFECT_REPUTATION',
    name: 'Perfect Reputation',
    description: 'Reach 100 reputation.',
    metric: AchievementMetric.reputation,
    threshold: 100,
  ),
  'ONE_WEEK_IN': const AchievementDef(
    id: 'ONE_WEEK_IN',
    name: 'One Week In',
    description: 'Survive 7 days in business.',
    metric: AchievementMetric.dayCount,
    threshold: 7,
  ),
  'ONE_MONTH_IN': const AchievementDef(
    id: 'ONE_MONTH_IN',
    name: 'One Month In',
    description: 'Survive 30 days in business.',
    metric: AchievementMetric.dayCount,
    threshold: 30,
  ),
  'CENTURY_CLUB': const AchievementDef(
    id: 'CENTURY_CLUB',
    name: 'Century Club',
    description: 'Survive 100 days in business.',
    metric: AchievementMetric.dayCount,
    threshold: 100,
  ),
  'OLD_GUARD': const AchievementDef(
    id: 'OLD_GUARD',
    name: 'Old Guard',
    description: 'Survive 365 days in business.',
    metric: AchievementMetric.dayCount,
    threshold: 365,
  ),
  'GIGABIT_PIPE': const AchievementDef(
    id: 'GIGABIT_PIPE',
    name: 'Gigabit Pipe',
    description: 'Serve 1,000 Mbps of bandwidth at once.',
    metric: AchievementMetric.peakBandwidthServed,
    threshold: 1000,
  ),
  'TEN_GIG_BACKBONE': const AchievementDef(
    id: 'TEN_GIG_BACKBONE',
    name: '10-Gig Backbone',
    description: 'Serve 10,000 Mbps of bandwidth at once.',
    metric: AchievementMetric.peakBandwidthServed,
    threshold: 10000,
  ),
  'FIRST_DEAL': const AchievementDef(
    id: 'FIRST_DEAL',
    name: 'First Deal',
    description: 'Complete your first contract.',
    metric: AchievementMetric.contractsCompleted,
    threshold: 1,
  ),
  'DEAL_MAKER': const AchievementDef(
    id: 'DEAL_MAKER',
    name: 'Deal Maker',
    description: 'Complete 10 contracts.',
    metric: AchievementMetric.contractsCompleted,
    threshold: 10,
  ),
  'CONTRACT_MACHINE': const AchievementDef(
    id: 'CONTRACT_MACHINE',
    name: 'Contract Machine',
    description: 'Complete 50 contracts.',
    metric: AchievementMetric.contractsCompleted,
    threshold: 50,
  ),
  'RELIABLE_HOST': const AchievementDef(
    id: 'RELIABLE_HOST',
    name: 'Reliable Host',
    description: 'Keep 7 consecutive days of uptime with no overloads or contract failures.',
    metric: AchievementMetric.uptimeStreakDays,
    threshold: 7,
  ),
  'ROCK_SOLID': const AchievementDef(
    id: 'ROCK_SOLID',
    name: 'Rock Solid',
    description: 'Keep 30 consecutive days of uptime with no overloads or contract failures.',
    metric: AchievementMetric.uptimeStreakDays,
    threshold: 30,
  ),
  'GROWING_FLEET': const AchievementDef(
    id: 'GROWING_FLEET',
    name: 'Growing Fleet',
    description: 'Own 10 rigs at once.',
    metric: AchievementMetric.rigCount,
    threshold: 10,
  ),
  'SCALED_UP': const AchievementDef(
    id: 'SCALED_UP',
    name: 'Scaled Up',
    description: 'Rebirth for the first time.',
    metric: AchievementMetric.prestigeLevel,
    threshold: 1,
  ),
  'MEGA_FLEET': const AchievementDef(
    id: 'MEGA_FLEET',
    name: 'Mega Fleet',
    description: 'Own 25 rigs at once.',
    metric: AchievementMetric.rigCount,
    threshold: 25,
  ),
  'CONTRACT_LEGEND': const AchievementDef(
    id: 'CONTRACT_LEGEND',
    name: 'Contract Legend',
    description: 'Complete 100 contracts.',
    metric: AchievementMetric.contractsCompleted,
    threshold: 100,
  ),
  'BANDWIDTH_KING': const AchievementDef(
    id: 'BANDWIDTH_KING',
    name: 'Bandwidth King',
    description: 'Serve 100,000 Mbps of bandwidth at once.',
    metric: AchievementMetric.peakBandwidthServed,
    threshold: 100000,
  ),
  'UNBREAKABLE': const AchievementDef(
    id: 'UNBREAKABLE',
    name: 'Unbreakable',
    description: 'Keep 100 consecutive days of uptime with no overloads or contract failures.',
    metric: AchievementMetric.uptimeStreakDays,
    threshold: 100,
  ),
  'PRESTIGE_MASTER': const AchievementDef(
    id: 'PRESTIGE_MASTER',
    name: 'Prestige Master',
    description: 'Reach prestige level 5.',
    metric: AchievementMetric.prestigeLevel,
    threshold: 5,
  ),
  'TEN_MILLION': const AchievementDef(
    id: 'TEN_MILLION',
    name: 'Ten Million Club',
    description: 'Earn a lifetime total of \$10,000,000.',
    metric: AchievementMetric.totalMoneyEarned,
    threshold: 10000000,
  ),
};

late final List<AchievementDef> achievementDefList = achievementDefsById.values.toList()
  ..sort((a, b) {
    if (a.metric != b.metric) return a.metric.index.compareTo(b.metric.index);
    return a.threshold.compareTo(b.threshold);
  });
