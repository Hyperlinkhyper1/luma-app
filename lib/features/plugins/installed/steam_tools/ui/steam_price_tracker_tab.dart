import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/steam_database.dart';
import '../steam_models.dart';
import '../steam_price_history.dart';
import '../steam_scope.dart';
import 'steam_connect_view.dart';
import 'steam_game_detail_page.dart';

/// How the library grid is ordered.
enum _LibrarySort {
  name('A–Z'),
  playtime('Playtime'),
  price('Price');

  const _LibrarySort(this.label);
  final String label;
}

/// The Price Tracker: every game on the account, and a way into each one's
/// price history.
class SteamPriceTrackerTab extends StatefulWidget {
  const SteamPriceTrackerTab({super.key});

  @override
  State<SteamPriceTrackerTab> createState() => _SteamPriceTrackerTabState();
}

class _SteamPriceTrackerTabState extends State<SteamPriceTrackerTab> {
  final _searchController = TextEditingController();
  String _query = '';
  _LibrarySort _sort = _LibrarySort.name;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The scope is not readable from initState — this is the first frame
    // where the repository exists.
    if (_started) return;
    _started = true;
    SteamScope.of(context).load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = SteamScope.of(context);

    if (!repository.loaded) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: luma.accent),
        ),
      );
    }
    if (!repository.connected) return const SteamConnectView();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          controller: _searchController,
          sort: _sort,
          onQuery: (value) => setState(() => _query = value),
          onSort: (value) => setState(() => _sort = value),
        ),
        if (repository.error case final message?)
          _InlineError(
            message: message,
            onDismiss: repository.clearError,
          ),
        if (repository.refreshingPrices) const _PriceRefreshBar(),
        Expanded(
          child: StreamData<List<SteamGame>>(
            stream: repository.watchLibrary(),
            builder: (context, games) {
              final visible = _filterAndSort(games);
              if (games.isEmpty) {
                return LumaEmptyState(
                  icon: Icons.videogame_asset_off_rounded,
                  title: 'No games in your library yet',
                  subtitle:
                      'Refresh to read your library from Steam again.',
                  action: LumaPrimaryButton(
                    label: 'Refresh library',
                    icon: Icons.refresh_rounded,
                    loading: repository.syncing,
                    onTap: repository.syncing
                        ? null
                        : repository.refreshLibrary,
                  ),
                );
              }
              if (visible.isEmpty) {
                return LumaEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No games match "$_query"',
                  subtitle: 'Try a shorter search.',
                );
              }
              return _GameGrid(games: visible);
            },
          ),
        ),
      ],
    );
  }

  List<SteamGame> _filterAndSort(List<SteamGame> games) {
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? [...games]
        : [
            for (final game in games)
              if (game.name.toLowerCase().contains(query)) game,
          ];

    switch (_sort) {
      case _LibrarySort.name:
        filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _LibrarySort.playtime:
        filtered.sort((a, b) => b.playtimeMinutes.compareTo(a.playtimeMinutes));
      case _LibrarySort.price:
        // Games with no price yet sort last rather than as free.
        filtered.sort((a, b) {
          final ap = a.lastPriceCents;
          final bp = b.lastPriceCents;
          if (ap == null && bp == null) {
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
          if (ap == null) return 1;
          if (bp == null) return -1;
          return bp.compareTo(ap);
        });
    }
    return filtered;
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.sort,
    required this.onQuery,
    required this.onSort,
  });

  final TextEditingController controller;
  final _LibrarySort sort;
  final ValueChanged<String> onQuery;
  final ValueChanged<_LibrarySort> onSort;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = SteamScope.of(context);

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
                      'Price Tracker',
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(repository.lastSyncAt),
                      style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              LumaGhostButton(
                label: 'Refresh library',
                icon: Icons.sync_rounded,
                onTap: repository.syncing ? null : repository.refreshLibrary,
              ),
              const SizedBox(width: 8),
              LumaPrimaryButton(
                label: repository.refreshingPrices
                    ? 'Checking…'
                    : 'Refresh prices',
                icon: Icons.price_change_rounded,
                onTap: repository.refreshingPrices
                    ? null
                    : repository.refreshAllPrices,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: controller,
                    onChanged: onQuery,
                    style: TextStyle(color: luma.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search your library',
                      hintStyle:
                          TextStyle(color: luma.textMuted, fontSize: 13),
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
              ),
              const SizedBox(width: 12),
              LumaSegmentedTabs(
                tabs: [for (final s in _LibrarySort.values) s.label],
                selectedIndex: sort.index,
                onSelect: (i) => onSort(_LibrarySort.values[i]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _subtitle(DateTime? lastSyncAt) {
    if (lastSyncAt == null) return 'Your Steam library, with recorded prices.';
    final ago = DateTime.now().difference(lastSyncAt);
    if (ago.inMinutes < 1) return 'Library synced just now.';
    if (ago.inHours < 1) return 'Library synced ${ago.inMinutes} min ago.';
    if (ago.inDays < 1) return 'Library synced ${ago.inHours} h ago.';
    return 'Library synced ${ago.inDays} d ago.';
  }
}

/// Progress for a full price sweep, which is deliberately slow — see the
/// spacing constant in `SteamRepository`.
class _PriceRefreshBar extends StatelessWidget {
  const _PriceRefreshBar();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = SteamScope.of(context);
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

class _GameGrid extends StatelessWidget {
  const _GameGrid({required this.games});

  final List<SteamGame> games;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      // A fixed tile height keeps every capsule the same size regardless of
      // how long the game's name is, so the grid stays on a rhythm.
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisExtent: 224,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: games.length,
      itemBuilder: (context, index) => _GameTile(game: games[index]),
    );
  }
}

class _GameTile extends StatefulWidget {
  const _GameTile({required this.game});

  final SteamGame game;

  @override
  State<_GameTile> createState() => _GameTileState();
}

class _GameTileState extends State<_GameTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final game = widget.game;
    final radius = BorderRadius.circular(decor.cardRadius);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Material(
        color: _hovering ? luma.surfaceHover : luma.surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SteamGameDetailPage(appId: game.appId),
            ),
          ),
          child: Semantics(
            label: '${game.name}. ${_priceSemantics(game)}',
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
                  Expanded(
                    child: _Capsule(
                      url: game.headerImage ?? steamHeaderImage(game.appId),
                      name: game.name,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          game.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: _TilePrice(game: game)),
                            Text(
                              _playtimeLabel(game.playtimeMinutes),
                              style: TextStyle(
                                color: luma.textMuted,
                                fontSize: 11,
                              ),
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
      ),
    );
  }

  static String _priceSemantics(SteamGame game) {
    if (game.isFree) return 'Free to play.';
    final price = game.lastPriceCents;
    if (price == null) return 'Price not checked yet.';
    return 'Costs ${formatSteamPrice(price, game.currency ?? 'USD')}.';
  }
}

class _TilePrice extends StatelessWidget {
  const _TilePrice({required this.game});

  final SteamGame game;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    if (game.isFree) {
      return Text(
        'Free to play',
        style: TextStyle(
          color: luma.success,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final price = game.lastPriceCents;
    if (price == null) {
      return Text(
        'Not checked yet',
        style: TextStyle(color: luma.textMuted, fontSize: 12),
      );
    }

    final currency = game.currency ?? 'USD';
    final discount = game.lastDiscountPercent ?? 0;
    return Row(
      children: [
        if (discount > 0) ...[
          _DiscountBadge(percent: discount),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            formatSteamPrice(price, currency),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// The discount marker carries its own "-40%" text, so the saving is legible
/// without relying on the green fill alone.
class _DiscountBadge extends StatelessWidget {
  const _DiscountBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: luma.success.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '-$percent%',
        style: TextStyle(
          color: luma.success,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// The wide store capsule, with a placeholder that holds the same box so the
/// grid does not reflow as images arrive.
class _Capsule extends StatelessWidget {
  const _Capsule({required this.url, required this.name});

  final String url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Image.network(
      url,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : ColoredBox(color: luma.background),
      errorBuilder: (context, _, _) => Container(
        color: luma.background,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: Icon(
          Icons.videogame_asset_rounded,
          color: luma.textMuted,
          size: 26,
        ),
      ),
    );
  }
}

String _playtimeLabel(int minutes) {
  if (minutes <= 0) return 'Unplayed';
  if (minutes < 60) return '$minutes min';
  final hours = minutes / 60;
  if (hours < 10) return '${hours.toStringAsFixed(1)} h';
  return '${hours.round()} h';
}
