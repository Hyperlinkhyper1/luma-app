import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/pet/luma_pet_panel.dart';
import 'package:luma/pet/pet_repository.dart';
import 'package:luma/pet/pet_scope.dart';
import 'package:luma/pet/pet_search.dart';
import 'package:luma/pet/pet_window_app.dart';
import 'package:luma/pet/pet_window_protocol.dart';
import 'package:luma/theme/luma_theme.dart';

void main() {
  const channel = MethodChannel('mixin.one/desktop_multi_window/channels');
  late Map<String, dynamic> state;
  late List<String> actions;

  setUp(() {
    state = {
      'intervalMs': 100,
      'button': 'left',
      'doubleClick': false,
      'clickAtCursor': true,
      'repeatMode': 'untilStopped',
      'repeatCount': 100,
      'isRunning': false,
      'clicksDone': 0,
      'hotKey': 'Ctrl + Shift + F6',
    };
    actions = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'invokeMethod');
          final args = call.arguments as Map;
          expect(args['channel'], petMainChannel.name);
          expect(args['method'], petMethodAutoClicker);
          final command = args['arguments'] as Map;
          final action = command['action'] as String;
          actions.add(action);
          if (action == 'toggle') {
            state = {...state, 'isRunning': state['isRunning'] != true};
          }
          return state;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> openAutoClicker(
    WidgetTester tester, {
    bool fullBleed = true,
  }) async {
    tester.view.physicalSize = fullBleed ? kPetPanelSize : const Size(800, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final pet = PetRepository();
    await tester.pumpWidget(
      PetScope(
        repository: pet,
        child: MaterialApp(
          theme: LumaTheme.dark,
          locale: const Locale('en'),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Scaffold(
                body: LumaPetPanel(
                  fullBleed: fullBleed,
                  targets: [
                    PetTarget(
                      id: 'plugin:auto-clicker',
                      label: 'Auto Clicker',
                      icon: Icons.ads_click_rounded,
                      kind: PetTargetKind.plugin,
                      open: () => fail('Auto Clicker must stay inside the pet'),
                      compactBuilder: (_, back) => PetAutoClickerPanel(
                        initialState: state,
                        onBack: back,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Auto Clicker'));
    await tester.pump();
  }

  for (final fullBleed in [true, false]) {
    testWidgets(
      'opens a running auto clicker in the ${fullBleed ? 'window' : 'overlay'}',
      (tester) async {
        state = {...state, 'isRunning': true, 'clicksDone': 42};
        await openAutoClicker(tester, fullBleed: fullBleed);

        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
        expect(find.text('42 CLICKS'), findsOneWidget);
        expect(find.text('Stop clicking'), findsOneWidget);

        await tester.tap(find.byTooltip('Back to pet'));
        await tester.pump();
        expect(find.byType(PetAutoClickerPanel), findsNothing);
        expect(find.text('Auto Clicker'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('start and stop keep the controls visible', (tester) async {
    await openAutoClicker(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('READY · Ctrl + Shift + F6'), findsOneWidget);

    await tester.tap(find.text('Start clicking'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.text('0 CLICKS'), findsOneWidget);
    expect(find.text('Stop clicking'), findsOneWidget);

    await tester.tap(find.text('Stop clicking'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Start clicking'), findsOneWidget);
    expect(actions, ['toggle', 'toggle']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('live snapshots update a numeric click count', (tester) async {
    await openAutoClicker(tester);
    state = {...state, 'isRunning': true, 'clicksDone': 7};
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.text('7 CLICKS'), findsOneWidget);
    state = {...state, 'clicksDone': 23};
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('23 CLICKS'), findsOneWidget);
    expect(actions, ['snapshot', 'snapshot']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a running snapshot without a count displays zero', (
    tester,
  ) async {
    state = {...state, 'isRunning': true}..remove('clicksDone');
    await openAutoClicker(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('0 CLICKS'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
