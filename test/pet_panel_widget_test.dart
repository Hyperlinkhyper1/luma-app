import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/pet/luma_pet_panel.dart';
import 'package:luma/pet/pet_repository.dart';
import 'package:luma/pet/pet_scope.dart';
import 'package:luma/pet/pet_search.dart';
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
}
