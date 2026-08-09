// Research tree: branches, prerequisites, and the effects owning a project has.
//
// Projects are bought with cash up front but *complete over time*, paid for in
// research points accrued per day (see ResearchProgress in game_state.dart).
// Every id here is load-bearing for old saves — the owned-set is keyed by it,
// so ids may be added but never renamed.

import 'dart:math' as math;

enum ResearchBranch { lab, compute, storage, networking, power, business }

const Map<ResearchBranch, String> researchBranchNames = {
  ResearchBranch.lab: 'R&D Lab',
  ResearchBranch.compute: 'Compute',
  ResearchBranch.storage: 'Storage & Data',
  ResearchBranch.networking: 'Networking',
  ResearchBranch.power: 'Power & Cooling',
  ResearchBranch.business: 'Business',
};

class ResearchProject {
  final String id;
  final String name;
  final ResearchBranch branch;

  /// Depth in the branch, 1-based. Drives the tier rows in the tree UI.
  final int tier;
  final String description;

  /// Paid immediately on queueing.
  final int cost;

  /// Accrued over the following days at the account's research-point rate.
  final double rpCost;
  final List<String> requires;
  final int minReputation;

  // ── Effects. All nullable so a project only declares what it changes. ──
  final int? maxRoutersBonus;
  final double? electricityDiscount;
  final double? rigCostDiscount;
  final int? contractSlotsBonus;
  final double? coolingEfficiency;
  final double? cpuBoost;
  final double? storageCompression;
  final double? bandwidthOverhead;
  final double? incidentResistance;
  final double? offlineRateBonus;
  final double? satisfactionBonus;
  final double? rpPerDayBonus;
  final double? incomeBonus;
  final int? queueSlotsBonus;

  /// Repeatable projects are tracked by level in GameState.researchLevels
  /// rather than by presence in the owned set, and their cost grows each time.
  final bool repeatable;
  final double costGrowth;
  final int maxLevel;

  const ResearchProject({
    required this.id,
    required this.name,
    required this.branch,
    required this.tier,
    required this.description,
    required this.cost,
    required this.rpCost,
    required this.requires,
    required this.minReputation,
    this.maxRoutersBonus,
    this.electricityDiscount,
    this.rigCostDiscount,
    this.contractSlotsBonus,
    this.coolingEfficiency,
    this.cpuBoost,
    this.storageCompression,
    this.bandwidthOverhead,
    this.incidentResistance,
    this.offlineRateBonus,
    this.satisfactionBonus,
    this.rpPerDayBonus,
    this.incomeBonus,
    this.queueSlotsBonus,
    this.repeatable = false,
    this.costGrowth = 1.6,
    this.maxLevel = 1,
  });

  String get category => researchBranchNames[branch] ?? '';

  /// Cash price of the next purchase. Only repeatable projects scale.
  int costAtLevel(int level) =>
      repeatable ? (cost * math.pow(costGrowth, level)).round() : cost;

  double rpCostAtLevel(int level) =>
      repeatable ? rpCost * math.pow(costGrowth, level) : rpCost;
}

final Map<String, ResearchProject> researchById = {
  // ── R&D Lab: gates the whole system by raising research throughput. ──
  'HOME_LAB': const ResearchProject(
    id: 'HOME_LAB',
    name: 'Home Lab',
    branch: ResearchBranch.lab,
    tier: 1,
    description: 'A corner of the office set aside for testing. Adds 1.0 research point per day.',
    cost: 400,
    rpCost: 4,
    requires: [],
    minReputation: 0,
    rpPerDayBonus: 1.0,
  ),
  'RESEARCH_WING': const ResearchProject(
    id: 'RESEARCH_WING',
    name: 'Research Wing',
    branch: ResearchBranch.lab,
    tier: 2,
    description: 'A proper lab space with bench hardware. Adds 2.5 research points per day and a second queue slot.',
    cost: 3200,
    rpCost: 26,
    requires: ['HOME_LAB'],
    minReputation: 15,
    rpPerDayBonus: 2.5,
    queueSlotsBonus: 1,
  ),
  'RND_DIVISION': const ResearchProject(
    id: 'RND_DIVISION',
    name: 'R&D Division',
    branch: ResearchBranch.lab,
    tier: 3,
    description: 'A staffed research division. Adds 6.0 research points per day and a third queue slot.',
    cost: 14000,
    rpCost: 90,
    requires: ['RESEARCH_WING'],
    minReputation: 40,
    rpPerDayBonus: 6.0,
    queueSlotsBonus: 1,
  ),
  'AUTOMATED_TELEMETRY': const ResearchProject(
    id: 'AUTOMATED_TELEMETRY',
    name: 'Automated Telemetry',
    branch: ResearchBranch.lab,
    tier: 3,
    description: 'Rigs report their own performance data, so your fleet keeps earning while the app is closed. Away earnings pay out 15% more.',
    cost: 6000,
    rpCost: 55,
    requires: ['RESEARCH_WING'],
    minReputation: 25,
    offlineRateBonus: 0.15,
  ),
  'LIGHTS_OUT_OPERATIONS': const ResearchProject(
    id: 'LIGHTS_OUT_OPERATIONS',
    name: 'Lights-Out Operations',
    branch: ResearchBranch.lab,
    tier: 4,
    description: 'The floor runs unattended overnight. Away earnings pay out a further 20% more.',
    cost: 22000,
    rpCost: 130,
    requires: ['AUTOMATED_TELEMETRY'],
    minReputation: 45,
    offlineRateBonus: 0.20,
  ),
  'CONTINUOUS_OPTIMIZATION': const ResearchProject(
    id: 'CONTINUOUS_OPTIMIZATION',
    name: 'Continuous Optimization',
    branch: ResearchBranch.lab,
    tier: 4,
    description: 'A standing programme of incremental tuning. Each level adds 2% to all service income, and it never runs out of levels.',
    cost: 9000,
    rpCost: 70,
    requires: ['RND_DIVISION'],
    minReputation: 40,
    incomeBonus: 0.02,
    repeatable: true,
    costGrowth: 1.6,
    maxLevel: 99,
  ),

  // ── Compute ──
  'KERNEL_TUNING': const ResearchProject(
    id: 'KERNEL_TUNING',
    name: 'Kernel Tuning',
    branch: ResearchBranch.compute,
    tier: 1,
    description: 'Scheduler and IRQ tuning squeeze 8% more useful work out of every CPU.',
    cost: 700,
    rpCost: 7,
    requires: [],
    minReputation: 0,
    cpuBoost: 0.08,
  ),
  'HYPERVISOR_OPTIMIZATION': const ResearchProject(
    id: 'HYPERVISOR_OPTIMIZATION',
    name: 'Hypervisor Optimization',
    branch: ResearchBranch.compute,
    tier: 2,
    description: 'Paravirtualised drivers and CPU pinning cut virtualisation overhead for another 12% of CPU capacity.',
    cost: 3000,
    rpCost: 28,
    requires: ['KERNEL_TUNING'],
    minReputation: 15,
    cpuBoost: 0.12,
  ),
  'OVERCLOCK_PROFILES': const ResearchProject(
    id: 'OVERCLOCK_PROFILES',
    name: 'Overclock Profiles',
    branch: ResearchBranch.compute,
    tier: 3,
    description: 'Per-chip tuned clocks add 15% CPU capacity, at the price of 10% less cooling headroom.',
    cost: 7500,
    rpCost: 62,
    requires: ['HYPERVISOR_OPTIMIZATION'],
    minReputation: 30,
    cpuBoost: 0.15,
    coolingEfficiency: -0.10,
  ),
  'SILICON_BINNING': const ResearchProject(
    id: 'SILICON_BINNING',
    name: 'Silicon Binning',
    branch: ResearchBranch.compute,
    tier: 4,
    description: 'Hand-picked chips run cooler and faster: 18% more CPU capacity and 10% more cooling headroom.',
    cost: 20000,
    rpCost: 135,
    requires: ['OVERCLOCK_PROFILES'],
    minReputation: 45,
    cpuBoost: 0.18,
    coolingEfficiency: 0.10,
  ),

  // ── Storage & Data ──
  'BLOCK_DEDUP': const ResearchProject(
    id: 'BLOCK_DEDUP',
    name: 'Block Deduplication',
    branch: ResearchBranch.storage,
    tier: 1,
    description: 'Identical blocks are stored once, cutting the storage every service needs by 10%.',
    cost: 800,
    rpCost: 8,
    requires: [],
    minReputation: 5,
    storageCompression: 0.10,
  ),
  'COMPRESSION_I': const ResearchProject(
    id: 'COMPRESSION_I',
    name: 'Inline Compression',
    branch: ResearchBranch.storage,
    tier: 2,
    description: 'Compress data on the way to disk for another 12% off storage requirements.',
    cost: 2800,
    rpCost: 26,
    requires: ['BLOCK_DEDUP'],
    minReputation: 15,
    storageCompression: 0.12,
  ),
  'COMPRESSION_II': const ResearchProject(
    id: 'COMPRESSION_II',
    name: 'Adaptive Compression',
    branch: ResearchBranch.storage,
    tier: 3,
    description: 'Per-workload compression algorithms shave a further 15% off storage requirements.',
    cost: 9000,
    rpCost: 70,
    requires: ['COMPRESSION_I'],
    minReputation: 30,
    storageCompression: 0.15,
  ),
  'TIERED_CACHING': const ResearchProject(
    id: 'TIERED_CACHING',
    name: 'Tiered Caching',
    branch: ResearchBranch.storage,
    tier: 4,
    description: 'Hot data is served from RAM and NVMe, lifting customer satisfaction by 5%.',
    cost: 16000,
    rpCost: 120,
    requires: ['COMPRESSION_II'],
    minReputation: 40,
    satisfactionBonus: 0.05,
  ),

  // ── Networking ──
  'MESH_NETWORKING': const ResearchProject(
    id: 'MESH_NETWORKING',
    name: 'Mesh Networking',
    branch: ResearchBranch.networking,
    tier: 1,
    description: 'Learn to run a second router so rigs can be split across separate ISP connections.',
    cost: 390,
    rpCost: 6,
    requires: [],
    minReputation: 0,
    maxRoutersBonus: 1,
  ),
  'PACKET_SHAPING': const ResearchProject(
    id: 'PACKET_SHAPING',
    name: 'Packet Shaping',
    branch: ResearchBranch.networking,
    tier: 2,
    description: 'Smarter queuing trims 10% off the bandwidth every service consumes.',
    cost: 1600,
    rpCost: 20,
    requires: ['MESH_NETWORKING'],
    minReputation: 10,
    bandwidthOverhead: 0.10,
  ),
  'BACKBONE_ROUTING': const ResearchProject(
    id: 'BACKBONE_ROUTING',
    name: 'Backbone Routing',
    branch: ResearchBranch.networking,
    tier: 2,
    description: 'Advanced routing tables support a third router on the network.',
    cost: 1600,
    rpCost: 24,
    requires: ['MESH_NETWORKING'],
    minReputation: 15,
    maxRoutersBonus: 1,
  ),
  'QOS_PRIORITIZATION': const ResearchProject(
    id: 'QOS_PRIORITIZATION',
    name: 'QoS Prioritization',
    branch: ResearchBranch.networking,
    tier: 3,
    description: 'Latency-sensitive traffic goes first, lifting customer satisfaction by 4%.',
    cost: 5200,
    rpCost: 52,
    requires: ['PACKET_SHAPING'],
    minReputation: 25,
    satisfactionBonus: 0.04,
  ),
  'FIBER_BACKHAUL': const ResearchProject(
    id: 'FIBER_BACKHAUL',
    name: 'Fiber Backhaul',
    branch: ResearchBranch.networking,
    tier: 3,
    description: 'Dedicated backhaul lets you operate up to five routers total.',
    cost: 5200,
    rpCost: 58,
    requires: ['BACKBONE_ROUTING'],
    minReputation: 35,
    maxRoutersBonus: 2,
  ),
  'ANYCAST_EDGE': const ResearchProject(
    id: 'ANYCAST_EDGE',
    name: 'Anycast Edge',
    branch: ResearchBranch.networking,
    tier: 4,
    description: 'Traffic lands at the nearest edge node, cutting bandwidth needs by a further 15%.',
    cost: 18000,
    rpCost: 125,
    requires: ['QOS_PRIORITIZATION'],
    minReputation: 40,
    bandwidthOverhead: 0.15,
  ),
  'HYPERSCALE_NETWORKING': const ResearchProject(
    id: 'HYPERSCALE_NETWORKING',
    name: 'Hyperscale Networking',
    branch: ResearchBranch.networking,
    tier: 4,
    description: 'Software-defined networking lets you operate up to eight routers total.',
    cost: 16000,
    rpCost: 140,
    requires: ['FIBER_BACKHAUL'],
    minReputation: 50,
    maxRoutersBonus: 3,
  ),

  // ── Power & Cooling ──
  'POWER_TUNING': const ResearchProject(
    id: 'POWER_TUNING',
    name: 'Power Tuning',
    branch: ResearchBranch.power,
    tier: 1,
    description: 'Undervolting and smarter fan curves cut your electricity bill by 10%.',
    cost: 580,
    rpCost: 7,
    requires: [],
    minReputation: 5,
    electricityDiscount: 0.10,
  ),
  'LIQUID_COOLING_I': const ResearchProject(
    id: 'LIQUID_COOLING_I',
    name: 'Liquid Cooling Research',
    branch: ResearchBranch.power,
    tier: 2,
    description: 'In-house loop designs give every rig 12% more cooling headroom.',
    cost: 2400,
    rpCost: 24,
    requires: ['POWER_TUNING'],
    minReputation: 10,
    coolingEfficiency: 0.12,
  ),
  'SMART_PDU': const ResearchProject(
    id: 'SMART_PDU',
    name: 'Smart Power Distribution',
    branch: ResearchBranch.power,
    tier: 2,
    description: 'Rack-grade PDUs shave another 15% off the power bill.',
    cost: 2600,
    rpCost: 28,
    requires: ['POWER_TUNING'],
    minReputation: 25,
    electricityDiscount: 0.15,
  ),
  'LIQUID_COOLING_II': const ResearchProject(
    id: 'LIQUID_COOLING_II',
    name: 'Direct-to-Chip Cooling',
    branch: ResearchBranch.power,
    tier: 3,
    description: 'Cold plates straight onto the die add a further 15% cooling headroom.',
    cost: 8000,
    rpCost: 66,
    requires: ['LIQUID_COOLING_I'],
    minReputation: 30,
    coolingEfficiency: 0.15,
  ),
  'RENEWABLE_ENERGY': const ResearchProject(
    id: 'RENEWABLE_ENERGY',
    name: 'Renewable Energy Contracts',
    branch: ResearchBranch.power,
    tier: 3,
    description: 'Solar and wind PPAs slash your electricity bill by another 15%.',
    cost: 7800,
    rpCost: 72,
    requires: ['SMART_PDU'],
    minReputation: 40,
    electricityDiscount: 0.15,
  ),
  'IMMERSION_COOLING': const ResearchProject(
    id: 'IMMERSION_COOLING',
    name: 'Immersion Cooling',
    branch: ResearchBranch.power,
    tier: 4,
    description: 'Whole rigs submerged in dielectric fluid: 25% more cooling headroom and far steadier temperatures.',
    cost: 24000,
    rpCost: 145,
    requires: ['LIQUID_COOLING_II'],
    minReputation: 45,
    coolingEfficiency: 0.25,
    incidentResistance: 0.10,
  ),
  'WASTE_HEAT_RECOVERY': const ResearchProject(
    id: 'WASTE_HEAT_RECOVERY',
    name: 'Waste Heat Recovery',
    branch: ResearchBranch.power,
    tier: 4,
    description: 'Sell your exhaust heat to the district network for another 12% off the power bill.',
    cost: 21000,
    rpCost: 138,
    requires: ['RENEWABLE_ENERGY'],
    minReputation: 50,
    electricityDiscount: 0.12,
  ),

  // ── Business ──
  'BULK_PURCHASING': const ResearchProject(
    id: 'BULK_PURCHASING',
    name: 'Bulk Purchasing',
    branch: ResearchBranch.business,
    tier: 1,
    description: 'Supplier deals knock 20% off the price of every new rig.',
    cost: 780,
    rpCost: 9,
    requires: [],
    minReputation: 10,
    rigCostDiscount: 0.20,
  ),
  'SALES_TEAM': const ResearchProject(
    id: 'SALES_TEAM',
    name: 'Sales Team',
    branch: ResearchBranch.business,
    tier: 1,
    description: 'A part-time sales rep lets you juggle one more company contract at a time.',
    cost: 980,
    rpCost: 10,
    requires: [],
    minReputation: 10,
    contractSlotsBonus: 1,
  ),
  'RUNBOOK_AUTOMATION': const ResearchProject(
    id: 'RUNBOOK_AUTOMATION',
    name: 'Runbook Automation',
    branch: ResearchBranch.business,
    tier: 2,
    description: 'Documented, automated responses mean 20% fewer incidents reach you at all.',
    cost: 3400,
    rpCost: 30,
    requires: ['SALES_TEAM'],
    minReputation: 15,
    incidentResistance: 0.20,
  ),
  'SUPPLY_CHAIN_OPTIMIZATION': const ResearchProject(
    id: 'SUPPLY_CHAIN_OPTIMIZATION',
    name: 'Supply Chain Optimization',
    branch: ResearchBranch.business,
    tier: 2,
    description: 'Streamlined procurement knocks an additional 15% off every new rig.',
    cost: 3250,
    rpCost: 32,
    requires: ['BULK_PURCHASING'],
    minReputation: 25,
    rigCostDiscount: 0.15,
  ),
  'ACCOUNT_MANAGERS': const ResearchProject(
    id: 'ACCOUNT_MANAGERS',
    name: 'Account Managers',
    branch: ResearchBranch.business,
    tier: 2,
    description: 'Dedicated account managers handle two additional simultaneous contracts.',
    cost: 3900,
    rpCost: 36,
    requires: ['SALES_TEAM'],
    minReputation: 30,
    contractSlotsBonus: 2,
  ),
  'REPUTATION_MANAGEMENT': const ResearchProject(
    id: 'REPUTATION_MANAGEMENT',
    name: 'Reputation Management',
    branch: ResearchBranch.business,
    tier: 3,
    description: 'Public status pages and proactive comms lift customer satisfaction by 4%.',
    cost: 6400,
    rpCost: 58,
    requires: ['RUNBOOK_AUTOMATION'],
    minReputation: 30,
    satisfactionBonus: 0.04,
  ),
  'PREMIUM_SLAS': const ResearchProject(
    id: 'PREMIUM_SLAS',
    name: 'Premium SLAs',
    branch: ResearchBranch.business,
    tier: 3,
    description: 'Guaranteed uptime tiers customers will pay for: 8% more income from every service.',
    cost: 11000,
    rpCost: 80,
    requires: ['ACCOUNT_MANAGERS'],
    minReputation: 35,
    incomeBonus: 0.08,
  ),
  'ENTERPRISE_SALES': const ResearchProject(
    id: 'ENTERPRISE_SALES',
    name: 'Enterprise Sales Division',
    branch: ResearchBranch.business,
    tier: 4,
    description: 'A dedicated enterprise sales team lets you manage one more contract simultaneously.',
    cost: 9750,
    rpCost: 128,
    requires: ['PREMIUM_SLAS'],
    minReputation: 45,
    contractSlotsBonus: 1,
  ),
  'AUTO_RENEWAL': const ResearchProject(
    id: 'AUTO_RENEWAL',
    name: 'Auto-Renewal Contracts',
    branch: ResearchBranch.business,
    tier: 4,
    description: 'Customers roll over by default, adding 12% to all service income.',
    cost: 19000,
    rpCost: 132,
    requires: ['PREMIUM_SLAS'],
    minReputation: 45,
    incomeBonus: 0.12,
  ),
};

late final List<ResearchProject> researchList = researchById.values.toList()
  ..sort((a, b) {
    if (a.branch != b.branch) return a.branch.index.compareTo(b.branch.index);
    if (a.tier != b.tier) return a.tier.compareTo(b.tier);
    return a.cost.compareTo(b.cost);
  });

List<ResearchProject> researchInBranch(ResearchBranch branch) =>
    researchList.where((p) => p.branch == branch).toList();

/// Highest tier present in a branch, so the tree UI knows how many rows to draw.
int researchMaxTier(ResearchBranch branch) {
  var max = 1;
  for (final p in researchList) {
    if (p.branch == branch && p.tier > max) max = p.tier;
  }
  return max;
}

class ResearchEffects {
  final int maxRouters;
  final double electricityDiscount;
  final double rigCostDiscount;
  final int contractSlots;
  final double coolingEfficiency;
  final double cpuBoost;
  final double storageCompression;
  final double bandwidthOverhead;
  final double incidentResistance;
  final double offlineRateBonus;
  final double satisfactionBonus;
  final double rpPerDayBonus;
  final double incomeBonus;
  final int queueSlots;

  const ResearchEffects({
    required this.maxRouters,
    required this.electricityDiscount,
    required this.rigCostDiscount,
    required this.contractSlots,
    this.coolingEfficiency = 0,
    this.cpuBoost = 0,
    this.storageCompression = 0,
    this.bandwidthOverhead = 0,
    this.incidentResistance = 0,
    this.offlineRateBonus = 0,
    this.satisfactionBonus = 0,
    this.rpPerDayBonus = 0,
    this.incomeBonus = 0,
    this.queueSlots = 1,
  });
}

ResearchEffects getResearchEffects(
  Set<String> owned, {
  int baseMaxRouters = 1,
  int baseContractSlots = 2,
  Map<String, int> levels = const {},
}) {
  int maxRouters = baseMaxRouters;
  double electricityDiscount = 0;
  double rigCostDiscount = 0;
  int contractSlots = baseContractSlots;
  double coolingEfficiency = 0;
  double cpuBoost = 0;
  double storageCompression = 0;
  double bandwidthOverhead = 0;
  double incidentResistance = 0;
  double offlineRateBonus = 0;
  double satisfactionBonus = 0;
  double rpPerDayBonus = 0;
  double incomeBonus = 0;
  int queueSlots = 1;

  void apply(ResearchProject project, int stacks) {
    if (project.maxRoutersBonus != null) maxRouters += project.maxRoutersBonus! * stacks;
    if (project.electricityDiscount != null) electricityDiscount += project.electricityDiscount! * stacks;
    if (project.rigCostDiscount != null) rigCostDiscount += project.rigCostDiscount! * stacks;
    if (project.contractSlotsBonus != null) contractSlots += project.contractSlotsBonus! * stacks;
    if (project.coolingEfficiency != null) coolingEfficiency += project.coolingEfficiency! * stacks;
    if (project.cpuBoost != null) cpuBoost += project.cpuBoost! * stacks;
    if (project.storageCompression != null) storageCompression += project.storageCompression! * stacks;
    if (project.bandwidthOverhead != null) bandwidthOverhead += project.bandwidthOverhead! * stacks;
    if (project.incidentResistance != null) incidentResistance += project.incidentResistance! * stacks;
    if (project.offlineRateBonus != null) offlineRateBonus += project.offlineRateBonus! * stacks;
    if (project.satisfactionBonus != null) satisfactionBonus += project.satisfactionBonus! * stacks;
    if (project.rpPerDayBonus != null) rpPerDayBonus += project.rpPerDayBonus! * stacks;
    if (project.incomeBonus != null) incomeBonus += project.incomeBonus! * stacks;
    if (project.queueSlotsBonus != null) queueSlots += project.queueSlotsBonus! * stacks;
  }

  for (final id in owned) {
    final project = researchById[id];
    if (project == null || project.repeatable) continue;
    apply(project, 1);
  }
  // Repeatable projects live in the level map, not the owned set, so they
  // stack instead of being counted once.
  for (final entry in levels.entries) {
    final project = researchById[entry.key];
    if (project == null || !project.repeatable || entry.value <= 0) continue;
    apply(project, entry.value);
  }

  return ResearchEffects(
    maxRouters: maxRouters,
    electricityDiscount: electricityDiscount.clamp(0, 0.6),
    rigCostDiscount: rigCostDiscount.clamp(0, 0.5),
    contractSlots: contractSlots,
    coolingEfficiency: coolingEfficiency.clamp(-0.5, 0.7),
    cpuBoost: cpuBoost.clamp(0, 1.0),
    storageCompression: storageCompression.clamp(0, 0.6),
    bandwidthOverhead: bandwidthOverhead.clamp(0, 0.5),
    incidentResistance: incidentResistance.clamp(0, 0.8),
    offlineRateBonus: offlineRateBonus.clamp(0, 0.6),
    satisfactionBonus: satisfactionBonus.clamp(0, 0.3),
    rpPerDayBonus: rpPerDayBonus,
    incomeBonus: incomeBonus,
    queueSlots: queueSlots,
  );
}

/// Research points earned per day. Always non-zero so a fresh save can still
/// finish a tier-1 project without having built the lab branch first.
double researchPointsPerDay({
  required int rigsServingTraffic,
  required double rpPerDayBonus,
  required int prestigeLevel,
}) {
  final base = 0.5 + 0.35 * rigsServingTraffic + rpPerDayBonus;
  return base * (1 + 0.15 * prestigeLevel);
}
