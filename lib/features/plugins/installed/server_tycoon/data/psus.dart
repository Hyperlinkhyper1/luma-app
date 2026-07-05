// Auto-ported from Roblox Server Hosting Tycoon

enum EfficiencyRating { white, bronze, silver, gold, platinum, titanium }

class PSU {
  final String id;
  final String name;
  final int wattage;
  final EfficiencyRating efficiencyRating;
  final double efficiencyPercent;
  final int price;

  const PSU({
    required this.id,
    required this.name,
    required this.wattage,
    required this.efficiencyRating,
    required this.efficiencyPercent,
    required this.price,
  });
}

final Map<String, PSU> psusById = {
  'CORSAIR_VS350': const PSU(
    id: 'CORSAIR_VS350',
    name: 'Corsair VS350',
    wattage: 350,
    efficiencyRating: EfficiencyRating.white,
    efficiencyPercent: 0.70,
    price: 0,
  ),
  'SEASONIC_FOCUS_GX550': const PSU(
    id: 'SEASONIC_FOCUS_GX550',
    name: 'Seasonic Focus GX-550',
    wattage: 550,
    efficiencyRating: EfficiencyRating.gold,
    efficiencyPercent: 0.90,
    price: 380,
  ),
  'CORSAIR_RM750X': const PSU(
    id: 'CORSAIR_RM750X',
    name: 'Corsair RM750x',
    wattage: 750,
    efficiencyRating: EfficiencyRating.gold,
    efficiencyPercent: 0.90,
    price: 550,
  ),
  'BEQUIET_STRAIGHT_POWER_1000': const PSU(
    id: 'BEQUIET_STRAIGHT_POWER_1000',
    name: 'be quiet! Straight Power 11 1000W',
    wattage: 1000,
    efficiencyRating: EfficiencyRating.platinum,
    efficiencyPercent: 0.93,
    price: 950,
  ),
  'SUPER_FLOWER_LEADEX_1600': const PSU(
    id: 'SUPER_FLOWER_LEADEX_1600',
    name: 'Super Flower Leadex Titanium 1600W',
    wattage: 1600,
    efficiencyRating: EfficiencyRating.titanium,
    efficiencyPercent: 0.96,
    price: 2100,
  ),
  'SEASONIC_PRIME_2200': const PSU(
    id: 'SEASONIC_PRIME_2200',
    name: 'Seasonic Prime TX-2200',
    wattage: 2200,
    efficiencyRating: EfficiencyRating.titanium,
    efficiencyPercent: 0.96,
    price: 3400,
  ),
  'SERVER_PSU_2000_REDUNDANT': const PSU(
    id: 'SERVER_PSU_2000_REDUNDANT',
    name: 'Redundant Server PSU 2000W (dual)',
    wattage: 2000,
    efficiencyRating: EfficiencyRating.platinum,
    efficiencyPercent: 0.94,
    price: 4200,
  ),
  'EVGA_600_BR': const PSU(
    id: 'EVGA_600_BR',
    name: 'EVGA 600 BR',
    wattage: 600,
    efficiencyRating: EfficiencyRating.bronze,
    efficiencyPercent: 0.85,
    price: 240,
  ),
  'SERVER_PSU_3000_TITANIUM': const PSU(
    id: 'SERVER_PSU_3000_TITANIUM',
    name: 'Redundant Server PSU 3000W Titanium (dual)',
    wattage: 3000,
    efficiencyRating: EfficiencyRating.titanium,
    efficiencyPercent: 0.96,
    price: 8600,
  ),
  'HYPERSCALE_PSU_5000': const PSU(
    id: 'HYPERSCALE_PSU_5000',
    name: 'Hyperscale Rack Bus PSU 5000W (N+1)',
    wattage: 5000,
    efficiencyRating: EfficiencyRating.titanium,
    efficiencyPercent: 0.97,
    price: 17000,
  ),
  'GENERIC_300W': const PSU(
    id: 'GENERIC_300W',
    name: 'Generic OEM 300W',
    wattage: 300,
    efficiencyRating: EfficiencyRating.white,
    efficiencyPercent: 0.65,
    price: 20,
  ),
  'CORSAIR_SF750': const PSU(
    id: 'CORSAIR_SF750',
    name: 'Corsair SF750 Platinum (SFX)',
    wattage: 750,
    efficiencyRating: EfficiencyRating.platinum,
    efficiencyPercent: 0.93,
    price: 700,
  ),
  'SERVER_PSU_1200_REDUNDANT': const PSU(
    id: 'SERVER_PSU_1200_REDUNDANT',
    name: 'Redundant Server PSU 1200W (dual)',
    wattage: 1200,
    efficiencyRating: EfficiencyRating.gold,
    efficiencyPercent: 0.92,
    price: 1800,
  ),
};

late final List<PSU> psuList = psusById.values.toList()
  ..sort((a, b) => a.price.compareTo(b.price));
