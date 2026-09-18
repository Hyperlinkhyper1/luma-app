import 'dart:math' as math;

import '../data/aircraft.dart';
import 'geo.dart';
import 'hub.dart';

/// Every number in the game, as pure functions over explicit arguments.
///
/// Nothing here reads the repository or the clock, so the whole economy can
/// be unit-tested and re-balanced without mounting a widget or simulating a
/// day. Money is in whole euros throughout: the repository accumulates these
/// over thousands of days, and a double would visibly drift.
class Economy {
  const Economy._();

  // ── Fares and demand ────────────────────────────────────────────────

  /// What the market considers a reasonable fare for a sector of this length.
  /// Priced above it and the cabin empties; below it and you leave money on
  /// the table.
  static double fairFareEur(double distanceKm) => 35 + 0.09 * distanceKm;

  /// How full the cabin ends up at [fareEur], as a fraction of seats.
  ///
  /// A logistic on the ratio to the fair fare, tuned so the curve has a real
  /// shoulder rather than a cliff: roughly 95% full at 0.8x the fair fare,
  /// 80% at 1.0x, 45% at 1.2x, and under 10% at 1.5x. That spread is what
  /// makes the fare slider a decision instead of a setting with one right
  /// answer.
  static double loadFactor(double fareEur, double fairFare) {
    if (fairFare <= 0) return 0;
    final ratio = fareEur / fairFare;
    final lf = 1 / (1 + math.exp(7.9 * (ratio - 1.175)));
    return lf.clamp(0.0, 0.98).toDouble();
  }

  /// How attractive a sector of this length is. Very short hops lose to rail
  /// and road; ultra-long ones run out of people willing to sit that long.
  static double distanceFactor(double distanceKm) {
    if (distanceKm <= 0) return 0;
    if (distanceKm < 800) return 0.35 + 0.65 * (distanceKm / 800);
    if (distanceKm <= 6000) return 1;
    if (distanceKm <= 12000) return 1 - 0.55 * ((distanceKm - 6000) / 6000);
    if (distanceKm <= 16000) return 0.45 - 0.20 * ((distanceKm - 12000) / 4000);
    return 0.25;
  }

  /// Scales the geometric mean of two catchments into passengers per day.
  static const double demandScale = 40;

  /// Daily passengers wanting to fly this sector, each way.
  ///
  /// [rivalRoutes] is how many other carriers already serve it — each one
  /// takes a shrinking bite rather than a fixed share, so a crowded route is
  /// unattractive without ever becoming worthless.
  static double demandPerDay({
    required int catchmentA,
    required int catchmentB,
    required double distanceKm,
    int rivalRoutes = 0,
  }) {
    final base = demandScale * math.sqrt(catchmentA * catchmentB.toDouble());
    final competition = 1 / (1 + rivalRoutes * 0.35);
    return base * distanceFactor(distanceKm) * competition;
  }

  // ── Operating costs ─────────────────────────────────────────────────

  /// Jet fuel, euros per kilogram, before the market index.
  static const double baseFuelPriceEurPerKg = 0.80;

  /// Landing and handling at a reference 50-tonne aircraft.
  static const double baseLandingFeeEur = 380;

  /// Cabin and flight crew per block hour. Scales with the cabin, since a
  /// widebody carries several times the crew of a turboprop.
  static double crewPerHourEur(int seats) => 220 + seats * 1.6;

  /// Usable hours in an operating day. What is left over after this is
  /// night curfew, turnaround and scheduled downtime.
  static const double usableHoursPerDay = 18;

  /// How many round trips one aircraft can fly this sector in a day.
  static int rotationsPerDay(double blockHours) {
    if (blockHours <= 0) return 0;
    final perRotation = blockHours * 2;
    return (usableHoursPerDay / perRotation).floor().clamp(0, 8);
  }

  // ── A single leg ────────────────────────────────────────────────────

  /// The result of flying one leg. Every field is whole euros.
  static FlightResult flight({
    required AircraftModel model,
    required double distanceKm,
    required double fareEur,
    required double availableDemand,
    required double fuelPriceIndex,
    required HubEffects hub,
  }) {
    final blockHours = Geo.blockHours(distanceKm, model.cruiseKmh);
    final fair = fairFareEur(distanceKm);
    final premium = distanceKm > 4000 ? hub.premiumMultiplier : 1.0;

    // The lounge uplift raises what people will pay, so it shifts the fair
    // fare rather than the fare — otherwise it would make the cabin emptier.
    final lf = loadFactor(fareEur, fair * premium);
    final seatsSold = model.seats * lf;
    final passengers = math.min(seatsSold, math.max(0, availableDemand)).floor();

    final revenue = (passengers * fareEur).round();
    final cargo = hub.hasCargo ? (revenue * 0.10).round() : 0;

    final fuel = (model.fuelKgPerKm *
            distanceKm *
            baseFuelPriceEurPerKg *
            fuelPriceIndex *
            hub.fuelMultiplier)
        .round();
    final crew = (crewPerHourEur(model.seats) * blockHours).round();
    final landing =
        (baseLandingFeeEur * (model.mtowTonnes / 50) * 2).round();
    final maintenance =
        (model.maintPerHourEur * blockHours * hub.maintenanceMultiplier)
            .round();

    return FlightResult(
      passengers: passengers,
      loadFactor: lf,
      blockHours: blockHours,
      revenueEur: revenue,
      cargoEur: cargo,
      fuelEur: fuel,
      crewEur: crew,
      landingEur: landing,
      maintenanceEur: maintenance,
    );
  }

  /// Whether [model] can serve a sector at all: it has to have the legs for
  /// it, and the hub has to have enough runway to get it airborne.
  static RouteBlocker? blocker({
    required AircraftModel model,
    required double distanceKm,
    required HubEffects hub,
  }) {
    if (distanceKm > model.rangeKm) return RouteBlocker.outOfRange;
    if (!model.canUseRunway(hub.maxRunwayM)) return RouteBlocker.runwayTooShort;
    return null;
  }
}

/// Why an aircraft cannot fly a route.
enum RouteBlocker { outOfRange, runwayTooShort }

class FlightResult {
  const FlightResult({
    required this.passengers,
    required this.loadFactor,
    required this.blockHours,
    required this.revenueEur,
    required this.cargoEur,
    required this.fuelEur,
    required this.crewEur,
    required this.landingEur,
    required this.maintenanceEur,
  });

  final int passengers;
  final double loadFactor;
  final double blockHours;

  final int revenueEur;
  final int cargoEur;
  final int fuelEur;
  final int crewEur;
  final int landingEur;
  final int maintenanceEur;

  int get costEur => fuelEur + crewEur + landingEur + maintenanceEur;

  int get profitEur => revenueEur + cargoEur - costEur;

  static const empty = FlightResult(
    passengers: 0,
    loadFactor: 0,
    blockHours: 0,
    revenueEur: 0,
    cargoEur: 0,
    fuelEur: 0,
    crewEur: 0,
    landingEur: 0,
    maintenanceEur: 0,
  );
}
