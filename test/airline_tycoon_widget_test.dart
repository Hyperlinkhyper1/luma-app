import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/airline_tycoon_page.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/airline_tycoon_repository.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/airline_tycoon_scope.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/data/airport_catalog.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/data/buildings.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/sim/iso.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/ui/hub_view.dart';
import 'package:luma/storage/storage_guard.dart';
import 'package:luma/theme/luma_theme.dart';

late AirportCatalog catalog;

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    StorageGuardService.instance = StorageGuardService();
    catalog = AirportCatalog.parse(
      File('assets/airline_tycoon/airports.json').readAsStringSync(),
    );
  });

  AirlineTycoonRepository makeRepo({bool started = true}) {
    final repo = AirlineTycoonRepository(autoStart: false)
      ..setCatalogForTest(catalog);
    if (started) {
      repo.startGame(airlineName: 'Test Air', hubIata: 'AMS');
    }
    // The day timer would otherwise roll days over mid-test and leave a
    // pending timer when the tree is torn down.
    repo.pause();
    return repo;
  }

  /// Advances the fake clock and real time in turn.
  ///
  /// `pumpAndSettle` cannot be used anywhere in this file: the routes tab
  /// decodes the bundled world outline off the real asset bundle, and until
  /// that future completes it shows an indeterminate spinner that never stops
  /// animating — so `pumpAndSettle` waits forever. (The same trap is
  /// documented in `mind_map_widget_test.dart` for drift's query streams.)
  /// Pumping first lets the sheet and tab animations run; `runAsync` then
  /// gives the bundle a slice of real time to finish.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 80));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
    }
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpPage(
    WidgetTester tester,
    AirlineTycoonRepository repo, {
    Size size = const Size(1280, 900),
  }) async {
    // The view itself is resized rather than just wrapping a MediaQuery:
    // wrapping only tells the widgets how big they are while the render
    // surface stays 800x600, so responsive branches pick the desktop layout
    // and are then laid out in a phone-sized box.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: Scaffold(
          body: AirlineTycoonScope(
            repository: repo,
            child: const AirlineTycoonPage(),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  group('setup', () {
    testWidgets('offers hubs before a game exists', (tester) async {
      final repo = makeRepo(started: false);
      addTearDown(repo.dispose);
      await pumpPage(tester, repo);

      expect(find.text('Start an airline'), findsOneWidget);
      expect(find.text('Take off'), findsOneWidget);
      expect(find.text('Choose a hub to continue.'), findsOneWidget);
    });

    testWidgets('picking a hub and taking off starts the game', (tester) async {
      final repo = makeRepo(started: false);
      addTearDown(repo.dispose);
      await pumpPage(tester, repo);

      final firstHub = repo.starterHubs().first;
      await tester.tap(find.text(firstHub.label));
      await tester.pump();
      await tester.tap(find.text('Take off'));
      await tester.pump();
      repo.pause();
      await tester.pump();

      expect(repo.hasGame, isTrue);
      expect(repo.state.hubIata, firstHub.iata);
    });
  });

  group('the page', () {
    testWidgets('shows all four tabs and the cash strip', (tester) async {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      await pumpPage(tester, repo);

      expect(find.text('Fleet'), findsOneWidget);
      expect(find.text('Routes'), findsOneWidget);
      expect(find.text('Hub'), findsOneWidget);
      expect(find.text('Finances'), findsOneWidget);
      expect(find.text('Test Air'), findsOneWidget);
    });

    testWidgets('switching tabs shows the hub capacity strip', (tester) async {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      await pumpPage(tester, repo);

      await tester.tap(find.text('Hub'));
      await tester.pump();

      expect(find.text('Gates'), findsOneWidget);
      expect(find.text('Runway'), findsOneWidget);
      // Two starter gates, both touching the terminal, none in use yet.
      expect(find.text('0 / 2'), findsOneWidget);
      expect(find.text('1 800 m'), findsOneWidget);
    });

    testWidgets('a stranded gate is called out in the capacity strip',
        (tester) async {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      repo.state.cashEur = 900000000;
      repo.placeBuilding(BuildingKind.gate, 0, 11);

      await pumpPage(tester, repo);
      await tester.tap(find.text('Hub'));
      await tester.pump();

      expect(find.text('Not on a terminal'), findsOneWidget);
    });

    testWidgets('picking a building and tapping the field builds it there',
        (tester) async {
      // The end-to-end path the isometric projection exists to support:
      // palette selection, screen point, inverse projection, tile, placement.
      // If picking and drawing ever disagree, this lands on the wrong tile.
      final repo = makeRepo();
      addTearDown(repo.dispose);
      repo.state.cashEur = 900000000;
      await pumpPage(tester, repo);

      await tester.tap(find.text('Hub'));
      await tester.pump();

      final buildingsBefore = repo.state.buildings.length;
      final cashBefore = repo.state.cashEur;

      await tester.tap(find.text('Hangar'));
      await tester.pump();

      // Tile (0, 0) is bare on the starter field.
      final layout = IsoCamera.layout(repo.state.gridSize);
      final camera = IsoCamera(origin: layout.origin);
      final viewer = find.descendant(
        of: find.byType(HubView),
        matching: find.byType(InteractiveViewer),
      );
      expect(viewer, findsOneWidget);
      await tester.tapAt(
        tester.getTopLeft(viewer) + camera.project(0.5, 0.5),
      );
      await tester.pump();

      expect(repo.state.buildings.length, buildingsBefore + 1);
      expect(
        repo.state.cashEur,
        cashBefore - buildingDef(BuildingKind.hangar).costEur,
      );
      final placed = repo.state.buildings.last;
      expect(placed.kind, BuildingKind.hangar);
      expect((placed.x, placed.y), (0, 0));
    });

    testWidgets('the fleet tab lists the starter aircraft', (tester) async {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      await pumpPage(tester, repo);

      expect(find.text('ATR 72-600'), findsOneWidget);
      expect(find.text('1 aircraft'), findsOneWidget);
    });

    testWidgets('an empty fleet shows an empty state, not a blank list',
        (tester) async {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      repo.releaseAircraft(repo.state.fleet.single.id);
      await pumpPage(tester, repo);

      expect(find.text('Your hangar is empty'), findsOneWidget);
    });

    testWidgets('the finances tab shows the balance', (tester) async {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      await pumpPage(tester, repo);

      await tester.tap(find.text('Finances'));
      await tester.pump();

      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('The airline so far'), findsOneWidget);
    });
  });

  group('layout', () {
    // A widget test fails on overflow by itself, so pumping at each size is
    // the assertion.
    testWidgets('fits a small phone', (tester) async {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      await pumpPage(tester, repo, size: const Size(375, 812));

      for (final tab in ['Routes', 'Hub', 'Finances']) {
        await tester.tap(find.text(tab));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a wide desktop window', (tester) async {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      await pumpPage(tester, repo, size: const Size(1600, 1000));

      for (final tab in ['Routes', 'Hub', 'Finances']) {
        await tester.tap(find.text(tab));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a phone in landscape', (tester) async {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      await pumpPage(tester, repo, size: const Size(812, 375));

      await tester.tap(find.text('Hub'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('the away report', () {
    /// Puts an aircraft to work and then jumps the clock back so reopening
    /// the page has days to catch up on.
    void goAway(AirlineTycoonRepository repo, int days) {
      expect(repo.openRoute('LHR').success, isTrue);
      repo.assignAircraft(
        repo.state.fleet.single.id,
        repo.state.routes.single.id,
      );
      repo.state.lastSeenEpochMs = DateTime.now().millisecondsSinceEpoch -
          days * AirlineTycoonRepository.offlineMsPerDay;
      repo.catchUpOnAwayTime();
    }

    testWidgets('appears after time has passed and dismisses', (tester) async {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      goAway(repo, 4);

      await pumpPage(tester, repo);
      // The sheet slides up; until that finishes its button is still below
      // the bottom edge and a tap would miss it.
      await settle(tester);

      expect(find.text('While you were away'), findsOneWidget);
      expect(find.textContaining('4 days flown'), findsOneWidget);

      await tester.tap(find.text('Back to work'));
      await settle(tester);

      expect(find.text('While you were away'), findsNothing);
      expect(repo.lastAwayReport, isNull);
    });

    testWidgets('says so when the absence was capped', (tester) async {
      final repo = makeRepo();
      addTearDown(repo.dispose);
      goAway(repo, 40);

      await pumpPage(tester, repo);
      await settle(tester);

      expect(find.textContaining('40 days went by'), findsOneWidget);
    });

    testWidgets('keeps its only action reachable on a short screen',
        (tester) async {
      // A capped report with events is the longest this sheet ever gets. On a
      // small phone that is taller than the screen, so the body has to scroll
      // with the button pinned — otherwise the only way out sits below the
      // bottom edge and cannot be tapped at all.
      final repo = makeRepo();
      addTearDown(repo.dispose);
      goAway(repo, 40);

      await pumpPage(tester, repo, size: const Size(375, 600));
      await settle(tester);

      final button = tester.getRect(find.text('Back to work'));
      expect(button.bottom, lessThanOrEqualTo(600),
          reason: 'the dismiss button must be on screen');

      await tester.tap(find.text('Back to work'));
      await settle(tester);
      expect(repo.lastAwayReport, isNull);
    });
  });
}
