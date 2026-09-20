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

  /// Adds a tracked copy of the current listing. [hasEntries] switches both
  /// the dialog's copy and whether the grade is still choosable: the first
  /// copy of a listing may want to pick a different wear before committing,
  /// but once any copy of *this exact* hash exists, wear is no longer a free
  /// choice — it's what makes this the listing it is.
  Future<void> _track({
    required bool hasEntries,
    required int? suggestedCents,
  }) async {
    final skin = _skin!;
    final result = await showCs2StartingPriceDialog(
      context,
      title: hasEntries ? 'Track another copy' : 'Track this listing',
      subtitle: hasEntries
          ? 'The price to measure this copy\'s gain and loss from.'
          : 'Pick the grade, and the price to measure gain and loss from.',
      wears: skin.wears,
      wear: _wear,
      wearEditable: !hasEntries && skin.wears.length > 1,
      suggestedCents: suggestedCents,
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

  Future<void> _untrackEntry(int entryId) async {
    await Cs2MarketScope.of(context).untrackEntry(entryId);
    _autoCheckedHash = null;
    _autoCheck();
  }

  Future<void> _editStartingPrice(Cs2MarketEntry entry, {int? currentCents}) async {
    final result = await showCs2StartingPriceDialog(
      context,
      title: entry.startingPriceCents == null
          ? 'Set starting price'
          : 'Edit starting price',
      subtitle: 'The price this copy\'s gain and loss is measured from.',
      wears: const [],
      wear: _wear,
      wearEditable: false,
      suggestedCents: entry.startingPriceCents ?? currentCents,
    );
    if (result == null || !mounted) return;
    await Cs2MarketScope.of(context)
        .setEntryStartingPrice(entry.id, result.priceCents);
  }

  Future<void> _clearStartingPrice(int entryId) async {
    await Cs2MarketScope.of(context).setEntryStartingPrice(entryId, null);
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
        builder: (context, itemSnapshot) {
          final trackedRow = itemSnapshot.data;
          final tracked = trackedRow != null;
          return StreamBuilder<List<Cs2MarketEntry>>(
            stream: repository.watchEntries(hash),
            builder: (context, entriesSnapshot) {
              final entries = entriesSnapshot.data ?? const [];
              final currentCents = tracked
                  ? (trackedRow.lastLowestCents ?? trackedRow.lastMedianCents)
                  : _transientPrice?.lowestCents ?? _transientPrice?.medianCents;
              return _DetailBody(
                skin: skin,
                wear: _wear,
                statTrak: _statTrak,
                hash: hash,
                tracked: tracked,
                trackedRow: trackedRow,
                entries: entries,
                transientPrice: _transientPrice,
                transientLoading: _transientLoading,
                transientError: _transientError,
                onWearChanged: skin.wears.length > 1 ? _onWearChanged : null,
                onStatTrakChanged: skin.stattrak ? _onStatTrakChanged : null,
                onCheckNow: () => tracked
                    ? repository.refreshPrice(hash, force: true)
                    : _checkTransient(force: true),
                onTrack: () => _track(
                  hasEntries: entries.isNotEmpty,
                  suggestedCents: currentCents,
                ),
                onEditEntry: (entry) =>
                    _editStartingPrice(entry, currentCents: currentCents),
                onRemoveEntry: _untrackEntry,
                onClearEntry: _clearStartingPrice,
              );
            },
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
    required this.entries,
    required this.transientPrice,
    required this.transientLoading,
    required this.transientError,
    required this.onWearChanged,
    required this.onStatTrakChanged,
    required this.onCheckNow,
    required this.onTrack,
    required this.onEditEntry,
    required this.onRemoveEntry,
    required this.onClearEntry,
  });

  final Cs2SkinDef skin;
  final String? wear;
  final bool statTrak;
  final String hash;
  final bool tracked;
  final Cs2MarketItem? trackedRow;
  final List<Cs2MarketEntry> entries;
  final Cs2MarketPrice? transientPrice;
  final bool transientLoading;
  final String? transientError;
  final ValueChanged<String?>? onWearChanged;
  final ValueChanged<bool>? onStatTrakChanged;
  final VoidCallback onCheckNow;
  final Future<void> Function() onTrack;
  final ValueChanged<Cs2MarketEntry> onEditEntry;
  final ValueChanged<int> onRemoveEntry;
  final ValueChanged<int> onClearEntry;

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
    // The Price/Gain & Loss toggle only makes sense for one baseline — with
    // several copies each having their own starting price, the shared chart
    // falls back to plain price rather than picking one copy's baseline to
    // speak for all of them.
    final chartStartingPriceCents =
        entries.length == 1 ? entries.single.startingPriceCents : null;

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
                      ),
                      if (entries.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _EntriesCard(
                          entries: entries,
                          currentCents: lowestCents ?? medianCents,
                          currency: currency,
                          onAddAnother: onTrack,
                          onEdit: onEditEntry,
                          onRemove: onRemoveEntry,
                          onClear: onClearEntry,
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
                          startingPriceCents: chartStartingPriceCents,
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
          LumaPrimaryButton(
            label: tracked ? 'Track another copy' : 'Track this listing',
            icon: tracked ? Icons.add_rounded : Icons.star_border_rounded,
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

/// Every tracked copy of this listing, each with its own cost basis and
/// gain/loss against the (shared) current price — plus a way to add
/// another. A skin bought twice at two different prices is two entries
/// here, not one row averaging them away.
class _EntriesCard extends StatelessWidget {
  const _EntriesCard({
    required this.entries,
    required this.currentCents,
    required this.currency,
    required this.onAddAnother,
    required this.onEdit,
    required this.onRemove,
    required this.onClear,
  });

  final List<Cs2MarketEntry> entries;
  final int? currentCents;
  final String currency;
  final Future<void> Function() onAddAnother;
  final ValueChanged<Cs2MarketEntry> onEdit;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onClear;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_rounded, size: 18, color: luma.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entries.length == 1
                      ? 'Your copy'
                      : 'Your copies (${entries.length})',
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
          for (final entry in entries) ...[
            _EntryRow(
              entry: entry,
              currentCents: currentCents,
              currency: currency,
              onEdit: () => onEdit(entry),
              onRemove: () => onRemove(entry.id),
              onClear: () => onClear(entry.id),
            ),
            if (entry != entries.last) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: luma.border),
              const SizedBox(height: 12),
            ],
          ],
          const SizedBox(height: 12),
          LumaGhostButton(
            label: 'Track another copy',
            icon: Icons.add_rounded,
            onTap: onAddAnother,
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.currentCents,
    required this.currency,
    required this.onEdit,
    required this.onRemove,
    required this.onClear,
  });

  final Cs2MarketEntry entry;
  final int? currentCents;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final starting = entry.startingPriceCents;

    return Column(
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
                  Text(
                    starting == null
                        ? 'No starting price set'
                        : formatSteamPrice(starting, currency),
                    style: TextStyle(
                      color: starting == null
                          ? luma.textMuted
                          : luma.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Tracked ${DateFormat.yMMMd().format(entry.trackedAt)}',
                    style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            if (starting != null && currentCents != null)
              Cs2GainLossBadge(
                deltaCents: currentCents! - starting,
                startingCents: starting,
                currency: currency,
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            LumaGhostButton(
              label: starting == null ? 'Set price' : 'Edit',
              icon: Icons.edit_rounded,
              onTap: onEdit,
            ),
            if (starting != null)
              LumaGhostButton(
                label: 'Clear price',
                icon: Icons.close_rounded,
                onTap: onClear,
              ),
            LumaGhostButton(
              label: 'Stop tracking this copy',
              icon: Icons.delete_outline_rounded,
              onTap: onRemove,
            ),
          ],
        ),
      ],
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
