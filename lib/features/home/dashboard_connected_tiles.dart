import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../finance/data/database.dart';
import '../../finance/finance_scope.dart';
import '../../finance/stock_service.dart';
import '../plugins/installed/account_overview/account_overview_scope.dart';
import '../plugins/installed/account_overview/ui/github_connect_dialog.dart';
import '../plugins/installed/ai_usage/ai_usage_scope.dart';
import '../plugins/installed/ai_usage/data/ai_usage_database.dart';

class DashboardGithubTile extends StatefulWidget {
  const DashboardGithubTile({super.key, required this.issues, this.repository});
  final bool issues;
  final String? repository;

  @override
  State<DashboardGithubTile> createState() => _DashboardGithubTileState();
}

class _DashboardGithubTileState extends State<DashboardGithubTile> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = context
        .dependOnInheritedWidgetOfExactType<AccountOverviewScope>()
        ?.notifier;
    if (repo != null) unawaited(repo.load());
  }

  @override
  Widget build(BuildContext context) {
    final repo = context
        .dependOnInheritedWidgetOfExactType<AccountOverviewScope>()
        ?.notifier;
    if (repo == null) return const Text('GitHub is unavailable.');
    if (!repo.loaded) return const Center(child: CircularProgressIndicator());
    if (!repo.connected) {
      return ListView(
        children: [
          const Text(
            'Connect GitHub to see your activity and private repositories. Your token stays on this device.',
          ),
          TextButton(
            onPressed: () => showGithubConnectDialog(context),
            child: const Text('Connect GitHub'),
          ),
        ],
      );
    }
    final data = repo.snapshot;
    final issues = data.issues
        .where(
          (i) =>
              !i.isPullRequest &&
              (widget.repository == null ||
                  widget.repository!.isEmpty ||
                  i.repo.toLowerCase() == widget.repository!.toLowerCase()),
        )
        .toList();
    final days = data.contributions.days;
    final peak = days.fold<int>(1, (value, d) => math.max(value, d.count));
    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.issues
                    ? 'Recent issues'
                    : '${data.contributions.calendarTotal} contributions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Refresh GitHub',
              onPressed: repo.refreshing ? null : repo.unawaitedRefresh,
              icon: const Icon(Icons.refresh, size: 18),
            ),
          ],
        ),
        if (repo.refreshing) const LinearProgressIndicator(),
        if (repo.error != null)
          Text(
            repo.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ...repo.warnings
            .where(
              (w) => w.startsWith(widget.issues ? 'Issues' : 'Contribution'),
            )
            .map((w) => Text(w)),
        if (widget.issues) ...[
          if (issues.isEmpty)
            const Text('No recent issues in the connected account snapshot.'),
          for (final issue in issues)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                issue.isOpen
                    ? Icons.radio_button_checked
                    : Icons.check_circle_outline,
                size: 18,
              ),
              title: Text(
                issue.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('${issue.repo} #${issue.number} · ${issue.state}'),
              onTap: () async {
                final uri = Uri.tryParse(issue.htmlUrl);
                if (uri != null &&
                    uri.scheme == 'https' &&
                    uri.host == 'github.com') {
                  final opened = await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open GitHub.')),
                    );
                  }
                }
              },
            ),
        ] else ...[
          if (days.isEmpty)
            const Text('Contribution history is not available yet.'),
          if (days.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final cell = math.max(
                  4.0,
                  (constraints.maxWidth - 52 * 2) / 53,
                );
                return SizedBox(
                  height: 7 * (cell + 2),
                  child: GridView.builder(
                    scrollDirection: Axis.horizontal,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                        ),
                    itemCount: days.length,
                    itemBuilder: (context, index) {
                      final day = days[index];
                      return Tooltip(
                        message:
                            '${DateFormat.yMMMd().format(day.date)}: ${day.count}',
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: day.count == 0
                                ? Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest
                                : Colors.green.withValues(
                                    alpha: .25 + .75 * day.count / peak,
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          const SizedBox(height: 10),
          Text(
            '${data.contributions.totalCommits} commits · ${data.contributions.totalPullRequests} pull requests',
          ),
          const Text(
            'Past year · includes private activity allowed by your token',
          ),
        ],
      ],
    );
  }
}

class DashboardStocksTile extends StatefulWidget {
  const DashboardStocksTile({super.key, this.symbol});
  final String? symbol;
  @override
  State<DashboardStocksTile> createState() => _DashboardStocksTileState();
}

class _DashboardStocksTileState extends State<DashboardStocksTile> {
  Stream<List<Holding>>? _holdings;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _holdings ??= context
        .dependOnInheritedWidgetOfExactType<FinanceScope>()
        ?.repository
        .watchHoldings();
  }

  @override
  Widget build(BuildContext context) {
    final symbol = widget.symbol?.trim();
    if (symbol != null && symbol.isNotEmpty) {
      return ListView(
        children: [_StockSeries(key: ValueKey(symbol), symbol: symbol)],
      );
    }
    if (_holdings == null) return const Text('Finance is unavailable.');
    return StreamBuilder<List<Holding>>(
      stream: _holdings,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Could not load your holdings.');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final symbols = snapshot.data!.map((h) => h.ticker).toSet().toList();
        if (symbols.isEmpty) {
          return const Text(
            'Add holdings in Finance, or choose a ticker in this tile’s settings.',
          );
        }
        return ListView(
          children: [
            for (final ticker in symbols)
              _StockSeries(key: ValueKey(ticker), symbol: ticker),
          ],
        );
      },
    );
  }
}

class _StockSeries extends StatefulWidget {
  const _StockSeries({super.key, required this.symbol});
  final String symbol;
  @override
  State<_StockSeries> createState() => _StockSeriesState();
}

class _StockSeriesState extends State<_StockSeries> {
  late Future<List<PricePoint>> _future;
  @override
  void initState() {
    super.initState();
    _future = StockService.fetchHistory(widget.symbol, ChartRange.month);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<PricePoint>>(
    future: _future,
    builder: (context, snapshot) {
      final points = snapshot.data ?? const <PricePoint>[];
      final delta = points.length > 1 && points.first.priceCents != 0
          ? (points.last.priceCents / points.first.priceCents - 1) * 100
          : null;
      final color = delta != null && delta < 0
          ? Theme.of(context).colorScheme.error
          : Colors.green;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.symbol} · 1M',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (delta != null)
                Text(
                  '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)}%',
                  style: TextStyle(color: color),
                ),
              IconButton(
                tooltip: 'Refresh prices',
                onPressed: () => setState(() {
                  _future = StockService.fetchHistory(
                    widget.symbol,
                    ChartRange.month,
                  );
                }),
                icon: const Icon(Icons.refresh, size: 16),
              ),
            ],
          ),
          if (snapshot.connectionState != ConnectionState.done)
            const LinearProgressIndicator()
          else if (points.length < 2)
            const Text('Price history unavailable. Try refreshing.')
          else
            SizedBox(
              height: 74,
              width: double.infinity,
              child: CustomPaint(
                painter: _Sparkline(
                  points.map((p) => p.priceCents.toDouble()).toList(),
                  color,
                ),
              ),
            ),
          const SizedBox(height: 10),
        ],
      );
    },
  );
}

class _Sparkline extends CustomPainter {
  _Sparkline(this.values, this.color);
  final List<double> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final range = high - low;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * size.width / (values.length - 1);
      final y = range == 0
          ? size.height / 2
          : size.height - 3 - (values[i] - low) / range * (size.height - 6);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_Sparkline oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class DashboardAiUsageTile extends StatefulWidget {
  const DashboardAiUsageTile({super.key});
  @override
  State<DashboardAiUsageTile> createState() => _DashboardAiUsageTileState();
}

class _DashboardAiUsageTileState extends State<DashboardAiUsageTile> {
  Stream<List<AiUsageTurn>>? _turns;
  String? _error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = context
        .dependOnInheritedWidgetOfExactType<AiUsageScope>()
        ?.notifier;
    final now = DateTime.now();
    _turns ??= repo?.watchRange(
      now.subtract(const Duration(days: 7)),
      DateTime(now.year + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context
        .dependOnInheritedWidgetOfExactType<AiUsageScope>()
        ?.notifier;
    if (repo == null) return const Text('AI usage is unavailable.');
    return StreamBuilder<List<AiUsageTurn>>(
      stream: _turns,
      builder: (context, snapshot) {
        final turns = (snapshot.data ?? const <AiUsageTurn>[])
            .where(
              (t) => t.timestamp.isAfter(
                DateTime.now().subtract(const Duration(days: 7)),
              ),
            )
            .toList();
        final tokens = turns.fold<int>(
          0,
          (sum, t) =>
              sum + t.inputTokens + t.outputTokens + t.cacheCreationTokens,
        );
        return ListView(
          children: [
            Text(
              NumberFormat.compact().format(tokens),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Text('new tokens · last 7 days'),
            const SizedBox(height: 8),
            Text('${turns.length} turns across local AI tools'),
            if (snapshot.hasError) const Text('Could not read usage records.'),
            if (turns.isEmpty)
              const Text(
                'Scan this device to import supported AI session logs.',
              ),
            if (_error != null) Text(_error!),
            TextButton.icon(
              onPressed: repo.scanning
                  ? null
                  : () async {
                      try {
                        await repo.rescan();
                        if (mounted) setState(() => _error = null);
                      } catch (_) {
                        if (mounted) {
                          setState(() => _error = 'Scan failed. Try again.');
                        }
                      }
                    },
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(repo.scanning ? 'Scanning…' : 'Scan usage'),
            ),
            const Text('Local session records; excludes cached input replays.'),
          ],
        );
      },
    );
  }
}
