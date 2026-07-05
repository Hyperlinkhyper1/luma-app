// Auto-ported from Roblox Server Hosting Tycoon
// Shared economic constants and formulas.

import 'dart:math' as math;

class Economy {
  static const int startingMoney = 250;
  static const int dayLengthSeconds = 180; // 1 in-game day = 3 real minutes
  static const double baseElectricityPricePerKWh = 0.15; // $/kWh

  static const double reputationSatisfactionBaseline = 0.75;
  static const double reputationChangeRate = 6; // reputation points per day at max deviation
  static const double reputationMin = 0;
  static const double reputationMax = 100;

  static double getFluctuatedPrice(double basePrice, int daySeed) {
    final wobble = math.sin(daySeed * 12.9898) * 43758.5453;
    final frac = wobble - wobble.floorToDouble();
    final variance = (frac - 0.5) * 0.3; // -0.15 .. +0.15
    return basePrice * (1 + variance);
  }

  static double calculateElectricityCost(double avgWatts, {double? pricePerKWh}) {
    final price = pricePerKWh ?? baseElectricityPricePerKWh;
    final kWhPerDay = (avgWatts * 24) / 1000;
    return kWhPerDay * price;
  }

  static double calculateReputationDelta(double avgSatisfaction) {
    final deviation = avgSatisfaction - reputationSatisfactionBaseline;
    return deviation * reputationChangeRate;
  }
}
