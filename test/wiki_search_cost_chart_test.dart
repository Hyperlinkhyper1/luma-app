import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/wiki_search_cost_chart.dart';
import 'package:luma/theme/luma_theme.dart';

void main() {
  testWidgets('plots free and priced models, and identifies missing prices', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: WikiSearchCostChart(
              models: [
                {'model': 'vendor/free', 'score': 80.0, 'pricePerMillion': 0},
                {
                  'model': 'vendor/paid',
                  'score': 90.0,
                  'pricePerMillion': 0.25,
                },
                {'model': 'vendor/unknown', 'score': 70.0},
                {
                  'model': 'vendor/invalid',
                  'score': 60.0,
                  'pricePerMillion': -1,
                },
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Cost vs performance'), findsOneWidget);
    expect(find.text('Cost per 1M input tokens (USD)'), findsOneWidget);
    expect(find.text('Retrieval score'), findsOneWidget);
    expect(
      find.text('Price unavailable for 2 models; excluded from the graph.'),
      findsOneWidget,
    );
    final tooltips = tester.widgetList<Tooltip>(find.byType(Tooltip)).toList();
    expect(
      tooltips.where(
        (tooltip) => tooltip.message?.contains('vendor/free') ?? false,
      ),
      hasLength(1),
    );
    expect(
      tooltips.where(
        (tooltip) => tooltip.message?.contains('vendor/paid') ?? false,
      ),
      hasLength(1),
    );
    expect(
      tooltips.where(
        (tooltip) => tooltip.message?.contains('vendor/unknown') ?? false,
      ),
      isEmpty,
    );

    await tester.tap(find.text('Model prices and scores'));
    await tester.pumpAndSettle();
    expect(find.text('vendor/unknown'), findsOneWidget);
    expect(find.text('Price unavailable · 70.0%'), findsOneWidget);
    expect(find.textContaining(r'$0 / 1M'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explains when no prices can be plotted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: const Scaffold(
          body: WikiSearchCostChart(
            models: [
              {'model': 'vendor/unknown', 'score': 70.0},
            ],
          ),
        ),
      ),
    );
    expect(
      find.text('No model prices are available for this comparison.'),
      findsOneWidget,
    );
    expect(
      find.text('Price unavailable for 1 model; excluded from the graph.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('groups overlapping points and fits a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: WikiSearchCostChart(
              models: [
                {
                  'model': 'nvidia/nemotron-3.5-embed-8b:free',
                  'score': 80.0,
                  'pricePerMillion': 0,
                },
                {
                  'model': 'vendor/another-free-model',
                  'score': 80.0,
                  'pricePerMillion': 0,
                },
                {
                  'model': 'amazon/titan-embed-text-v2',
                  'score': 70.0,
                  'pricePerMillion': 0.12,
                },
              ],
            ),
          ),
        ),
      ),
    );
    final tooltips = tester.widgetList<Tooltip>(find.byType(Tooltip)).toList();
    final combined = tooltips.where(
      (tooltip) => tooltip.message?.contains('nvidia/nemotron') ?? false,
    );
    expect(combined, hasLength(1));
    expect(combined.single.message, contains('vendor/another-free-model'));
    await tester.tap(find.text('Model prices and scores'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
