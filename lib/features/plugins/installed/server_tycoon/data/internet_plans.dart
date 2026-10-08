// Auto-ported from Roblox Server Hosting Tycoon

import '../../../../../l10n/current_l.dart';

enum InternetTier { home, business, dedicated, colocation }

class InternetPlan {
  final String id;
  final InternetTier tier;
  final int downMbps;
  final int upMbps;
  final int monthlyPrice;
  final int maxLatencyMs;

  const InternetPlan({
    required this.id,
    required this.tier,
    required this.downMbps,
    required this.upMbps,
    required this.monthlyPrice,
    required this.maxLatencyMs,
  });

  String get name => switch (id) {
        'HOME_25' => currentL.serverTycoonPlanHome('25 Mbps'),
        'HOME_100' => currentL.serverTycoonPlanHome('100 Mbps'),
        'HOME_500' => currentL.serverTycoonPlanHome('500 Mbps'),
        'HOME_1000' => currentL.serverTycoonPlanHome('1 Gbps'),
        'BUSINESS_1G' => currentL.serverTycoonPlanBusiness('1 Gbps'),
        'BUSINESS_2G' => currentL.serverTycoonPlanBusiness('2 Gbps'),
        'BUSINESS_5G' => currentL.serverTycoonPlanBusiness('5 Gbps'),
        'BUSINESS_10G' => currentL.serverTycoonPlanBusiness('10 Gbps'),
        'DEDICATED_10G' => currentL.serverTycoonPlanDedicated('10 Gbps'),
        'DEDICATED_25G' => currentL.serverTycoonPlanDedicated('25 Gbps'),
        'DEDICATED_40G' => currentL.serverTycoonPlanDedicated('40 Gbps'),
        'DEDICATED_100G' => currentL.serverTycoonPlanDedicated('100 Gbps'),
        'COLOCATION_400G' => currentL.serverTycoonPlanColocation('400 Gbps'),
        _ => id,
      };
}

final Map<String, InternetPlan> internetPlansById = {
  'HOME_25': const InternetPlan(
    id: 'HOME_25',
    tier: InternetTier.home,
    downMbps: 25,
    upMbps: 5,
    monthlyPrice: 0,
    maxLatencyMs: 35,
  ),
  'HOME_100': const InternetPlan(
    id: 'HOME_100',
    tier: InternetTier.home,
    downMbps: 100,
    upMbps: 20,
    monthlyPrice: 55,
    maxLatencyMs: 25,
  ),
  'HOME_500': const InternetPlan(
    id: 'HOME_500',
    tier: InternetTier.home,
    downMbps: 500,
    upMbps: 50,
    monthlyPrice: 90,
    maxLatencyMs: 20,
  ),
  'HOME_1000': const InternetPlan(
    id: 'HOME_1000',
    tier: InternetTier.home,
    downMbps: 1000,
    upMbps: 100,
    monthlyPrice: 130,
    maxLatencyMs: 15,
  ),
  'BUSINESS_1G': const InternetPlan(
    id: 'BUSINESS_1G',
    tier: InternetTier.business,
    downMbps: 1000,
    upMbps: 1000,
    monthlyPrice: 200,
    maxLatencyMs: 12,
  ),
  'BUSINESS_2G': const InternetPlan(
    id: 'BUSINESS_2G',
    tier: InternetTier.business,
    downMbps: 2000,
    upMbps: 2000,
    monthlyPrice: 400,
    maxLatencyMs: 10,
  ),
  'BUSINESS_5G': const InternetPlan(
    id: 'BUSINESS_5G',
    tier: InternetTier.business,
    downMbps: 5000,
    upMbps: 5000,
    monthlyPrice: 850,
    maxLatencyMs: 8,
  ),
  'BUSINESS_10G': const InternetPlan(
    id: 'BUSINESS_10G',
    tier: InternetTier.business,
    downMbps: 10000,
    upMbps: 10000,
    monthlyPrice: 1600,
    maxLatencyMs: 6,
  ),
  'DEDICATED_10G': const InternetPlan(
    id: 'DEDICATED_10G',
    tier: InternetTier.dedicated,
    downMbps: 10000,
    upMbps: 10000,
    monthlyPrice: 2200,
    maxLatencyMs: 5,
  ),
  'DEDICATED_25G': const InternetPlan(
    id: 'DEDICATED_25G',
    tier: InternetTier.dedicated,
    downMbps: 25000,
    upMbps: 25000,
    monthlyPrice: 3800,
    maxLatencyMs: 4,
  ),
  'DEDICATED_40G': const InternetPlan(
    id: 'DEDICATED_40G',
    tier: InternetTier.dedicated,
    downMbps: 40000,
    upMbps: 40000,
    monthlyPrice: 5600,
    maxLatencyMs: 3,
  ),
  'DEDICATED_100G': const InternetPlan(
    id: 'DEDICATED_100G',
    tier: InternetTier.dedicated,
    downMbps: 100000,
    upMbps: 100000,
    monthlyPrice: 12000,
    maxLatencyMs: 2,
  ),
  'COLOCATION_400G': const InternetPlan(
    id: 'COLOCATION_400G',
    tier: InternetTier.colocation,
    downMbps: 400000,
    upMbps: 400000,
    monthlyPrice: 38000,
    maxLatencyMs: 1,
  ),
};

late final List<InternetPlan> internetPlanList = internetPlansById.values.toList()
  ..sort((a, b) => a.monthlyPrice.compareTo(b.monthlyPrice));
