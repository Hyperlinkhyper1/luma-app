// Auto-ported from Roblox Server Hosting Tycoon

enum InternetTier { home, business, dedicated, colocation }

class InternetPlan {
  final String id;
  final String name;
  final InternetTier tier;
  final int downMbps;
  final int upMbps;
  final int monthlyPrice;
  final int maxLatencyMs;

  const InternetPlan({
    required this.id,
    required this.name,
    required this.tier,
    required this.downMbps,
    required this.upMbps,
    required this.monthlyPrice,
    required this.maxLatencyMs,
  });
}

final Map<String, InternetPlan> internetPlansById = {
  'HOME_25': const InternetPlan(
    id: 'HOME_25',
    name: 'Home Internet - 25 Mbps',
    tier: InternetTier.home,
    downMbps: 25,
    upMbps: 5,
    monthlyPrice: 0,
    maxLatencyMs: 35,
  ),
  'HOME_100': const InternetPlan(
    id: 'HOME_100',
    name: 'Home Internet - 100 Mbps',
    tier: InternetTier.home,
    downMbps: 100,
    upMbps: 20,
    monthlyPrice: 55,
    maxLatencyMs: 25,
  ),
  'HOME_500': const InternetPlan(
    id: 'HOME_500',
    name: 'Home Internet - 500 Mbps',
    tier: InternetTier.home,
    downMbps: 500,
    upMbps: 50,
    monthlyPrice: 90,
    maxLatencyMs: 20,
  ),
  'HOME_1000': const InternetPlan(
    id: 'HOME_1000',
    name: 'Home Internet - 1 Gbps',
    tier: InternetTier.home,
    downMbps: 1000,
    upMbps: 100,
    monthlyPrice: 130,
    maxLatencyMs: 15,
  ),
  'BUSINESS_1G': const InternetPlan(
    id: 'BUSINESS_1G',
    name: 'Business Fiber - 1 Gbps',
    tier: InternetTier.business,
    downMbps: 1000,
    upMbps: 1000,
    monthlyPrice: 200,
    maxLatencyMs: 12,
  ),
  'BUSINESS_2G': const InternetPlan(
    id: 'BUSINESS_2G',
    name: 'Business Fiber - 2 Gbps',
    tier: InternetTier.business,
    downMbps: 2000,
    upMbps: 2000,
    monthlyPrice: 400,
    maxLatencyMs: 10,
  ),
  'BUSINESS_5G': const InternetPlan(
    id: 'BUSINESS_5G',
    name: 'Business Fiber - 5 Gbps',
    tier: InternetTier.business,
    downMbps: 5000,
    upMbps: 5000,
    monthlyPrice: 850,
    maxLatencyMs: 8,
  ),
  'BUSINESS_10G': const InternetPlan(
    id: 'BUSINESS_10G',
    name: 'Business Fiber - 10 Gbps',
    tier: InternetTier.business,
    downMbps: 10000,
    upMbps: 10000,
    monthlyPrice: 1600,
    maxLatencyMs: 6,
  ),
  'DEDICATED_10G': const InternetPlan(
    id: 'DEDICATED_10G',
    name: 'Dedicated Fiber - 10 Gbps',
    tier: InternetTier.dedicated,
    downMbps: 10000,
    upMbps: 10000,
    monthlyPrice: 2200,
    maxLatencyMs: 5,
  ),
  'DEDICATED_25G': const InternetPlan(
    id: 'DEDICATED_25G',
    name: 'Dedicated Fiber - 25 Gbps',
    tier: InternetTier.dedicated,
    downMbps: 25000,
    upMbps: 25000,
    monthlyPrice: 3800,
    maxLatencyMs: 4,
  ),
  'DEDICATED_40G': const InternetPlan(
    id: 'DEDICATED_40G',
    name: 'Dedicated Fiber - 40 Gbps',
    tier: InternetTier.dedicated,
    downMbps: 40000,
    upMbps: 40000,
    monthlyPrice: 5600,
    maxLatencyMs: 3,
  ),
  'DEDICATED_100G': const InternetPlan(
    id: 'DEDICATED_100G',
    name: 'Dedicated Fiber - 100 Gbps',
    tier: InternetTier.dedicated,
    downMbps: 100000,
    upMbps: 100000,
    monthlyPrice: 12000,
    maxLatencyMs: 2,
  ),
  'COLOCATION_400G': const InternetPlan(
    id: 'COLOCATION_400G',
    name: 'Colocation Uplink - 400 Gbps',
    tier: InternetTier.colocation,
    downMbps: 400000,
    upMbps: 400000,
    monthlyPrice: 38000,
    maxLatencyMs: 1,
  ),
};

late final List<InternetPlan> internetPlanList = internetPlansById.values.toList()
  ..sort((a, b) => a.monthlyPrice.compareTo(b.monthlyPrice));
