import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/home/home_classic_tiles.dart';
import 'package:luma/features/home/home_greeting.dart';
import 'package:luma/features/home/home_layout.dart';
import 'package:luma/finance/data/database.dart';
import 'package:luma/finance/finance_repository.dart';
import 'package:luma/finance/finance_scope.dart';
import 'package:luma/finance/logic/money.dart';
import 'package:luma/settings/settings_controller.dart';
import 'package:luma/settings/settings_scope.dart';
import 'package:luma/theme/luma_theme.dart';

class _Finance implements FinanceRepository {
  @override
  Stream<List<Holding>> watchHoldings() => Stream.value([
    const Holding(
      id: 1,
      ticker: 'TEST',
      name: 'Test holding',
      shares: 2,
      avgCostCents: 9000,
      lastPriceCents: 10000,
    ),
  ]);
  @override
  Stream<List<FinanceTransaction>> watchTransactions({int? limit}) {
    final now = DateTime.now();
    return Stream.value([
      FinanceTransaction(
        id: 1,
        kind: TxnKind.income,
        amountCents: 10000,
        date: now,
        createdAt: now,
      ),
      FinanceTransaction(
        id: 2,
        kind: TxnKind.expense,
        amountCents: 2500,
        date: now,
        createdAt: now,
      ),
      FinanceTransaction(
        id: 3,
        kind: TxnKind.allocation,
        amountCents: 2000,
        potId: 1,
        date: now,
        createdAt: now,
      ),
      FinanceTransaction(
        id: 4,
        kind: TxnKind.income,
        amountCents: 4000,
        date: DateTime(now.year, now.month - 1),
        createdAt: now,
      ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'greeting remains visible with no tiles and custom summary is editable',
    (tester) async {
      var layout = HomeLayout(columns: 12, tiles: []);
      await tester.pumpWidget(
        MaterialApp(
          theme: LumaTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => HomeGreeting(
                layout: layout,
                onEdit: () async {
                  final changed = await editHomeSummary(context, layout);
                  if (changed != null) setState(() => layout = changed);
                },
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('home-greeting')), findsOneWidget);
      await tester.tap(find.text('Edit summary'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom text').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Today’s focus');
      await tester.enterText(
        find.byType(TextField).last,
        'Build something lovely',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Today’s focus'), findsOneWidget);
      expect(find.text('Build something lovely'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-greeting')), findsOneWidget);
      expect(layout.tiles, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('default greeting summary combines cash and investments', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: FinanceScope(
          repository: _Finance(),
          child: Scaffold(
            body: HomeGreeting(layout: HomeLayout.defaults('desktop')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('All together'), findsOneWidget);
    expect(find.text(formatCents(31500)), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'classic finance cards use current month, pot balances and market value',
    (tester) async {
      for (final entry in {
        'income': 10000,
        'spending': 2500,
        'pots': 2000,
        'investments': 20000,
      }.entries) {
        await tester.pumpWidget(
          MaterialApp(
            theme: LumaTheme.dark,
            home: FinanceScope(
              repository: _Finance(),
              child: Scaffold(
                body: SizedBox(
                  width: 300,
                  height: 100,
                  child: HomeClassicMetric(kind: entry.key),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(formatCents(entry.value)), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('classic money cards respect hide amounts', (tester) async {
    late SettingsController settings;
    await tester.runAsync(() async {
      settings = await SettingsController.load();
      settings.setHideAmounts(true);
    });
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: SettingsScope(
          controller: settings,
          child: FinanceScope(
            repository: _Finance(),
            child: const Scaffold(body: HomeClassicMetric(kind: 'income')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('••••••'), findsOneWidget);
    expect(find.text(formatCents(10000)), findsNothing);
  });

  testWidgets('classic shortcuts open their configured destination', (
    tester,
  ) async {
    int? destination;
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: Scaffold(
          body: HomeClassicShortcut(
            destination: 1,
            onNavigate: (value) => destination = value,
          ),
        ),
      ),
    );
    await tester.tap(find.text('File Converter'));
    expect(destination, 1);
  });

  testWidgets('a shortcut takes taps across its whole card', (tester) async {
    int? destination;
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              height: 134,
              child: HomeClassicShortcut(
                destination: 2,
                onNavigate: (value) => destination = value,
              ),
            ),
          ),
        ),
      ),
    );
    final card = tester.getRect(find.byType(HomeClassicShortcut));
    final ink = tester.getRect(
      find.descendant(
        of: find.byType(HomeClassicShortcut),
        matching: find.byType(InkWell),
      ),
    );
    expect(ink, card);
    await tester.tapAt(card.bottomRight - const Offset(3, 3));
    expect(destination, 2);
  });
}
