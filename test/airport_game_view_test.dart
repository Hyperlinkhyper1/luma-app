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
  Future<(_AirportUiRepository, AirportSceneBridge Function())> mount(
    WidgetTester tester,
    Size size,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _AirportUiRepository();
    addTearDown(repo.dispose);
    late AirportSceneBridge bridge;
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: Scaffold(
          body: AirportGameView(
            repository: repo,
            sceneBuilder: (_, value) {
              bridge = value;
              return ColoredBox(
                color: Colors.teal,
                child: Center(
                  child: Text(
                    value.visible ? 'Airport scene' : 'Airport hidden',
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    return (repo, () => bridge);
  }

  Map<String, Object?> command(
    String action, [
    Map<String, Object?> args = const {},
  ]) => {'type': 'command', 'id': 'hud-$action', 'action': action, ...args};

  testWidgets(
    'page commands reach the repository and its refusal goes back to the page',
    (tester) async {
      final (repo, bridge) = await mount(tester, const Size(1200, 850));
      expect(find.text('Airport scene'), findsOneWidget);
      bridge().receive(command('acceptContract', {'offerId': 'regional'}));
      expect(repo.commands, ['acceptContract']);
      expect(repo.commandArgs.single['offerId'], 'regional');
      expect(bridge().messages.value, {
        'type': 'result',
        'id': 'hud-acceptContract',
        'ok': false,
        'message': 'Connect the stand to a service road first.',
      });
      bridge().receive(command('resume'));
      expect(repo.paused, isFalse);
      expect(bridge().messages.value?['ok'], isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('commands outside the allowlist never reach the repository', (
    tester,
  ) async {
    final (repo, bridge) = await mount(tester, const Size(1200, 850));
    for (final action in ['startGame', 'importData', 'select', '']) {
      bridge().receive(command(action));
      expect(bridge().messages.value?['ok'], isFalse, reason: action);
    }
    bridge().receive({'type': 'view', 'action': 'resume'});
    bridge().receive({'action': 'resume'});
    expect(repo.commands, isEmpty);
    expect(repo.paused, isTrue);
  });

  testWidgets('timetable commands reach the repository', (tester) async {
    final (repo, bridge) = await mount(tester, const Size(1200, 850));
    for (final action in ['placeContract', 'moveFlight', 'unscheduleFlight']) {
      bridge().receive(command(action, {'flightId': 'f1', 'arrival': 600}));
    }
    expect(repo.commands, ['placeContract', 'moveFlight', 'unscheduleFlight']);
    expect(repo.commandArgs[1]['arrival'], 600);
  });

  testWidgets('move keeps its rotation on the way to the repository', (
    tester,
  ) async {
    final (repo, bridge) = await mount(tester, const Size(1200, 850));
    bridge().receive(
      command('move', {
        'facilityId': 'check-in-1',
        'kind': 'checkIn',
        'x': 5,
        'y': 10,
        'rotation': 3,
      }),
    );
    expect(repo.commands, ['move']);
    expect(repo.commandArgs.single['rotation'], 3);
    expect(repo.commandArgs.single['facilityId'], 'check-in-1');
  });

  testWidgets('snapshot carries aircraft names for the page', (tester) async {
    final (_, bridge) = await mount(tester, const Size(1200, 850));
    final world = bridge().snapshot();
    expect(world['cash'], 100000);
    final names = world['modelNames'] as Map;
    expect(names, isNotEmpty);
    expect(names.values, everyElement(isA<String>()));
  });

  for (final size in const [Size(1200, 850), Size(390, 844), Size(812, 375)]) {
    testWidgets(
      'Fleet opens as a full page over a hidden scene at ${size.width} × ${size.height}',
      (tester) async {
        final (repo, bridge) = await mount(tester, size);
        bridge().receive(command('openPage', {'page': 'Fleet'}));
        await tester.pump();
        expect(bridge().messages.value?['ok'], isTrue);
        expect(bridge().visible, isFalse);
        expect(find.text('Airport hidden'), findsOneWidget);
        expect(find.text('Back to airport'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Back to airport'));
        await tester.pump();
        expect(bridge().visible, isTrue);
        expect(find.text('Airport scene'), findsOneWidget);
        expect(repo.commands, isEmpty);
      },
    );
  }

  testWidgets('unknown pages are refused', (tester) async {
    final (_, bridge) = await mount(tester, const Size(1200, 850));
    bridge().receive(command('openPage', {'page': 'Settings'}));
    await tester.pump();
    expect(bridge().messages.value?['ok'], isFalse);
    expect(bridge().visible, isTrue);
  });
}
