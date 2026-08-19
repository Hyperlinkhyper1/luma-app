import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/ai_usage/leaderboard/ai_catalog_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/leaderboard/ai_catalog_scope.dart';
import 'package:luma/features/plugins/installed/ai_usage/leaderboard/ai_leaderboard_tab.dart';
import 'package:luma/features/plugins/installed/ai_usage/leaderboard/ai_model.dart';
import 'package:luma/features/plugins/installed/ai_usage/open_source/open_source_tab.dart';
import 'package:luma/theme/luma_theme.dart';
import 'package:luma/theme/theme_style.dart';

const _catalog = AiCatalog(
  models: [
    AiModel(
      id: 'anthropic/claude-opus-5',
      slug: 'claude-opus-5',
      name: 'Claude Opus 5',
      vendor: 'anthropic',
      vendorName: 'Anthropic',
      llmStatsIndex: 63.1,
      reasoningIndex: 71.4,
      codingIndex: 78.0,
      agentIndex: 59.2,
      codeArena: 1344,
      contextTokens: 1000000,
      inputPricePerM: 5,
      outputPricePerM: 25,
    ),
    AiModel(
      id: 'moonshotai/kimi-k3',
      slug: 'kimi-k3',
      name: 'Kimi K3',
      vendor: 'moonshotai',
      vendorName: 'Moonshot AI',
      llmStatsIndex: 59.7,
      codingIndex: 76.2,
      contextTokens: 1048576,
      inputPricePerM: 3,
      outputPricePerM: 15,
      openWeights: true,
      licenseName: 'Custom licence',
      parametersB: 1026,
    ),
    AiModel(
      id: 'qwen/qwen3-8b',
      slug: 'qwen3-8b',
      name: 'Qwen3 8B',
      vendor: 'qwen',
      vendorName: 'Qwen',
      contextTokens: 128000,
      openWeights: true,
      licenseName: 'Apache 2.0',
      parametersB: 8,
    ),
  ],
  news: [],
  refreshedAt: null,
);

Widget _wrap(Widget child) => MaterialApp(
      theme: LumaTheme.from(Brightness.dark, null, LumaThemeStyle.standard),
      home: Scaffold(
        body: AiCatalogScope(
          repository: AiCatalogRepository.withCatalog(_catalog),
          child: child,
        ),
      ),
    );

/// The plugin renders in a desktop pane; the default 800x600 test window is
/// narrower than any real one, so the wide table would sit half off-screen and
/// taps on its right-hand headers would miss.
void _desktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('leaderboard table', () {
    testWidgets('renders a row per model, best rating first',
        (tester) async {
      _desktopSurface(tester);
      await tester.pumpWidget(_wrap(const AiLeaderboardTab()));
      await tester.pumpAndSettle();

      expect(find.text('Claude Opus 5'), findsOneWidget);
      expect(find.text('Kimi K3'), findsOneWidget);
      expect(find.text('Qwen3 8B'), findsOneWidget);
      expect(find.text('3 models'), findsOneWidget);

      // The four rating columns and the arena column are all present.
      expect(find.text('63.1'), findsOneWidget);
      expect(find.text('71.4'), findsOneWidget);
      expect(find.text('78.0'), findsOneWidget);
      expect(find.text('59.2'), findsOneWidget);
      expect(find.text('1344'), findsOneWidget);
    });

    testWidgets('shows the average price and the context window',
        (tester) async {
      _desktopSurface(tester);
      await tester.pumpWidget(_wrap(const AiLeaderboardTab()));
      await tester.pumpAndSettle();

      // (5 + 25) / 2
      expect(find.text(r'$15.00'), findsOneWidget);
      expect(find.text('1.0M'), findsOneWidget);
      expect(find.text('128K'), findsOneWidget);
    });

    testWidgets('an unrated model shows a dash, not a zero', (tester) async {
      _desktopSurface(tester);
      await tester.pumpWidget(_wrap(const AiLeaderboardTab()));
      await tester.pumpAndSettle();

      // Qwen3 8B has no ratings and no price: four rating cells plus price.
      expect(find.text('–'), findsWidgets);
      expect(find.text('0.0'), findsNothing);
    });

    testWidgets('the open-weights filter narrows the table', (tester) async {
      _desktopSurface(tester);
      await tester.pumpWidget(_wrap(const AiLeaderboardTab()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open weights'));
      await tester.pumpAndSettle();

      expect(find.text('Claude Opus 5'), findsNothing);
      expect(find.text('Kimi K3'), findsOneWidget);
      expect(find.text('2 of 3 models'), findsOneWidget);
    });

    testWidgets('searching filters down to one model', (tester) async {
      _desktopSurface(tester);
      await tester.pumpWidget(_wrap(const AiLeaderboardTab()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'kimi');
      await tester.pumpAndSettle();

      expect(find.text('Kimi K3'), findsOneWidget);
      expect(find.text('Claude Opus 5'), findsNothing);
    });

    testWidgets('clicking a column header re-sorts, and again reverses it',
        (tester) async {
      _desktopSurface(tester);
      await tester.pumpWidget(_wrap(const AiLeaderboardTab()));
      await tester.pumpAndSettle();

      Offset firstRowCentre() =>
          tester.getCenter(find.text('Claude Opus 5'));
      final topBefore = firstRowCentre().dy;

      // Price ascending puts the cheapest first, so Opus (the dearest of the
      // two priced models) drops below Kimi.
      await tester.tap(find.text(r'PRICE $/M'));
      await tester.pumpAndSettle();
      expect(firstRowCentre().dy, greaterThan(topBefore));

      await tester.tap(find.text(r'PRICE $/M'));
      await tester.pumpAndSettle();
      expect(firstRowCentre().dy, topBefore);
    });

    testWidgets('renders at a narrow window without overflowing',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(const AiLeaderboardTab()));
      await tester.pumpAndSettle();

      // The table scrolls sideways inside its own box rather than painting
      // past the edge of the page.
      expect(tester.takeException(), isNull);
    });

    testWidgets('the model column fills a wide pane instead of leaving it blank',
        (tester) async {
      tester.view.physicalSize = const Size(2000, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(const AiLeaderboardTab()));
      await tester.pumpAndSettle();

      final modelHeaderBox = tester.widget<SizedBox>(find
          .ancestor(of: find.text('MODEL'), matching: find.byType(SizedBox))
          .first);
      // The column's fixed minimum is 240 — on a 2000px pane it must have
      // grown well past that rather than the table sitting narrow with a
      // blank strip of card background to its right.
      expect(modelHeaderBox.width, greaterThan(600));
    });
  });

  group('open source calculator', () {
    testWidgets('sizes the selected model and judges each device',
        (tester) async {
      _desktopSurface(tester);
      await tester.pumpWidget(_wrap(const OpenSourceTab()));
      await tester.pumpAndSettle();

      // Largest open-weight model is selected by default.
      expect(find.textContaining('Kimi K3'), findsWidgets);
      expect(find.text('GB of memory'), findsOneWidget);
      expect(find.text('Weights '), findsOneWidget);
      expect(find.text('Context cache '), findsOneWidget);

      // A 1026B model at Q4 needs ~616 GB — nothing on the list runs it.
      expect(find.text('Runs well'), findsNothing);
      expect(find.text('Won’t run'), findsWidgets);
    });

    testWidgets('a small model runs comfortably on ordinary hardware',
        (tester) async {
      _desktopSurface(tester);
      await tester.pumpWidget(_wrap(const OpenSourceTab()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<AiModel>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Qwen3 8B').last);
      await tester.pumpAndSettle();

      // 8B at Q4_K_M is ~4.8 GB of weights: comfortable on a 12 GB card.
      expect(find.text('Runs well'), findsWidgets);
    });

    testWidgets('closed-weight models are not offered', (tester) async {
      _desktopSurface(tester);
      await tester.pumpWidget(_wrap(const OpenSourceTab()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<AiModel>));
      await tester.pumpAndSettle();

      // Claude has no downloadable weights, so it can't be sized.
      expect(find.textContaining('Claude Opus 5'), findsNothing);
    });
  });
}
