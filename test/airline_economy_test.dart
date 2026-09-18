import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/data/aircraft.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/sim/economy.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/sim/geo.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/sim/hub.dart';

void main() {
  group('great-circle distance', () {
    test('London to New York is about 5,550 km', () {
      final d = Geo.distanceKm(51.4700, -0.4543, 40.6413, -73.7781);
      expect(d, closeTo(5550, 60));
    });

    test('Amsterdam to Barcelona is about 1,240 km', () {
      final d = Geo.distanceKm(52.3105, 4.7683, 41.2974, 2.0833);
      expect(d, closeTo(1240, 40));
    });

    test('a point is zero from itself', () {
      expect(Geo.distanceKm(52.3105, 4.7683, 52.3105, 4.7683), closeTo(0, 1e-9));
    });

    test('antipodal points are half the circumference apart', () {
      // asin would return NaN here; atan2 is why this case works at all.
      final d = Geo.distanceKm(0, 0, 0, 180);
      expect(d, closeTo(20015, 5));
    });

    test('distance is symmetric', () {
      final there = Geo.distanceKm(35.5494, 139.7798, -33.9399, 151.1753);
      final back = Geo.distanceKm(-33.9399, 151.1753, 35.5494, 139.7798);
      expect(there, closeTo(back, 1e-9));
    });
  });

  group('great-circle interpolation', () {
    test('the ends are the endpoints', () {
      final start = Geo.interpolate(52.3, 4.8, 40.6, -73.8, 0);
      final end = Geo.interpolate(52.3, 4.8, 40.6, -73.8, 1);
      expect(start.lat, closeTo(52.3, 1e-6));
      expect(start.lon, closeTo(4.8, 1e-6));
      expect(end.lat, closeTo(40.6, 1e-6));
      expect(end.lon, closeTo(-73.8, 1e-6));
    });

    test('the midpoint of a transatlantic leg bends north of the rhumb line',
        () {
      // The whole point of drawing arcs rather than straight lines: the
      // great circle from Amsterdam to New York passes well north of the
      // latitude midpoint (46.45).
      final mid = Geo.interpolate(52.3105, 4.7683, 40.6413, -73.7781, 0.5);
      expect(mid.lat, greaterThan(50));
    });

    test('coincident endpoints do not divide by zero', () {
      final mid = Geo.interpolate(10, 20, 10, 20, 0.5);
      expect(mid.lat, closeTo(10, 1e-9));
      expect(mid.lon, closeTo(20, 1e-9));
    });
  });

  group('block time', () {
    test('adds half an hour of taxi and turnaround to the airborne time', () {
      expect(Geo.blockHours(833, 833), closeTo(1.5, 1e-9));
    });

    test('a stationary aircraft has no block time rather than infinite', () {
      expect(Geo.blockHours(500, 0), 0);
    });
  });

  group('fares and load factor', () {
    test('the fair fare grows with distance', () {
      expect(Economy.fairFareEur(1000), closeTo(125, 0.001));
      expect(
        Economy.fairFareEur(5000),
        greaterThan(Economy.fairFareEur(1000)),
      );
    });

    test('load factor is exactly a half at the curve centre', () {
      // The anchor the whole pricing curve is tuned around.
      final fair = Economy.fairFareEur(1000);
      expect(Economy.loadFactor(fair * 1.175, fair), closeTo(0.5, 1e-9));
    });

    test('pricing under the fair fare fills the cabin', () {
      final fair = Economy.fairFareEur(1000);
      expect(Economy.loadFactor(fair * 0.8, fair), greaterThan(0.9));
    });

    test('pricing well over the fair fare empties it', () {
      final fair = Economy.fairFareEur(1000);
      expect(Economy.loadFactor(fair * 1.5, fair), lessThan(0.12));
    });

    test('load factor falls monotonically as the fare rises', () {
      final fair = Economy.fairFareEur(2000);
      var previous = 1.0;
      for (var fare = 20.0; fare < fair * 2; fare += 10) {
        final lf = Economy.loadFactor(fare, fair);
        expect(lf, lessThanOrEqualTo(previous + 1e-12));
        previous = lf;
      }
    });

    test('load factor never exceeds the cap, even when free', () {
      expect(Economy.loadFactor(0, Economy.fairFareEur(1000)), 0.98);
    });

    test('a nonsensical fair fare yields no passengers rather than infinity',
        () {
      expect(Economy.loadFactor(100, 0), 0);
    });
  });

  group('demand', () {
    double demand(int a, int b, double d, {int rivals = 0}) =>
        Economy.demandPerDay(
          catchmentA: a,
          catchmentB: b,
          distanceKm: d,
          rivalRoutes: rivals,
        );

    test('bigger cities want more flights', () {
      expect(demand(80, 80, 1500), greaterThan(demand(80, 20, 1500)));
    });

    test('very short hops lose out to road and rail', () {
      expect(demand(60, 60, 200), lessThan(demand(60, 60, 1500)));
    });

    test('ultra-long sectors thin out too', () {
      expect(demand(60, 60, 15000), lessThan(demand(60, 60, 3000)));
    });

    test('each competitor takes a shrinking bite, never all of it', () {
      final alone = demand(60, 60, 2000);
      final oneRival = demand(60, 60, 2000, rivals: 1);
      final fiveRivals = demand(60, 60, 2000, rivals: 5);
      expect(oneRival, lessThan(alone));
      expect(fiveRivals, lessThan(oneRival));
      expect(fiveRivals, greaterThan(0));
    });

    test('the distance factor is continuous across its band boundaries', () {
      for (final edge in [800.0, 6000.0, 12000.0, 16000.0]) {
        final below = Economy.distanceFactor(edge - 0.01);
        final above = Economy.distanceFactor(edge + 0.01);
        expect((below - above).abs(), lessThan(0.01),
            reason: 'discontinuity at $edge km');
      }
    });
  });

  group('rotations per day', () {
    test('a short hop fits more round trips than a long one', () {
      final short = Economy.rotationsPerDay(Geo.blockHours(500, 800));
      final long = Economy.rotationsPerDay(Geo.blockHours(11000, 900));
      expect(short, greaterThan(long));
    });

    test('an ultra-long sector still manages a daily rotation of nothing', () {
      // 13,000 km round trip does not fit in 18 hours, so it flies zero
      // times a day rather than a fraction of a time.
      expect(Economy.rotationsPerDay(Geo.blockHours(13000, 900)), 0);
    });

    test('a zero block time cannot produce infinite rotations', () {
      expect(Economy.rotationsPerDay(0), 0);
    });
  });

  group('a single leg', () {
    final a320 = kAircraftById['a320neo']!;

    FlightResult fly({
      double fare = 140,
      double demand = 10000,
      double fuelIndex = 1,
      HubEffects hub = HubEffects.empty,
    }) =>
        Economy.flight(
          model: a320,
          distanceKm: 1240,
          fareEur: fare,
          availableDemand: demand,
          fuelPriceIndex: fuelIndex,
          hub: hub,
        );

    test('a sensibly priced short-haul leg makes money', () {
      expect(fly().profitEur, greaterThan(0));
    });

    test('passengers never exceed the seats fitted', () {
      expect(fly(fare: 10).passengers, lessThanOrEqualTo(a320.seats));
    });

    test('passengers never exceed the demand available', () {
      expect(fly(fare: 10, demand: 12).passengers, lessThanOrEqualTo(12));
    });

    test('negative demand is treated as none, not as a credit', () {
      expect(fly(demand: -500).passengers, 0);
    });

    test('an absurd fare loses money on a flight nobody boards', () {
      expect(fly(fare: 4000).profitEur, lessThan(0));
    });

    test('expensive fuel costs more', () {
      expect(fly(fuelIndex: 1.3).fuelEur, greaterThan(fly(fuelIndex: 0.8).fuelEur));
    });

    test('a hub that cuts fuel and maintenance makes the leg more profitable',
        () {
      const geared = HubEffects(
        activeGates: 4,
        inactiveGates: 0,
        maxRunwayM: 3400,
        maintenanceMultiplier: 0.7,
        fuelMultiplier: 0.85,
        hasCargo: true,
        premiumMultiplier: 1,
        upkeepPerDayEur: 0,
      );
      expect(fly(hub: geared).profitEur, greaterThan(fly().profitEur));
    });

    test('a cargo terminal adds belly revenue on top', () {
      const withCargo = HubEffects(
        activeGates: 1,
        inactiveGates: 0,
        maxRunwayM: 3400,
        maintenanceMultiplier: 1,
        fuelMultiplier: 1,
        hasCargo: true,
        premiumMultiplier: 1,
        upkeepPerDayEur: 0,
      );
      expect(fly().cargoEur, 0);
      expect(fly(hub: withCargo).cargoEur, greaterThan(0));
    });
  });

  group('what an aircraft may fly', () {
    final atr = kAircraftById['atr72']!;
    final b787 = kAircraftById['b787_9']!;

    const shortField = HubEffects(
      activeGates: 2,
      inactiveGates: 0,
      maxRunwayM: 1800,
      maintenanceMultiplier: 1,
      fuelMultiplier: 1,
      hasCargo: false,
      premiumMultiplier: 1,
      upkeepPerDayEur: 0,
    );
    const longField = HubEffects(
      activeGates: 2,
      inactiveGates: 0,
      maxRunwayM: 3400,
      maintenanceMultiplier: 1,
      fuelMultiplier: 1,
      hasCargo: false,
      premiumMultiplier: 1,
      upkeepPerDayEur: 0,
    );

    test('range is respected', () {
      expect(
        Economy.blocker(model: atr, distanceKm: 4000, hub: longField),
        RouteBlocker.outOfRange,
      );
    });

    test('a short runway keeps the widebody on the ground', () {
      expect(
        Economy.blocker(model: b787, distanceKm: 6000, hub: shortField),
        RouteBlocker.runwayTooShort,
      );
    });

    test('a long runway lets it go', () {
      expect(
        Economy.blocker(model: b787, distanceKm: 6000, hub: longField),
        isNull,
      );
    });
  });

  group('aircraft catalog', () {
    test('every model has a unique id', () {
      final ids = kAircraftCatalog.map((m) => m.id).toSet();
      expect(ids.length, kAircraftCatalog.length);
    });

    test('bigger aircraft cost more to maintain and burn more', () {
      final atr = kAircraftById['atr72']!;
      final a380 = kAircraftById['a380_800']!;
      expect(a380.fuelKgPerKm, greaterThan(atr.fuelKgPerKm));
      expect(a380.maintPerHourEur, greaterThan(atr.maintPerHourEur));
      expect(a380.minRunwayM, greaterThan(atr.minRunwayM));
    });

    test('selling always loses money against the purchase price', () {
      for (final model in kAircraftCatalog) {
        expect(model.resaleValueEur(0), lessThan(model.priceEur));
      }
    });

    test('a worn airframe is worth less than a fresh one', () {
      final model = kAircraftById['a320neo']!;
      expect(
        model.resaleValueEur(20000),
        lessThan(model.resaleValueEur(0)),
      );
    });

    test('leasing is a cheap start and an expensive habit', () {
      // The on-ramp has to work in both directions: a day of leasing must be
      // affordable long before the aircraft is, and holding the lease for a
      // decade must cost more than simply having bought it.
      final model = kAircraftById['a320neo']!;
      expect(model.leasePerDayEur * 30, lessThan(model.priceEur ~/ 100));
      expect(model.leasePerDayEur * 365 * 11, greaterThan(model.priceEur));
    });
  });
}
