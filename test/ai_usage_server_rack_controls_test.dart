import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_scope.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/model_banner.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/server_rack_test_page.dart';
import 'package:luma/theme/luma_theme.dart';

void main() {
  testWidgets('rack search filters uploaded and bundled models in both views', (
    tester,
  ) async {
    final repository = AiBenchmarkRepository.withManifest(
      const AiBenchmarkManifest(
        benchmarks: [
          AiBenchmark(
            id: 'server_rack_test_uploaded',
            kind: 'server_rack',
            model: 'Uploaded Rack Model',
            vendor: 'openai',
            description: 'Uploaded rack',
            sizeBytes: 0,
            sha256: '',
          ),
        ],
        fallbackPreviews: {},
        refreshedAt: null,
      ),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      AiBenchmarkScope(
        repository: repository,
        child: MaterialApp(
          theme: LumaTheme.dark,
          home: const ServerRackTestPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    expect(find.text('Uploaded Rack Model'), findsOneWidget);
    expect(find.text('Opus 5.5 (Low)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  UPLOADED  ');
    await tester.pumpAndSettle();
    expect(find.text('Uploaded Rack Model'), findsOneWidget);
    expect(find.text('Opus 5.5 (Low)'), findsNothing);
    await tester.tap(find.text('Banners'));
    await tester.pumpAndSettle();
    expect(find.byType(ModelBanner), findsOneWidget);
    expect(
      tester.widget<ModelBanner>(find.byType(ModelBanner)).benchmark.id,
      'server_rack_test_uploaded',
    );
    await tester.enterText(find.byType(TextField), 'Opus 5.5 (Low)');
    await tester.pumpAndSettle();
    expect(find.byType(ModelBanner), findsOneWidget);
    expect(
      tester.widget<ModelBanner>(find.byType(ModelBanner)).benchmark.model,
      'Opus 5.5 (Low)',
    );
    await tester.enterText(find.byType(TextField), 'no-such-model');
    await tester.pumpAndSettle();
    expect(find.byType(ModelBanner), findsNothing);
    expect(find.text('No models match "no-such-model"'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Sonnet 5.5 (Low)');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ModelBanner));
    await tester.pump();
    expect(find.text('Sonnet 5.5 (Low)'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
