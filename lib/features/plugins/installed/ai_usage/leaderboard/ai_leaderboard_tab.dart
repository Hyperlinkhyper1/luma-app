import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import 'ai_compare_page.dart';
import 'ai_leaderboard_graph.dart';
import 'ai_leaderboard_insights.dart';
import 'ai_leaderboard_table.dart';

/// The three views inside the Leaderboard section.
enum _LeaderboardView { table, graph, insights }

/// The plugin's **Leaderboard** section: a segmented switch between the
/// ranked table, a scatter graph of any two metrics, and a scrollable page of
/// price/performance and news — plus a way to compare specific models
/// head to head.
///
/// Each view is kept alive in an [IndexedStack] so switching between Table
/// and Graph doesn't lose a scroll position, a sort, or an axis pick.
class AiLeaderboardTab extends StatefulWidget {
  const AiLeaderboardTab({super.key});

  @override
  State<AiLeaderboardTab> createState() => _AiLeaderboardTabState();
}

class _AiLeaderboardTabState extends State<AiLeaderboardTab> {
  _LeaderboardView _view = _LeaderboardView.table;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: [
              Flexible(
                child: LumaSegmentedTabs(
                  tabs: const ['Table', 'Graph', 'Insights'],
                  selectedIndex: _view.index,
                  onSelect: (i) =>
                      setState(() => _view = _LeaderboardView.values[i]),
                ),
              ),
              const Spacer(),
              LumaGhostButton(
                label: 'Compare',
                icon: Icons.compare_arrows_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AiComparePage()),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.only(top: 12),
          color: luma.border,
        ),
        Expanded(
          child: IndexedStack(
            index: _view.index,
            children: const [
              AiLeaderboardTableView(),
              AiLeaderboardGraphView(),
              AiLeaderboardInsightsView(),
            ],
          ),
        ),
      ],
    );
  }
}
