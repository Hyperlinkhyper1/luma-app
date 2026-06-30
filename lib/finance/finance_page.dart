import 'package:flutter/material.dart';

import '../app/widgets.dart';
import 'ui/overview_tab.dart';
import 'ui/pots_tab.dart';
import 'ui/recurring_tab.dart';
import 'ui/stocks_tab.dart';
import 'ui/transactions_tab.dart';

/// Root of the Finance destination: a segmented sub-navigation over the
/// overview, transactions, pots, recurring and stocks screens.
class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  int _tab = 0;

  static const _tabs = ['Overview', 'Transactions', 'Pots', 'Recurring', 'Stocks'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: LumaSegmentedTabs(
            tabs: _tabs,
            selectedIndex: _tab,
            onSelect: (i) => setState(() => _tab = i),
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
              StocksTab(),
            ],
          ),
        ),
      ],
    );
  }
}
