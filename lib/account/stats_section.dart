import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/widgets.dart';
import '../finance/data/database.dart';
import '../finance/finance_scope.dart';
import '../finance/logic/money.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_scope.dart';
import '../theme/luma_theme.dart';
import 'profile_stats.dart';
import 'travel/travel_map_page.dart';
import 'travel/world_map_data.dart';

/// The Account page's "Stats" tab: lifetime money totals plus the travel map
/// entry point.
class StatsSection extends StatelessWidget {
  const StatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = FinanceScope.of(context);
    final settings = SettingsScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StatsHeader(
          icon: Icons.insights_rounded,
          title: 'Net worth',
          subtitle: 'Everything you\'ve earned since you started tracking.',
        ),
        const SizedBox(height: 12),
        StreamData<List<FinanceTransaction>>(
          stream: finance.watchTransactions(),
          loading: const LumaCard(
            child: SizedBox(
              height: 148,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            ),
          ),
          builder: (context, txns) {
            final stats = ProfileStats.fromTransactions(txns);
            return ListenableBuilder(
              listenable: settings,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _NetWorthHero(stats: stats, hide: settings.hideAmounts),
                  const SizedBox(height: 12),
                  _LifetimeList(stats: stats, hide: settings.hideAmounts),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        const _StatsHeader(
          icon: Icons.public_rounded,
          title: 'Travel',
          subtitle: 'The countries you\'ve been to, on a map.',
        ),
        const SizedBox(height: 12),
        const _TravelCard(),
      ],
    );
  }
}

// ---- Net worth ------------------------------------------------------------

class _NetWorthHero extends StatelessWidget {
  const _NetWorthHero({required this.stats, required this.hide});

  final ProfileStats stats;
  final bool hide;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            luma.accent.withValues(alpha: 0.22),
            luma.accent.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: luma.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total income of all time',
            style: TextStyle(color: luma.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              hide ? '••••••' : formatCents(stats.incomeCents),
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroStat(
                label: 'Spent',
                value: hide ? '••••' : formatCents(stats.spentCents),
              ),
              const _HeroDivider(),
              _HeroStat(
                label: 'Kept',
                value: hide ? '••••' : formatCents(stats.keptCents),
              ),
              const _HeroDivider(),
              _HeroStat(
                label: 'Per month',
                value: hide
                    ? '••••'
                    : formatCents(stats.averageMonthlyIncomeCents),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: luma.textMuted, fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  const _HeroDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: context.luma.border,
    );
  }
}

/// The plain read-out under the hero: one line per lifetime figure.
class _LifetimeList extends StatelessWidget {
  const _LifetimeList({required this.stats, required this.hide});

  final ProfileStats stats;
  final bool hide;

  @override
  Widget build(BuildContext context) {
    final since = stats.firstEntry;
    String money(int cents) => hide ? '••••' : formatCents(cents);

    return LumaCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        children: [
          _StatRow(label: 'Total income', value: money(stats.incomeCents)),
          _StatRow(label: 'Total spent', value: money(stats.spentCents)),
          _StatRow(
            label: 'Kept',
            value: '${money(stats.keptCents)} · '
                '${(stats.keptFraction * 100).toStringAsFixed(0)}% of income',
          ),
          _StatRow(
            label: 'Average income per month',
            value: money(stats.averageMonthlyIncomeCents),
          ),
          _StatRow(label: 'Entries logged', value: '${stats.entryCount}'),
          _StatRow(
            label: 'Tracking since',
            value: since == null
                ? 'No entries yet'
                : DateFormat.yMMMM().format(since),
            last: true,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: luma.border)),
            ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: luma.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Travel ---------------------------------------------------------------

class _TravelCard extends StatefulWidget {
  const _TravelCard();

  @override
  State<_TravelCard> createState() => _TravelCardState();
}

class _TravelCardState extends State<_TravelCard> {
  /// Only used for the "x of y" total — the map itself loads its own copy
  /// (both share [WorldMap]'s cache).
  late final Future<WorldMap> _map = WorldMap.load();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final settings = SettingsScope.of(context);

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return FutureBuilder<WorldMap>(
          future: _map,
          builder: (context, snapshot) {
            final map = snapshot.data;
            final visited = _visitedCount(settings, map);
            final total = map?.countries.length;
            return LumaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: luma.accentSubtle,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.travel_explore_rounded,
                          color: luma.accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Countries visited',
                              style: TextStyle(
                                color: luma.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              total == null
                                  ? '$visited so far'
                                  : '$visited of $total · '
                                      '${(visited / total * 100).toStringAsFixed(0)}% '
                                      'of the world',
                              style: TextStyle(
                                color: luma.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$visited',
                        style: TextStyle(
                          color: luma.accent,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  if (total != null) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : visited / total,
                        minHeight: 8,
                        backgroundColor: luma.surfaceHover,
                        valueColor: AlwaysStoppedAnimation(luma.accent),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  LumaPrimaryButton(
                    label: 'Map',
                    icon: Icons.map_rounded,
                    expand: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TravelMapPage()),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Codes the bundled map no longer knows about are ignored, so the count
  /// can't run past the total.
  int _visitedCount(SettingsController settings, WorldMap? map) {
    final codes = settings.visitedCountries;
    if (map == null) return codes.length;
    return codes.where((code) => map.byCode(code) != null).length;
  }
}

// ---- Shared -----------------------------------------------------------------

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Icon(icon, size: 18, color: luma.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
