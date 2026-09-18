import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/airline_game_state.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/data/aircraft.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/data/airport_catalog.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/sim/airport_world.dart';

/// Signs an offer and places its flights on the first stand that fits, an
/// hour from now: the one-step contract flow the older tests assume.
String? signAndPlace(
  AirportWorld world,
  AirlineGameState airline,
  String offerId, {
  double? at,
}) {
  final error = world.acceptContract(airline, offerId);
  if (error != null) return error;
  final c = world.contracts.last;
  final stand = world.stands.firstWhere(
    (s) => s.connected && world.standAccepts(s, c.offer.model),
  );
  return world.placeContract(c.id, stand.id, at ?? world.time + 60);
}

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
    signAndPlace(world, airline, 'coastal');
    world.facilities.removeWhere((f) => f.kind == 'security');
    world.resolveConnections();
    world.advance(120, airline, catalog);
    expect(world.flights.first.boarded, 0);
    expect(world.passengers.any((p) => p.stage == 'checkIn'), isTrue);
  });

  test('vehicles drive back before accepting another service job', () {
    signAndPlace(world, airline, 'coastal');
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
    expect(signAndPlace(world, airline, 'coastal'), isNull);
    expect(world.flights, hasLength(7));
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
    signAndPlace(world, airline, 'coastal');
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
      signAndPlace(world, airline, 'coastal');
      world.vehicles.removeWhere((v) => v.kind == 'fuel');
      world.advance(420, airline, catalog);
      expect(world.flights.first.stage, 'cancelled');
      expect(world.ledger.any((e) => e['category'] == 'penalty'), isTrue);
      expect(
        world.reservations.values,
        isNot(contains(world.flights.first.id)),
      );
    },
  );

  test('imminent flight protects infrastructure from removal or movement', () {
    signAndPlace(world, airline, 'coastal');
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
    signAndPlace(world, airline, 'coastal');
    final cash = airline.cashEur, c = world.contracts.single;
    expect(world.cancelContract(airline, c.id), isNull);
    expect(airline.cashEur, cash - 7 * c.offer.penalty);
    expect(world.cancelContract(airline, c.id), isNotNull);
    world.advance(1440, airline, catalog);
    expect(world.ledger.where((e) => e['category'] == 'penalty'), hasLength(7));
  });

  test('two arrivals never hold the same runway concurrently', () {
    signAndPlace(world, airline, 'coastal');
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
      signAndPlace(world, airline, 'coastal');
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

  test('every buildable has a menu category and stands know their limits', () {
    const categories = {
      'airfield',
      'apron',
      'services',
      'terminal',
      'interior',
      'shops',
      'decor',
    };
    for (final def in airportFacilities) {
      expect(categories, contains(def.category), reason: def.kind);
      expect(
        def.interior,
        ['interior', 'shops', 'decor'].contains(def.category),
        reason: def.kind,
      );
    }
    final regional = AirportFacility(
      id: 'r',
      kind: 'standRegional',
      x: 0,
      y: 0,
    );
    expect(world.standAccepts(regional, aircraftModelById('atr72')!), isTrue);
    expect(
      world.standAccepts(regional, aircraftModelById('a320neo')!),
      isFalse,
    );
    expect(
      world.standAccepts(world.stands.first, aircraftModelById('b787_9')!),
      isTrue,
    );
  });

  test('a jet bridge stand has to touch a terminal', () {
    final terminal = world.ofKind('terminal').first;
    expect(
      world.build(airline, 'standContact', 500, 500, 0),
      contains('terminal'),
    );
    expect(
      world.build(
        airline,
        'standContact',
        terminal.x + terminal.width,
        terminal.y,
        0,
      ),
      isNull,
    );
    expect(world.ofKind('standContact'), hasLength(1));
    expect(world.stands, hasLength(3));
  });

  test('scheduled flights move between stands only into free slots', () {
    expect(signAndPlace(world, airline, 'coastal'), isNull);
    final flight = world.flights.first;
    final other = world.stands.firstWhere((s) => s.id != flight.standId);
    expect(world.reassignFlight(flight.id, other.id), isNull);
    expect(world.flights.first.standId, other.id);
    expect(world.flights.first.arrival, flight.arrival);
    expect(world.flights, hasLength(7));

    airline.fleet.add(
      OwnedAircraft(
        id: 'ac2',
        registration: 'PH-TWO',
        modelId: 'atr72',
        purchasedDay: 1,
      ),
    );
    final free = flight.arrival + 700;
    final stands = world.stands;
    expect(
      world.schedule(
        airline,
        catalog,
        aircraftId: 'ac1',
        routeId: 'rt1',
        departure: free,
        standId: stands.first.id,
      ),
      isNull,
    );
    expect(
      world.schedule(
        airline,
        catalog,
        aircraftId: 'ac2',
        routeId: 'rt1',
        departure: free,
        standId: stands.last.id,
      ),
      isNull,
    );
    final mine = world.flights.last;
    expect(world.reassignFlight(mine.id, stands.first.id), contains('busy'));
    expect(world.reassignFlight(mine.id, 'nope'), isNotNull);
    expect(world.flights.last.standId, stands.last.id);

    final busy = world.flights.first;
    world.advance(busy.arrival - world.time + 1, airline, catalog);
    expect(world.flights.first.stage, isNot('scheduled'));
    expect(
      world.reassignFlight(world.flights.first.id, mine.standId),
      contains('not arrived'),
    );
  });

  test('a staffed counter replaces the check-in desks', () {
    final terminal = world.ofKind('terminal').last;
    world.facilities.removeWhere((f) => f.kind == 'checkIn');
    world.resolveConnections();
    expect(world.hasService('checkIn'), isFalse);
    expect(
      world.build(
        airline,
        'checkInCounter',
        terminal.x + 60,
        terminal.y + 40,
        0,
      ),
      isNull,
    );
    expect(world.hasService('checkIn'), isTrue);
    final counter = world.ofKind('checkInCounter').single;
    expect(signAndPlace(world, airline, 'coastal'), isNull);
    var used = false;
    for (var i = 0; i < 400 && !used; i++) {
      world.advance(1, airline, catalog);
      used = world.passengers.any((p) => p.facilityId == counter.id);
    }
    expect(used, isTrue);
    world.advance(400, airline, catalog);
    expect(world.flights.first.boarded, greaterThan(0));
  });

  test('ticket machines share the check-in queue with the desks', () {
    final terminal = world.ofKind('terminal').last;
    expect(
      world.build(
        airline,
        'ticketMachine',
        terminal.x + 60,
        terminal.y + 40,
        0,
      ),
      isNull,
    );
    final kiosk = world.ofKind('ticketMachine').single;
    expect(kiosk.connected, isTrue);
    signAndPlace(world, airline, 'coastal');
    var used = false;
    for (var i = 0; i < 400 && !used; i++) {
      world.advance(1, airline, catalog);
      used = world.passengers.any((p) => p.facilityId == kiosk.id);
    }
    expect(used, isTrue);
  });

  group('baggage reclaim', () {
    AirportContract reclaimContract() {
      final c = AirportContract(
        id: 'reclaim',
        offer: const AirportOffer(
          id: 'reclaim',
          carrier: 'Coastal Connect',
          modelId: 'atr72',
          type: AirportOffer.charter,
          flights: 1,
          slot: 'ALL',
          passengers: 60,
          fee: 42000,
          penalty: 12000,
          requiredServices: ['fuelDepot', 'baggage', 'baggageCarousel'],
        ),
        signedDay: 1,
      );
      world.contracts.add(c);
      return c;
    }

    test('medium and long-haul offers need a carousel', () {
      expect(world.contractBlocker('meridian'), contains('carousel'));
      for (var day = 1; day < 30; day++) {
        for (final o in offersPublishedOn(day)) {
          expect(
            o.requiredServices.contains('baggageCarousel'),
            o.haul != 'SH',
            reason: o.id,
          );
        }
      }
    });

    test('arrivals wait for bags, collect them and leave', () {
      final terminal = world.ofKind('terminal').last;
      expect(
        world.build(
          airline,
          'baggageCarousel',
          terminal.x + 60,
          terminal.y + 40,
          0,
        ),
        isNull,
      );
      final carousel = world.ofKind('baggageCarousel').single;
      expect(carousel.connected, isTrue);
      final c = reclaimContract();
      expect(
        world.placeContract(c.id, world.stands.first.id, world.time + 60),
        isNull,
      );
      final seen = <String>{};
      var collectedWhileBagsOut = false;
      for (var i = 0; i < 400; i++) {
        world.advance(1, airline, catalog);
        final arrivals = world.passengers.where((p) => p.arriving).toList();
        seen.addAll(arrivals.map((p) => p.stage));
        expect(
          world.carouselLoad(carousel.id),
          lessThanOrEqualTo(carouselCapacity),
        );
        if (arrivals.any((p) => p.stage == 'collecting')) {
          collectedWhileBagsOut |= world.flights.single.serviced.contains(
            'baggage',
          );
        }
      }
      expect(seen, containsAll(['reclaim', 'collecting', 'leaving']));
      expect(collectedWhileBagsOut, isTrue);
      expect(world.passengers.where((p) => p.arriving), isEmpty);
      expect(world.flights.single.stage, 'completed');
    });

    test('a full carousel keeps the next arrivals waiting', () {
      final terminal = world.ofKind('terminal').last;
      world.build(
        airline,
        'baggageCarousel',
        terminal.x + 60,
        terminal.y + 40,
        0,
      );
      final carousel = world.ofKind('baggageCarousel').single;
      final c = reclaimContract();
      world.placeContract(c.id, world.stands.first.id, world.time + 60);
      for (var n = 0; n < carouselCapacity; n += 10) {
        world.passengers.add(
          AirportPassengerGroup(
              'busy$n',
              'elsewhere',
              10,
              carousel.cx,
              carousel.cy,
            )
            ..arriving = true
            ..stage = 'reclaim'
            ..facilityId = carousel.id
            ..nextEvent = 1e9,
        );
      }
      world.advance(90, airline, catalog);
      final waiting = world.passengers.where(
        (p) => p.arriving && p.flightId != 'elsewhere',
      );
      expect(waiting, isNotEmpty);
      expect(waiting.every((p) => p.stage == 'arrived'), isTrue);
      expect(world.carouselLoad(carousel.id), carouselCapacity);
    });
  });

  test('food carts sell cheap snacks in tight corners', () {
    final terminal = world.ofKind('terminal').last;
    expect(
      world.build(airline, 'foodCart', terminal.x + 50, terminal.y + 20, 0),
      isNull,
    );
    signAndPlace(world, airline, 'coastal');
    world.advance(400, airline, catalog);
    expect(
      world.ledger.where((e) => e['description'] == 'Food cart sales'),
      isNotEmpty,
    );
  });

  test('coffee to-go stalls sell to passengers on the way to the gate', () {
    final terminal = world.ofKind('terminal').last;
    expect(
      world.build(airline, 'coffeeToGo', terminal.x + 50, terminal.y + 30, 0),
      isNull,
    );
    signAndPlace(world, airline, 'coastal');
    world.advance(400, airline, catalog);
    expect(
      world.ledger.where((e) => e['description'] == 'Coffee to-go sales'),
      isNotEmpty,
    );
  });

  test('restaurants serve instead of the café', () {
    world.facilities.removeWhere((f) => f.kind == 'cafe');
    world.resolveConnections();
    final terminal = world.ofKind('terminal').last;
    expect(
      world.build(airline, 'restaurant', terminal.x + 50, terminal.y + 30, 0),
      isNull,
    );
    signAndPlace(world, airline, 'coastal');
    world.advance(400, airline, catalog);
    expect(
      world.ledger.where((e) => e['description'] == 'Restaurant covers'),
      isNotEmpty,
    );
  });

  test('bins make the terminal cleaner and passengers happier', () {
    expect(world.cleanliness, .6);
    final plain = AirportWorld.fromJson(world.toJson());
    final plainAirline = AirlineGameState.fromJson(airline.toJson());
    final terminal = world.ofKind('terminal').last;
    for (var i = 0; i < 3; i++) {
      expect(
        world.build(
          airline,
          'bins',
          terminal.x + 40 + i * 4,
          terminal.y + 40,
          0,
        ),
        isNull,
      );
    }
    expect(world.cleanliness, closeTo(.72, .0001));
    expect(signAndPlace(world, airline, 'coastal'), isNull);
    expect(signAndPlace(plain, plainAirline, 'coastal'), isNull);
    world.advance(400, airline, catalog);
    plain.advance(400, plainAirline, catalog);
    expect(
      world.contracts.first.satisfaction,
      greaterThan(plain.contracts.first.satisfaction),
    );
  });

  test('information desks raise passenger satisfaction', () {
    expect(world.infoDeskBonus, 0);
    final plain = AirportWorld.fromJson(world.toJson());
    final plainAirline = AirlineGameState.fromJson(airline.toJson());
    final terminal = world.ofKind('terminal').last;
    expect(
      world.build(airline, 'infoDesk', terminal.x + 60, terminal.y + 40, 0),
      isNull,
    );
    expect(world.infoDeskBonus, .02);
    expect(signAndPlace(world, airline, 'coastal'), isNull);
    expect(signAndPlace(plain, plainAirline, 'coastal'), isNull);
    world.advance(400, airline, catalog);
    plain.advance(400, plainAirline, catalog);
    expect(
      world.contracts.first.satisfaction,
      greaterThan(plain.contracts.first.satisfaction),
    );
  });

  test('vending machines stand in for the café', () {
    world.facilities.removeWhere((f) => f.kind == 'cafe');
    world.resolveConnections();
    final terminal = world.ofKind('terminal').last;
    expect(
      world.build(
        airline,
        'vendingMachine',
        terminal.x + 60,
        terminal.y + 40,
        0,
      ),
      isNull,
    );
    signAndPlace(world, airline, 'coastal');
    world.advance(400, airline, catalog);
    expect(
      world.ledger.where((e) => e['description'] == 'Vending machines'),
      isNotEmpty,
    );
    expect(
      world.ledger.where((e) => e['description'] == 'Terminal café'),
      isEmpty,
    );
  });

  test('fashion boutiques sell to passengers after security', () {
    final terminal = world.ofKind('terminal').last;
    expect(
      world.build(airline, 'clothingShop', terminal.x + 60, terminal.y + 40, 0),
      isNull,
    );
    signAndPlace(world, airline, 'coastal');
    world.advance(400, airline, catalog);
    expect(
      world.ledger.where((e) => e['description'] == 'Fashion boutique sales'),
      isNotEmpty,
    );
  });

  test('luxury boutiques sell to passengers after security', () {
    final terminal = world.ofKind('terminal').last;
    expect(
      world.build(
        airline,
        'luxuryBoutique',
        terminal.x + 60,
        terminal.y + 40,
        0,
      ),
      isNull,
    );
    signAndPlace(world, airline, 'coastal');
    world.advance(400, airline, catalog);
    expect(
      world.ledger.where((e) => e['description'] == 'Luxury boutique sales'),
      isNotEmpty,
    );
  });

  test('arcades earn tokens and lift the mood of the wait', () {
    final terminal = world.ofKind('terminal').last;
    expect(
      world.build(airline, 'arcade', terminal.x + 60, terminal.y + 40, 0),
      isNull,
    );
    world.facilities.removeWhere((f) => f.kind == 'seating');
    world.resolveConnections();
    signAndPlace(world, airline, 'coastal');
    world.advance(400, airline, catalog);
    expect(
      world.ledger.where((e) => e['description'] == 'Arcade tokens'),
      isNotEmpty,
    );
  });

  test('VIP lounges host passengers before boarding', () {
    final terminal = world.ofKind('terminal').last;
    expect(
      world.build(airline, 'vipLounge', terminal.x + 60, terminal.y + 40, 0),
      isNull,
    );
    world.facilities.removeWhere((f) => f.kind == 'seating');
    world.resolveConnections();
    signAndPlace(world, airline, 'coastal');
    world.advance(400, airline, catalog);
    expect(
      world.ledger.where((e) => e['description'] == 'VIP lounge access'),
      isNotEmpty,
    );
  });

  test('duty-free food halls sell to passengers after security', () {
    final terminal = world.ofKind('terminal').last;
    expect(
      world.build(airline, 'foodShop', terminal.x + 60, terminal.y + 30, 0),
      isNull,
    );
    signAndPlace(world, airline, 'coastal');
    world.advance(400, airline, catalog);
    expect(
      world.ledger.where(
        (e) => e['description'] == 'Duty-free food & drink sales',
      ),
      isNotEmpty,
    );
  });

  test('perfume boutiques sell to a quarter of each group', () {
    final terminal = world.ofKind('terminal').last;
    expect(
      world.build(airline, 'perfumeShop', terminal.x + 60, terminal.y + 30, 0),
      isNull,
    );
    signAndPlace(world, airline, 'coastal');
    world.advance(400, airline, catalog);
    final sales = world.ledger.where(
      (e) => e['description'] == 'Perfume sales',
    );
    expect(sales, isNotEmpty);
    for (final e in sales) {
      expect((e['amount'] as num) % 90, 0);
    }
  });

  test('flower shops sell to passengers after security', () {
    final terminal = world.ofKind('terminal').last;
    expect(
      world.build(airline, 'flowerShop', terminal.x + 60, terminal.y + 30, 0),
      isNull,
    );
    signAndPlace(world, airline, 'coastal');
    world.advance(400, airline, catalog);
    expect(
      world.ledger.where((e) => e['description'] == 'Flower shop sales'),
      isNotEmpty,
    );
  });

  test('newsstand kiosks sell to passengers after security', () {
    final terminal = world.ofKind('terminal').last;
    expect(
      world.build(airline, 'kiosk', terminal.x + 60, terminal.y + 40, 0),
      isNull,
    );
    signAndPlace(world, airline, 'coastal');
    world.advance(400, airline, catalog);
    expect(
      world.ledger.where((e) => e['description'] == 'Newsstand sales'),
      isNotEmpty,
    );
  });

  test('duty-free shops earn from passengers on their way to the gate', () {
    final terminal = world.ofKind('terminal').last;
    expect(
      world.build(airline, 'shop', terminal.x + 60, terminal.y + 40, 0),
      isNull,
    );
    expect(world.ofKind('shop').single.connected, isTrue);
    signAndPlace(world, airline, 'coastal');
    world.advance(400, airline, catalog);
    expect(
      world.ledger.where((e) => e['description'] == 'Duty-free sales'),
      isNotEmpty,
    );
  });

  test('passengers walk in from the kerb through the entrance doors', () {
    final entrance = world.ofKind('entrance').single;
    final terminal = world.ofKind('terminal').first;
    final door = world.entranceDoor(entrance)!;
    // The nearest outside wall; the one shared with the second section is
    // inside the hall and never gets a door.
    expect(door.door[0], terminal.x + terminal.width);
    expect(door.kerb[0], door.door[0] + AirportWorld.kerbDistance);
    expect(door.kerb[1], door.door[1]);
    signAndPlace(world, airline, 'coastal');
    for (var i = 0; i < 200 && world.passengers.isEmpty; i++) {
      world.advance(1, airline, catalog);
    }
    final group = world.passengers.first;
    expect(group.path.first, door.kerb);
    expect(group.path[1], door.door);
    world.advance(400, airline, catalog);
    expect(world.flights.where((f) => f.boarded > 0), isNotEmpty);
  });

  group('customs, check-in and check-out are required', () {
    for (final kind in ['customs', 'checkOut', 'checkIn']) {
      test('no contracts and no own flights without $kind', () {
        world.facilities.removeWhere((f) => f.kind == kind);
        world.resolveConnections();
        expect(world.contractBlocker('coastal'), isNotNull);
        expect(
          world.schedule(
            airline,
            catalog,
            aircraftId: 'ac1',
            routeId: 'rt1',
            departure: 500,
          ),
          isNotNull,
        );
      });
    }

    test('planned flights wait at the stand when customs is removed', () {
      signAndPlace(world, airline, 'coastal');
      world.facilities.removeWhere((f) => f.kind == 'customs');
      world.resolveConnections();
      world.advance(120, airline, catalog);
      final f = world.flights.first;
      expect(f.stage, isNot('completed'));
      expect(f.issue, contains('customs'));
    });

    test('arrivals walk off, clear customs, check out and leave', () {
      signAndPlace(world, airline, 'coastal');
      final seen = <String>{};
      var boarding = false;
      for (var i = 0; i < 400; i++) {
        world.advance(1, airline, catalog);
        for (final p in world.passengers) {
          if (p.arriving) seen.add(p.stage);
          if (p.stage == 'walkingOnBoard') boarding = true;
        }
      }
      expect(
        seen,
        containsAll(['deplaning', 'customs', 'checkOut', 'leaving']),
      );
      expect(boarding, isTrue, reason: 'departing groups walk to the plane');
      expect(world.passengers.where((p) => p.arriving), isEmpty);
      expect(world.flights.first.stage, 'completed');
    });
  });

  test('own aircraft are towed from the hangar instead of appearing', () {
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
    world.advance(420 - world.time + .5, airline, catalog);
    final f = world.flights.single;
    expect(f.stage, 'positioning');
    final hangar = world.ofKind('hangar').single;
    expect(f.path.first, [hangar.x - 5, hangar.y - 25, 0]);
    expect(f.path.last[0], world.facility(f.standId)!.cx);
  });

  group('building upgrades', () {
    test('an upgrade charges the next level and survives a reload', () {
      airline.cashEur = 5000000;
      final stand = world.stands.first;
      final cost = world.upgradeCost(stand)!;
      expect(cost, upgradeCostAt(facilityDef(stand.kind), 1));
      expect(world.upgrade(airline, stand.id), isNull);
      expect(stand.level, 2);
      expect(airline.cashEur, 5000000 - cost);
      expect(
        world.upgradeCost(stand),
        upgradeCostAt(facilityDef(stand.kind), 2),
      );
      final reloaded = AirportWorld.fromJson(
        jsonDecode(jsonEncode(world.toJson())) as Map<String, Object?>,
      );
      expect(reloaded.facility(stand.id)!.level, 2);
    });

    test('maxed, unaffordable and fixed buildings are refused', () {
      airline.cashEur = 5000000;
      expect(
        world.upgrade(airline, world.ofKind('hangar').single.id),
        isNotNull,
      );
      final stand = world.stands.first..level = maxFacilityLevel;
      expect(world.upgradeCost(stand), isNull);
      expect(world.upgrade(airline, stand.id), 'Already at the highest level.');
      airline.cashEur = 0;
      expect(
        world.upgrade(airline, world.stands.last.id),
        'Not enough cash for this upgrade.',
      );
    });

    test('demolishing refunds half of the upgrades too', () {
      airline.cashEur = 1000000;
      final taxiway = world.ofKind('taxiway').last;
      final def = facilityDef('taxiway');
      expect(world.upgrade(airline, taxiway.id), isNull);
      final before = airline.cashEur;
      expect(world.demolish(airline, taxiway.id), isNull);
      expect(
        airline.cashEur - before,
        ((def.cost + upgradeCostAt(def, 1)) * .5).round(),
      );
    });

    test('an upgraded shop sells more to each passenger', () {
      final terminal = world.ofKind('terminal').last;
      expect(
        world.build(airline, 'shop', terminal.x + 60, terminal.y + 40, 0),
        isNull,
      );
      world.ofKind('shop').single.level = 2;
      signAndPlace(world, airline, 'coastal');
      world.advance(400, airline, catalog);
      final sales = world.ledger
          .where((e) => e['description'] == 'Duty-free sales')
          .map((e) => e['amount'])
          .toList();
      expect(sales, isNotEmpty);
      final allowed = {for (var n = 1; n <= 10; n++) (n * 14 * 1.15).round()};
      expect(sales.every(allowed.contains), isTrue, reason: '$sales');
    });
  });

  group('planning like the timetable in the original game', () {
    test('signing waits in the holding bar until the series is placed', () {
      expect(world.acceptContract(airline, 'coastal'), isNull);
      final c = world.contracts.single;
      expect(world.flights, isEmpty);
      expect(c.remaining, 7);
      final stand = world.stands.first;
      expect(world.placeContract(c.id, stand.id, 600), isNull);
      expect(c.remaining, 0);
      expect(world.flights, hasLength(7));
      for (var d = 0; d < 7; d++) {
        final f = world.flights[d];
        expect(f.arrival, 600 + d * 1440.0);
        expect(f.departure - f.arrival, 180 - slotExitMinutes);
        expect(f.standId, stand.id);
        expect(f.passengers, c.offer.passengers);
      }
      expect(c.startDay, 1);
      expect(c.endDay, 7);
      expect(world.placeContract(c.id, stand.id, 900), contains('planned'));
      expect(world.contractBlocker('coastal'), contains('still flying'));
    });

    test('placement respects slots, stand size, conflicts and the clock', () {
      AirportContract contractFor(String id, String modelId) {
        final c = AirportContract(
          id: id,
          offer: AirportOffer(
            id: id,
            carrier: 'Northwind Regional',
            modelId: modelId,
            type: AirportOffer.regular,
            flights: 7,
            slot: 'AM',
            passengers: 50,
            fee: 40000,
            penalty: 10000,
            requiredServices: const ['fuelDepot'],
            expiresDay: 9,
          ),
          signedDay: 1,
        );
        world.contracts.add(c);
        return c;
      }

      final c = contractFor('am', 'atr72');
      final stands = world.stands;
      expect(
        world.placeContract(c.id, stands.first.id, 780),
        contains('AM (06:00–12:00)'),
      );
      expect(
        world.placeContract(c.id, stands.first.id, 200),
        contains('30 minutes'),
      );
      expect(world.placeContract(c.id, 'nowhere', 500), contains('stand'));
      world.facilities.add(
        AirportFacility(id: 'r1', kind: 'standRegional', x: 900, y: 900)
          ..connected = true,
      );
      final jet = contractFor('jet', 'a320neo');
      expect(world.placeContract(jet.id, 'r1', 500), contains('cannot take'));
      world.contracts.remove(jet);
      world.facilities.removeWhere((f) => f.id == 'r1');
      expect(world.placeContract(c.id, stands.first.id, 1440 + 400), isNull);
      expect(world.flights, hasLength(7));
      expect(world.flights.first.departure - world.flights.first.arrival, 150);

      expect(world.acceptContract(airline, 'coastal'), isNull);
      final coastal = world.contracts.last;
      expect(
        world.placeContract(coastal.id, stands.first.id, 1440 + 500),
        contains('busy'),
      );
      expect(world.flights, hasLength(7));
      expect(
        world.placeContract(coastal.id, stands.last.id, 1440 + 500),
        isNull,
      );
      expect(world.flights, hasLength(14));
    });

    test('charters are placed one flight at a time', () {
      final base = airportOffers.first;
      final charter = AirportContract(
        id: 'charter',
        offer: AirportOffer(
          id: 'x',
          carrier: base.carrier,
          modelId: base.modelId,
          type: AirportOffer.charter,
          flights: 3,
          slot: 'ALL',
          passengers: 40,
          fee: 50000,
          penalty: 9000,
          requiredServices: const ['fuelDepot'],
          expiresDay: 3,
        ),
        signedDay: 1,
      );
      world.contracts.add(charter);
      final stand = world.stands.first.id;
      expect(world.placeContract('charter', stand, 500), isNull);
      expect(world.placeContract('charter', stand, 900), isNull);
      expect(charter.remaining, 1);
      expect(world.flights, hasLength(2));
      expect(
        world.placeContract('charter', stand, 9 * 1440),
        contains('fly by day 7'),
      );
    });

    test('flights move in time, and return to the holding bar', () {
      expect(signAndPlace(world, airline, 'coastal', at: 600), isNull);
      final c = world.contracts.single;
      final first = world.flights.first;
      final other = world.stands.last.id;
      expect(world.moveFlight(first.id, other, 800), isNull);
      final moved = world.flights.first;
      expect(moved.id, first.id);
      expect(moved.arrival, 800);
      expect(moved.departure, 950);
      expect(moved.standId, other);
      expect(world.moveFlight(moved.id, other, 250), contains('30 minutes'));

      expect(world.unscheduleFlight(moved.id), isNull);
      expect(world.flights, hasLength(6));
      expect(c.remaining, 1);
      expect(world.placeContract(c.id, other, 700), isNull);
      expect(world.flights, hasLength(7));
      expect(c.remaining, 0);

      world.advance(700 - world.time + 5, airline, catalog);
      final active = world.flights.firstWhere((f) => f.arrival == 700);
      expect(world.unscheduleFlight(active.id), contains('not arrived'));
      expect(world.moveFlight(active.id, other, 3000), contains('not arrived'));
    });

    test('flights never planned lapse with a penalty after the deadline', () {
      expect(world.acceptContract(airline, 'coastal'), isNull);
      final c = world.contracts.single;
      expect(c.deadlineDay, 4);
      final cash = airline.cashEur;
      world.advance(4 * 1440, airline, catalog);
      expect(c.remaining, 0);
      expect(c.lapsed, 7);
      final penalties = world.ledger.where((e) => e['category'] == 'penalty');
      expect(penalties, hasLength(1));
      expect(penalties.single['amount'], -7 * c.offer.penalty);
      expect(airline.cashEur, lessThan(cash));
      expect(world.contractBlocker('coastal'), isNull);
    });

    test('the market is the same everywhere and forgets signed offers', () {
      final today = world.offers.map((o) => o.toJson()).toList();
      expect(
        AirportWorld.fromJson(world.toJson()).offers.map((o) => o.toJson()),
        today,
      );
      final generated = world.offers.where((o) => o.expiresDay != null);
      expect(generated, isNotEmpty);
      for (final o in generated) {
        expect(o.flights, greaterThan(0));
        expect(haulMinutes, contains(o.haul));
        expect(o.fee, greaterThan(o.penalty));
      }
      final id = generated.first.id;
      world.contracts.add(
        AirportContract(id: 'direct', offer: generated.first, signedDay: 1),
      );
      world.signedOffers.add(id);
      expect(world.offers.map((o) => o.id), isNot(contains(id)));
      final reloaded = AirportWorld.fromJson(
        jsonDecode(jsonEncode(world.toJson())) as Map<String, dynamic>,
      );
      expect(reloaded.offers.map((o) => o.id), isNot(contains(id)));
      expect(
        reloaded.contracts.single.offer.toJson(),
        world.contracts.single.offer.toJson(),
      );
      world.advance(3 * 1440, airline, catalog);
      expect(
        world.offers.where(
          (o) => o.expiresDay != null && o.expiresDay! < world.day,
        ),
        isEmpty,
      );
    });

    test('every day opens with a short-haul offer the starter can take', () {
      for (var d = 1; d <= 30; d++) {
        expect(offersPublishedOn(d).first.haul, 'SH', reason: 'day $d');
      }
      final first = world.offers.firstWhere((o) => o.expiresDay != null);
      expect(world.contractBlocker(first.id), isNull);
    });

    test('contracts saved before placement existed still load', () {
      final c = AirportContract.fromJson({
        'id': 'c9',
        'offerId': 'coastal',
        'carrier': 'Coastal Connect',
        'startDay': 1,
        'endDay': 7,
        'satisfaction': .9,
        'cancelled': false,
      });
      expect(c.offer.id, 'coastal');
      expect(c.remaining, 0);
      expect(c.satisfaction, .9);
    });
  });
}
