import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/converter/tools/file_corruptor_view.dart';
import 'package:luma/features/converter/tools/file_fixer_view.dart';
import 'package:luma/features/converter/tools/other_tools_view.dart';
import 'package:luma/theme/luma_theme.dart';

Widget _app(Widget child) =>
    MaterialApp(theme: LumaTheme.dark, home: Scaffold(body: child));

void main() {
  testWidgets('the Other hub offers the corruptor and the fixer', (
    tester,
  ) async {
    await tester.pumpWidget(_app(OtherToolsView(onBack: () {})));
    await tester.pump();

    expect(find.text('File corruptor'), findsOneWidget);
    expect(find.text('File fixer'), findsOneWidget);
    expect(find.text('Minecraft schematics'), findsOneWidget);
  });

  testWidgets('tapping the corruptor tile opens its screen', (tester) async {
    await tester.pumpWidget(_app(OtherToolsView(onBack: () {})));
    await tester.pump();

    await tester.tap(find.text('File corruptor'));
    await tester.pumpAndSettle();

    expect(
      find.text('Break a file on purpose, and keep the key to unbreak it'),
      findsOneWidget,
    );
    expect(find.text('Click to choose a file'), findsOneWidget);
  });

  testWidgets('tapping the fixer tile opens its screen', (tester) async {
    await tester.pumpWidget(_app(OtherToolsView(onBack: () {})));
    await tester.pump();

    await tester.tap(find.text('File fixer'));
    await tester.pumpAndSettle();

    expect(find.text('Click to choose the damaged file'), findsOneWidget);
  });

  testWidgets('the corruptor starts with no file chosen', (tester) async {
    await tester.pumpWidget(_app(FileCorruptorView(onBack: () {})));
    await tester.pump();

    // The damage options only appear once there is something to damage.
    expect(find.text('Corrupt file'), findsNothing);
    expect(find.text('Click to choose a file'), findsOneWidget);
  });

  testWidgets('the fixer starts with no file chosen', (tester) async {
    await tester.pumpWidget(_app(FileFixerView(onBack: () {})));
    await tester.pump();

    expect(find.text('Analyse & repair'), findsNothing);
    expect(find.text('Click to choose the damaged file'), findsOneWidget);
  });

  testWidgets('both screens fit a phone without overflowing', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    for (final screen in <Widget>[
      FileCorruptorView(onBack: () {}),
      FileFixerView(onBack: () {}),
      OtherToolsView(onBack: () {}),
    ]) {
      await tester.pumpWidget(_app(screen));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
