import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/airline_game_state.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/data/airport_catalog.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/sim/airport_world.dart';

void main() {
  final catalog = AirportCatalog.parse(
    File('assets/airline_tycoon/airports.json').readAsStringSync(),
  );
  late AirportWorld world;
  late AirlineGameState airline;
  setUp(() {
    world = AirportWorld.starter();
    airline = AirlineGameState(airlineName: 'Test Air', hubIata: 'AMS');
    airline.fleet.add(
      OwnedAircraft(
        id: 'ac1',
        registration: 'PH-TEST',
        modelId: 'atr72',
        purchasedDay: 1,
      ),
    );
    airline.routes.add(
      AirlineRoute(id: 'rt1', destIata: 'LHR', fareEur: 75, openedDay: 1),
    );
  });

  test('starter has connected stands and a usable terminal', () {
    expect(world.stands.where((s) => s.connected), hasLength(2));
    for (final kind in [
      'entrance',
      'checkIn',
      'security',
      'boardingGate',
      'fuelDepot',
      'baggage',
    ]) {
      expect(world.hasService(kind), isTrue, reason: kind);
    }
    expect(world.contractBlocker('coastal'), isNull);
    expect(world.contractBlocker('aurora'), isNotNull);
  });

  test('multi-day catch-up uses each day fuel prices just like live play', () {
    expect(
      world.schedule(
        airline,
        catalog,
        aircraftId: 'ac1',
        routeId: 'rt1',
        departure: 500,
      ),
      isNull,
    );
    expect(
      world.schedule(
        airline,
        catalog,
        aircraftId: 'ac1',
        routeId: 'rt1',
        departure: 1940,
      ),
      isNull,
    );
    final copy = AirportWorld.fromJson(world.toJson());
    final other = AirlineGameState.fromJson(airline.toJson());
    world.advance(2500, airline, catalog);
    for (var i = 0; i < 250; i++) {
      copy.advance(10, other, catalog);
    }
    expect(other.cashEur, airline.cashEur);
    expect(
      other.history.map((h) => h.toJson()),
      airline.history.map((h) => h.toJson()),
    );
    expect(copy.ledger, world.ledger);
  });

  test('moving a custom length taxiway retains its size under rotation', () {
    final taxi = world.ofKind('taxiway').first;
    expect(taxi.depth, 1700);
    expect(
      world.build(airline, taxi.kind, -800, 1000, 1, moving: taxi.id),
      isNull,
    );
    expect(world.facility(taxi.id)!.width, 1700);
    expect(world.facility(taxi.id)!.depth, 20);
  });

  test('owned flights return through the airport and settle each leg once', () {
    expect(
      world.schedule(
        airline,
        catalog,
        aircraftId: 'ac1',
        routeId: 'rt1',
        departure: 500,
      ),
      isNull,
    );
    world.advance(220, airline, catalog);
    expect(world.flights.single.stage, 'enRoute');
    expect(world.ledger.where((e) => e['category'] == 'tickets'), hasLength(1));
    final saved = AirportWorld.fromJson(world.toJson());
    final other = AirlineGameState.fromJson(airline.toJson());
    world.advance(700, airline, catalog);
    saved.advance(700, other, catalog);
    expect(world.flights.single.stage, 'completed');
    expect(world.flights.single.returnSettled, isTrue);
    expect(world.ledger.where((e) => e['category'] == 'tickets'), hasLength(2));
    expect(airline.flightsFlownEver, 2);
    expect(other.cashEur, airline.cashEur);
    expect(world.reservations, isEmpty);
  });

  test('a blocked security route prevents passengers from boarding', () {
    world.acceptContract(airline, 'coastal');
    world.facilities.removeWhere((f) => f.kind == 'security');
    world.resolveConnections();
    world.advance(120, airline, catalog);
    expect(world.flights.first.boarded, 0);
    expect(world.passengers.any((p) => p.stage == 'checkIn'), isTrue);
  });

  test('vehicles drive back before accepting another service job', () {
    world.acceptContract(airline, 'coastal');
    var sawReturning = false;
    for (var i = 0; i < 160; i++) {
      world.advance(.5, airline, catalog);
      for (final v in world.vehicles) {
        if (v.returning) {
          sawReturning = true;
          expect(v.flightId, isNotNull);
          expect(v.path, isNotEmpty);
        }
      }
    }
    expect(sawReturning, isTrue);
  });

  test('contract serves passengers and settles once per flight', () {
    expect(world.acceptContract(airline, 'coastal'), isNull);
    expect(world.flights, hasLength(14));
    world.advance(400, airline, catalog);
    expect(
      world.flights.first.stage,
      'completed',
      reason: world.flights.first.issue,
    );
    expect(world.flights.first.boarded, greaterThan(0));
    final id = world.flights.first.id;
    expect(
      world.ledger.where(
        (e) =>
            e['category'] == 'handling' && '${e['description']}'.contains(id),
      ),
      hasLength(1),
    );
    final loaded = AirportWorld.fromJson(
      jsonDecode(jsonEncode(world.toJson())) as Map<String, dynamic>,
    );
    loaded.advance(10, airline, catalog);
    expect(
      loaded.ledger.where(
        (e) =>
            e['category'] == 'handling' && '${e['description']}'.contains(id),
      ),
      hasLength(1),
    );
  });

  test('event catch-up and incremental ticks produce identical books', () {
    world.acceptContract(airline, 'coastal');
    final incremental = AirportWorld.fromJson(world.toJson());
    final otherAirline = AirlineGameState.fromJson(airline.toJson());
    world.advance(450, airline, catalog);
    for (var i = 0; i < 450; i++) {
      incremental.advance(1, otherAirline, catalog);
    }
    expect(otherAirline.cashEur, airline.cashEur);
    expect(incremental.ledger, world.ledger);
    expect(
      incremental.flights.map((f) => f.stage),
      world.flights.map((f) => f.stage),
    );
    expect(otherAirline.passengersCarriedEver, airline.passengersCarriedEver);
  });

  test('stand conflicts and impossible aircraft rotations are rejected', () {
    expect(
      world.schedule(
        airline,
        catalog,
        aircraftId: 'ac1',
        routeId: 'rt1',
        departure: 500,
      ),
      isNull,
    );
    expect(
      world.schedule(
        airline,
        catalog,
        aircraftId: 'ac1',
        routeId: 'rt1',
        departure: 550,
      ),
      contains('aircraft'),
    );
    airline.fleet.add(
      OwnedAircraft(
        id: 'ac2',
        registration: 'PH-TWO',
        modelId: 'atr72',
        purchasedDay: 1,
      ),
    );
    expect(
      world.schedule(
        airline,
        catalog,
        aircraftId: 'ac2',
        routeId: 'rt1',
        departure: 500,
        standId: world.flights.first.standId,
      ),
      contains('stand'),
    );
  });

  test('disconnected taxiway cannot accept a contract', () {
    world.facilities.removeWhere((f) => f.kind == 'taxiway');
    world.resolveConnections();
    expect(world.stands.every((s) => !s.connected), isTrue);
    expect(world.acceptContract(airline, 'coastal'), isNotNull);
    expect(world.flights, isEmpty);
  });

  test(
    'service shortage causes a penalty and leaves no stuck reservations',
    () {
      world.acceptContract(airline, 'coastal');
      world.vehicles.removeWhere((v) => v.kind == 'fuel');
      world.advance(360, airline, catalog);
      expect(world.flights.first.stage, 'cancelled');
      expect(world.ledger.any((e) => e['category'] == 'penalty'), isTrue);
      expect(
        world.reservations.values,
        isNot(contains(world.flights.first.id)),
      );
    },
  );

  test('imminent flight protects infrastructure from removal or movement', () {
    world.acceptContract(airline, 'coastal');
    final terminal = world.ofKind('terminal').first;
    expect(world.demolish(airline, terminal.id), isNotNull);
    expect(
      world.build(airline, terminal.kind, 100, 100, 1, moving: terminal.id),
      isNotNull,
    );
  });

  test('furniture must fit inside terminals and may not overlap', () {
    final cash = airline.cashEur;
    expect(world.build(airline, 'security', 1000, 1000, 0), isNotNull);
    final existing = world.ofKind('security').first;
    expect(
      world.build(airline, 'security', existing.x, existing.y, 0),
      isNotNull,
    );
    expect(airline.cashEur, cash);
    expect(world.build(airline, 'seating', -220, 5, 1), isNull);
    expect(world.facilities.last.rotation, 1);
    expect(world.facilities.last.width, 4);
  });

  test('contract cancellation charges each unserved flight once', () {
    world.acceptContract(airline, 'coastal');
    final cash = airline.cashEur, c = world.contracts.single;
    expect(world.cancelContract(airline, c.id), isNull);
    expect(airline.cashEur, cash - 14 * c.offer.penalty);
    expect(world.cancelContract(airline, c.id), isNotNull);
    world.advance(1440, airline, catalog);
    expect(
      world.ledger.where((e) => e['category'] == 'penalty'),
      hasLength(14),
    );
  });

  test('two arrivals never hold the same runway concurrently', () {
    world.acceptContract(airline, 'coastal');
    final first = world.flights.first;
    world.flights.add(
      AirportFlight(
        id: 'extra',
        carrier: 'Test Air',
        modelId: 'atr72',
        standId: world.stands.last.id,
        arrival: first.arrival,
        departure: first.departure,
        passengers: 20,
      ),
    );
    for (var i = 0; i < 120; i++) {
      world.advance(1, airline, catalog);
      final using = world.flights.where(
        (f) => [
          'landing',
          'taxiIn',
          'pushback',
          'taxiOut',
          'departing',
        ].contains(f.stage),
      );
      expect(using.length, lessThanOrEqualTo(1));
    }
  });

  test(
    'save during servicing preserves resource work and later settlement',
    () {
      world.acceptContract(airline, 'coastal');
      world.advance(80, airline, catalog);
      final restored = AirportWorld.fromJson(
        jsonDecode(jsonEncode(world.toJson())) as Map<String, dynamic>,
      );
      final other = AirlineGameState.fromJson(airline.toJson());
      world.advance(250, airline, catalog);
      restored.advance(250, other, catalog);
      expect(other.cashEur, airline.cashEur);
      expect(restored.ledger, world.ledger);
    },
  );
}
