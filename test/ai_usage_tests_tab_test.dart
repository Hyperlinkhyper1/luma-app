import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/ai_usage_shell.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_scope.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/hero_tile.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/pagoda_test_page.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/tests_tab.dart';
import 'package:luma/theme/luma_theme.dart';

/// Benchmark tile art downloads from the luma server now — nothing ships in
/// the bundle — so the tab starts with no roster and both tiles render their
/// gradient stand-in.
///
/// The scope sits above [MaterialApp] (as in `main.dart`) so pages pushed by
/// the tiles still see the repository.
Widget _app({AiBenchmarkManifest manifest = AiBenchmarkManifest.empty}) =>
    AiBenchmarkScope(
      repository: AiBenchmarkRepository.withManifest(manifest),
      child: MaterialApp(
        theme: LumaTheme.dark,
        home: const Scaffold(body: TestsTab()),
      ),
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
    expect(find.text('Engine Test'), findsOneWidget);
    expect(find.text('PC Test'), findsOneWidget);
    // All three tiles currently share the same subtitle.
    expect(find.text('Open the test screen'), findsNWidgets(3));
  });

  testWidgets('the whole tile is one button that opens the test screen',
      (tester) async {
    await tester.pumpWidget(_app());

    expect(find.byType(PagodaTestPage), findsNothing);
    await tester.tap(find.widgetWithText(LumaHeroTile, 'Pagoda Test'));
    await tester.pumpAndSettle();

    expect(find.byType(PagodaTestPage), findsOneWidget);
  });

  // With no roster the tiles show their gradient stand-in rather than
  // throwing: the tab must look deliberate with no account at all.
  testWidgets('tiles with no downloaded artwork yet still render',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.precision_manufacturing_rounded), findsOneWidget);
    expect(find.byIcon(Icons.temple_buddhist_rounded), findsOneWidget);
    expect(find.byIcon(Icons.computer_rounded), findsOneWidget);
    expect(find.text('Pagoda Test'), findsOneWidget);
    expect(find.text('Engine Test'), findsOneWidget);
    expect(find.text('PC Test'), findsOneWidget);
  });

  testWidgets('a test page with no roster explains itself', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.widgetWithText(LumaHeroTile, 'Pagoda Test'));
    await tester.pumpAndSettle();

    expect(find.text('No benchmarks yet'), findsOneWidget);
    expect(find.textContaining('approved account'), findsOneWidget);
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
