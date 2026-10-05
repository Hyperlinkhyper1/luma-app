import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_scope.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/hero_tile.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/scene_test_page.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/test_view_prefs.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/tests_tab.dart';
import 'package:luma/theme/luma_theme.dart';

Widget _app(AiBenchmarkRepository repository) => AiBenchmarkScope(
  repository: repository,
  child: MaterialApp(
    theme: LumaTheme.dark,
    home: const Scaffold(body: TestsTab()),
  ),
);

void main() {
  test('every scene test is a kind the server knows and has a prompt for', () {
    final store = File('server/lib/ai_benchmark_store.dart').readAsStringSync();
    final prompts = File(
      'server/lib/benchmark_prompts.dart',
    ).readAsStringSync();
    for (final test in kSceneTests) {
      expect(store, contains("'${test.kind}',"), reason: test.kind);
      expect(
        RegExp("'${test.kind}':\\s*\\(\\s*label:").hasMatch(prompts),
        isTrue,
        reason: test.kind,
      );
      expect(
        File('server/benchmarks/prompts/${test.kind}.md').existsSync(),
        isTrue,
        reason: test.kind,
      );
    }
    expect({
      for (final t in kSceneTests) t.kind,
    }, hasLength(kSceneTests.length));
  });

  testWidgets('each scene tile opens its own test with only its entries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final test in kSceneTests) {
      await tester.runAsync(
        () => TestViewPrefs.saveBannerView(test.kind, false),
      );
    }
    final repository = AiBenchmarkRepository.withManifest(
      AiBenchmarkManifest.fromJson({
        'benchmarks': [
          for (final test in kSceneTests)
            {
              'id': '${test.kind}_demo',
              'kind': test.kind,
              'model': 'Demo ${test.kind}',
              'vendor': 'anthropic',
            },
        ],
      }),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    for (final test in kSceneTests) {
      final tile = find.widgetWithText(LumaHeroTile, test.title);
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(find.byType(SceneTestPage), findsOneWidget);
      expect(find.text(test.blurb), findsOneWidget);
      expect(find.text('Demo ${test.kind}'), findsOneWidget);
      for (final other in kSceneTests.where((t) => t != test)) {
        expect(find.text('Demo ${other.kind}'), findsNothing);
      }
      expect(tester.takeException(), isNull);

      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('an empty scene test says so instead of a blank page', (
    tester,
  ) async {
    final repository = AiBenchmarkRepository.withManifest(
      AiBenchmarkManifest.empty,
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      AiBenchmarkScope(
        repository: repository,
        child: MaterialApp(
          theme: LumaTheme.dark,
          home: SceneTestPage(test: kSceneTests.first),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No entries yet'), findsOneWidget);
  });

  testWidgets('landing page tile opens its model list at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(
      () => TestViewPrefs.saveBannerView('website_landing_page', false),
    );
    final repository = AiBenchmarkRepository.withManifest(
      AiBenchmarkManifest.fromJson({
        'benchmarks': [
          {
            'id': 'website_landing_page_demo',
            'kind': 'website_landing_page',
            'model': 'Landing page demo',
          },
          {'id': 'sports_car_demo', 'kind': 'sports_car', 'model': 'Car demo'},
        ],
      }),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(_app(repository));
    final tile = find.widgetWithText(LumaHeroTile, 'Website landing page');
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(SceneTestPage), findsOneWidget);
    expect(find.text('Landing page demo'), findsOneWidget);
    expect(find.text('Car demo'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
