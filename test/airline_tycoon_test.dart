import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/airline_game_state.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/airline_tycoon_repository.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/data/aircraft.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/data/airport_catalog.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/data/buildings.dart';
import 'package:luma/storage/storage_guard.dart';

late AirportCatalog catalog;

/// A repository with a game already running and the clock stopped, so a test
/// can drive days explicitly.
AirlineTycoonRepository makeRepo({String hub = 'AMS'}) {
  final repo = AirlineTycoonRepository(autoStart: false)
    ..setCatalogForTest(catalog);
  repo.startGame(airlineName: 'Test Air', hubIata: hub);
  // The day timer would otherwise roll days over mid-test.
  repo.pause();
  return repo;
}

/// Puts the free turboprop to work on a short sector, so days actually trade.
void flyShortHaul(AirlineTycoonRepository repo, {String dest = 'LHR'}) {
  expect(repo.openRoute(dest).success, isTrue);
  final route = repo.state.routes.single;
  final aircraft = repo.state.fleet.single;
  expect(repo.assignAircraft(aircraft.id, route.id).success, isTrue);
}

void main() {
  setUpAll(() {
    // The repository reaches for path_provider on construction; without a
    // binding that call throws before its own try/catch can swallow it.
    TestWidgetsFlutterBinding.ensureInitialized();
    // Every save consults the app-wide storage cap; outside main.dart's real
    // startup this static is never set.
    StorageGuardService.instance = StorageGuardService();
    catalog = AirportCatalog.parse(
      File('assets/airline_tycoon/airports.json').readAsStringSync(),
    );
  });

  group('starting a game', () {
    test('lays out a field that can already fly something', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);

      expect(repo.hasGame, isTrue);
      expect(repo.state.hubIata, 'AMS');
      expect(repo.state.fleet.length, 1);
      expect(repo.state.cashEur, AirlineGameState.startingCashEur);

      final effects = repo.hubEffects;
      expect(effects.activeGates, 2, reason: 'both starter gates touch the terminal');
      expect(effects.inactiveGates, 0);
      expect(effects.maxRunwayM, 1800);

      // The free ATR has somewhere to go on day one.
      final atr = kAircraftById['atr72']!;
      expect(atr.canUseRunway(effects.maxRunwayM), isTrue);
    });

    test('the starter aircraft is unassigned until the player says so', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      expect(repo.state.fleet.single.routeId, isNull);
    });
  });

  group('routes', () {
    test('a route can be opened and flown', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      flyShortHaul(repo);

      final report = repo.processDay()!;
      expect(report.flights, greaterThan(0));
      expect(report.passengers, greaterThan(0));
      expect(report.revenueEur, greaterThan(0));
    });

    test('opening a route costs a launch fee', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      final before = repo.state.cashEur;
      expect(repo.openRoute('LHR').success, isTrue);
      expect(repo.state.cashEur, lessThan(before));
    });

    test('you cannot fly to your own hub', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      expect(repo.openRoute('AMS').success, isFalse);
    });

    test('you cannot open the same route twice', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      expect(repo.openRoute('LHR').success, isTrue);
      final second = repo.openRoute('LHR');
      expect(second.success, isFalse);
      expect(second.message, contains('London'));
    });

    test('routes are capped by gates that touch a terminal', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      // Two starter gates, so the third route has nowhere to park.
      expect(repo.openRoute('LHR').success, isTrue);
      expect(repo.openRoute('CDG').success, isTrue);
      final third = repo.openRoute('BCN');
      expect(third.success, isFalse);
      expect(third.message, contains('gate'));
    });

    test('a stranded gate is named in the refusal, so the rule teaches itself',
        () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      repo.state.cashEur = 900000000;
      // A gate nowhere near the terminal: paid for, and useless.
      expect(repo.placeBuilding(BuildingKind.gate, 0, 11).success, isTrue);
      expect(repo.hubEffects.inactiveGates, 1);

      expect(repo.openRoute('LHR').success, isTrue);
      expect(repo.openRoute('CDG').success, isTrue);
      final refused = repo.openRoute('BCN');
      expect(refused.success, isFalse);
      expect(refused.message, contains('not touching a terminal'));
    });

    test('closing a route frees its aircraft', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      flyShortHaul(repo);
      repo.closeRoute(repo.state.routes.single.id);
      expect(repo.state.routes, isEmpty);
      expect(repo.state.fleet.single.routeId, isNull);
    });

    test('the fare is clamped to something sane', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      flyShortHaul(repo);
      final id = repo.state.routes.single.id;
      repo.setFare(id, -50);
      expect(repo.state.routes.single.fareEur, greaterThan(0));
      repo.setFare(id, 99999999);
      expect(repo.state.routes.single.fareEur, lessThanOrEqualTo(100000));
    });
  });

  group('fleet', () {
    test('an aircraft out of range is refused, with the numbers', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      // Sydney is far beyond an ATR 72.
      expect(repo.openRoute('SYD').success, isTrue);
      final result = repo.assignAircraft(
        repo.state.fleet.single.id,
        repo.state.routes.single.id,
      );
      expect(result.success, isFalse);
      expect(result.message, contains('range'));
    });

    test('an aircraft needing more runway than the hub has is refused', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      repo.state.cashEur = 900000000;
      expect(
        repo.acquireAircraft(kAircraftById['b787_9']!, lease: false).success,
        isTrue,
      );
      expect(repo.openRoute('JFK').success, isTrue);

      final widebody =
          repo.state.fleet.firstWhere((a) => a.modelId == 'b787_9');
      final result =
          repo.assignAircraft(widebody.id, repo.state.routes.single.id);
      expect(result.success, isFalse);
      expect(result.message, contains('runway'));
    });

    test('buying costs cash, leasing does not', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      repo.state.cashEur = 900000000;
      final model = kAircraftById['a320neo']!;

      final beforeBuy = repo.state.cashEur;
      expect(repo.acquireAircraft(model, lease: false).success, isTrue);
      expect(repo.state.cashEur, beforeBuy - model.priceEur);

      final beforeLease = repo.state.cashEur;
      expect(repo.acquireAircraft(model, lease: true).success, isTrue);
      expect(repo.state.cashEur, beforeLease);
    });

    test('you cannot buy what you cannot afford', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      repo.state.cashEur = 1000;
      expect(
        repo.acquireAircraft(kAircraftById['a380_800']!, lease: false).success,
        isFalse,
      );
    });

    test('a lease needs a week of payments in the bank', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      repo.state.cashEur = 100;
      expect(
        repo.acquireAircraft(kAircraftById['a320neo']!, lease: true).success,
        isFalse,
      );
    });

    test('selling returns cash; handing back a lease does not', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      repo.state.cashEur = 900000000;
      final model = kAircraftById['a320neo']!;

      repo.acquireAircraft(model, lease: false);
      final owned = repo.state.fleet.last;
      final beforeSale = repo.state.cashEur;
      repo.releaseAircraft(owned.id);
      expect(repo.state.cashEur, greaterThan(beforeSale));

      repo.acquireAircraft(model, lease: true);
      final leased = repo.state.fleet.last;
      final beforeReturn = repo.state.cashEur;
      repo.releaseAircraft(leased.id);
      expect(repo.state.cashEur, beforeReturn);
    });

    test('leased aircraft cost money every day', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      repo.state.cashEur = 900000000;
      repo.acquireAircraft(kAircraftById['a320neo']!, lease: true);
      final report = repo.processDay()!;
      expect(report.leaseEur, greaterThan(0));
    });

    test('flying wears the airframe out', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      flyShortHaul(repo);
      final before = repo.state.fleet.single.condition;
      for (var i = 0; i < 20; i++) {
        repo.processDay();
      }
      final aircraft = repo.state.fleet.single;
      expect(aircraft.blockHours, greaterThan(0));
      expect(aircraft.condition, lessThan(before));
    });

    test('a grounded aircraft earns nothing but keeps its route', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      flyShortHaul(repo);
      final aircraft = repo.state.fleet.single;
      aircraft.groundedUntilDay = repo.state.day + 5;

      final report = repo.processDay()!;
      expect(report.flights, 0);
      expect(report.revenueEur, 0);
      expect(repo.state.fleet.single.routeId, isNotNull);
    });
  });

  group('the hub', () {
    test('building costs cash and demolishing gives half back', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      final def = buildingDef(BuildingKind.hangar);

      final before = repo.state.cashEur;
      expect(repo.placeBuilding(BuildingKind.hangar, 0, 0).success, isTrue);
      expect(repo.state.cashEur, before - def.costEur);

      expect(repo.demolishAt(0, 0).success, isTrue);
      expect(repo.state.cashEur, before - def.costEur + def.costEur ~/ 2);
    });

    test('a hangar makes maintenance cheaper on the very next day', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      repo.state.cashEur = 900000000;
      flyShortHaul(repo);

      final plain = repo.processDay()!;
      expect(repo.placeBuilding(BuildingKind.hangar, 0, 0).success, isTrue);
      final geared = repo.processDay()!;
      expect(geared.maintenanceEur, lessThan(plain.maintenanceEur));
    });

    test('you cannot build on top of something', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      repo.state.cashEur = 900000000;
      // The starter terminal sits at (5,5).
      expect(repo.placeBuilding(BuildingKind.gate, 5, 5).success, isFalse);
    });

    test('you cannot build off the edge of the field', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      repo.state.cashEur = 900000000;
      expect(repo.placeBuilding(BuildingKind.gate, 11, 11).success, isTrue);
      expect(repo.placeBuilding(BuildingKind.terminal, 11, 0).success, isFalse);
    });

    test('you cannot build what you cannot afford', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      repo.state.cashEur = 100;
      expect(repo.placeBuilding(BuildingKind.terminal, 0, 0).success, isFalse);
    });

    test('demolishing nothing is refused', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      expect(repo.demolishAt(11, 11).success, isFalse);
    });

    test('expanding the field keeps everything already built', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      repo.state.cashEur = 900000000;
      final before = repo.state.buildings.length;
      final size = repo.state.gridSize;

      expect(repo.expandField().success, isTrue);
      expect(repo.state.gridSize, size + 2);
      expect(repo.state.buildings.length, before);
    });

    test('the field stops growing at its limit', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      repo.state.cashEur = 9000000000;
      while (repo.state.gridSize < AirlineGameState.maxGridSize) {
        expect(repo.expandField().success, isTrue);
      }
      expect(repo.expandField().success, isFalse);
      expect(repo.state.gridSize, AirlineGameState.maxGridSize);
    });
  });

  group('offline catch-up', () {
    void goOffline(AirlineTycoonRepository repo, int days) {
      repo.state.lastSeenEpochMs = DateTime.now().millisecondsSinceEpoch -
          days * AirlineTycoonRepository.offlineMsPerDay;
    }

    test('a first run pays nothing and only stamps the clock', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      repo.state.lastSeenEpochMs = 0;
      final day = repo.state.day;

      repo.catchUpOnAwayTime();
      expect(repo.lastAwayReport, isNull);
      expect(repo.state.day, day);
      expect(repo.state.lastSeenEpochMs, greaterThan(0));
    });

    test('a clock moved backwards never pays out', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      flyShortHaul(repo);
      // A timezone change or a manual clock set must not mint money.
      repo.state.lastSeenEpochMs =
          DateTime.now().millisecondsSinceEpoch + 86400000;
      final cash = repo.state.cashEur;
      final day = repo.state.day;

      repo.catchUpOnAwayTime();
      expect(repo.lastAwayReport, isNull);
      expect(repo.state.cashEur, cash);
      expect(repo.state.day, day);
    });

    test('an absence shorter than one offline day pays nothing', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      flyShortHaul(repo);
      repo.state.lastSeenEpochMs = DateTime.now().millisecondsSinceEpoch -
          (AirlineTycoonRepository.offlineMsPerDay - 1);
      final day = repo.state.day;

      repo.catchUpOnAwayTime();
      expect(repo.lastAwayReport, isNull);
      expect(repo.state.day, day);
    });

    test('a few days away simulate exactly that many days', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      flyShortHaul(repo);
      final day = repo.state.day;
      goOffline(repo, 4);

      repo.catchUpOnAwayTime();
      final report = repo.lastAwayReport!;
      expect(report.daysSimulated, 4);
      expect(report.daysElapsed, 4);
      expect(report.capped, isFalse);
      expect(repo.state.day, day + 4);
      expect(report.passengers, greaterThan(0));
    });

    test('a long absence is capped, and says so', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      flyShortHaul(repo);
      goOffline(repo, 40);

      repo.catchUpOnAwayTime();
      final report = repo.lastAwayReport!;
      expect(report.daysSimulated, AirlineGameState.maxOfflineDays);
      expect(report.daysElapsed, 40);
      expect(report.capped, isTrue);
    });

    test('an offline day earns less than a played one', () {
      final live = makeRepo();
      final away = makeRepo();
      addTearDown(live.dispose);
      addTearDown(away.dispose);
      flyShortHaul(live);
      flyShortHaul(away);

      final liveReport = live.processDay()!;
      final awayReport = away.processDay(offline: true)!;
      expect(awayReport.incomeEur, lessThan(liveReport.incomeEur));
    });

    test('an offline day discounts costs too, so being away cannot bankrupt you',
        () {
      // The rule that matters: if revenue is scaled but costs are not, a
      // thin-margin airline dies while the player is asleep.
      final live = makeRepo();
      final away = makeRepo();
      addTearDown(live.dispose);
      addTearDown(away.dispose);
      flyShortHaul(live);
      flyShortHaul(away);

      final liveReport = live.processDay()!;
      final awayReport = away.processDay(offline: true)!;
      expect(
        awayReport.costEur,
        closeTo(liveReport.costEur * AirlineGameState.baseOfflineRate, 500),
      );
      expect(
        awayReport.profitEur,
        closeTo(liveReport.profitEur * AirlineGameState.baseOfflineRate, 800),
      );
    });

    test('an offline catch-up leaves no day modal queued behind it', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      flyShortHaul(repo);
      goOffline(repo, 3);

      repo.catchUpOnAwayTime();
      expect(repo.lastDayReport, isNull);
      expect(repo.lastAwayReport, isNotNull);
    });

    test('the away report can be dismissed', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      flyShortHaul(repo);
      goOffline(repo, 3);
      repo.catchUpOnAwayTime();

      repo.clearAwayReport();
      expect(repo.lastAwayReport, isNull);
    });
  });

  group('determinism', () {
    test('two identical airlines trade identically', () {
      // The guard against an unseeded Random ever creeping into the day path.
      final a = makeRepo();
      final b = makeRepo();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      flyShortHaul(a);
      flyShortHaul(b);

      for (var i = 0; i < 30; i++) {
        final ra = a.processDay()!;
        final rb = b.processDay()!;
        expect(ra.revenueEur, rb.revenueEur, reason: 'day $i revenue');
        expect(ra.costEur, rb.costEur, reason: 'day $i cost');
        expect(ra.passengers, rb.passengers, reason: 'day $i passengers');
      }
      expect(a.state.cashEur, b.state.cashEur);
    });

    test('cash stays exact over hundreds of days', () {
      // Money is int precisely so this holds; a double balance would drift.
      final a = makeRepo();
      final b = makeRepo();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      flyShortHaul(a);
      flyShortHaul(b);

      for (var i = 0; i < 500; i++) {
        a.processDay();
        b.processDay();
      }
      expect(a.state.cashEur, b.state.cashEur);
      expect(a.state.cashEur, isA<int>());
    });

    test('the fuel price varies by day but repeats for the same day', () {
      final first = AirlineGameState.fuelPriceIndexFor(12);
      expect(AirlineGameState.fuelPriceIndexFor(12), first);
      expect(AirlineGameState.fuelPriceIndexFor(13), isNot(first));
      for (var day = 1; day < 400; day++) {
        expect(
          AirlineGameState.fuelPriceIndexFor(day),
          inInclusiveRange(0.8, 1.2),
        );
      }
    });
  });

  group('the books', () {
    test('profit is income minus cost, and cash follows it', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      flyShortHaul(repo);
      final before = repo.state.cashEur;

      final report = repo.processDay()!;
      expect(report.profitEur, report.incomeEur - report.costEur);
      expect(repo.state.cashEur, before + report.profitEur);
    });

    test('history is kept but bounded, so the save cannot grow forever', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      flyShortHaul(repo);
      for (var i = 0; i < AirlineGameState.historyLength + 40; i++) {
        repo.processDay();
      }
      expect(repo.state.history.length, AirlineGameState.historyLength);
      expect(repo.state.routes.single.profitHistory.length,
          AirlineRoute.historyLength);
    });

    test('lifetime totals accumulate', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      flyShortHaul(repo);
      repo.processDay();
      repo.processDay();
      expect(repo.state.flightsFlownEver, greaterThan(0));
      expect(repo.state.passengersCarriedEver, greaterThan(0));
    });
  });

  group('saving', () {
    test('a full state round-trips through JSON', () {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      repo.state.cashEur = 900000000;
      flyShortHaul(repo);
      repo.placeBuilding(BuildingKind.hangar, 0, 0);
      repo.acquireAircraft(kAircraftById['a320neo']!, lease: true);
      repo.processDay();

      final original = repo.state;
      final restored = AirlineGameState.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, Object?>,
      );

      expect(restored.airlineName, original.airlineName);
      expect(restored.hubIata, original.hubIata);
      expect(restored.cashEur, original.cashEur);
      expect(restored.day, original.day);
      expect(restored.gridSize, original.gridSize);
      expect(restored.buildings.length, original.buildings.length);
      expect(restored.fleet.length, original.fleet.length);
      expect(restored.routes.length, original.routes.length);
      expect(restored.history.length, original.history.length);
      expect(restored.fleet.first.blockHours,
          closeTo(original.fleet.first.blockHours, 1e-9));
      expect(restored.routes.first.fareEur, original.routes.first.fareEur);
      expect(restored.flightsFlownEver, original.flightsFlownEver);
    });

    test('a save from an older build loads with defaults instead of throwing',
        () {
      final restored =
          AirlineGameState.fromJson(const {'hub': 'AMS', 'name': 'Old Air'});
      expect(restored.hubIata, 'AMS');
      expect(restored.cashEur, AirlineGameState.startingCashEur);
      expect(restored.day, 1);
      expect(restored.buildings, isEmpty);
      expect(restored.fleet, isEmpty);
    });

    test('a nonsense grid size is clamped rather than trusted', () {
      expect(
        AirlineGameState.fromJson(const {'hub': 'AMS', 'grid': 9999}).gridSize,
        AirlineGameState.maxGridSize,
      );
      expect(
        AirlineGameState.fromJson(const {'hub': 'AMS', 'grid': -4}).gridSize,
        AirlineGameState.minGridSize,
      );
    });
  });

  group('sync', () {
    test('exports a snapshot the importer accepts', () async {
      final source = makeRepo();
      addTearDown(source.dispose);
      flyShortHaul(source);
      source.processDay();

      final target = AirlineTycoonRepository(autoStart: false)
        ..setCatalogForTest(catalog);
      addTearDown(target.dispose);

      await target.importData(await source.exportData());
      expect(target.state.hubIata, source.state.hubIata);
      expect(target.state.cashEur, source.state.cashEur);
      expect(target.state.routes.length, source.state.routes.length);
    });

    test('a stale snapshot never rolls this device backwards', () {
      // Both devices run their own day clock, so plain last-write-wins would
      // let an old snapshot undo real play.
      final repo = makeRepo();
      addTearDown(repo.dispose);
      flyShortHaul(repo);
      repo.processDay();

      final stale = AirlineGameState(airlineName: 'Stale', hubIata: 'BCN')
        ..cashEur = 1
        ..lastSeenEpochMs = repo.state.lastSeenEpochMs - 60000;

      final cash = repo.state.cashEur;
      repo.importData(stale.toJson());
      expect(repo.state.cashEur, cash);
      expect(repo.state.hubIata, 'AMS');
    });

    test('a newer snapshot is taken', () async {
      final repo = makeRepo();
      addTearDown(repo.dispose);

      final newer = AirlineGameState(airlineName: 'Newer', hubIata: 'BCN')
        ..cashEur = 12345
        ..lastSeenEpochMs = repo.state.lastSeenEpochMs + 60000;

      await repo.importData(newer.toJson());
      expect(repo.state.hubIata, 'BCN');
      expect(repo.state.cashEur, 12345);
    });

    test('rubbish handed to the importer is ignored', () async {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      final cash = repo.state.cashEur;
      await repo.importData('not a snapshot');
      await repo.importData(null);
      expect(repo.state.cashEur, cash);
    });
  });
}
