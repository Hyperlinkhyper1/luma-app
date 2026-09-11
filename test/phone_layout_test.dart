import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/leaderboard/ai_catalog_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/leaderboard/ai_catalog_scope.dart';
import 'package:luma/features/plugins/installed/ai_usage/leaderboard/ai_leaderboard_tab.dart';
import 'package:luma/features/plugins/installed/ai_usage/leaderboard/ai_model.dart';
import 'package:luma/features/plugins/installed/ai_usage/leaderboard/ai_model_detail_page.dart';
import 'package:luma/features/plugins/installed/school/ui/tests_tab.dart';
import 'package:luma/theme/luma_theme.dart';
import 'package:luma/theme/theme_style.dart';

/// Screens that were only ever laid out on a desktop pane, checked at the size
/// they actually get on a phone.
///
/// Two things are asserted throughout: that nothing overflows (a `RenderFlex`
/// overflow surfaces through [WidgetTester.takeException]), and that the thing
/// the screen is *for* is still reachable — a table you can only read one
/// column at a time is not a pass.

const _catalog = AiCatalog(
  models: [
    AiModel(
      id: 'anthropic/claude-opus-5',
      slug: 'claude-opus-5',
      name: 'Claude Opus 5',
      vendor: 'anthropic',
      vendorName: 'Anthropic',
      llmStatsIndex: 63.1,
      codingIndex: 78.0,
      agentIndex: 59.2,
      codeArena: 1344,
      contextTokens: 1000000,
      inputPricePerM: 5,
      outputPricePerM: 25,
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

/// A mid-range phone in portrait, at 1:1 so sizes read in logical pixels.
void _phoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// The scope goes *above* `MaterialApp`, as `main.dart` nests it — pushing
/// the model detail page has to stay inside it.
Widget _leaderboard() => AiCatalogScope(
      repository: AiCatalogRepository.withCatalog(_catalog),
      child: MaterialApp(
        theme: LumaTheme.from(Brightness.dark, null, LumaThemeStyle.standard),
        home: const Scaffold(body: AiLeaderboardTab()),
      ),
    );

Widget _school() => MaterialApp(
      theme: LumaTheme.dark,
      home: const Scaffold(body: TestsTab()),
    );

/// The tests tab carries a clock that reschedules every second, so
/// `pumpAndSettle` would time out. Four short pumps clear the 200 ms phase
/// transition and stay inside one tick.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  group('AI leaderboard on a phone', () {
    testWidgets('lays out as cards, not a sideways-scrolling table',
        (tester) async {
      _phoneSurface(tester);
      await tester.pumpWidget(_leaderboard());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Every model, and every number the table columns carried, on screen
      // without scrolling sideways for it.
      expect(find.text('Claude Opus 5'), findsOneWidget);
      expect(find.text('Anthropic'), findsOneWidget);
      expect(find.text('63.1'), findsOneWidget);
      expect(find.text('78.0'), findsOneWidget);
      expect(find.text('1344'), findsOneWidget);
      expect(find.textContaining(r'$15.00 /M'), findsOneWidget);

      // Each rating says what it is, since there is no header row above it:
      // one per card, plus the sort button naming the current sort.
      expect(find.text('Intelligence'), findsNWidgets(3));
      expect(find.text('Coding'), findsNWidgets(2));
      expect(find.text('Agent'), findsNWidgets(2));

      // The column headers — the desktop table's only sort affordance — are
      // gone, so the card layout must be offering its own.
      expect(find.text('INTELLIGENCE'), findsNothing);
      expect(find.byTooltip('Sort by'), findsOneWidget);
    });

    testWidgets('nothing is laid out wider than the phone', (tester) async {
      _phoneSurface(tester);
      await tester.pumpWidget(_leaderboard());
      await tester.pumpAndSettle();

      for (final element in find.byType(Scrollable).evaluate()) {
        final box = element.renderObject! as RenderBox;
        expect(
          box.size.width,
          lessThanOrEqualTo(390),
          reason: 'a scrollable is wider than the screen — the table layout '
              'is still in play',
        );
      }
    });

    testWidgets('a card opens the model detail page', (tester) async {
      _phoneSurface(tester);
      await tester.pumpWidget(_leaderboard());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Claude Opus 5'));
      await tester.pumpAndSettle();

      expect(find.byType(AiModelDetailPage), findsOneWidget);
    });

    testWidgets('sorting from the menu reorders the cards', (tester) async {
      _phoneSurface(tester);
      await tester.pumpWidget(_leaderboard());
      await tester.pumpAndSettle();

      // Qwen has no intelligence rating, so it ranks last by default.
      Offset yOf(String name) => tester.getCenter(find.text(name));
      expect(yOf('Claude Opus 5').dy, lessThan(yOf('Qwen3 8B').dy));

      await tester.tap(find.byTooltip('Sort by'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Model').last);
      await tester.pumpAndSettle();

      // Sorted by name ascending now: Claude before Qwen still, so flip it to
      // prove the control actually drives the order.
      await tester.tap(find.byTooltip('Sort by'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Model').last);
      await tester.pumpAndSettle();

      expect(yOf('Qwen3 8B').dy, lessThan(yOf('Claude Opus 5').dy));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the desktop table is still used on a wide window',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_leaderboard());
      await tester.pumpAndSettle();

      expect(find.text('INTELLIGENCE'), findsOneWidget);
      expect(find.byTooltip('Sort by'), findsNothing);
    });
  });

  group('School tests with the keyboard up', () {
    /// Runs a taalverzorging test and stops on the first question that wants
    /// something typed.
    Future<void> openTypedQuestion(WidgetTester tester) async {
      await tester.pumpWidget(_school());
      await tester.ensureVisible(find.text('Taalverzorging'));
      await tester.tap(find.text('Taalverzorging'));
      await tester.pump();
      await tester.ensureVisible(find.text('10 vragen'));
      await tester.tap(find.text('10 vragen'));
      await tester.pump();
      await tester.ensureVisible(find.text('Start toets taalverzorging'));
      await tester.tap(find.text('Start toets taalverzorging'));
      await _settle(tester);

      var hops = 0;
      while (find.byType(TextFormField).evaluate().isEmpty && hops < 9) {
        await tester.tap(find.text('Volgende'));
        await tester.pump();
        hops++;
      }
      expect(find.byType(TextFormField), findsOneWidget);
    }

    /// How tall the question's scroll area is right now. This is the space
    /// the phone has left to actually show the question in, and the thing the
    /// slim header buys back.
    double bodyHeight(WidgetTester tester) => tester
        .renderObject<RenderBox>(find.byKey(const ValueKey('runner-body')))
        .size
        .height;

    testWidgets('focusing the answer gives the question back its space',
        (tester) async {
      _phoneSurface(tester);
      await openTypedQuestion(tester);

      final before = bodyHeight(tester);

      // enterText focuses the field, which is exactly what raises the
      // keyboard on a real phone.
      await tester.enterText(find.byType(TextFormField), 'mijn antwoord');
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: 'the runner overflowed once the answer field took focus',
      );
      expect(
        bodyHeight(tester),
        greaterThan(before),
        reason: 'the header did not stand aside, so the question still has '
            'the same sliver to scroll in',
      );

      // Both halves of the interaction survive: somewhere to type, and the
      // button that moves you on.
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Volgende'), findsOneWidget);
      // Which question you are on is never lost, only reduced to one line.
      expect(find.textContaining('1 beantwoord'), findsOneWidget);
      // The link that ends the test early does step aside — it is the one
      // thing you would hate to hit by accident with a keyboard up.
      expect(find.text('Nu al nakijken'), findsNothing);
    });

    testWidgets('typing survives the header standing aside', (tester) async {
      _phoneSurface(tester);
      await openTypedQuestion(tester);

      // Folding the header shifts every child of the runner's Column, and
      // Flutter matches unkeyed children by position. Without keys on the
      // parts that stay, the question subtree would be rebuilt from scratch
      // on the first keystroke and take the answer with it.
      await tester.enterText(find.byType(TextFormField), 'mijn antwoord');
      await tester.pump();
      expect(find.text('mijn antwoord'), findsOneWidget);

      // Unfocusing puts the full header back and must not lose the text.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(find.text('mijn antwoord'), findsOneWidget);
      expect(find.text('Nu al nakijken'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the header stays put on a desktop window', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await openTypedQuestion(tester);

      await tester.enterText(find.byType(TextFormField), 'mijn antwoord');
      await tester.pump();

      // Standing the header aside is a phone concession; a desktop window has
      // the room and shouldn't rearrange itself when a field takes focus.
      expect(find.text('Nu al nakijken'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });
}
