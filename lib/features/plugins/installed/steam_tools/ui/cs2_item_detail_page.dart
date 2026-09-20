import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../cs2_market_api.dart';
import '../cs2_market_scope.dart';
import '../cs2_models.dart';
import '../data/steam_database.dart';
import '../steam_price_history.dart' show formatSteamPrice;
import 'cs2_price_chart.dart';
import 'cs2_shared.dart';
import 'cs2_starting_price_dialog.dart';

/// One CS2 listing: its render, rarity, the case it drops from, its current
/// Community Market price, and — once tracked — the history luma has built
/// for it.
///
/// A "listing" is a specific combination of finish, wear and StatTrak
/// state; [initialWear]/[initialStatTrak] preselect one when arriving from
/// an already-tracked tile, and the selectors below let it change to any
/// other variant the same finish ships in.
class Cs2ItemDetailPage extends StatefulWidget {
  const Cs2ItemDetailPage({
    super.key,
    required this.skinId,
    this.initialWear,
    this.initialStatTrak = false,
  });

  final String skinId;
  final String? initialWear;
  final bool initialStatTrak;

  @override
  State<Cs2ItemDetailPage> createState() => _Cs2ItemDetailPageState();
}

class _Cs2ItemDetailPageState extends State<Cs2ItemDetailPage> {
  bool _started = false;
  Cs2SkinDef? _skin;
  String? _wear;
  bool _statTrak = false;

  String? _autoCheckedHash;
  Cs2MarketPrice? _transientPrice;
  bool _transientLoading = false;
  String? _transientError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final repository = Cs2MarketScope.of(context);
    final skin = repository.skinById(widget.skinId);
    _skin = skin;
    if (skin != null) {
      _wear = widget.initialWear ??
          (skin.wears.isNotEmpty ? skin.wears.first : null);
      _statTrak = skin.stattrak && widget.initialStatTrak;
      _autoCheck();
    }
  }

  String get _hash {
    final skin = _skin!;
    return cs2MarketHashName(
      baseName: skin.name,
      wear: _wear,
      statTrak: _statTrak,
    );
  }

  Future<void> _autoCheck() async {
    final hash = _hash;
    if (_autoCheckedHash == hash) return;
    _autoCheckedHash = hash;
    final repository = Cs2MarketScope.of(context);
    final tracked = await repository.isTracked(hash);
    if (!mounted || hash != _hash) return;
    if (tracked) {
      repository.refreshPrice(hash);
    } else {
      _checkTransient(force: false);
    }
  }

  Future<void> _checkTransient({required bool force}) async {
    final hash = _hash;
    setState(() {
      _transientLoading = true;
      _transientError = null;
    });
    final repository = Cs2MarketScope.of(context);
    final price = await repository.checkPriceOnce(hash);
    if (!mounted || hash != _hash) return;
    setState(() {
      _transientPrice = price;
      _transientLoading = false;
      if (price == null) _transientError = repository.error;
    });
  }

  void _onWearChanged(String? wear) {
    setState(() {
      _wear = wear;
      _transientPrice = null;
      _transientError = null;
    });
    _autoCheck();
  }

  void _onStatTrakChanged(bool value) {
    setState(() {
      _statTrak = value;
      _transientPrice = null;
      _transientError = null;
    });
    _autoCheck();
  }

  Future<void> _track() async {
    final skin = _skin!;
    final result = await showCs2StartingPriceDialog(
      context,
      title: 'Track this listing',
      subtitle: 'Pick the grade, and the price to measure gain and loss '
          'from.',
      wears: skin.wears,
      wear: _wear,
      wearEditable: skin.wears.length > 1,
      suggestedCents: _transientPrice?.lowestCents ?? _transientPrice?.medianCents,
    );
    if (result == null || !mounted) return;
    setState(() {
      _wear = result.wear;
      _transientPrice = null;
      _transientError = null;
    });
    await Cs2MarketScope.of(context).track(
      skin: skin,
      wear: result.wear,
      statTrak: _statTrak,
      startingPriceCents: result.priceCents,
    );
  }

  Future<void> _untrack(String hash) async {
    await Cs2MarketScope.of(context).untrack(hash);
    _autoCheckedHash = null;
    _autoCheck();
  }

  Future<void> _editStartingPrice(Cs2MarketItem row) async {
    final result = await showCs2StartingPriceDialog(
      context,
      title: row.startingPriceCents == null
          ? 'Set starting price'
          : 'Edit starting price',
      subtitle: 'The price gain and loss on the chart below is measured '
          'from.',
      wears: const [],
      wear: row.wear,
      wearEditable: false,
      suggestedCents:
          row.startingPriceCents ?? row.lastLowestCents ?? row.lastMedianCents,
    );
    if (result == null || !mounted) return;
    await Cs2MarketScope.of(context)
        .setStartingPrice(row.marketHashName, result.priceCents);
  }

  Future<void> _clearStartingPrice(String hash) async {
    await Cs2MarketScope.of(context).setStartingPrice(hash, null);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final skin = _skin;

    if (skin == null) {
      return Scaffold(
        backgroundColor: luma.background,
        body: Stack(
          children: [
            Center(
              child: LumaEmptyState(
                icon: Icons.search_off_rounded,
                title: 'Item not found',
                subtitle: 'It may have dropped out of the last catalog '
                    'update — try refreshing the catalog.',
              ),
            ),
            const _BackButton(),
          ],
        ),
      );
    }

    final repository = Cs2MarketScope.of(context);
    final hash = _hash;

    return Scaffold(
      backgroundColor: luma.background,
      body: StreamBuilder<Cs2MarketItem?>(
        stream: repository.watchItem(hash),
        builder: (context, snapshot) {
          final trackedRow = snapshot.data;
          final tracked = trackedRow != null;
          return _DetailBody(
            skin: skin,
            wear: _wear,
            statTrak: _statTrak,
            hash: hash,
            tracked: tracked,
            trackedRow: trackedRow,
            transientPrice: _transientPrice,
            transientLoading: _transientLoading,
            transientError: _transientError,
            onWearChanged: skin.wears.length > 1 ? _onWearChanged : null,
            onStatTrakChanged: skin.stattrak ? _onStatTrakChanged : null,
            onCheckNow: () => tracked
                ? repository.refreshPrice(hash, force: true)
                : _checkTransient(force: true),
            onTrack: _track,
            onUntrack: () => _untrack(hash),
            onEditStartingPrice:
                trackedRow == null ? null : () => _editStartingPrice(trackedRow),
            onClearStartingPrice: trackedRow?.startingPriceCents == null
                ? null
                : () => _clearStartingPrice(hash),
          );
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.skin,
    required this.wear,
    required this.statTrak,
    required this.hash,
    required this.tracked,
    required this.trackedRow,
    required this.transientPrice,
    required this.transientLoading,
    required this.transientError,
    required this.onWearChanged,
    required this.onStatTrakChanged,
    required this.onCheckNow,
    required this.onTrack,
    required this.onUntrack,
    required this.onEditStartingPrice,
    required this.onClearStartingPrice,
  });

  final Cs2SkinDef skin;
  final String? wear;
  final bool statTrak;
  final String hash;
  final bool tracked;
  final Cs2MarketItem? trackedRow;
  final Cs2MarketPrice? transientPrice;
  final bool transientLoading;
  final String? transientError;
  final ValueChanged<String?>? onWearChanged;
  final ValueChanged<bool>? onStatTrakChanged;
  final VoidCallback onCheckNow;
  final Future<void> Function() onTrack;
  final VoidCallback onUntrack;
  final VoidCallback? onEditStartingPrice;
  final VoidCallback? onClearStartingPrice;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final wide = media.size.width >= 900;
    final heroHeight = wide ? 300.0 : 240.0;

    final lowestCents = tracked ? trackedRow!.lastLowestCents : transientPrice?.lowestCents;
    final medianCents = tracked ? trackedRow!.lastMedianCents : transientPrice?.medianCents;
    final currency = tracked ? trackedRow!.currency : 'USD';
    final fetchedAt = tracked ? trackedRow!.priceFetchedAt : null;
    final loading = tracked ? false : transientLoading;
    final priceError = tracked ? null : transientError;

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.zero,
          children: [
            _Hero(skin: skin, height: heroHeight),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      wide ? 32 : 16, 0, wide ? 32 : 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (onWearChanged != null || onStatTrakChanged != null)
                        _VariantCard(
                          skin: skin,
                          wear: wear,
                          statTrak: statTrak,
                          onWearChanged: onWearChanged,
                          onStatTrakChanged: onStatTrakChanged,
                        ),
                      if (onWearChanged != null || onStatTrakChanged != null)
                        const SizedBox(height: 16),
                      _PriceCard(
                        lowestCents: lowestCents,
                        medianCents: medianCents,
                        currency: currency,
                        fetchedAt: fetchedAt,
                        loading: loading,
                        error: priceError,
                        tracked: tracked,
                        onCheckNow: onCheckNow,
                        onTrack: onTrack,
                        onUntrack: onUntrack,
                      ),
                      if (trackedRow case final row?) ...[
                        const SizedBox(height: 16),
                        _StartingPriceCard(
                          startingPriceCents: row.startingPriceCents,
                          startingPriceAt: row.startingPriceAt,
                          currentCents: lowestCents ?? medianCents,
                          currency: currency,
                          onEdit: onEditStartingPrice!,
                          onClear: onClearStartingPrice,
                        ),
                      ],
                      const SizedBox(height: 16),
                      StreamBuilder<List<Cs2MarketPricePoint>>(
                        stream: Cs2MarketScope.of(context)
                            .watchPriceHistory(hash),
                        builder: (context, snapshot) => Cs2PriceHistoryCard(
                          points: snapshot.data ?? const [],
                          fallbackCurrency: currency,
                          tracked: tracked,
                          startingPriceCents:
                              tracked ? trackedRow!.startingPriceCents : null,
                          loading: loading ||
                              snapshot.connectionState ==
                                  ConnectionState.waiting,
                          onTrack: tracked ? null : onTrack,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _FactsCard(skin: skin, hash: hash),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const _BackButton(),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.skin, required this.height});

  final Cs2SkinDef skin;
  final double height;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final rarity = parseCs2RarityColor(skin.rarityColor);

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  rarity.withValues(alpha: 0.28),
                  luma.background,
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 64, top: 24),
            child: skin.imageUrl.isEmpty
                ? Icon(Icons.inventory_2_outlined,
                    size: 80, color: luma.textMuted)
                : Image.network(
                    skin.imageUrl,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (context, _, _) => Icon(
                      Icons.inventory_2_outlined,
                      size: 80,
                      color: luma.textMuted,
                    ),
                  ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        skin.name,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          fontFamily: context.lumaDecor.displayFontFamily,
                          fontFamilyFallback:
                              context.lumaDecor.displayFontFallback,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Cs2RarityChip(
                        name: skin.rarityName,
                        colorHex: skin.rarityColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Positioned(
      top: 16,
      left: 16,
      child: Material(
        color: luma.rail.withValues(alpha: 0.82),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back to the market',
          icon: Icon(Icons.arrow_back_rounded, color: luma.textPrimary),
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        ),
      ),
    );
  }
}

/// Wear and StatTrak selectors — each one changes which exact listing
/// everything below is priced for.
class _VariantCard extends StatelessWidget {
  const _VariantCard({
    required this.skin,
    required this.wear,
    required this.statTrak,
    required this.onWearChanged,
    required this.onStatTrakChanged,
  });

  final Cs2SkinDef skin;
  final String? wear;
  final bool statTrak;
  final ValueChanged<String?>? onWearChanged;
  final ValueChanged<bool>? onStatTrakChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onWearChanged != null) ...[
            Text('Wear',
                style: TextStyle(color: luma.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            LumaSegmentedTabs(
              tabs: skin.wears,
              selectedIndex: wear == null ? 0 : skin.wears.indexOf(wear!),
              onSelect: (i) => onWearChanged!(skin.wears[i]),
              scrollable: true,
            ),
          ],
          if (onWearChanged != null && onStatTrakChanged != null)
            const SizedBox(height: 16),
          if (onStatTrakChanged != null) ...[
            Text('Variant',
                style: TextStyle(color: luma.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            LumaSegmentedTabs(
              tabs: const ['Normal', 'StatTrak™'],
              selectedIndex: statTrak ? 1 : 0,
              onSelect: (i) => onStatTrakChanged!(i == 1),
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.lowestCents,
    required this.medianCents,
    required this.currency,
    required this.fetchedAt,
    required this.loading,
    required this.error,
    required this.tracked,
    required this.onCheckNow,
    required this.onTrack,
    required this.onUntrack,
  });

  final int? lowestCents;
  final int? medianCents;
  final String currency;
  final DateTime? fetchedAt;
  final bool loading;
  final String? error;
  final bool tracked;
  final VoidCallback onCheckNow;
  final Future<void> Function() onTrack;
  final VoidCallback onUntrack;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final price = lowestCents ?? medianCents;

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Lowest listed',
                        style:
                            TextStyle(color: luma.textMuted, fontSize: 12)),
                    const SizedBox(height: 6),
                    if (price == null)
                      Text(
                        loading
                            ? 'Checking…'
                            : error != null
                                ? 'Could not check price'
                                : 'Not checked yet',
                        style: TextStyle(
                          color: luma.textSecondary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text(
                        formatSteamPrice(price, currency),
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    if (medianCents != null && lowestCents != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Median ${formatSteamPrice(medianCents!, currency)}',
                        style:
                            TextStyle(color: luma.textMuted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              LumaGhostButton(
                label: 'Check now',
                icon: Icons.refresh_rounded,
                onTap: loading ? null : onCheckNow,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 13, color: luma.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _statusLine(fetchedAt, tracked, error),
                  style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (tracked)
            LumaGhostButton(
              label: 'Stop tracking',
              icon: Icons.star_rounded,
              onTap: onUntrack,
            )
          else
            LumaPrimaryButton(
              label: 'Track this listing',
              icon: Icons.star_border_rounded,
              onTap: onTrack,
            ),
        ],
      ),
    );
  }

  static String _statusLine(DateTime? at, bool tracked, String? error) {
    if (error != null) return error;
    if (!tracked) {
      return 'A quick check, not saved — track this listing to keep a '
          'history of its price.';
    }
    if (at == null) return 'Not checked yet.';
    final ago = DateTime.now().difference(at);
    if (ago.inMinutes < 1) return 'Checked just now.';
    if (ago.inHours < 1) return 'Checked ${ago.inMinutes} min ago.';
    if (ago.inDays < 1) return 'Checked ${ago.inHours} h ago.';
    return 'Checked on ${DateFormat.yMMMd().format(at)}.';
  }
}

/// The manual cost basis gain/loss is measured from, plus how the current
/// price compares to it. Only ever shown for a tracked listing — an
/// untracked one has no row to hang a baseline off of.
class _StartingPriceCard extends StatelessWidget {
  const _StartingPriceCard({
    required this.startingPriceCents,
    required this.startingPriceAt,
    required this.currentCents,
    required this.currency,
    required this.onEdit,
    required this.onClear,
  });

  final int? startingPriceCents;
  final DateTime? startingPriceAt;
  final int? currentCents;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final starting = startingPriceCents;

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, size: 18, color: luma.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Starting price',
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
          if (starting == null) ...[
            Text(
              'Set what you paid — or any baseline — to see gain and loss '
              'tracked against it below.',
              style: TextStyle(
                color: luma.textMuted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            LumaGhostButton(
              label: 'Set starting price',
              icon: Icons.add_rounded,
              onTap: onEdit,
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatSteamPrice(starting, currency),
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (startingPriceAt case final at?) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Set ${DateFormat.yMMMd().format(at)}',
                          style: TextStyle(
                              color: luma.textMuted, fontSize: 11.5),
                        ),
                      ],
                    ],
                  ),
                ),
                if (currentCents case final current?)
                  Cs2GainLossBadge(
                    deltaCents: current - starting,
                    startingCents: starting,
                    currency: currency,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                LumaGhostButton(
                  label: 'Edit',
                  icon: Icons.edit_rounded,
                  onTap: onEdit,
                ),
                if (onClear != null) ...[
                  const SizedBox(width: 8),
                  LumaGhostButton(
                    label: 'Clear',
                    icon: Icons.close_rounded,
                    onTap: onClear,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.skin, required this.hash});

  final Cs2SkinDef skin;
  final String hash;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final facts = <(String, String)>[
      ('Weapon', skin.weaponName),
      ('Rarity', skin.rarityName),
      ('Case', skin.caseName ?? 'No case — collection or promo item'),
      if (skin.stattrak) ('StatTrak™', 'Available for this finish'),
      if (skin.souvenir) ('Souvenir', 'Available for this finish'),
    ];

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: luma.accent),
              const SizedBox(width: 8),
              Text(
                'Details',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final (label, value) in facts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      label,
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          LumaGhostButton(
            label: 'Open on Steam Market',
            icon: Icons.open_in_new_rounded,
            onTap: () => launchUrl(
              Uri.parse(
                'https://steamcommunity.com/market/listings/'
                '${Cs2MarketApi.csAppId}/${Uri.encodeComponent(hash)}',
              ),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
    );
  }
}
