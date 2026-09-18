import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/data/airport_catalog.dart';

const _fixture = '''
{
  "format": 1,
  "airports": [
    {"iata":"AMS","name":"Schiphol","city":"Amsterdam","country":"NL",
     "lat":52.3105,"lon":4.7683,"runwayM":3800,"catchment":84},
    {"iata":"BCN","name":"El Prat","city":"Barcelona","country":"ES",
     "lat":41.2974,"lon":2.0833,"runwayM":3352,"catchment":62},
    {"iata":"TNY","name":"Tiny Field","city":"Tinyville","country":"NL",
     "lat":52.0,"lon":5.0,"runwayM":900,"catchment":4}
  ]
}
''';

void main() {
  group('parsing', () {
    test('reads every well-formed row', () {
      final catalog = AirportCatalog.parse(_fixture);
      expect(catalog.airports.length, 3);
      expect(catalog.byIata('AMS')!.city, 'Amsterdam');
      expect(catalog.byIata('AMS')!.runwayM, 3800);
    });

    test('lookup is case-insensitive', () {
      final catalog = AirportCatalog.parse(_fixture);
      expect(catalog.byIata('ams'), isNotNull);
      expect(catalog.byIata('Ams'), isNotNull);
      expect(catalog.byIata(null), isNull);
      expect(catalog.byIata('ZZZ'), isNull);
    });

    test('sorts by city, which is the order every picker wants', () {
      final cities = AirportCatalog.parse(_fixture).airports.map((a) => a.city);
      expect(cities, ['Amsterdam', 'Barcelona', 'Tinyville']);
    });

    test('skips a malformed row instead of throwing', () {
      // A bad edit to the JSON should cost one destination, not the plugin.
      const broken = '''
      {"airports":[
        {"iata":"AMS","lat":52.3,"lon":4.8},
        {"iata":"BAD","lat":"north","lon":4.8},
        "not an object",
        {"name":"no code","lat":1,"lon":2},
        {"iata":"BCN","lat":41.3,"lon":2.1}
      ]}
      ''';
      final catalog = AirportCatalog.parse(broken);
      expect(catalog.airports.map((a) => a.iata), ['AMS', 'BCN']);
    });

    test('drops duplicate codes, keeping the first', () {
      const dupes = '''
      {"airports":[
        {"iata":"AMS","city":"Amsterdam","lat":52.3,"lon":4.8},
        {"iata":"AMS","city":"Impostor","lat":0,"lon":0}
      ]}
      ''';
      final catalog = AirportCatalog.parse(dupes);
      expect(catalog.airports.length, 1);
      expect(catalog.byIata('AMS')!.city, 'Amsterdam');
    });

    test('survives entirely wrong shapes', () {
      expect(AirportCatalog.parse('[]').airports, isEmpty);
      expect(AirportCatalog.parse('{"airports":"nope"}').airports, isEmpty);
      expect(AirportCatalog.parse('{}').airports, isEmpty);
    });

    test('fills in sensible defaults for optional fields', () {
      final catalog =
          AirportCatalog.parse('{"airports":[{"iata":"XXX","lat":1,"lon":2}]}');
      final airport = catalog.byIata('XXX')!;
      expect(airport.name, 'XXX');
      expect(airport.runwayM, 0);
      expect(airport.catchment, 1);
    });
  });

  group('queries', () {
    final catalog = AirportCatalog.parse(_fixture);

    test('reachable destinations respect range and runway', () {
      final hub = catalog.byIata('AMS')!;

      final everything =
          catalog.reachableFrom(hub, maxRangeKm: 20000, minRunwayM: 0);
      expect(everything.map((a) => a.iata), containsAll(['BCN', 'TNY']));
      expect(everything.map((a) => a.iata), isNot(contains('AMS')));

      final needsPavement =
          catalog.reachableFrom(hub, maxRangeKm: 20000, minRunwayM: 3000);
      expect(needsPavement.map((a) => a.iata), ['BCN']);

      final shortLegs =
          catalog.reachableFrom(hub, maxRangeKm: 200, minRunwayM: 0);
      expect(shortLegs.map((a) => a.iata), ['TNY']);
    });

    test('label reads as a person would say it', () {
      expect(catalog.byIata('AMS')!.label, 'Amsterdam (AMS)');
    });
  });

  group('the bundled asset', () {
    // Reads the real file straight off disk rather than through rootBundle,
    // so the shipped data is checked without needing a Flutter binding.
    final raw = File('assets/airline_tycoon/airports.json').readAsStringSync();
    final catalog = AirportCatalog.parse(raw);

    test('parses and is not empty', () {
      expect(catalog.airports.length, greaterThan(150));
    });

    test('every row survived parsing', () {
      final rows = (jsonDecode(raw) as Map)['airports'] as List;
      expect(catalog.airports.length, rows.length,
          reason: 'a shipped row failed to parse');
    });

    test('coordinates are on Earth', () {
      for (final airport in catalog.airports) {
        expect(airport.lat, inInclusiveRange(-90, 90), reason: airport.iata);
        expect(airport.lon, inInclusiveRange(-180, 180), reason: airport.iata);
      }
    });

    test('IATA codes are three upper-case letters', () {
      final pattern = RegExp(r'^[A-Z]{3}$');
      for (final airport in catalog.airports) {
        expect(pattern.hasMatch(airport.iata), isTrue, reason: airport.iata);
      }
    });

    test('every airport has a runway and a plausible catchment', () {
      for (final airport in catalog.airports) {
        expect(airport.runwayM, greaterThan(1000), reason: airport.iata);
        expect(airport.catchment, inInclusiveRange(1, 100),
            reason: airport.iata);
      }
    });

    test('the world is not just Europe', () {
      final countries = catalog.airports.map((a) => a.country).toSet();
      expect(countries.length, greaterThan(50));
      for (final code in ['US', 'JP', 'AU', 'BR', 'ZA', 'IN', 'CN']) {
        expect(countries, contains(code));
      }
    });

    test('offers enough starter hubs to choose from', () {
      expect(catalog.starterHubs().length, greaterThan(5));
    });

    test('a starter hub can actually reach somewhere a turboprop could fly',
        () {
      final hub = catalog.starterHubs().first;
      final reachable =
          catalog.reachableFrom(hub, maxRangeKm: 1528, minRunwayM: 1290);
      expect(reachable, isNotEmpty,
          reason: '${hub.iata} has nowhere to fly on day one');
    });
  });
}
