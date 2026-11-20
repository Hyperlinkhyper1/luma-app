import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/notes/notes_page.dart';
import 'package:luma/features/notes/notes_repository.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';

Widget _app(Size size) => MediaQuery(
  data: MediaQueryData(size: size),
  child: MaterialApp(
    theme: LumaTheme.dark,
    localizationsDelegates: L.localizationsDelegates,
    supportedLocales: L.supportedLocales,
    home: const Scaffold(body: NotesPage()),
  ),
);

void main() {
  setUp(() async {
    await NotesRepository.instance.importData(<Object?>[]);
  });

  testWidgets('composer creates a card on close', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const Size(1280, 800)));

    expect(find.text('Notes you add appear here'), findsOneWidget);

    await tester.tap(find.text('Take a note…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Groceries');
    await tester.enterText(find.byType(TextField).at(1), '[ ] milk\n[x] eggs');
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(NotesRepository.instance.notes, hasLength(1));
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('milk'), findsOneWidget);
    expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);
  });

  testWidgets('many notes lay out without overflow at phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(380, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(
      () => NotesRepository.instance.importData([
        for (var i = 0; i < 12; i++)
          Note(
            id: '$i',
            title: i.isEven ? 'Note $i' : '',
            content: List.filled(i + 1, 'line $i').join('\n'),
            updatedAt: DateTime(2026, 1, i + 1),
          ).toJson(),
      ]),
    );
    await tester.pumpWidget(_app(const Size(380, 800)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Note 10'), findsOneWidget);

    await tester.tap(find.text('Note 10'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
  });
}
