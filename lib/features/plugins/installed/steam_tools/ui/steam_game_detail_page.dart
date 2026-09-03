import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/widgets.dart';
import '../../../../../settings/sync_section.dart';
import '../../../../../sync/sync_scope.dart';
import '../../../../../sync/sync_service.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/steam_database.dart';
import '../steam_models.dart';
import '../steam_price_history.dart';
import '../steam_repository.dart';
import '../steam_requirements.dart';
import '../steam_scope.dart';
import 'steam_price_chart.dart';

/// One game: its art, what it costs now, what it has cost since luma started
/// watching, and what it needs to run.
class SteamGameDetailPage extends StatefulWidget {
  const SteamGameDetailPage({super.key, required this.appId});

  final int appId;

  @override
  State<SteamGameDetailPage> createState() => _SteamGameDetailPageState();
}

class _SteamGameDetailPageState extends State<SteamGameDetailPage> {
  bool _started = false;
  SyncService? _sync;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Both fetches happen on open rather than during the library sync: Steam
    // rate limits its store API, and a 300-game library would spend that
    // budget on pages nobody looked at. They are independent, so the price
    // can land while the history is still coming.
    final repository = SteamScope.of(context);
    repository.ensureDetails(widget.appId);
    repository.ensureHistory(widget.appId);

    // Price history needs a signed-in account; if the user signs in from the
    // prompt below while this page is open, fetch it immediately rather than
    // waiting for the next visit. ensureHistory already no-ops when nothing
    // changed, so re-calling it on every sync event is cheap.
    _sync = SyncScope.of(context)..addListener(_onSyncChanged);
  }

  void _onSyncChanged() {
    if (!mounted) return;
    SteamScope.of(context).ensureHistory(widget.appId);
  }

  @override
  void dispose() {
    _sync?.removeListener(_onSyncChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = SteamScope.of(context);

    return Scaffold(
      backgroundColor: luma.background,
      body: StreamBuilder<SteamGame?>(
        stream: repository.watchGame(widget.appId),
        builder: (context, snapshot) {
          final game = snapshot.data;
          if (game == null) {
            return Stack(
              children: [
                Center(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: luma.accent,
                          ),
                        )
                      : LumaEmptyState(
                          icon: Icons.videogame_asset_off_rounded,
                          title: 'That game is no longer in your library',
                          subtitle: 'Refresh your library to see what changed.',
                        ),
                ),
                const _BackButton(),
              ],
            );
          }
          return _DetailBody(game: game, repository: repository);
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.game, required this.repository});

  final SteamGame game;
  final SteamRepository repository;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final wide = media.size.width >= 900;
    // The hero is a share of the window rather than a fixed height, so it
    // stays a banner on a laptop and does not eat a phone screen whole.
    final heroHeight =
        math.max(240.0, math.min(420.0, media.size.height * 0.44));

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.zero,
          children: [
            _Hero(game: game, height: heroHeight),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 32 : 16,
                    0,
                    wide ? 32 : 16,
                    32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PriceCard(game: game, repository: repository),
                      const SizedBox(height: 16),
                      // Merged so the card reacts to both a fetch starting
                      // or finishing (repository) and a sign-in happening
                      // (sync) — either alone would leave the other stale.
                      ListenableBuilder(
                        listenable:
                            Listenable.merge([repository, SyncScope.of(context)]),
                        builder: (context, _) =>
                            StreamBuilder<List<SteamPricePoint>>(
                          stream: repository.watchPriceHistory(game.appId),
                          builder: (context, snapshot) =>
                              SteamPriceHistoryCard(
                            points: snapshot.data ?? const [],
                            fallbackCurrency: game.currency ?? 'USD',
                            loading:
                                repository.isFetchingHistory(game.appId) ||
                                    snapshot.connectionState ==
                                        ConnectionState.waiting,
                            canFetchHistory: repository.canFetchHistory,
                            lowestEverCents: game.lowestEverCents,
                            lowestEverAt: game.lowestEverAt,
                            onSignIn: () => showAccountSetupDialog(
                                context, SyncScope.of(context)),
                          ),
                        ),
                      ),
                      if (game.shortDescription?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 16),
                        _AboutCard(text: game.shortDescription!),
                      ],
                      if (_tagsOf(game).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _TagsCard(tags: _tagsOf(game)),
                      ],
                      const SizedBox(height: 16),
                      _RequirementsCard(
                        requirements: decodeSteamRequirements(game.requirements),
                        wide: wide,
                        loading: repository.isFetchingDetails(game.appId),
                      ),
                      const SizedBox(height: 16),
                      _FactsCard(game: game),
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

  static List<String> _tagsOf(SteamGame game) {
    final raw = game.tags;
    if (raw == null || raw.isEmpty) return const [];
    return [
      for (final tag in raw.split('\n'))
        if (tag.trim().isNotEmpty) tag.trim(),
    ];
  }
}

/// The game's banner, fading down into the page background.
///
/// The fade is the whole point: the art is a backdrop the page grows out of,
/// not a picture sitting in a box. It runs the full height of the hero and
/// ends on exactly [LumaPalette.background], so there is no seam where the
/// image stops — and by the time the title is drawn the gradient is nearly
/// opaque, which is what guarantees the text stays readable over art the app
/// has never seen.
class _Hero extends StatelessWidget {
  const _Hero({required this.game, required this.height});

  final SteamGame game;
  final double height;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final banner = game.backgroundImage?.isNotEmpty ?? false
        ? game.backgroundImage!
        : game.headerImage?.isNotEmpty ?? false
            ? game.headerImage!
            : steamHeaderImage(game.appId);

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            banner,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            gaplessPlayback: true,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : ColoredBox(color: luma.rail),
            errorBuilder: (context, _, _) => ColoredBox(color: luma.rail),
          ),
          // The long fade to the page background.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  luma.background.withValues(alpha: 0.10),
                  luma.background.withValues(alpha: 0.42),
                  luma.background.withValues(alpha: 0.88),
                  luma.background,
                ],
                stops: const [0.0, 0.48, 0.82, 1.0],
              ),
            ),
          ),
          // A short scrim at the very top so the back button keeps its
          // contrast over bright art.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  luma.background.withValues(alpha: 0.55),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.22],
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
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: _HeroTitle(game: game),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTitle extends StatelessWidget {
  const _HeroTitle({required this.game});

  final SteamGame game;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final facts = <String>[
      if (game.developers?.isNotEmpty ?? false) game.developers!,
      if (game.releaseDate?.isNotEmpty ?? false) game.releaseDate!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          game.name,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.15,
            fontFamily: context.lumaDecor.displayFontFamily,
            fontFamilyFallback: context.lumaDecor.displayFontFallback,
          ),
        ),
        if (facts.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            facts.join('  •  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: luma.textSecondary, fontSize: 13),
          ),
        ],
      ],
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
          tooltip: 'Back to your library',
          icon: Icon(Icons.arrow_back_rounded, color: luma.textPrimary),
          // 44pt minimum, whatever the icon size works out to.
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        ),
      ),
    );
  }
}

/// What the game costs right now, and when that was last confirmed.
class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.game, required this.repository});

  final SteamGame game;
  final SteamRepository repository;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final fetching = repository.isFetchingDetails(game.appId);
    final currency = game.currency ?? 'USD';
    final price = game.lastPriceCents;
    final initial = game.lastInitialCents;
    final discount = game.lastDiscountPercent ?? 0;

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
                    Text(
                      'Price now',
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    if (game.isFree)
                      Text(
                        'Free to play',
                        style: TextStyle(
                          color: luma.success,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else if (price == null)
                      Text(
                        fetching ? 'Checking…' : 'Not checked yet',
                        style: TextStyle(
                          color: luma.textSecondary,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          Text(
                            formatSteamPrice(price, currency),
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          if (discount > 0 &&
                              initial != null &&
                              initial > price) ...[
                            _DiscountPill(percent: discount),
                            Text(
                              'was ${formatSteamPrice(initial, currency)}',
                              style: TextStyle(
                                color: luma.textMuted,
                                fontSize: 13,
                                decoration: TextDecoration.lineThrough,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              LumaGhostButton(
                label: 'Check now',
                icon: Icons.refresh_rounded,
                onTap: fetching
                    ? null
                    : () => repository.ensureDetails(game.appId, force: true),
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
                  _lastChecked(game.detailsFetchedAt),
                  style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _lastChecked(DateTime? at) {
    if (at == null) return 'This game has not been priced yet.';
    final ago = DateTime.now().difference(at);
    if (ago.inMinutes < 1) return 'Checked just now.';
    if (ago.inHours < 1) return 'Checked ${ago.inMinutes} min ago.';
    if (ago.inDays < 1) return 'Checked ${ago.inHours} h ago.';
    return 'Checked on ${DateFormat.yMMMd().format(at)}.';
  }
}

class _DiscountPill extends StatelessWidget {
  const _DiscountPill({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: luma.success.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '-$percent%',
        style: TextStyle(
          color: luma.success,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: Icons.notes_rounded, label: 'About this game'),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 13.5,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagsCard extends StatelessWidget {
  const _TagsCard({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: Icons.sell_rounded, label: 'Tags'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in tags)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: luma.accentSubtle,
                    borderRadius:
                        BorderRadius.circular(context.lumaDecor.pillRadius),
                    border: Border.all(color: luma.border),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(color: luma.textSecondary, fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Minimum and recommended specs, side by side where there is room.
class _RequirementsCard extends StatelessWidget {
  const _RequirementsCard({
    required this.requirements,
    required this.wide,
    required this.loading,
  });

  final SteamRequirements requirements;
  final bool wide;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    if (requirements.isEmpty) {
      return LumaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(
              icon: Icons.memory_rounded,
              label: 'System requirements',
            ),
            const SizedBox(height: 10),
            Text(
              loading
                  ? 'Reading the store page…'
                  : 'Steam lists no PC requirements for this game.',
              style: TextStyle(color: luma.textMuted, fontSize: 12.5),
            ),
          ],
        ),
      );
    }

    final blocks = <Widget>[
      if (requirements.minimum.isNotEmpty)
        _RequirementBlock(title: 'Minimum', lines: requirements.minimum),
      if (requirements.recommended.isNotEmpty)
        _RequirementBlock(
          title: 'Recommended',
          lines: requirements.recommended,
        ),
    ];

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: Icons.memory_rounded, label: 'System requirements'),
          const SizedBox(height: 14),
          if (wide && blocks.length == 2)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: blocks[0]),
                const SizedBox(width: 24),
                Expanded(child: blocks[1]),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < blocks.length; i++) ...[
                  if (i > 0) const SizedBox(height: 20),
                  blocks[i],
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _RequirementBlock extends StatelessWidget {
  const _RequirementBlock({required this.title, required this.lines});

  final String title;
  final List<SteamRequirementLine> lines;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            color: luma.accent,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (line.label != null) ...[
                  SizedBox(
                    width: 92,
                    child: Text(
                      line.label!,
                      style: TextStyle(
                        color: luma.textMuted,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    line.value,
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
      ],
    );
  }
}

/// Publisher, platforms, score — the store-page facts that do not belong
/// anywhere else.
class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.game});

  final SteamGame game;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    final platforms = <String>[
      if (game.onWindows) 'Windows',
      if (game.onMac) 'macOS',
      if (game.onLinux) 'Linux',
    ];

    final facts = <(String, String)>[
      if (game.developers?.isNotEmpty ?? false)
        ('Developer', game.developers!),
      if (game.publishers?.isNotEmpty ?? false)
        ('Publisher', game.publishers!),
      if (game.releaseDate?.isNotEmpty ?? false)
        ('Released', game.releaseDate!),
      if (game.metacritic != null) ('Metacritic', '${game.metacritic}/100'),
      if (platforms.isNotEmpty) ('Platforms', platforms.join(', ')),
      // Only meaningful for a game the Steam library sync actually
      // confirmed is owned — a searched-and-tracked game has no playtime.
      if (game.owned) ('Your playtime', _playtime(game.playtimeMinutes)),
    ];

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: Icons.info_outline_rounded, label: 'Details'),
          const SizedBox(height: 12),
          for (final (label, value) in facts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
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
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              LumaGhostButton(
                label: 'Open on Steam',
                icon: Icons.open_in_new_rounded,
                onTap: () => launchUrl(
                  Uri.parse(
                      'https://store.steampowered.com/app/${game.appId}'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              LumaGhostButton(
                label: 'Stop tracking',
                icon: Icons.delete_outline_rounded,
                onTap: () => _confirmUntrack(context, game),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _playtime(int minutes) {
    if (minutes <= 0) return 'Never played';
    if (minutes < 60) return '$minutes minutes';
    final hours = minutes / 60;
    if (hours < 10) return '${hours.toStringAsFixed(1)} hours';
    return '${hours.round()} hours';
  }

  static Future<void> _confirmUntrack(
    BuildContext context,
    SteamGame game,
  ) async {
    final luma = context.luma;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text('Stop tracking ${game.name}?',
            style: TextStyle(color: luma.textPrimary)),
        content: Text(
          game.owned
              ? 'This removes it from your tracked games and deletes its '
                  'price history on this device. It is still in your Steam '
                  'library, so refreshing the library later will add it '
                  'back.'
              : 'This removes it from your tracked games and deletes its '
                  'price history on this device.',
          style: TextStyle(color: luma.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child:
                Text('Cancel', style: TextStyle(color: luma.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Stop tracking', style: TextStyle(color: luma.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await SteamScope.of(context).untrackGame(game.appId);
    if (context.mounted) Navigator.of(context).pop();
  }
}


class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Icon(icon, size: 18, color: luma.accent),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
