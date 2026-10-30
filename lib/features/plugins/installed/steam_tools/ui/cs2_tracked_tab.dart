import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../cs2_market_repository.dart';
import '../cs2_price_history.dart';
import '../data/steam_database.dart';
import '../steam_price_history.dart' show formatSteamPrice;
import 'cs2_item_detail_page.dart';
import 'cs2_price_chart.dart';
import 'cs2_shared.dart';
import 'cs2_starting_price_dialog.dart';

/// Every tracked copy of one listing, joined with that listing's shared
/// metadata and price — what one tile renders. [Cs2MarketEntry] alone has
/// no name, image or current price; those live once on [Cs2MarketItem].
class _TrackedGroup {
  const _TrackedGroup({required this.item, required this.entries});

  final Cs2MarketItem item;
  final List<Cs2MarketEntry> entries;

  int? get priceCents => item.lastLowestCents ?? item.lastMedianCents;
  int get totalCents => (priceCents ?? 0) * entries.length;
}

/// The CS2 Market's "Tracked" view: every listing being watched, plus one
/// combined total-value chart across all of them.
///
/// Copies of the same listing share one tile with a ×N count — a linked
/// inventory can hold hundreds of one case or sticker, and a tile per copy
/// would bury everything else. The grid is built lazily so an inventory of
/// any size scrolls as smoothly as a handful of items.
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
    final t = L.of(context);

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
            final entriesByHash = <String, List<Cs2MarketEntry>>{};
            for (final entry in entriesSnapshot.data!) {
              if (!itemsByHash.containsKey(entry.marketHashName)) continue;
              (entriesByHash[entry.marketHashName] ??= []).add(entry);
            }
            final allGroups = [
              for (final MapEntry(key: hash, value: entries)
                  in entriesByHash.entries)
                _TrackedGroup(item: itemsByHash[hash]!, entries: entries),
            ]..sort((a, b) {
                final byValue = b.totalCents.compareTo(a.totalCents);
                return byValue != 0
                    ? byValue
                    : a.item.displayName.compareTo(b.item.displayName);
              });

            if (allGroups.isEmpty) {
              return LumaEmptyState(
                icon: Icons.star_border_rounded,
                title: t.cs2TrackedEmptyTitle,
                subtitle: t.cs2TrackedEmptySubtitle,
              );
            }

            final trimmed = query.trim().toLowerCase();
            final groups = trimmed.isEmpty
                ? allGroups
                : allGroups
                    .where((g) =>
                        g.item.displayName.toLowerCase().contains(trimmed) ||
                        g.item.weaponName.toLowerCase().contains(trimmed) ||
                        g.item.rarityName.toLowerCase().contains(trimmed))
                    .toList();

            return StreamBuilder<List<Cs2MarketPricePoint>>(
              stream: repository.watchAllPriceHistory(),
              builder: (context, historySnapshot) {
                final allPoints = historySnapshot.data ?? const [];
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      sliver: SliverToBoxAdapter(
                        child: _PortfolioCard(
                          groups: allGroups,
                          allPoints: allPoints,
                        ),
                      ),
                    ),
                    if (groups.isEmpty)
                      SliverToBoxAdapter(
                        child: LumaEmptyState(
                          icon: Icons.search_off_rounded,
                          title: t.cs2TrackedNoMatchTitle(query),
                          subtitle: t.cs2TrackedNoMatchSubtitle,
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        sliver: SliverGrid.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            mainAxisExtent: 290,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: groups.length,
                          itemBuilder: (context, index) => _TrackedTile(
                            group: groups[index],
                            repository: repository,
                          ),
                        ),
                      ),
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
  const _PortfolioCard({required this.groups, required this.allPoints});

  final List<_TrackedGroup> groups;
  final List<Cs2MarketPricePoint> allPoints;

  @override
  State<_PortfolioCard> createState() => _PortfolioCardState();
}

class _PortfolioCardState extends State<_PortfolioCard> {
  Cs2PriceRange _range = Cs2PriceRange.week;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final entries = [for (final g in widget.groups) ...g.entries];
    final series = buildCs2PortfolioSeries(
      widget.allPoints,
      entries,
      _range,
      DateTime.now(),
    );

    final currentTotal =
        widget.groups.fold<int>(0, (sum, g) => sum + g.totalCents);
    var withStart = 0;
    var startingTotal = 0;
    var currentForStart = 0;
    for (final group in widget.groups) {
      for (final entry in group.entries) {
        final start = entry.startingPriceCents;
        if (start == null) continue;
        withStart++;
        startingTotal += start;
        currentForStart += group.priceCents ?? start;
      }
    }

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
                  t.cs2TrackedTotalValue,
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
                      t.cs2TrackedCopiesTracked(entries.length),
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (withStart > 0)
                Cs2GainLossBadge(
                  deltaCents: currentForStart - startingTotal,
                  startingCents: startingTotal,
                  currency: 'USD',
                ),
            ],
          ),
          if (withStart > 0 && withStart < entries.length) ...[
            const SizedBox(height: 6),
            Text(
              t.cs2TrackedGainLossCoverage(withStart, entries.length),
              style: TextStyle(color: luma.textMuted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 16),
          LumaSegmentedTabs(
            tabs: [
              for (final r in Cs2PriceRange.values)
                r == Cs2PriceRange.all ? t.cs2RangeAll : r.label,
            ],
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

class _TrackedTile extends StatelessWidget {
  const _TrackedTile({required this.group, required this.repository});

  final _TrackedGroup group;
  final Cs2MarketRepository repository;

  /// One copy's cost, or — for a stack of identical items such as cases —
  /// the same per-copy cost on every copy at once.
  Future<void> _editCost(BuildContext context) async {
    final t = L.of(context);
    final single = group.entries.length == 1;
    final result = await showCs2StartingPriceDialog(
      context,
      title: single ? t.cs2TrackedSetCost : t.cs2TrackedSetCostEach,
      subtitle: group.item.displayName,
      wears: const [],
      wear: group.item.wear,
      wearEditable: false,
      suggestedCents: group.entries.first.startingPriceCents,
    );
    if (result == null) return;
    for (final entry in group.entries) {
      await repository.setEntryStartingPrice(entry.id, result.priceCents);
    }
  }

  Future<void> _removeAll() async {
    for (final entry in group.entries) {
      await repository.untrackEntry(entry.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final radius = BorderRadius.circular(decor.cardRadius);
    final item = group.item;
    final count = group.entries.length;
    final priceCents = group.priceCents;
    final starts = [
      for (final e in group.entries) ?e.startingPriceCents,
    ];
    final startingTotal = starts.fold<int>(0, (sum, s) => sum + s);
    final t = L.of(context);

    return Material(
      color: luma.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (!repository.catalog.any((skin) => skin.id == item.skinId)) {
            _editCost(context);
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Cs2ItemDetailPage(
                skinId: item.skinId,
                initialWear: item.wear,
                initialStatTrak: item.statTrak,
              ),
            ),
          );
        },
        child: Semantics(
          label: '${item.displayName}, ${_variantLabel(t, item)}, '
              '${count > 1 ? '${t.cs2TrackedQuantity(count)}, ' : ''}'
              '${priceCents == null ? t.steamPriceNotChecked : formatSteamPrice(priceCents, item.currency)}',
          button: true,
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Cs2ItemImage(url: item.imageUrl),
                      if (count > 1)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: luma.accent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              t.cs2TrackedQuantity(count),
                              style: TextStyle(
                                color: luma.onAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: PopupMenuButton<String>(
                          tooltip: 'Item actions',
                          onSelected: (action) {
                            switch (action) {
                              case 'cost':
                                _editCost(context);
                              case 'remove':
                                repository.untrackEntry(group.entries.last.id);
                              case 'removeAll':
                                _removeAll();
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'cost',
                              child: Text(count == 1
                                  ? t.cs2TrackedSetCost
                                  : t.cs2TrackedSetCostEach),
                            ),
                            PopupMenuItem(
                              value: 'remove',
                              child: Text(count == 1
                                  ? t.cs2TrackedRemove
                                  : t.cs2TrackedRemoveOne),
                            ),
                            if (count > 1)
                              PopupMenuItem(
                                value: 'removeAll',
                                child: Text(t.cs2TrackedRemoveAll(count)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                      if (item.rarityName.isNotEmpty)
                        Cs2RarityChip(
                          name: item.rarityName,
                          colorHex: item.rarityColor,
                        ),
                      const SizedBox(height: 6),
                      Text(
                        _variantLabel(t, item),
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
                                  ? t.steamPriceNotChecked
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
                          if (starts.isNotEmpty && priceCents != null)
                            Cs2GainLossBadge(
                              deltaCents:
                                  priceCents * starts.length - startingTotal,
                              startingCents: startingTotal,
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

  /// Wear and StatTrak for a skin; Steam's item type ("Sticker",
  /// "Container") for everything the skin catalog doesn't cover.
  static String _variantLabel(L t, Cs2MarketItem item) {
    final parts = <String>[
      if (item.wear != null) item.wear!,
      if (item.statTrak) 'StatTrak™',
    ];
    if (parts.isNotEmpty) return parts.join(' · ');
    if (item.skinId.startsWith('steam:') && item.weaponName.isNotEmpty) {
      return item.weaponName;
    }
    return t.cs2NoWearVariants;
  }
}
