import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_scope.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/wiki_search_test_page.dart';
import 'package:luma/theme/luma_theme.dart';

void main() {
  testWidgets('compares scores and explains each model including ties', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository =
        AiBenchmarkRepository.withManifest(AiBenchmarkManifest.empty)
          ..wikiSearch = {
            'cases': 48,
            'models': [
              {'model': 'vendor/second', 'score': 70.0},
              {'model': 'vendor/first', 'score': 80.0},
              {'model': 'vendor/tied', 'score': 80.0},
            ],
          };
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      AiBenchmarkScope(
        repository: repository,
        child: MaterialApp(
          theme: LumaTheme.dark,
          home: const WikiSearchTestPage(),
        ),
      ),
    );

    expect(find.text('Embedding model comparison'), findsOneWidget);
    expect(find.text('Cost vs performance'), findsOneWidget);
    expect(find.text('Retrieval score · 48 queries'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
    expect(find.text('Model conclusions'), findsOneWidget);
    expect(
      find.text('Scored 80.0%, tied for the highest score on this test.'),
      findsNWidgets(2),
    );
    expect(
      find.text(
        'Scored 70.0%, 10.0 percentage points behind vendor/first on this test.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('one model has a conclusion without inventing a comparison', (
    tester,
  ) async {
    final repository =
        AiBenchmarkRepository.withManifest(AiBenchmarkManifest.empty)
          ..wikiSearch = {
            'cases': 48,
            'models': [
              {'model': 'vendor/only', 'score': 75.0},
            ],
          };
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      AiBenchmarkScope(
        repository: repository,
        child: MaterialApp(
          theme: LumaTheme.dark,
          home: const WikiSearchTestPage(),
        ),
      ),
    );
    expect(
      find.text('Scored 75.0% on this test. Run more models to compare.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('comparison fits a narrow phone with long model IDs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository =
        AiBenchmarkRepository.withManifest(AiBenchmarkManifest.empty)
          ..wikiSearch = {
            'cases': 48,
            'models': [
              {'model': 'nvidia/nemotron-3.5-embed-8b:free', 'score': 80.0},
              {'model': 'amazon/titan-embed-text-v2', 'score': 70.0},
            ],
          };
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      AiBenchmarkScope(
        repository: repository,
        child: MaterialApp(
          theme: LumaTheme.dark,
          home: const WikiSearchTestPage(),
        ),
      ),
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('10.0 percentage points behind'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
