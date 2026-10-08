import 'package:flutter/material.dart';

import '../app/widgets.dart';
import '../l10n/app_localizations.dart';
import 'ui/debts_tab.dart';
import 'ui/overview_tab.dart';
import 'ui/pots_tab.dart';
import 'ui/recurring_tab.dart';
import 'ui/reports_tab.dart';
import 'ui/stocks_tab.dart';
import 'ui/transactions_tab.dart';

/// Root of the Finance destination: a segmented sub-navigation over the
/// overview, transactions, pots, recurring, debts, stocks and reports
/// screens.
class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final tabs = [
      t.commonOverview,
      t.financeTabTransactions,
      t.financeTabPots,
      t.financeTabRecurring,
      t.financeTabDebts,
      t.financeTabStocks,
      t.financeTabReports,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: LumaSegmentedTabs(
            tabs: tabs,
            selectedIndex: _tab,
            onSelect: (i) => setState(() => _tab = i),
            scrollable: context.isPhoneWidth,
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: const [
              OverviewTab(),
              TransactionsTab(),
              PotsTab(),
              RecurringTab(),
              DebtsTab(),
              StocksTab(),
              ReportsTab(),
            ],
          ),
        ),
      ],
    );
  }
}
