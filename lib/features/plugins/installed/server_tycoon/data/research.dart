// Auto-ported from Roblox Server Hosting Tycoon

class ResearchProject {
  final String id;
  final String name;
  final String category;
  final String description;
  final int cost;
  final List<String> requires;
  final int minReputation;
  final int? maxRoutersBonus;
  final double? electricityDiscount;
  final double? rigCostDiscount;
  final int? contractSlotsBonus;

  const ResearchProject({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.cost,
    required this.requires,
    required this.minReputation,
    this.maxRoutersBonus,
    this.electricityDiscount,
    this.rigCostDiscount,
    this.contractSlotsBonus,
  });
}

final Map<String, ResearchProject> researchById = {
  'MESH_NETWORKING': const ResearchProject(
    id: 'MESH_NETWORKING',
    name: 'Mesh Networking',
    category: 'Networking',
    description: 'Learn to run a second router so rigs can be split across separate ISP connections.',
    cost: 600,
    requires: [],
    minReputation: 0,
    maxRoutersBonus: 1,
  ),
  'BACKBONE_ROUTING': const ResearchProject(
    id: 'BACKBONE_ROUTING',
    name: 'Backbone Routing',
    category: 'Networking',
    description: 'Advanced routing tables support a third router on the network.',
    cost: 2500,
    requires: ['MESH_NETWORKING'],
    minReputation: 15,
    maxRoutersBonus: 1,
  ),
  'FIBER_BACKHAUL': const ResearchProject(
    id: 'FIBER_BACKHAUL',
    name: 'Fiber Backhaul',
    category: 'Networking',
    description: 'Dedicated backhaul lets you operate up to five routers total.',
    cost: 8000,
    requires: ['BACKBONE_ROUTING'],
    minReputation: 35,
    maxRoutersBonus: 2,
  ),
  'POWER_TUNING': const ResearchProject(
    id: 'POWER_TUNING',
    name: 'Power Tuning',
    category: 'Efficiency',
    description: 'Undervolting and smarter fan curves cut your electricity bill by 10%.',
    cost: 900,
    requires: [],
    minReputation: 5,
    electricityDiscount: 0.10,
  ),
  'SMART_PDU': const ResearchProject(
    id: 'SMART_PDU',
    name: 'Smart Power Distribution',
    category: 'Efficiency',
    description: 'Rack-grade PDUs shave another 15% off the power bill.',
    cost: 4000,
    requires: ['POWER_TUNING'],
    minReputation: 25,
    electricityDiscount: 0.15,
  ),
  'BULK_PURCHASING': const ResearchProject(
    id: 'BULK_PURCHASING',
    name: 'Bulk Purchasing',
    category: 'Business',
    description: 'Supplier deals knock 20% off the price of every new rig.',
    cost: 1200,
    requires: [],
    minReputation: 10,
    rigCostDiscount: 0.20,
  ),
  'SALES_TEAM': const ResearchProject(
    id: 'SALES_TEAM',
    name: 'Sales Team',
    category: 'Business',
    description: 'A part-time sales rep lets you juggle one more company contract at a time.',
    cost: 1500,
    requires: [],
    minReputation: 10,
    contractSlotsBonus: 1,
  ),
  'ACCOUNT_MANAGERS': const ResearchProject(
    id: 'ACCOUNT_MANAGERS',
    name: 'Account Managers',
    category: 'Business',
    description: 'Dedicated account managers handle two additional simultaneous contracts.',
    cost: 6000,
    requires: ['SALES_TEAM'],
    minReputation: 30,
    contractSlotsBonus: 2,
  ),
};

late final List<ResearchProject> researchList = researchById.values.toList()
  ..sort((a, b) {
    if (a.category != b.category) return a.category.compareTo(b.category);
    return a.cost.compareTo(b.cost);
  });

class ResearchEffects {
  final int maxRouters;
  final double electricityDiscount;
  final double rigCostDiscount;
  final int contractSlots;

  const ResearchEffects({
    required this.maxRouters,
    required this.electricityDiscount,
    required this.rigCostDiscount,
    required this.contractSlots,
  });
}

ResearchEffects getResearchEffects(
  Set<String> owned, {
  int baseMaxRouters = 1,
  int baseContractSlots = 2,
}) {
  int maxRouters = baseMaxRouters;
  double electricityDiscount = 0;
  double rigCostDiscount = 0;
  int contractSlots = baseContractSlots;

  for (final id in owned) {
    final project = researchById[id];
    if (project == null) continue;
    if (project.maxRoutersBonus != null) maxRouters += project.maxRoutersBonus!;
    if (project.electricityDiscount != null) electricityDiscount += project.electricityDiscount!;
    if (project.rigCostDiscount != null) rigCostDiscount += project.rigCostDiscount!;
    if (project.contractSlotsBonus != null) contractSlots += project.contractSlotsBonus!;
  }

  return ResearchEffects(
    maxRouters: maxRouters,
    electricityDiscount: electricityDiscount.clamp(0, 0.6),
    rigCostDiscount: rigCostDiscount.clamp(0, 0.5),
    contractSlots: contractSlots,
  );
}
