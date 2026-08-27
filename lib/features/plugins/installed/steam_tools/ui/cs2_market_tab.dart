import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../cs2_market_repository.dart';
import '../cs2_market_scope.dart';
import '../cs2_models.dart';
import 'cs2_item_detail_page.dart';
import 'cs2_shared.dart';

/// The CS2 Market tool: every CS2 item, browsable A–Z or narrowed by name,
/// rarity or case, with a pin to keep favourites at the top and a way into
/// each listing's Community Market price and history.
///
/// Unlike the game Price Tracker, this browses everything rather than
/// seeding a watchlist from a keyed API — the catalog behind it is a single
/// public dataset covering every skin at once (see `Cs2CatalogService`), so
/// there is no per-search network cost to spare and nothing gates the grid
/// on having searched or tracked anything first. What *is* rationed is
/// price checks: a tile shows no price at all, only once opened does its
/// listing get read from Steam, the same restraint the game tracker applies
/// to store pages.
class Cs2MarketTab extends StatefulWidget {
  const Cs2MarketTab({super.key});

  @override
  State<Cs2MarketTab> createState() => _Cs2MarketTabState();
}

class _Cs2MarketTabState extends State<Cs2MarketTab> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    Cs2MarketScope.of(context).loadCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = Cs2MarketScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          controller: _searchController,
          onQuery: (value) => setState(() => _query = value),
        ),
        ListenableBuilder(
          listenable: repository,
          builder: (context, _) {
            if (repository.catalogError case final message?) {
              return _InlineError(
                message: message,
                onDismiss: repository.clearError,
              );
            }
            if (repository.error case final message?) {
              return _InlineError(
                message: message,
                onDismiss: repository.clearError,
              );
            }
            return const SizedBox.shrink();
          },
        ),
        ListenableBuilder(
          listenable: repository,
          builder: (context, _) => repository.refreshingPrices
              ? _PriceRefreshBar(repository: repository)
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: repository,
            builder: (context, _) {
              if (!repository.catalogLoaded) {
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
              final trimmed = _query.trim();
              if (trimmed.isEmpty) {
                return _BrowseBody(repository: repository);
              }
              // A single letter matches a huge share of a 2000+ item
              // catalog — "a" alone turns up hundreds of skins, which reads
              // as "search is broken and just dumped everything" rather
              // than a real narrowing. Waiting for a second character keeps
              // every real search fast (it's all in memory) while giving
              // the list something to actually be short over.
              if (trimmed.length < 2) {
                return const _ShortQueryHint();
              }
              return _SearchBody(query: trimmed, repository: repository);
            },
          ),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller, required this.onQuery});

  final TextEditingController controller;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = Cs2MarketScope.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: luma.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'CS2 Market',
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    ListenableBuilder(
                      listenable: repository,
                      builder: (context, _) => Text(
                        _subtitle(repository),
                        style:
                            TextStyle(color: luma.textMuted, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ListenableBuilder(
                listenable: repository,
                builder: (context, _) => LumaGhostButton(
                  label: repository.catalogLoading
                      ? 'Updating…'
                      : 'Refresh catalog',
                  icon: Icons.sync_rounded,
                  onTap: repository.catalogLoading
                      ? null
                      : () => repository.refreshCatalog(force: true),
                ),
              ),
              const SizedBox(width: 8),
              ListenableBuilder(
                listenable: repository,
                builder: (context, _) => LumaGhostButton(
                  label: repository.refreshingPrices
                      ? 'Checking…'
                      : 'Refresh prices',
                  icon: Icons.price_change_rounded,
                  onTap: repository.refreshingPrices
                      ? null
                      : repository.refreshAllPrices,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: TextField(
              controller: controller,
              onChanged: onQuery,
              style: TextStyle(color: luma.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search any CS2 item — name, weapon, rarity, case',
                hintStyle: TextStyle(color: luma.textMuted, fontSize: 13),
                prefixIcon:
                    Icon(Icons.search_rounded, size: 18, color: luma.textMuted),
                filled: true,
                fillColor: luma.surface,
                contentPadding: EdgeInsets.zero,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: luma.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: luma.accent),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: luma.border),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _subtitle(Cs2MarketRepository repository) {
    if (repository.catalogLoading && repository.catalogSize == 0) {
      return 'Loading the item catalog…';
    }
    final count = repository.catalogSize;
    if (count == 0) return 'Item catalog not loaded yet.';
    final at = repository.catalogFetchedAt;
    if (at == null) return '$count items catalogued.';
    final ago = DateTime.now().difference(at);
    final freshness = ago.inDays >= 1
        ? 'updated ${ago.inDays}d ago'
        : ago.inHours >= 1
            ? 'updated ${ago.inHours}h ago'
            : 'updated just now';
    return '$count items catalogued, $freshness.';
  }
}

class _PriceRefreshBar extends StatelessWidget {
  const _PriceRefreshBar({required this.repository});

  final Cs2MarketRepository repository;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final total = repository.priceTotal;
    final done = repository.priceChecked;
    final progress = total == 0 ? 0.0 : done / total;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      color: luma.accentSubtle,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Checking prices — $done of $total',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: luma.border,
                    valueColor: AlwaysStoppedAnimation(luma.accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          LumaGhostButton(
            label: 'Stop',
            icon: Icons.stop_rounded,
            onTap: repository.cancelPriceRefresh,
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
        color: luma.danger.withValues(alpha: 0.12),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 16, color: luma.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: luma.textPrimary, fontSize: 12),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: Icon(Icons.close_rounded, size: 16, color: luma.textMuted),
              tooltip: 'Dismiss',
            ),
          ],
        ),
      ),
    );
  }
}

/// Puts pinned skins first, otherwise leaving the incoming order (already
/// A–Z from the catalog, or already relevance-ordered from a search) alone.
List<Cs2SkinDef> _pinnedFirst(List<Cs2SkinDef> items, Set<String> pinned) {
  if (pinned.isEmpty) return items;
  final pinnedItems = <Cs2SkinDef>[];
  final rest = <Cs2SkinDef>[];
  for (final item in items) {
    (pinned.contains(item.id) ? pinnedItems : rest).add(item);
  }
  return [...pinnedItems, ...rest];
}

/// The empty-query view: the whole catalog, A–Z, pinned skins first — there
/// is always something to look at here, never a prompt to search first.
class _BrowseBody extends StatelessWidget {
  const _BrowseBody({required this.repository});

  final Cs2MarketRepository repository;

  @override
  Widget build(BuildContext context) {
    if (repository.catalog.isEmpty) {
      return LumaEmptyState(
        icon: Icons.diamond_outlined,
        title: 'Catalog is empty',
        subtitle: 'Refresh the catalog to load every CS2 item.',
      );
    }
    return StreamBuilder<Set<String>>(
      stream: repository.watchPinnedSkinIds(),
      builder: (context, snapshot) {
        final pinned = snapshot.data ?? const <String>{};
        final items = _pinnedFirst(repository.catalog, pinned);
        return _ItemGrid(
          itemCount: items.length,
          tileBuilder: (context, index) => _CatalogTile(
            skin: items[index],
            pinned: pinned.contains(items[index].id),
          ),
        );
      },
    );
  }
}

/// Shown for a single-character query — too short to narrow a 2000+ item
/// catalog to anything useful.
class _ShortQueryHint extends StatelessWidget {
  const _ShortQueryHint();

  @override
  Widget build(BuildContext context) {
    return LumaEmptyState(
      icon: Icons.keyboard_rounded,
      title: 'Keep typing',
      subtitle: 'One letter matches too much of the catalog to be useful — '
          'a couple more will narrow it down.',
    );
  }
}

/// The search-query view: a live filter over the whole catalog, pinned
/// matches still surfaced first.
class _SearchBody extends StatelessWidget {
  const _SearchBody({required this.query, required this.repository});

  final String query;
  final Cs2MarketRepository repository;

  @override
  Widget build(BuildContext context) {
    final results = repository.search(query);
    if (results.isEmpty) {
      return LumaEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No items match "$query"',
        subtitle: 'Try a weapon name, a rarity like "Covert", or a case '
            'name.',
      );
    }
    return StreamBuilder<Set<String>>(
      stream: repository.watchPinnedSkinIds(),
      builder: (context, snapshot) {
        final pinned = snapshot.data ?? const <String>{};
        final items = _pinnedFirst(results, pinned);
        return _ItemGrid(
          itemCount: items.length,
          tileBuilder: (context, index) => _CatalogTile(
            skin: items[index],
            pinned: pinned.contains(items[index].id),
          ),
        );
      },
    );
  }
}

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({required this.itemCount, required this.tileBuilder});

  final int itemCount;
  final Widget Function(BuildContext, int) tileBuilder;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 252,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: itemCount,
      itemBuilder: tileBuilder,
    );
  }
}

class _CatalogTile extends StatefulWidget {
  const _CatalogTile({required this.skin, required this.pinned});

  final Cs2SkinDef skin;
  final bool pinned;

  @override
  State<_CatalogTile> createState() => _CatalogTileState();
}

class _CatalogTileState extends State<_CatalogTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final skin = widget.skin;
    final pinned = widget.pinned;
    final radius = BorderRadius.circular(decor.cardRadius);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onSecondaryTapDown: (details) =>
            _showPinMenu(context, details.globalPosition, skin, pinned),
        child: Material(
          color: _hovering ? luma.surfaceHover : luma.surface,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Cs2ItemDetailPage(skinId: skin.id),
              ),
            ),
            onLongPress: () => _showPinMenu(context, null, skin, pinned),
            child: Semantics(
              label: '${skin.name}, ${skin.rarityName}. '
                  '${skin.caseName == null ? 'No case' : 'From ${skin.caseName}'}'
                  '${pinned ? '. Pinned' : ''}',
              button: true,
              excludeSemantics: true,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: _hovering ? luma.accent : luma.border,
                    width: decor.borderWidth,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 1.4,
                          child: Cs2ItemImage(url: skin.imageUrl),
                        ),
                        if (pinned)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: luma.accentSubtle,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.push_pin_rounded,
                                  size: 13, color: luma.accent),
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            skin.name,
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
                            name: skin.rarityName,
                            colorHex: skin.rarityColor,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            skin.caseName ?? 'No case',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: luma.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Right-click (desktop) or long-press (touch) menu for pinning a skin —
/// mirrors the pin/unpin context menu already used for chat conversations
/// (`chat_page.dart`) rather than adding a second always-visible icon button
/// to an already dense grid tile. [globalPosition] anchors the menu at the
/// click point; pass null (long-press has no useful point) to centre it.
Future<void> _showPinMenu(
  BuildContext context,
  Offset? globalPosition,
  Cs2SkinDef skin,
  bool pinned,
) async {
  final luma = context.luma;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final anchor = globalPosition ?? overlay.size.center(Offset.zero);
  final position = RelativeRect.fromRect(
    Rect.fromPoints(anchor, anchor),
    Offset.zero & overlay.size,
  );

  final action = await showMenu<String>(
    context: context,
    position: position,
    color: luma.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: luma.border),
    ),
    items: [
      PopupMenuItem(
        value: 'pin',
        child: Text(pinned ? 'Unpin' : 'Pin to top'),
      ),
    ],
  );
  if (action == 'pin' && context.mounted) {
    Cs2MarketScope.of(context).togglePin(skin.id, pinned: pinned);
  }
}
