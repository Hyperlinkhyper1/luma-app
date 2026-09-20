import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_scope.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/model_banner.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/pagoda_test_page.dart';
import 'package:luma/theme/luma_theme.dart';

AiBenchmark _benchmark(String id, String model) => AiBenchmark(
      id: id,
      kind: 'pagoda',
      model: model,
      description: 'A benchmark scene',
      sizeBytes: 10,
      sha256: 'x',
      hasPreview: false,
    );

void main() {
  group('pagodaVendorKey', () {
    test('Fable is Anthropic', () {
      expect(pagodaVendorKey('Fable 5.1 (Low)'), 'anthropic');
      expect(pagodaVendorKey('Fable 5 (Medium)'), 'anthropic');
      expect(pagodaVendorKey('FABLE 5.1 (HIGH)'), 'anthropic');
    });

    test('Mimo matches regardless of capitalisation', () {
      expect(pagodaVendorKey('MiMo V2.5'), 'xiaomi');
      expect(pagodaVendorKey('Mimo v2.5 Pro'), 'xiaomi');
    });

    test('Seed is ByteDance', () {
      expect(pagodaVendorKey('Seed 2.1 Pro'), 'seed');
    });

    test('unknown models get the fallback cube', () {
      expect(pagodaVendorKey('hy4'), isNull);
    });
  });

  group('pagodaVendorName', () {
    test('never echoes the model name for a known vendor', () {
      expect(pagodaVendorName('Fable 5.1 (Low)'), 'Anthropic');
      expect(pagodaVendorName('Fable 5.1 (High)'), 'Anthropic');
      expect(pagodaVendorName('Mimo v2.5 Pro'), 'Xiaomi');
      expect(pagodaVendorName('Seed 2.1 Pro'), 'ByteDance');
    });
  });

  group('ModelBannerGrid', () {
    Widget app(List<AiBenchmark> models, {void Function(AiBenchmark)? onPick}) {
      return AiBenchmarkScope(
        repository: AiBenchmarkRepository.withManifest(
          AiBenchmarkManifest(
            benchmarks: models,
            fallbackPreviews: const {},
            refreshedAt: null,
          ),
        ),
        child: MaterialApp(
          theme: LumaTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ModelBannerGrid(
                models: models,
                fallbackIcon: Icons.temple_buddhist_rounded,
                onPick: onPick ?? (_) {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('missing artwork renders the branded placeholder',
        (tester) async {
      await tester.pumpWidget(app([
        _benchmark('pagoda_fable51_low', 'Fable 5.1 (Low)'),
        _benchmark('pagoda_seed21_pro', 'Seed 2.1 Pro'),
        _benchmark('pagoda_hy4', 'hy4'),
      ]));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Fable 5.1 (Low)'), findsOneWidget);
      expect(find.text('by Anthropic'), findsOneWidget);
      expect(find.text('by ByteDance'), findsOneWidget);
      expect(
        find.byIcon(Icons.temple_buddhist_rounded),
        findsNWidgets(3),
      );
    });

    testWidgets('tapping a banner picks that model', (tester) async {
      AiBenchmark? picked;
      await tester.pumpWidget(app(
        [_benchmark('pagoda_fable51_low', 'Fable 5.1 (Low)')],
        onPick: (b) => picked = b,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fable 5.1 (Low)'));
      await tester.pumpAndSettle();
      expect(picked?.id, 'pagoda_fable51_low');
    });

    testWidgets('uses four banner columns on wide desktop layouts',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(app([
        _benchmark('model_1', 'Model 1'),
        _benchmark('model_2', 'Model 2'),
        _benchmark('model_3', 'Model 3'),
        _benchmark('model_4', 'Model 4'),
      ]));
      await tester.pumpAndSettle();

      final banners = find.byType(ModelBanner);
      expect(banners, findsNWidgets(4));
      expect(
        {
          for (var i = 0; i < 4; i++) tester.getTopLeft(banners.at(i)).dx,
        },
        hasLength(4),
      );
    });
  });
}
