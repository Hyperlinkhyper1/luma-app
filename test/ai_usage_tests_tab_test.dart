import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/ai_usage_shell.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/hero_tile.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/pagoda_test_page.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/tests_tab.dart';
import 'package:luma/theme/luma_theme.dart';

Widget _app() => MaterialApp(
      theme: LumaTheme.dark,
      home: const Scaffold(body: TestsTab()),
    );

void main() {
  // The shell drives its IndexedStack off the enum's index, so a section added
  // anywhere but the end silently shows the wrong tab. Pin both.
  test('Tests is the last rail section', () {
    expect(AiUsageSection.values.length, 4);
    expect(AiUsageSection.tests.index, 3);
    expect(AiUsageSection.tests.label, 'Tests');
  });

  testWidgets('the tile names itself in the purple band', (tester) async {
    await tester.pumpWidget(_app());

    expect(find.text('Pagoda Test'), findsOneWidget);
    expect(find.text('Open the test screen'), findsOneWidget);
  });

  testWidgets('the whole tile is one button that opens the test screen',
      (tester) async {
    await tester.pumpWidget(_app());

    expect(find.byType(PagodaTestPage), findsNothing);
    await tester.tap(find.byType(LumaHeroTile));
    await tester.pumpAndSettle();

    expect(find.byType(PagodaTestPage), findsOneWidget);
  });

  // The artwork is dropped into assets/tests/ by hand and is not in the test
  // bundle, so this exercises the missing-image path: the tile must still draw
  // its wash and its label rather than throwing.
  testWidgets('a tile with no artwork yet still renders', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.temple_buddhist_rounded), findsOneWidget);
    expect(find.text('Pagoda Test'), findsOneWidget);
  });

  test('the wash goes opaque exactly at the bottom third', () {
    expect(HeroTileWash.solidStart, closeTo(2 / 3, 1e-9));

    final stops = HeroTileWash.gradient.stops!;
    final colors = HeroTileWash.gradient.colors;
    expect(stops.length, colors.length);

    // Transparent above the ramp, fully opaque from the bottom third down.
    expect(colors.first.a, 0);
    final solidIndex = stops.indexOf(HeroTileWash.solidStart);
    expect(solidIndex, isNonNegative);
    for (var i = solidIndex; i < colors.length; i++) {
      expect(colors[i].a, 1);
    }

    // The ramp only ever gets more opaque on the way down.
    for (var i = 1; i < colors.length; i++) {
      expect(stops[i], greaterThan(stops[i - 1]));
      expect(colors[i].a, greaterThanOrEqualTo(colors[i - 1].a));
    }
  });
}
