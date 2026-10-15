import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/luma_theme.dart';
import '../plugins/installed/steam_tools/cs2_market_repository.dart';
import '../plugins/installed/steam_tools/cs2_market_scope.dart';
import '../plugins/installed/steam_tools/cs2_price_history.dart';
import '../plugins/installed/steam_tools/data/steam_database.dart';
import '../plugins/installed/steam_tools/steam_price_history.dart';
import '../plugins/installed/steam_tools/steam_repository.dart';
import '../plugins/installed/steam_tools/steam_scope.dart';
import '../plugins/installed/steam_tools/ui/cs2_price_chart.dart';

class DashboardSteamGamePriceTile extends StatelessWidget {
  const DashboardSteamGamePriceTile({
    super.key,
    this.appId,
    required this.onOpen,
  });

  final int? appId;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => _SteamDashboardTile(
    kind: _SteamTileKind.games,
    appId: appId,
    onOpen: onOpen,
  );
}

class DashboardCs2SkinPriceTile extends StatelessWidget {
  const DashboardCs2SkinPriceTile({
    super.key,
    this.marketHashName,
    required this.onOpen,
  });

  final String? marketHashName;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => _SteamDashboardTile(
    kind: _SteamTileKind.skins,
    marketHashName: marketHashName,
    onOpen: onOpen,
  );
}

class DashboardCs2TrackedGraphTile extends StatelessWidget {
  const DashboardCs2TrackedGraphTile({
    super.key,
    this.marketHashName,
    required this.onOpen,
  });

  final String? marketHashName;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => _SteamDashboardTile(
    kind: _SteamTileKind.graph,
    marketHashName: marketHashName,
    onOpen: onOpen,
  );
}

enum _SteamTileKind { games, skins, graph }

class _SteamDashboardTile extends StatefulWidget {
  const _SteamDashboardTile({
    required this.kind,
    required this.onOpen,
    this.appId,
    this.marketHashName,
  });

  final _SteamTileKind kind;
  final VoidCallback onOpen;
  final int? appId;
  final String? marketHashName;

  @override
  State<_SteamDashboardTile> createState() => _SteamDashboardTileState();
}

class _SteamDashboardTileState extends State<_SteamDashboardTile> {
  SteamRepository? _steam;
  Cs2MarketRepository? _cs2;
  Stream<List<SteamGame>>? _games;
  Stream<List<Cs2MarketItem>>? _items;
  Stream<List<Cs2MarketEntry>>? _entries;
  Stream<List<Cs2MarketPricePoint>>? _history;
  Cs2PriceRange _range = Cs2PriceRange.week;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.kind == _SteamTileKind.games) {
      final repository = context
          .dependOnInheritedWidgetOfExactType<SteamScope>()
          ?.notifier;
      if (!identical(repository, _steam)) {
        _steam = repository;
        _games = repository?.watchTrackedGames();
      }
    } else {
      final repository = context
          .dependOnInheritedWidgetOfExactType<Cs2MarketScope>()
          ?.notifier;
      if (!identical(repository, _cs2)) {
        _cs2 = repository;
        _items = repository?.watchTrackedItems();
        _entries = repository?.watchAllEntries();
        _history = repository?.watchAllPriceHistory();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    if (widget.kind == _SteamTileKind.games) {
      final repository = _steam;
      if (repository == null) return _frame([Text(t.homeSteamDataError)]);
      return StreamBuilder<List<SteamGame>>(
        stream: _games,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _frame([Text(t.homeSteamDataError)]);
          if (!snapshot.hasData) return _loading();
          final games = snapshot.data!
              .where(
                (game) => widget.appId == null || game.appId == widget.appId,
              )
              .toList();
          return _frame(
            [
              if (games.isEmpty)
                Text(
                  widget.appId == null
                      ? t.homeSteamGamesEmpty
                      : t.homeSteamGameUnavailable,
                ),
              for (final game in games)
                _SavedPriceRow(
                  title: game.name,
                  price: game.isFree
                      ? t.steamFreeToPlay
                      : game.lastPriceCents == null
                      ? t.steamPriceNotChecked
                      : formatSteamPrice(
                          game.lastPriceCents!,
                          game.currency ?? 'USD',
                        ),
                  checkedAt: game.detailsFetchedAt,
                  discountPercent: game.lastDiscountPercent,
                  onOpen: widget.onOpen,
                ),
            ],
            error: repository.error,
            refreshing:
                repository.refreshingPrices ||
                (widget.appId != null &&
                    repository.isFetchingDetails(widget.appId!)),
            onRefresh: games.isEmpty
                ? null
                : () => unawaited(
                    widget.appId == null
                        ? repository.refreshAllPrices()
                        : repository.ensureDetails(widget.appId!, force: true),
                  ),
          );
        },
      );
    }
    final repository = _cs2;
    if (repository == null) return _frame([Text(t.homeSteamDataError)]);
    return StreamBuilder<List<Cs2MarketItem>>(
      stream: _items,
      builder: (context, itemsSnapshot) => StreamBuilder<List<Cs2MarketEntry>>(
        stream: _entries,
        builder: (context, entriesSnapshot) {
          if (itemsSnapshot.hasError || entriesSnapshot.hasError) {
            return _frame([Text(t.homeSteamDataError)]);
          }
          if (!itemsSnapshot.hasData || !entriesSnapshot.hasData) {
            return _loading();
          }
          final entries = entriesSnapshot.data!
              .where(
                (entry) =>
                    widget.marketHashName == null ||
                    entry.marketHashName == widget.marketHashName,
              )
              .toList();
          final hashes = entries.map((entry) => entry.marketHashName).toSet();
          final items = itemsSnapshot.data!
              .where((item) => hashes.contains(item.marketHashName))
              .toList();
          final refreshing =
              repository.refreshingPrices ||
              items.any(
                (item) => repository.isFetchingPrice(item.marketHashName),
              );
          void refresh() => unawaited(
            widget.marketHashName == null
                ? repository.refreshAllPrices()
                : repository.refreshPrice(widget.marketHashName!, force: true),
          );

          Widget frame(List<Widget> content) => _frame(
            content,
            error: repository.error,
            refreshing: refreshing,
            onRefresh: items.isEmpty ? null : refresh,
          );
          if (items.isEmpty) {
            return frame([
              Text(
                widget.marketHashName == null
                    ? t.homeSteamSkinsEmpty
                    : t.homeSteamSkinUnavailable,
              ),
            ]);
          }
          if (widget.kind == _SteamTileKind.skins) {
            return frame([
              for (final item in items)
                _SavedPriceRow(
                  title: item.marketHashName,
                  price: (item.lastLowestCents ?? item.lastMedianCents) == null
                      ? t.steamPriceNotChecked
                      : formatSteamPrice(
                          (item.lastLowestCents ?? item.lastMedianCents)!,
                          item.currency,
                        ),
                  checkedAt: item.priceFetchedAt,
                  copies: entries
                      .where(
                        (entry) => entry.marketHashName == item.marketHashName,
                      )
                      .length,
                  onOpen: widget.onOpen,
                ),
            ]);
          }
          return StreamBuilder<List<Cs2MarketPricePoint>>(
            stream: _history,
            builder: (context, historySnapshot) {
              if (historySnapshot.hasError) {
                return frame([Text(t.homeSteamDataError)]);
              }
              if (!historySnapshot.hasData) return _loading();
              final points = historySnapshot.data!
                  .where((point) => hashes.contains(point.marketHashName))
                  .toList();
              final currencies = {
                for (final item in items) item.currency,
                for (final point in points) point.currency,
              };
              if (currencies.length > 1) {
                return frame([Text(t.homeSteamMixedCurrency)]);
              }
              final single = widget.marketHashName != null;
              final series = single
                  ? buildCs2PriceSeries(
                      points,
                      _range,
                      DateTime.now(),
                      fallbackCurrency: items.first.currency,
                    )
                  : buildCs2PortfolioSeries(
                      points,
                      entries,
                      _range,
                      DateTime.now(),
                      fallbackCurrency: items.first.currency,
                    );
              final itemsByHash = {
                for (final item in items) item.marketHashName: item,
              };
              final completePrices = entries.every((entry) {
                final item = itemsByHash[entry.marketHashName];
                return (item?.lastLowestCents ?? item?.lastMedianCents) != null;
              });
              final total = single
                  ? items.first.lastLowestCents ?? items.first.lastMedianCents
                  : !completePrices
                  ? null
                  : entries.fold<int>(0, (sum, entry) {
                      final item = itemsByHash[entry.marketHashName];
                      return sum +
                          (item?.lastLowestCents ?? item?.lastMedianCents ?? 0);
                    });
              final checked = items.map((item) => item.priceFetchedAt);
              final checkedAt = checked.any((at) => at == null)
                  ? null
                  : checked.cast<DateTime>().reduce(
                      (a, b) => a.isBefore(b) ? a : b,
                    );
              return frame([
                Text(
                  single ? items.first.marketHashName : t.cs2TrackedTotalValue,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  total == null
                      ? t.steamPriceNotChecked
                      : formatSteamPrice(total, series.currency),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  t.cs2TrackedCopiesTracked(entries.length),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                _CheckedAt(at: checkedAt),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final range in Cs2PriceRange.values)
                      ChoiceChip(
                        label: Text(
                          range == Cs2PriceRange.all
                              ? t.cs2RangeAll
                              : range.label,
                        ),
                        selected: _range == range,
                        onSelected: (_) => setState(() => _range = range),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Cs2PriceSeriesView(series: series, height: 160),
              ]);
            },
          );
        },
      ),
    );
  }

  Widget _loading() => _frame([
    const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    ),
  ]);

  Widget _frame(
    List<Widget> children, {
    String? error,
    bool refreshing = false,
    VoidCallback? onRefresh,
  }) {
    final t = L.of(context);
    return ListView(
      padding: EdgeInsets.zero,
      primary: false,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t.homeSteamSavedPrices,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (onRefresh != null)
              IconButton(
                tooltip: t.steamTrackerRefreshPrices,
                onPressed: refreshing ? null : onRefresh,
                icon: const Icon(Icons.refresh, size: 18),
              ),
          ],
        ),
        if (refreshing) const LinearProgressIndicator(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(error, style: TextStyle(color: context.luma.danger)),
          ),
        ...children,
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onOpen,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(t.homeOpenSteamTools),
          ),
        ),
      ],
    );
  }
}

class _SavedPriceRow extends StatelessWidget {
  const _SavedPriceRow({
    required this.title,
    required this.price,
    required this.checkedAt,
    required this.onOpen,
    this.discountPercent,
    this.copies,
  });

  final String title;
  final String price;
  final DateTime? checkedAt;
  final VoidCallback onOpen;
  final int? discountPercent;
  final int? copies;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onOpen,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                price,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.luma.accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if ((discountPercent ?? 0) > 0)
                Text(
                  '-$discountPercent%',
                  style: TextStyle(color: context.luma.accent),
                ),
              if (copies != null)
                Text(
                  L.of(context).cs2TrackedCopiesTracked(copies!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          _CheckedAt(at: checkedAt),
        ],
      ),
    ),
  );
}

class _CheckedAt extends StatelessWidget {
  const _CheckedAt({required this.at});

  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final date = at;
    return Text(
      date == null
          ? t.steamPriceNotChecked
          : t.homeSteamPriceChecked(
              DateFormat.yMd(
                Localizations.localeOf(context).toString(),
              ).add_jm().format(date.toLocal()),
            ),
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: context.luma.textMuted),
    );
  }
}
