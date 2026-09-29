import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_scope.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/hero_tile.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/model_banner.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/pc_test_page.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/test_view_prefs.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/tests_tab.dart';
import 'package:luma/theme/luma_theme.dart';

class _LoadingRepository extends AiBenchmarkRepository {
  _LoadingRepository() : super.withManifest(AiBenchmarkManifest.empty);

  @override
  bool get loading => true;

  @override
  Future<void> load() async {}
}

Widget _app(AiBenchmarkRepository repository) => AiBenchmarkScope(
  repository: repository,
  child: MaterialApp(
    theme: LumaTheme.dark,
    home: const Scaffold(body: TestsTab()),
  ),
);

Future<void> _openPcTest(WidgetTester tester) async {
  final tile = find.widgetWithText(LumaHeroTile, 'PC Test');
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
  expect(find.byType(PcTestPage), findsOneWidget);
}

void main() {
  test(
    'GPT 6.1 Sol Xhigh PC scene is included in the Flutter asset bundle',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final scene = await rootBundle.loadString(
        'assets/ai_usage/pc_tests/gpt61_sol_xhigh/index.html',
      );
      expect(scene.toLowerCase(), contains('<!doctype html>'));
      expect(scene, contains('GPT 6.1 Sol (Xhigh)'));
    },
  );

  testWidgets('Tests opens a searchable GPT 6.1 Sol Xhigh PC entry offline', (
    tester,
  ) async {
    await tester.runAsync(() => TestViewPrefs.saveBannerView('pc', false));
    final repository = AiBenchmarkRepository.withManifest(
      AiBenchmarkManifest.empty,
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(_app(repository));
    await _openPcTest(tester);

    expect(find.text('GPT 6.1 Sol (Xhigh)'), findsOneWidget);
    expect(find.text('No entries yet'), findsNothing);
    expect(repository.canRefresh, isFalse);

    await tester.enterText(find.byType(TextField), 'gpt 6.1 sol');
    await tester.pumpAndSettle();
    expect(find.text('GPT 6.1 Sol (Xhigh)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'unrelated model');
    await tester.pumpAndSettle();
    expect(find.text('GPT 6.1 Sol (Xhigh)'), findsNothing);
    expect(find.text('No models match "unrelated model"'), findsOneWidget);
  });

  testWidgets('PC banners preserve other variants and deduplicate the new id', (
    tester,
  ) async {
    await tester.runAsync(() => TestViewPrefs.saveBannerView('pc', false));
    addTearDown(
      () => tester.runAsync(() => TestViewPrefs.saveBannerView('pc', false)),
    );
    final repository = AiBenchmarkRepository.withManifest(
      AiBenchmarkManifest.fromJson({
        'benchmarks': [
          {
            'id': 'pc_gpt61_sol_low',
            'kind': 'pc',
            'model': 'GPT 6.1 Sol (Low)',
            'description': 'Existing low effort scene',
          },
          {
            'id': 'pc_gpt56_sol_xhigh',
            'kind': 'pc',
            'model': 'GPT 5.6 Sol (XHigh)',
            'description': 'Existing GPT 5.6 scene',
          },
          {
            'id': 'pc_gpt61_sol_xhigh',
            'kind': 'pc',
            'model': 'GPT 6.1 Sol (Xhigh)',
            'description': 'Server entry for the bundled contestant',
          },
          {
            'id': 'engine_gpt61_sol_low',
            'kind': 'engine',
            'model': 'Engine contestant',
          },
        ],
      }),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(_app(repository));
    await _openPcTest(tester);

    expect(find.text('GPT 6.1 Sol (Xhigh)'), findsOneWidget);
    expect(find.text('GPT 6.1 Sol (Low)'), findsOneWidget);
    expect(find.text('GPT 5.6 Sol (XHigh)'), findsOneWidget);
    expect(find.text('Engine contestant'), findsNothing);

    await tester.tap(find.text('Banners'));
    await tester.pumpAndSettle();
    final banners = tester.widgetList<ModelBanner>(find.byType(ModelBanner));
    expect(banners, hasLength(3));
    final entry = banners.singleWhere(
      (banner) => banner.benchmark.id == 'pc_gpt61_sol_xhigh',
    );
    expect(entry.benchmark.kind, 'pc');
    expect(entry.benchmark.model, 'GPT 6.1 Sol (Xhigh)');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bundled PC stays listed during a roster load', (
    tester,
  ) async {
    await tester.runAsync(() => TestViewPrefs.saveBannerView('pc', false));
    final repository = _LoadingRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(_app(repository));
    await _openPcTest(tester);
    expect(find.text('GPT 6.1 Sol (Xhigh)'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
