import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/pet/luma_pet_panel.dart';
import 'package:luma/pet/pet_repository.dart';
import 'package:luma/pet/pet_scope.dart';
import 'package:luma/pet/pet_search.dart';
import 'package:luma/pet/pet_settings_section.dart';
import 'package:luma/pet/pet_sprite.dart';
import 'package:luma/theme/luma_theme.dart';

/// The panel under a real theme and the app's localizations, with animations
/// switched off — the pet bobs and blinks on a repeating timer, which would
/// otherwise still be pending when the test ends.
Widget _app(PetRepository pet, List<PetTarget> targets) => PetScope(
      repository: pet,
      child: MaterialApp(
        theme: LumaTheme.dark,
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: L.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Scaffold(
              body: LumaPetPanel(targets: targets, fullBleed: true),
            ),
          ),
        ),
      ),
    );

void main() {
  late List<String> opened;

  PetTarget target(String label, String id) => PetTarget(
        id: id,
        label: label,
        icon: Icons.circle,
        kind: PetTargetKind.plugin,
        open: () => opened.add(id),
      );

  late List<PetTarget> targets;

  setUp(() {
    opened = [];
    targets = [
      target('Finance', 'finance'),
      target('Mind Map', 'mind-map'),
      target('Whiteboard', 'whiteboard'),
    ];
  });

  testWidgets('lists everything it can open before anything is typed',
      (tester) async {
    await tester.pumpWidget(_app(PetRepository(), targets));
    await tester.pump();

    expect(find.text('Finance'), findsOneWidget);
    expect(find.text('Mind Map'), findsOneWidget);
    expect(find.text('Whiteboard'), findsOneWidget);
  });

  testWidgets('typing filters the list down', (tester) async {
    await tester.pumpWidget(_app(PetRepository(), targets));
    await tester.enterText(find.byType(TextField), 'mind');
    await tester.pump();

    expect(find.text('Mind Map'), findsOneWidget);
    expect(find.text('Finance'), findsNothing);
    expect(find.text('Whiteboard'), findsNothing);
  });

  testWidgets('says so when nothing matches', (tester) async {
    await tester.pumpWidget(_app(PetRepository(), targets));
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump();

    expect(find.text('Nothing by that name'), findsOneWidget);
  });

  testWidgets('arrow keys move the selection and Enter opens it',
      (tester) async {
    final pet = PetRepository();
    await tester.pumpWidget(_app(pet, targets));
    await pet.open();
    await tester.pump();

    // Starts on the first row; one step down lands on the second.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(opened, ['mind-map']);
    // Picking something dismisses the pet, and it is remembered for next time.
    expect(pet.visible, isFalse);
    expect(pet.recentIds, ['mind-map']);

    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the selection wraps around the ends', (tester) async {
    await tester.pumpWidget(_app(PetRepository(), targets));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(opened, ['whiteboard']);
  });

  testWidgets('Escape dismisses without opening anything', (tester) async {
    final pet = PetRepository();
    await tester.pumpWidget(_app(pet, targets));
    await pet.open();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(pet.visible, isFalse);
    expect(opened, isEmpty);

    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('tapping the pet pats it', (tester) async {
    final pet = PetRepository();
    await tester.pumpWidget(_app(pet, targets));
    await tester.pump();

    expect(pet.pats, 0);
    await tester.tap(find.byType(PetSprite));
    await tester.pump();

    expect(pet.pats, 1);
    expect(pet.mood, PetMood.happy);
    expect(find.text('That tickles.'), findsOneWidget);
  });

  testWidgets('recently opened targets come first next time', (tester) async {
    final pet = PetRepository();
    await pet.recordOpen('whiteboard');
    await tester.pumpWidget(_app(pet, targets));
    await tester.pump();

    final labels = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Text),
        ))
        .map((t) => t.data)
        .toList();
    expect(labels.first, 'Whiteboard');
  });

  testWidgets('lays out in a pet-sized window with no Scaffold above it',
      (tester) async {
    // The exact shape the shell builds while the pet has the window shrunk,
    // and two ways it went black. The panel is layered over an *offstage*
    // shell, so the app's own Scaffold is a sibling rather than an ancestor:
    // without a Material of its own the text field fails to build and its
    // error widget blows the card open by ~100,000 pixels. And an offstage
    // child reports the smallest size it is allowed, so under the loose
    // constraints the boot gate hands down, a loosely-fitted stack collapses
    // to 0x0 and lays the panel out into nothing at all.
    tester.view.physicalSize = const Size(480, 556);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(PetScope(
      repository: PetRepository(),
      child: MaterialApp(
        theme: LumaTheme.dark,
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        // The outer stack is the boot gate's, which holds the splash over
        // the shell. It hands its children *loose* constraints, which is what
        // makes the inner stack's fit load-bearing.
        home: Stack(
          children: [
            Stack(
              fit: StackFit.expand,
              children: [
                const Offstage(offstage: true, child: Scaffold()),
                Positioned.fill(
                  child: LumaPetPanel(targets: targets, fullBleed: true),
                ),
              ],
            ),
          ],
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(LumaPetPanel)), const Size(480, 556));
    expect(find.text('Finance'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
  });

  group('the Settings card', () {
    Widget settingsCard(PetRepository pet) => PetScope(
          repository: pet,
          child: MaterialApp(
            theme: LumaTheme.dark,
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: const Scaffold(
              body: SingleChildScrollView(child: PetSettingsSection()),
            ),
          ),
        );

    testWidgets('its button opens the pet with no hotkey involved',
        (tester) async {
      final pet = PetRepository();
      await pet.setEnabled(false);
      await tester.pumpWidget(settingsCard(pet));
      await tester.pump();

      expect(pet.visible, isFalse);
      await tester.tap(find.text('Open the pet now'));
      await tester.pump();

      expect(pet.visible, isTrue);
      expect(pet.enabled, isFalse);

      // Let the blur-dismissal arming timer expire.
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
