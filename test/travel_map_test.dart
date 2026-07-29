import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/account/travel/world_map_data.dart';
import 'package:luma/settings/settings_controller.dart';

/// The bundled outline, read straight off disk so the test covers the real
/// asset rather than a fixture.
WorldMap _bundled() =>
    WorldMap.parse(File('assets/world/world_countries.json').readAsStringSync());

/// A square country covering 10°..20° east, 0°..10° north.
const _square = '''
{"q":1,"countries":[
  {"c":"SQ","n":"Square","r":"Nowhere","p":[[10,0,20,0,20,10,10,10]]},
  {"c":"IN","n":"Inner","r":"Nowhere","p":[[14,4,16,4,16,6,14,6]]}
]}
''';

void main() {
  // SettingsController.load() reaches for path_provider, which isn't there on
  // the host — it falls back to an in-memory controller.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('visited countries', () {
    test('a second tap takes a country back off the map', () async {
      final settings = await SettingsController.load();
      settings.setVisitedCountries(const []);

      settings.toggleVisitedCountry('NL');
      expect(settings.visitedCountries, ['NL']);

      settings.toggleVisitedCountry('JP');
      expect(settings.visitedCountries, ['JP', 'NL']);

      settings.toggleVisitedCountry('NL');
      expect(settings.visitedCountries, ['JP']);

      settings.toggleVisitedCountry('JP');
      expect(settings.visitedCountries, isEmpty);
    });

    test('picks are deduplicated, sorted and notify listeners', () async {
      final settings = await SettingsController.load();
      settings.setVisitedCountries(const []);

      var notifications = 0;
      settings.addListener(() => notifications++);

      settings.setVisitedCountries(['NL', 'BE', 'NL']);
      expect(settings.visitedCountries, ['BE', 'NL']);
      expect(notifications, 1);

      // Setting the same picks again is a no-op.
      settings.setVisitedCountries(['NL', 'BE']);
      expect(notifications, 1);
    });

    test('picks survive an export/import round trip', () async {
      final settings = await SettingsController.load();
      settings.setVisitedCountries(['FR', 'IT']);

      final snapshot = settings.exportData();
      settings.setVisitedCountries(const []);
      await settings.importData(Map<String, dynamic>.from(snapshot));

      expect(settings.visitedCountries, ['FR', 'IT']);
    });
  });

  group('MillerProjection', () {
    test('projects the antimeridian and the prime meridian', () {
      expect(MillerProjection.project(-180, 0).dx, closeTo(0, 1e-9));
      expect(MillerProjection.project(0, 0).dx, closeTo(0.5, 1e-9));
      expect(MillerProjection.project(180, 0).dx, closeTo(1, 1e-9));
    });

    test('north is up and the band is clipped to the map edges', () {
      final north = MillerProjection.project(0, MillerProjection.maxLatitude);
      final south = MillerProjection.project(0, MillerProjection.minLatitude);
      expect(north.dy, closeTo(0, 1e-9));
      expect(south.dy, closeTo(1, 1e-9));
      expect(MillerProjection.project(0, 40).dy, lessThan(0.5));
      expect(MillerProjection.project(0, -40).dy, greaterThan(0.5));
      // Beyond the band, points clamp onto the edge instead of running off.
      expect(MillerProjection.project(0, 89).dy, closeTo(0, 1e-9));
      expect(MillerProjection.project(0, -89).dy, closeTo(1, 1e-9));
    });

    test('keeps the world wider than it is tall', () {
      expect(MillerProjection.aspectRatio, greaterThan(1.9));
      expect(MillerProjection.aspectRatio, lessThan(2.2));
    });
  });

  group('WorldMap.parse', () {
    test('reads codes, names and rings', () {
      final map = WorldMap.parse(_square);
      expect(map.countries.map((c) => c.code), ['IN', 'SQ']);
      expect(map.byCode('SQ')!.name, 'Square');
      expect(map.byCode('SQ')!.rings.single.length, 8);
      expect(map.byCode('nope'), isNull);
    });

    test('hit-tests inside and outside a country', () {
      final map = WorldMap.parse(_square);
      expect(map.countryAt(MillerProjection.project(12, 2))?.code, 'SQ');
      expect(map.countryAt(MillerProjection.project(30, 2)), isNull);
    });

    test('an enclave wins the tap over the country around it', () {
      final map = WorldMap.parse(_square);
      expect(map.countryAt(MillerProjection.project(15, 5))?.code, 'IN');
      // …and it paints last, so it stays visible.
      expect(map.byDescendingSize.first.code, 'SQ');
    });

    test('a near miss still lands on a country', () {
      final map = WorldMap.parse(_square);
      // Just off the west coast of the square, in open water.
      final justOutside = MillerProjection.project(9.8, 5);
      expect(map.countryAt(justOutside), isNull);
      expect(map.countryNear(justOutside, 0.0)?.code, isNull);
      expect(map.countryNear(justOutside, 0.01)?.code, 'SQ');
      // A tap far out to sea stays a miss.
      expect(map.countryNear(MillerProjection.project(40, 5), 0.01), isNull);
    });

    test('an exact hit beats a neighbour within the slop', () {
      final map = WorldMap.parse(_square);
      expect(map.countryNear(MillerProjection.project(15, 5), 0.02)?.code, 'IN');
    });

    test('groups countries by region', () {
      final map = WorldMap.parse(_square);
      expect(map.byRegion.keys, ['Nowhere']);
      expect(map.byRegion['Nowhere']!.length, 2);
    });
  });

  group('bundled world outline', () {
    test('covers the world with unique codes', () {
      final map = _bundled();
      expect(map.countries.length, greaterThan(200));
      final codes = map.countries.map((c) => c.code).toSet();
      expect(codes.length, map.countries.length);
      for (final code in ['NL', 'US', 'JP', 'BR', 'ZA', 'AU', 'SG']) {
        expect(map.byCode(code), isNotNull, reason: '$code is missing');
      }
    });

    test('every point lands inside the unit square', () {
      for (final country in _bundled().countries) {
        expect(country.bounds.left, greaterThanOrEqualTo(0));
        expect(country.bounds.top, greaterThanOrEqualTo(0));
        expect(country.bounds.right, lessThanOrEqualTo(1));
        expect(country.bounds.bottom, lessThanOrEqualTo(1));
      }
    });

    test('real coordinates resolve to the right country', () {
      final map = _bundled();
      final places = {
        'FR': (2.35, 48.85), // Paris
        'ES': (-3.7, 40.4), // Madrid
        'JP': (138.0, 36.0), // Honshu
        'US': (-105.0, 39.7), // Denver
        'NL': (4.9, 52.2), // Amsterdam
        'KE': (36.8, -1.3), // Nairobi
        'AU': (149.1, -35.3), // Canberra
        'LS': (28.3, -29.5), // Maseru, inside South Africa
      };
      places.forEach((code, place) {
        final hit = map.countryAt(MillerProjection.project(place.$1, place.$2));
        expect(hit?.code, code, reason: 'expected $code at $place');
      });
      // Mid-Atlantic: open ocean, nothing to select.
      expect(map.countryAt(MillerProjection.project(-30, 0)), isNull);
    });
  });
}
