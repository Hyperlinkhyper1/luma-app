import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../cs2_market_repository.dart';
import '../cs2_price_history.dart';
import '../data/steam_database.dart';
import '../steam_price_history.dart' show formatSteamPrice;
import 'cs2_item_detail_page.dart';
import 'cs2_price_chart.dart';
import 'cs2_shared.dart';

/// One tracked copy, joined with its listing's shared metadata and price —
/// what every widget below actually renders. [Cs2MarketEntry] alone has no
/// name, image or current price; those live once on [Cs2MarketItem] and are
/// shared by every copy of that listing.
class _TrackedRow {
  const _TrackedRow({required this.entry, required this.item});

  final Cs2MarketEntry entry;
  final Cs2MarketItem item;
}

/// The CS2 Market's "Tracked" view: every copy being watched, plus one
/// combined total-value chart across all of them.
///
/// [Cs2MarketTab] owns the Browse/Tracked toggle and the search field this
/// takes [query] from — the same box narrows the catalog grid in Browse and
/// this list in Tracked, since typing a weapon name to find is the same
/// action either way.
class Cs2TrackedBody extends StatelessWidget {
  const Cs2TrackedBody({
    super.key,
    required this.repository,
    required this.query,
  });

  final Cs2MarketRepository repository;
  final String query;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    return StreamBuilder<List<Cs2MarketEntry>>(
      stream: repository.watchAllEntries(),
      builder: (context, entriesSnapshot) {
        return StreamBuilder<List<Cs2MarketItem>>(
          stream: repository.watchTrackedItems(),
          builder: (context, itemsSnapshot) {
            if (!entriesSnapshot.hasData || !itemsSnapshot.hasData) {
              return Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: luma.accent,
                  ),
                ),
              );
            }

            final itemsByHash = {
              for (final item in itemsSnapshot.data!) item.marketHashName: item,
            };
            // An entry whose listing hasn't arrived on this stream tick yet
            // (the two streams update independently) is skipped rather than
            // shown half-built — the next emission fills it in immediately.
            final allRows = [
              for (final entry in entriesSnapshot.data!)
                if (itemsByHash[entry.marketHashName] case final item?)
                  _TrackedRow(entry: entry, item: item),
            ];

            if (allRows.isEmpty) {
              return LumaEmptyState(
                icon: Icons.star_border_rounded,
                title: 'Nothing tracked yet',
                subtitle: 'Track a listing from Browse to start watching its '
                    'price — it shows up here, alongside everything else you '
                    'track.',
              );
            }

            final trimmed = query.trim().toLowerCase();
            final rows = trimmed.isEmpty
                ? allRows
                : allRows
                    .where((r) =>
                        r.item.displayName.toLowerCase().contains(trimmed) ||
                        r.item.weaponName.toLowerCase().contains(trimmed) ||
                        r.item.rarityName.toLowerCase().contains(trimmed))
                    .toList();

            return StreamBuilder<List<Cs2MarketPricePoint>>(
              stream: repository.watchAllPriceHistory(),
              builder: (context, historySnapshot) {
                final allPoints = historySnapshot.data ?? const [];
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _PortfolioCard(
                      rows: allRows,
                      allPoints: allPoints,
                    ),
                    const SizedBox(height: 20),
                    if (rows.isEmpty)
                      LumaEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No tracked items match "$query"',
                        subtitle: 'Try a different weapon name or rarity.',
                      )
                    else
                      _TrackedGrid(rows: rows),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

/// The combined "how much is everything I'm tracking worth" chart, plus the
/// current total and the aggregate gain/loss across whichever tracked
/// copies have a starting price set.
class _PortfolioCard extends StatefulWidget {
  const _PortfolioCard({required this.rows, required this.allPoints});

  final List<_TrackedRow> rows;
  final List<Cs2MarketPricePoint> allPoints;

  @override
  State<_PortfolioCard> createState() => _PortfolioCardState();
}

class _PortfolioCardState extends State<_PortfolioCard> {
  Cs2PriceRange _range = Cs2PriceRange.week;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final series = buildCs2PortfolioSeries(
      widget.allPoints,
      [for (final r in widget.rows) r.entry],
      _range,
      DateTime.now(),
    );

    final currentTotal = widget.rows.fold<int>(
      0,
      (sum, r) => sum + (r.item.lastLowestCents ?? r.item.lastMedianCents ?? 0),
    );
    final withStart =
        widget.rows.where((r) => r.entry.startingPriceCents != null).toList();
    final startingTotal =
        withStart.fold<int>(0, (sum, r) => sum + r.entry.startingPriceCents!);
    final currentForStart = withStart.fold<int>(
      0,
      (sum, r) => sum +
          (r.item.lastLowestCents ??
              r.item.lastMedianCents ??
              r.entry.startingPriceCents!),
    );

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_rounded, size: 18, color: luma.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Total value',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatSteamPrice(currentTotal, 'USD'),
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.rows.length} cop'
                      '${widget.rows.length == 1 ? 'y' : 'ies'} tracked',
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (withStart.isNotEmpty)
                Cs2GainLossBadge(
                  deltaCents: currentForStart - startingTotal,
                  startingCents: startingTotal,
                  currency: 'USD',
                ),
            ],
          ),
          if (withStart.isNotEmpty && withStart.length < widget.rows.length) ...[
            const SizedBox(height: 6),
            Text(
              'Gain/loss covers the ${withStart.length} of '
              '${widget.rows.length} with a starting price set.',
              style: TextStyle(color: luma.textMuted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 16),
          LumaSegmentedTabs(
            tabs: [for (final r in Cs2PriceRange.values) r.label],
            selectedIndex: _range.index,
            onSelect: (i) => setState(() => _range = Cs2PriceRange.values[i]),
          ),
          const SizedBox(height: 16),
          Cs2PriceSeriesView(series: series),
        ],
      ),
    );
  }
}

/// Every tracked copy, grid-laid-out the same way the Browse catalog is —
/// two copies of the same listing get two tiles, since each has its own
/// starting price and gain/loss.
class _TrackedGrid extends StatelessWidget {
  const _TrackedGrid({required this.rows});

  final List<_TrackedRow> rows;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 290,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: rows.length,
      itemBuilder: (context, index) => _TrackedTile(row: rows[index]),
    );
  }
}

class _TrackedTile extends StatelessWidget {
  const _TrackedTile({required this.row});

  final _TrackedRow row;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final radius = BorderRadius.circular(decor.cardRadius);
    final item = row.item;
    final entry = row.entry;
    final priceCents = item.lastLowestCents ?? item.lastMedianCents;
    final starting = entry.startingPriceCents;

    return Material(
      color: luma.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Cs2ItemDetailPage(
              skinId: item.skinId,
              initialWear: item.wear,
              initialStatTrak: item.statTrak,
            ),
          ),
        ),
        child: Semantics(
          label: '${item.displayName}, ${_variantLabel(item)}, '
              '${priceCents == null ? 'not checked yet' : formatSteamPrice(priceCents, item.currency)}',
          button: true,
          excludeSemantics: true,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: luma.border, width: decor.borderWidth),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1.4,
                  child: Cs2ItemImage(url: item.imageUrl),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Cs2RarityChip(
                        name: item.rarityName,
                        colorHex: item.rarityColor,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _variantLabel(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: luma.textMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              priceCents == null
                                  ? 'Not checked yet'
                                  : formatSteamPrice(priceCents, item.currency),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: luma.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ),
                          if (starting != null && priceCents != null)
                            Cs2GainLossBadge(
                              deltaCents: priceCents - starting,
                              startingCents: starting,
                              currency: item.currency,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _variantLabel(Cs2MarketItem item) {
    final parts = <String>[
      if (item.wear != null) item.wear!,
      if (item.statTrak) 'StatTrak™',
    ];
    return parts.isEmpty ? 'No wear variants' : parts.join(' · ');
  }
}
