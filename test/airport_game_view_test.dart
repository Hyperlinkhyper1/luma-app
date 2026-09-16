import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/airline_game_state.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/airline_tycoon_repository.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/ui/airport_game_view.dart';
import 'package:luma/theme/luma_theme.dart';

class _AirportUiRepository extends AirlineTycoonRepository {
  _AirportUiRepository()
    : super(
        initialState: AirlineGameState(airlineName: 'Test Air', hubIata: 'AMS'),
        autoStart: false,
      );
  final commands = <String>[];
  final commandArgs = <Map<String, Object?>>[];
  bool paused = true;

  @override
  Map<String, Object?> airportSnapshot() => {
    'paused': paused,
    'speed': 1,
    'time': 0,
    'day': 1,
    'cash': 100000,
    'facilities': <Object?>[
      {
        'id': 'check-in-1',
        'kind': 'checkIn',
        'width': 8,
        'depth': 4,
        'connected': true,
        'rotation': 0,
      },
    ],
    'catalog': <Object?>[
      {
        'kind': 'checkIn',
        'name': 'Check-in desks',
        'interior': true,
        'cost': 1200,
        'width': 8,
        'depth': 4,
        'blurb': 'Passenger check-in',
      },
    ],
    'fleet': <Object?>[],
    'routes': <Object?>[],
    'flights': <Object?>[],
    'contracts': <Object?>[
      {
        'id': 'active',
        'carrier': 'Current Air',
        'startDay': 1,
        'endDay': 7,
        'satisfaction': .87,
        'cancelCost': 12000,
      },
      {
        'id': 'cancelled',
        'carrier': 'Cancelled Air',
        'startDay': 1,
        'endDay': 7,
        'cancelled': true,
        'satisfaction': 1,
        'cancelCost': 0,
      },
      {
        'id': 'expired',
        'carrier': 'Expired Air',
        'startDay': 0,
        'endDay': 0,
        'satisfaction': 1,
        'cancelCost': 0,
      },
    ],
    'ledger': <Object?>[],
    'offers': [
      {
        'id': 'regional',
        'carrier': 'Coastal Air',
        'modelId': 'atr72',
        'flightsPerDay': 2,
        'fee': 2000,
        'penalty': 5000,
        'runwayM': 1200,
        'requiredServices': ['fuel', 'baggage'],
      },
    ],
  };

  @override
  ActionResult airportCommand(String action, Map<String, Object?> args) {
    commands.add(action);
    commandArgs.add(Map.of(args));
    if (action == 'acceptContract') {
      return const ActionResult.failed(
        'Connect the stand to a service road first.',
      );
    }
    if (action == 'resume') paused = false;
    notifyListeners();
    return const ActionResult.ok();
  }
}

void main() {
  Future<_AirportUiRepository> mount(
    WidgetTester tester,
    Size size, {
    ValueChanged<AirportSceneBridge>? onBridge,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _AirportUiRepository();
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: Scaffold(
          body: AirportGameView(
            repository: repo,
            sceneBuilder: (_, bridge) {
              onBridge?.call(bridge);
              return const ColoredBox(
                color: Colors.teal,
                child: Center(child: Text('Airport scene')),
              );
            },
          ),
        ),
      ),
    );
    return repo;
  }

  testWidgets(
    'desktop opens on airport and renders repository refusal without accepting a contract',
    (tester) async {
      final repo = await mount(tester, const Size(1200, 850));
      expect(find.text('Airport scene'), findsOneWidget);
      expect(find.text('AIRLINE OFFERS · SEVEN DAYS'), findsNothing);
      await tester.tap(find.text('Contracts'));
      await tester.pump();
      await tester.tap(find.text('Accept contract'));
      await tester.pump();
      expect(repo.commands, ['acceptContract']);
      expect(
        find.text('Connect the stand to a service road first.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('phone keeps airport controls and scrollable panels usable', (
    tester,
  ) async {
    final repo = await mount(tester, const Size(390, 844));
    await tester.tap(find.byTooltip('Resume airport'));
    await tester.pump();
    expect(repo.paused, isFalse);
    await tester.tap(find.text('Build'));
    await tester.pump();
    expect(find.text('AIRFIELD & TERMINAL'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close panel'));
    await tester.pump();
    expect(find.text('AIRFIELD & TERMINAL'), findsNothing);
  });

  testWidgets(
    'landscape phone keeps build panel and pause controls within bounds',
    (tester) async {
      await mount(tester, const Size(812, 375));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Build'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Close panel'), findsOneWidget);
      await tester.tap(find.byTooltip('Close panel'));
      await tester.pump();
      expect(find.byTooltip('Resume airport'), findsOneWidget);
    },
  );

  testWidgets(
    'selected facility moves at each quarter turn through the authoritative bridge',
    (tester) async {
      late AirportSceneBridge bridge;
      final repo = await mount(
        tester,
        const Size(1200, 850),
        onBridge: (value) => bridge = value,
      );
      bridge.receive({
        'type': 'command',
        'action': 'select',
        'facilityId': 'check-in-1',
      });
      await tester.pump();
      expect(find.text('Selected · Check-in desks'), findsOneWidget);
      await tester.tap(find.text('Move'));
      await tester.pump();
      expect(bridge.messages.value?['rotation'], 0);
      for (var turn = 1; turn <= 4; turn++) {
        await tester.tap(find.byTooltip('Rotate 90°'));
        await tester.pump();
        expect(bridge.messages.value?['rotation'], turn % 4);
      }
      bridge.receive({
        'id': 'move-1',
        'type': 'command',
        'action': 'move',
        'facilityId': 'check-in-1',
        'kind': 'checkIn',
        'x': 5,
        'y': 10,
        'rotation': 0,
      });
      await tester.pump();
      expect(repo.commands, ['move']);
      expect(repo.commandArgs.single['rotation'], 0);
      expect(find.byTooltip('Rotate 90°'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(375, 812), const Size(812, 375)]) {
    testWidgets(
      'construction toolbar stays inside ${size.width} × ${size.height} and reveals the scene',
      (tester) async {
        await mount(tester, size);
        await tester.tap(find.text('Build'));
        await tester.pump();
        await tester.ensureVisible(find.text('Check-in desks'));
        await tester.tap(find.text('Check-in desks'));
        await tester.pump();
        expect(find.byTooltip('Close panel'), findsNothing);
        expect(find.textContaining('Place Check-in desks ·'), findsOneWidget);
        final rotate = tester.getRect(find.byTooltip('Rotate 90°'));
        final cancel = tester.getRect(find.byTooltip('Cancel construction'));
        expect(rotate.left, greaterThanOrEqualTo(0));
        expect(cancel.right, lessThanOrEqualTo(size.width));
        await tester.tap(find.byTooltip('Rotate 90°'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('active contracts show percentage and total cancellation cost', (
    tester,
  ) async {
    final repo = await mount(tester, const Size(1200, 850));
    await tester.tap(find.text('Contracts'));
    await tester.pump();
    await tester.ensureVisible(find.text('Current Air'));
    expect(find.text('Cancelled Air'), findsNothing);
    expect(find.text('Expired Air'), findsNothing);
    expect(find.textContaining('Satisfaction 87%'), findsOneWidget);
    expect(find.textContaining('Cancel remaining flights:'), findsOneWidget);
    final cancel = find.byTooltip(RegExp(r'Cancel contract · .*12'));
    expect(cancel, findsOneWidget);
    await tester.tap(cancel);
    expect(repo.commands.last, 'cancelContract');
    expect(repo.commandArgs.last['contractId'], 'active');
  });
}
