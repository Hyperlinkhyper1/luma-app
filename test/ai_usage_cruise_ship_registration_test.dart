import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_scope.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/cruise_ship_test_page.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/hero_tile.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/model_banner.dart';
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

Future<void> _open(WidgetTester tester) async {
  final tile = find.widgetWithText(LumaHeroTile, 'Cruise Ship Test');
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
  expect(find.byType(CruiseShipTestPage), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'canonical cruise scene is bundled with its requested identity',
    () async {
      final scene = await rootBundle.loadString(cruiseShipAsset);
      expect(scene.toLowerCase(), contains('<!doctype html>'));
      expect(scene, contains('GPT 6 Astra (Ultra)'));
      expect(scene, contains('cruise-ready'));
      expect(scene, contains('cruise-error'));
    },
  );

  testWidgets('Tests opens a searchable cruise contestant without a server', (
    tester,
  ) async {
    await tester.runAsync(
      () => TestViewPrefs.saveBannerView('cruise_ship', false),
    );
    final repository = AiBenchmarkRepository.withManifest(
      AiBenchmarkManifest.empty,
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(_app(repository));
    await _open(tester);
    expect(find.text('GPT 6 Astra (Ultra)'), findsOneWidget);
    expect(repository.canRefresh, isFalse);
    await tester.enterText(find.byType(TextField), 'astra');
    await tester.pumpAndSettle();
    expect(find.text('GPT 6 Astra (Ultra)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'missing model');
    await tester.pumpAndSettle();
    expect(find.text('GPT 6 Astra (Ultra)'), findsNothing);
    expect(find.text('No models match "missing model"'), findsOneWidget);
  });

  testWidgets('server cruise entry replaces only its matching fallback', (
    tester,
  ) async {
    await tester.runAsync(
      () => TestViewPrefs.saveBannerView('cruise_ship', false),
    );
    addTearDown(
      () => tester.runAsync(
        () => TestViewPrefs.saveBannerView('cruise_ship', false),
      ),
    );
    final repository = AiBenchmarkRepository.withManifest(
      AiBenchmarkManifest.fromJson({
        'benchmarks': [
          {
            'id': 'cruise_ship_gpt6_astra_ultra',
            'kind': 'cruise_ship',
            'model': 'GPT 6 Astra (Ultra)',
            'vendor': 'openai',
            'description': 'Updated server cruise scene',
          },
          {
            'id': 'cruise_ship_opus55_ultracode',
            'kind': 'cruise_ship',
            'model': 'Opus 5.5 (Ultracode)',
            'description': 'Another independent contestant',
          },
          {
            'id': 'engine_other',
            'kind': 'engine',
            'model': 'Engine contestant',
          },
        ],
      }),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(_app(repository));
    await _open(tester);
    expect(find.text('GPT 6 Astra (Ultra)'), findsOneWidget);
    expect(find.text('Updated server cruise scene'), findsOneWidget);
    expect(find.text('Opus 5.5 (Ultracode)'), findsOneWidget);
    expect(find.text('Engine contestant'), findsNothing);
    await tester.tap(find.text('Banners'));
    await tester.pumpAndSettle();
    final banners = tester.widgetList<ModelBanner>(find.byType(ModelBanner));
    expect(banners, hasLength(2));
    expect(
      banners
          .singleWhere(
            (banner) => banner.benchmark.id == cruiseShipBenchmark.id,
          )
          .benchmark
          .vendor,
      'openai',
    );
  });

  testWidgets('cruise list and banners fit a 320px window', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(
      () => TestViewPrefs.saveBannerView('cruise_ship', false),
    );
    addTearDown(
      () => tester.runAsync(
        () => TestViewPrefs.saveBannerView('cruise_ship', false),
      ),
    );
    final repository = AiBenchmarkRepository.withManifest(
      AiBenchmarkManifest.empty,
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(_app(repository));
    await _open(tester);
    expect(find.text('GPT 6 Astra (Ultra)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Banners'));
    await tester.pumpAndSettle();
    expect(find.byType(ModelBanner), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
