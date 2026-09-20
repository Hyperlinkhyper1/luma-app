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

/// The CS2 Market's "Tracked" view: every listing being watched, plus one
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

    return StreamBuilder<List<Cs2MarketItem>>(
      stream: repository.watchTrackedItems(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
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

        final allItems = snapshot.data!;
        if (allItems.isEmpty) {
          return LumaEmptyState(
            icon: Icons.star_border_rounded,
            title: 'Nothing tracked yet',
            subtitle: 'Track a listing from Browse to start watching its '
                'price — it shows up here, alongside everything else you '
                'track.',
          );
        }

        final trimmed = query.trim().toLowerCase();
        final items = trimmed.isEmpty
            ? allItems
            : allItems
                .where((i) =>
                    i.displayName.toLowerCase().contains(trimmed) ||
                    i.weaponName.toLowerCase().contains(trimmed) ||
                    i.rarityName.toLowerCase().contains(trimmed))
                .toList();

        return StreamBuilder<List<Cs2MarketPricePoint>>(
          stream: repository.watchAllPriceHistory(),
          builder: (context, historySnapshot) {
            final allPoints = historySnapshot.data ?? const [];
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _PortfolioCard(items: allItems, allPoints: allPoints),
                const SizedBox(height: 20),
                if (items.isEmpty)
                  LumaEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No tracked items match "$query"',
                    subtitle: 'Try a different weapon name or rarity.',
                  )
                else
                  _TrackedGrid(items: items),
              ],
            );
          },
        );
      },
    );
  }
}

/// The combined "how much is everything I'm tracking worth" chart, plus the
/// current total and the aggregate gain/loss across whichever tracked items
/// have a starting price set.
class _PortfolioCard extends StatefulWidget {
  const _PortfolioCard({required this.items, required this.allPoints});

  final List<Cs2MarketItem> items;
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
      _range,
      DateTime.now(),
    );

    final currentTotal = widget.items.fold<int>(
      0,
      (sum, i) => sum + (i.lastLowestCents ?? i.lastMedianCents ?? 0),
    );
    final withStart =
        widget.items.where((i) => i.startingPriceCents != null).toList();
    final startingTotal =
        withStart.fold<int>(0, (sum, i) => sum + i.startingPriceCents!);
    final currentForStart = withStart.fold<int>(
      0,
      (sum, i) =>
          sum + (i.lastLowestCents ?? i.lastMedianCents ?? i.startingPriceCents!),
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
                      '${widget.items.length} listing'
                      '${widget.items.length == 1 ? '' : 's'} tracked',
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
          if (withStart.isNotEmpty && withStart.length < widget.items.length) ...[
            const SizedBox(height: 6),
            Text(
              'Gain/loss covers the ${withStart.length} of '
              '${widget.items.length} with a starting price set.',
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

/// Every tracked listing, grid-laid-out the same way the Browse catalog is.
class _TrackedGrid extends StatelessWidget {
  const _TrackedGrid({required this.items});

  final List<Cs2MarketItem> items;

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
      itemCount: items.length,
      itemBuilder: (context, index) => _TrackedTile(item: items[index]),
    );
  }
}

class _TrackedTile extends StatelessWidget {
  const _TrackedTile({required this.item});

  final Cs2MarketItem item;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final radius = BorderRadius.circular(decor.cardRadius);
    final priceCents = item.lastLowestCents ?? item.lastMedianCents;
    final starting = item.startingPriceCents;

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
