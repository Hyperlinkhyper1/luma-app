import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/widgets.dart';
import '../../theme/luma_theme.dart';
import '../data/database.dart';
import '../finance_repository.dart';
import '../finance_scope.dart';
import '../fx_service.dart';
import '../logic/holding_value.dart';
import '../logic/money.dart';
import '../stock_service.dart';
import 'finance_form.dart';

class StocksTab extends StatefulWidget {
  const StocksTab({super.key});

  @override
  State<StocksTab> createState() => _StocksTabState();
}

/// How long a stored price stays trustworthy before the tab quietly refetches
/// it. Without this the portfolio total keeps showing whatever the price was
/// the last time "Refresh prices" was pressed, while the chart — which always
/// fetches fresh — shows today's, so the two disagree.
const _maxPriceAge = Duration(minutes: 15);

/// Saves a fetched quote with its currency and today's euro rate. A failed
/// rate lookup passes null, which keeps the holding's last good rate.
Future<void> _storeQuote(
    FinanceRepository repo, int holdingId, StockQuote quote) async {
  final currency = quote.currency;
  final rate = currency == null ? null : await FxService.eurPerUnit(currency);
  await repo.updateHoldingPrice(holdingId, quote.priceCents,
      currency: currency, eurPerUnit: rate);
}

class _CachedSeries {
  const _CachedSeries(this.points, this.fetchedAt);
  final List<PricePoint> points;
  final DateTime fetchedAt;
}

class _StocksTabState extends State<StocksTab> {
  bool _refreshing = false;
  bool _autoRefreshing = false;
  DateTime? _lastAutoRefresh;

  // Chart state.
  int? _selectedHoldingId; // null => aggregate of all holdings
  ChartRange _range = ChartRange.day;
  List<double>? _chartValues;
  bool _loadingChart = false;
  String? _chartError;

  // Cache fetched series, keyed by "ticker|range". Entries expire after
  // [_maxPriceAge] so flipping between ranges can't resurrect an old price.
  final Map<String, _CachedSeries> _historyCache = {};
  // Identifies the (selection, range, holdings) combination currently loaded.
  String? _activeKey;

  String _holdingsSig(List<Holding> holdings) =>
      (holdings.map((h) => '${h.id}:${h.ticker}:${h.shares}').toList()..sort())
          .join(',');

  String _chartKey(List<Holding> holdings) =>
      '${_selectedHoldingId ?? "all"}|${_range.name}|${_holdingsSig(holdings)}';

  void _maybeLoadChart(List<Holding> holdings) {
    final key = _chartKey(holdings);
    if (key == _activeKey) return;
    _activeKey = key;
    _loadChart(holdings, key);
  }

  Future<List<PricePoint>> _history(String ticker) async {
    final cacheKey = '$ticker|${_range.name}';
    final cached = _historyCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _maxPriceAge) {
      return cached.points;
    }
    final series = await StockService.fetchHistory(ticker, _range);
    _historyCache[cacheKey] = _CachedSeries(series, DateTime.now());
    return series;
  }

  Future<void> _loadChart(List<Holding> holdings, String key) async {
    final repo = FinanceScope.of(context);
    setState(() {
      _loadingChart = true;
      _chartError = null;
    });

    final included = _selectedHoldingId == null
        ? holdings
        : holdings.where((h) => h.id == _selectedHoldingId).toList();

    final seriesByHolding = <int, List<PricePoint>>{};
    for (final h in included) {
      seriesByHolding[h.id] = await _history(h.ticker);
    }

    // Ignore if a newer request superseded this one.
    if (!mounted || key != _activeKey) return;

    // The freshly fetched series is the most recent price we have; store it so
    // the portfolio total is quoting exactly what the chart is drawing.
    await _syncPricesFromHistory(repo, included, seriesByHolding);
    if (!mounted || key != _activeKey) return;

    final values = _buildValueSeries(included, seriesByHolding);
    setState(() {
      _loadingChart = false;
      _chartValues = values;
      _chartError = values.length < 2 ? 'No chart data available.' : null;
    });
  }

  /// Writes the last point of each fetched series back onto its holding, so
  /// the rows, the portfolio total and the chart all quote one price.
  Future<void> _syncPricesFromHistory(FinanceRepository repo,
      List<Holding> holdings, Map<int, List<PricePoint>> seriesByHolding) async {
    for (final h in holdings) {
      final series = seriesByHolding[h.id];
      if (series == null || series.isEmpty) continue;
      final latest = series.last.priceCents;
      if (latest == h.lastPriceCents) continue;
      await repo.updateHoldingPrice(h.id, latest);
    }
  }

  bool _isStale(Holding h) {
    final at = h.lastPriceAt;
    if (h.lastPriceCents == null || at == null) return true;
    return DateTime.now().difference(at) > _maxPriceAge;
  }

  /// Quietly brings stale prices up to date when the tab is opened, so the
  /// total reflects the market instead of the last manual refresh. Failures
  /// are silent — the rows keep their previous price and the "as of" stamp
  /// shows how old it is.
  Future<void> _maybeRefreshStalePrices(
      FinanceRepository repo, List<Holding> holdings) async {
    if (_refreshing || _autoRefreshing) return;
    final last = _lastAutoRefresh;
    if (last != null && DateTime.now().difference(last) < _maxPriceAge) return;
    final stale = holdings.where(_isStale).toList();
    if (stale.isEmpty) return;

    _autoRefreshing = true;
    _lastAutoRefresh = DateTime.now();
    try {
      for (final h in stale) {
        final quote = await StockService.fetchQuote(h.ticker);
        if (quote == null) continue;
        await _storeQuote(repo, h.id, quote);
      }
    } finally {
      _autoRefreshing = false;
    }
  }

  /// Portfolio value (shares × price, summed) sampled across the union of all
  /// timestamps, carrying each holding's last known price forward.
  List<double> _buildValueSeries(
      List<Holding> holdings, Map<int, List<PricePoint>> seriesByHolding) {
    final times = <DateTime>{};
    for (final s in seriesByHolding.values) {
      for (final p in s) {
        times.add(p.time);
      }
    }
    if (times.isEmpty) return const [];
    final sorted = times.toList()..sort();

    final values = <double>[];
    for (final t in sorted) {
      var sum = 0.0;
      for (final h in holdings) {
        final series = seriesByHolding[h.id];
        if (series == null || series.isEmpty) continue;
        final priceCents = _priceAtOrBefore(series, t) ?? series.first.priceCents;
        // Today's rate across the whole range: the line shows how the
        // holdings moved, not how the currency did.
        final rate = h.isEuro ? 1.0 : (h.eurPerUnit ?? 1.0);
        sum += h.shares * priceCents * rate / 100.0;
      }
      values.add(sum);
    }
    return values;
  }

  int? _priceAtOrBefore(List<PricePoint> series, DateTime t) {
    int? price;
    for (final p in series) {
      if (p.time.isAfter(t)) break;
      price = p.priceCents;
    }
    return price;
  }

  Future<void> _refreshAll(FinanceRepository repo, List<Holding> holdings) async {
    setState(() => _refreshing = true);
    var failed = 0;
    for (final h in holdings) {
      final quote = await StockService.fetchQuote(h.ticker);
      if (quote != null) {
        await _storeQuote(repo, h.id, quote);
      } else {
        failed++;
      }
    }
    // Force the chart to refetch fresh history too.
    _historyCache.clear();
    _activeKey = null;
    _lastAutoRefresh = DateTime.now();
    if (mounted) {
      setState(() => _refreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failed == 0
              ? 'Prices updated.'
              : 'Updated, but $failed ticker(s) could not be fetched.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = FinanceScope.of(context);
    return StreamData<List<Dividend>>(
      stream: repo.watchDividends(),
      builder: (context, dividends) => StreamData<List<Holding>>(
      stream: repo.watchHoldings(),
      builder: (context, holdings) {
        // If the selected holding was deleted, fall back to the aggregate.
        if (_selectedHoldingId != null &&
            !holdings.any((h) => h.id == _selectedHoldingId)) {
          _selectedHoldingId = null;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeRefreshStalePrices(repo, holdings);
          _maybeLoadChart(holdings);
        });

        final luma = context.luma;
        var value = 0;
        var cost = 0;
        DateTime? asOf;
        for (final h in holdings) {
          value += h.valueEurCents;
          cost += h.costEurCents;
          final at = h.lastPriceAt;
          // The total is only as current as its oldest price.
          if (h.lastPriceCents != null &&
              at != null &&
              (asOf == null || at.isBefore(asOf))) {
            asOf = at;
          }
        }
        final gain = value - cost;
        final selected = _selectedHoldingId == null
            ? null
            : holdings.firstWhere((h) => h.id == _selectedHoldingId);

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A Wrap, not a Row: on phone widths the buttons would otherwise
              // be pushed off the edge of the screen.
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  if (holdings.isNotEmpty)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('Portfolio ${formatCents(value)}',
                                style: TextStyle(
                                    color: luma.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                            Text(formatSignedCents(gain),
                                style: TextStyle(
                                    color:
                                        gain >= 0 ? luma.success : luma.danger,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Text(
                          _asOfLabel(asOf, refreshing: _refreshing),
                          style:
                              TextStyle(color: luma.textMuted, fontSize: 11),
                        ),
                        if (holdings.any((h) => h.missingFxRate))
                          Text(
                            'Some foreign prices aren\'t converted to euros yet',
                            style:
                                TextStyle(color: luma.warning, fontSize: 11),
                          ),
                      ],
                    ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (holdings.isNotEmpty || dividends.isNotEmpty)
                        LumaGhostButton(
                          label: 'Dividends ${formatCents(_thisYear(dividends))}',
                          icon: Icons.payments_rounded,
                          onTap: () => showFinanceDialog<void>(
                            context,
                            _DividendHistory(repo: repo, dividends: dividends),
                            maxWidth: 480,
                          ),
                        ),
                      if (holdings.isNotEmpty)
                        LumaGhostButton(
                          label: _refreshing ? 'Refreshing…' : 'Refresh prices',
                          icon: Icons.refresh_rounded,
                          onTap: _refreshing
                              ? null
                              : () => _refreshAll(repo, holdings),
                        ),
                      LumaPrimaryButton(
                        label: 'Add holding',
                        icon: Icons.add_rounded,
                        onTap: () => _openHoldingEditor(context, repo),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: holdings.isEmpty
                    ? LumaEmptyState(
                        icon: Icons.show_chart_rounded,
                        title: 'No holdings yet',
                        subtitle:
                            'Add a stock like AAPL or ASML to watch its price.',
                      )
                    : ListView.separated(
                        itemCount: holdings.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final h = holdings[i];
                          return _HoldingRow(
                            holding: h,
                            selected: h.id == _selectedHoldingId,
                            onTap: () => setState(() {
                              _selectedHoldingId =
                                  _selectedHoldingId == h.id ? null : h.id;
                            }),
                            dividendCents: dividends
                                .where((d) => d.holdingId == h.id)
                                .fold(0, (s, d) => s + d.amountCents),
                            onDividend: () => showFinanceDialog<void>(
                              context,
                              _DividendEditor(repo: repo, holding: h),
                            ),
                            onDelete: () async {
                              final ok = await confirmFinanceDelete(
                                context,
                                'Remove ${h.ticker}?',
                                'Its dividend history is kept.',
                              );
                              if (ok) await repo.deleteHolding(h.id);
                            },
                          );
                        },
                      ),
              ),
              if (holdings.isNotEmpty)
                _ChartCard(
                  title: selected?.name ?? 'All holdings',
                  subtitle: selected != null
                      ? selected.ticker.toUpperCase()
                      : '${holdings.length} holdings combined',
                  values: _chartValues,
                  loading: _loadingChart,
                  error: _chartError,
                  range: _range,
                  onRange: (r) => setState(() => _range = r),
                  onShowAll: selected != null
                      ? () => setState(() => _selectedHoldingId = null)
                      : null,
                ),
            ],
          ),
        );
      },
      ),
    );
  }
}

int _thisYear(List<Dividend> dividends) {
  final year = DateTime.now().year;
  return dividends
      .where((d) => d.date.year == year)
      .fold(0, (s, d) => s + d.amountCents);
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.values,
    required this.loading,
    required this.error,
    required this.range,
    required this.onRange,
    required this.onShowAll,
  });

  final String title;
  final String subtitle;
  final List<double>? values;
  final bool loading;
  final String? error;
  final ChartRange range;
  final ValueChanged<ChartRange> onRange;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final vals = values;
    final hasData = vals != null && vals.length >= 2;
    final first = hasData ? vals.first : 0.0;
    final last = hasData ? vals.last : 0.0;
    final change = last - first;
    final pct = (hasData && first != 0) ? (change / first) * 100 : 0.0;
    final up = change >= 0;
    final lineColor = up ? luma.success : luma.danger;

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 12),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      if (onShowAll != null)
                        GestureDetector(
                          onTap: onShowAll,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Text('Show all',
                                style: TextStyle(
                                    color: luma.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(color: luma.textMuted, fontSize: 12)),
                ],
              ),
              const Spacer(),
              if (hasData)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatCents((last * 100).round()),
                        style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${up ? '+' : ''}${formatCents((change * 100).round())}  (${up ? '+' : ''}${pct.toStringAsFixed(2)}%)',
                      style: TextStyle(color: lineColor, fontSize: 12),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: loading
                ? Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation(luma.accent)),
                    ),
                  )
                : !hasData
                    ? Center(
                        child: Text(error ?? 'No chart data.',
                            style: TextStyle(
                                color: luma.textMuted, fontSize: 13)),
                      )
                    : CustomPaint(
                        painter: _LineChartPainter(
                          values: vals,
                          color: lineColor,
                          fillColor: lineColor.withValues(alpha: 0.14),
                        ),
                        size: Size.infinite,
                      ),
          ),
          const SizedBox(height: 12),
          LumaSegmentedTabs(
            tabs: ChartRange.values.map((r) => r.label).toList(),
            selectedIndex: ChartRange.values.indexOf(range),
            onSelect: (i) => onRange(ChartRange.values[i]),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.color,
    required this.fillColor,
  });

  final List<double> values;
  final Color color;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    const padV = 8.0;
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);
    final h = size.height;
    final w = size.width;

    Offset pointAt(int i) {
      final x = values.length == 1 ? 0.0 : i / (values.length - 1) * w;
      final y = h - padV - ((values[i] - minV) / span) * (h - 2 * padV);
      return Offset(x, y);
    }

    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < values.length; i++) {
      final p = pointAt(i);
      line.lineTo(p.dx, p.dy);
    }

    final area = Path.from(line)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(area, Paint()..color = fillColor);

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.values != values || old.color != color;
}

class _HoldingRow extends StatelessWidget {
  const _HoldingRow({
    required this.holding,
    required this.selected,
    required this.onTap,
    required this.onDelete,
    required this.onDividend,
    required this.dividendCents,
  });
  final Holding holding;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onDividend;

  /// Every dividend logged for this holding, in euros.
  final int dividendCents;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final price = holding.lastPriceCents ?? holding.avgCostCents;
    final value = holding.valueEurCents;
    final gain = value - holding.costEurCents;
    final hasLive = holding.lastPriceCents != null;
    final priceLabel = holding.isEuro
        ? formatCents(price)
        : '${_plain.format(price / 100)} ${holding.currency}';
    final fxNote = holding.missingFxRate ? ' · no FX rate' : '';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? luma.accentSubtle : luma.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? luma.accent : luma.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: luma.accentSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  holding.ticker.toUpperCase(),
                  style: TextStyle(
                    color: luma.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      holding.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: luma.textPrimary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_trimShares(holding.shares)} @ $priceLabel${hasLive ? '' : ' (cost)'}$fxNote',
                      style: TextStyle(
                          color: holding.missingFxRate
                              ? luma.warning
                              : luma.textMuted,
                          fontSize: 12),
                    ),
                    if (dividendCents > 0)
                      Text(
                        'Dividends ${formatCents(dividendCents)}',
                        style: TextStyle(color: luma.success, fontSize: 11),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatCents(value),
                      style: TextStyle(
                          color: luma.textPrimary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(formatSignedCents(gain),
                      style: TextStyle(
                          color: gain >= 0 ? luma.success : luma.danger,
                          fontSize: 12)),
                ],
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    size: 18, color: luma.textMuted),
                color: luma.surface,
                onSelected: (v) => v == 'dividend' ? onDividend() : onDelete(),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'dividend',
                    child: Row(children: [
                      Icon(Icons.payments_rounded,
                          size: 18, color: luma.textSecondary),
                      const SizedBox(width: 8),
                      Text('Log dividend',
                          style: TextStyle(color: luma.textPrimary)),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 18, color: luma.danger),
                      const SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: luma.textPrimary)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openHoldingEditor(BuildContext context, FinanceRepository repo) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: context.luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _HoldingEditor(repo: repo),
      ),
    ),
  );
}

class _HoldingEditor extends StatefulWidget {
  const _HoldingEditor({required this.repo});
  final FinanceRepository repo;

  @override
  State<_HoldingEditor> createState() => _HoldingEditorState();
}

class _HoldingEditorState extends State<_HoldingEditor> {
  final _ticker = TextEditingController();
  final _name = TextEditingController();
  final _shares = TextEditingController();
  final _avgCost = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _ticker.dispose();
    _name.dispose();
    _shares.dispose();
    _avgCost.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ticker = _ticker.text.trim();
    final shares = double.tryParse(_shares.text.replaceAll(',', '.'));
    final avgCost = parseToCents(_avgCost.text);
    if (ticker.isEmpty || shares == null || shares <= 0 || avgCost == null) {
      setState(() => _error = 'Enter a ticker, number of shares and avg cost.');
      return;
    }
    setState(() => _saving = true);

    // Try to enrich with a live quote (name + current price).
    final quote = await StockService.fetchQuote(ticker);
    final name = _name.text.trim().isNotEmpty
        ? _name.text.trim()
        : (quote?.name ?? ticker.toUpperCase());
    final currency = quote?.currency;
    final rate = currency == null ? null : await FxService.eurPerUnit(currency);

    await widget.repo.upsertHolding(HoldingsCompanion.insert(
      ticker: ticker.toUpperCase(),
      name: name,
      shares: shares,
      avgCostCents: avgCost,
      lastPriceCents: Value(quote?.priceCents),
      lastPriceAt: Value(quote != null ? DateTime.now() : null),
      currency: Value(currency),
      eurPerUnit: Value(rate),
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add holding',
              style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _field(luma, 'Ticker', _ticker, hint: 'e.g. AAPL or ASML.NL'),
          const SizedBox(height: 12),
          _field(luma, 'Name (optional)', _name, hint: 'auto-filled if blank'),
          const SizedBox(height: 12),
          _field(luma, 'Shares', _shares, hint: 'e.g. 10', number: true),
          const SizedBox(height: 12),
          _field(luma, 'Average cost per share, in the stock\'s own currency',
              _avgCost,
              hint: '0,00', number: true),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: luma.danger, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              LumaGhostButton(
                  label: 'Cancel', onTap: () => Navigator.pop(context)),
              const SizedBox(width: 10),
              LumaPrimaryButton(
                label: 'Add',
                icon: Icons.check_rounded,
                loading: _saving,
                onTap: _save,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _field(
  LumaPalette luma,
  String label,
  TextEditingController controller, {
  String? hint,
  String? prefix,
  bool number = false,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label,
            style: TextStyle(
                color: luma.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
      TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: TextStyle(color: luma.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: TextStyle(color: luma.textMuted),
          prefixText: prefix,
          prefixStyle: TextStyle(color: luma.textSecondary),
          filled: true,
          fillColor: luma.background,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: luma.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: luma.accent),
          ),
        ),
      ),
    ],
  );
}

/// Says how current the portfolio total is, so a price that could not be
/// refreshed reads as old rather than as today's value.
String _asOfLabel(DateTime? asOf, {required bool refreshing}) {
  if (refreshing) return 'Updating prices…';
  if (asOf == null) return 'At cost price — no live quote yet';
  final now = DateTime.now();
  final sameDay =
      asOf.year == now.year && asOf.month == now.month && asOf.day == now.day;
  final stamp = sameDay
      ? DateFormat('HH:mm').format(asOf)
      : DateFormat('d MMM, HH:mm').format(asOf);
  return 'Prices as of $stamp';
}

final _plain = NumberFormat.decimalPatternDigits(locale: 'nl_NL', decimalDigits: 2);

class _DividendEditor extends StatefulWidget {
  const _DividendEditor({required this.repo, required this.holding});
  final FinanceRepository repo;
  final Holding holding;

  @override
  State<_DividendEditor> createState() => _DividendEditorState();
}

class _DividendEditorState extends State<_DividendEditor> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _book = true;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cents = parseToCents(_amount.text);
    if (cents == null || cents <= 0) {
      setState(() => _error = 'Enter the amount you received.');
      return;
    }
    await widget.repo.addDividend(
      holding: widget.holding,
      amountCents: cents,
      date: _date,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      bookAsIncome: _book,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return FinanceDialogScaffold(
      title: 'Dividend from ${widget.holding.ticker}',
      confirmLabel: 'Log',
      onConfirm: _save,
      error: _error,
      children: [
        FinanceField(
          label: 'Received (after tax, in euros)',
          controller: _amount,
          autofocus: true,
          hint: '0,00',
          prefix: '€ ',
          number: true,
        ),
        const SizedBox(height: 12),
        FinanceDateField(
          label: 'Paid on',
          date: _date,
          onChanged: (d) => setState(() => _date = d),
        ),
        const SizedBox(height: 12),
        FinanceField(label: 'Note (optional)', controller: _note),
        const SizedBox(height: 8),
        FinanceCheckRow(
          value: _book,
          onChanged: (v) => setState(() => _book = v),
          label: 'Also add it to my main balance as income',
        ),
      ],
    );
  }
}

class _DividendHistory extends StatelessWidget {
  const _DividendHistory({required this.repo, required this.dividends});
  final FinanceRepository repo;
  final List<Dividend> dividends;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final total = dividends.fold<int>(0, (s, d) => s + d.amountCents);
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Dividends',
              style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            '${formatCents(_thisYear(dividends))} this year · ${formatCents(total)} all time',
            style: TextStyle(color: luma.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (dividends.isEmpty)
            Text('Log one from a holding\'s ⋮ menu.',
                style: TextStyle(color: luma.textMuted, fontSize: 13))
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final d in dividends)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(d.ticker,
                          style: TextStyle(
                              color: luma.textPrimary,
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        [longDate(d.date), ?d.note].join(' · '),
                        style: TextStyle(color: luma.textMuted),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(formatCents(d.amountCents),
                              style: TextStyle(
                                  color: luma.success,
                                  fontWeight: FontWeight.w600)),
                          IconButton(
                            tooltip: 'Delete',
                            icon: Icon(Icons.delete_outline_rounded,
                                size: 18, color: luma.textMuted),
                            onPressed: () async {
                              await repo.deleteDividend(d);
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: LumaGhostButton(
                label: 'Close', onTap: () => Navigator.pop(context)),
          ),
        ],
      ),
    );
  }
}

String _trimShares(double shares) {
  if (shares == shares.roundToDouble()) return shares.toInt().toString();
  return shares.toString();
}
