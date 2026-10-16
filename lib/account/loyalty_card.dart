import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/widgets.dart';
import '../l10n/app_localizations.dart';
import '../settings/settings_scope.dart';
import '../theme/luma_theme.dart';
import 'loyalty.dart';
import 'plan.dart';
import 'plan_selection_page.dart';

/// The Profile section's loyalty card: the rank earned by staying on a paid
/// plan, a progression bar across the first year with one marker per rank,
/// and the $1-a-month discount waiting at the end of it. On Core it shows
/// the same ladder, locked, with a way to the plans.
class LoyaltyCard extends StatelessWidget {
  const LoyaltyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final plan = planById(settings.selectedPlanId);
        final status = loyaltyStatusOf(settings);
        return LumaCard(
          child: status.active
              ? _ActiveLoyalty(status: status, plan: plan)
              : const _InactiveLoyalty(),
        );
      },
    );
  }
}

class _ActiveLoyalty extends StatelessWidget {
  const _ActiveLoyalty({required this.status, required this.plan});

  final LoyaltyStatus status;
  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final locale = Localizations.localeOf(context).toString();
    final rank = status.rank;
    final next = status.nextRank;
    final since = status.paidSince!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LoyaltyHeader(
          trailing: status.discountUnlocked
              ? _Pill(
                  icon: Icons.sell_rounded,
                  label: t.loyaltyDiscountBadge,
                  color: luma.success,
                )
              : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            LumaIconBadge(icon: rank.icon, color: luma.accent, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rank.name,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${t.loyaltyDaysSubscribed(status.daysSubscribed)} · '
                    '${t.loyaltySubscribedSince(DateFormat.yMMMd(locale).format(since.toLocal()))}',
                    style: TextStyle(
                      color: luma.textMuted,
                      fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _RankLadder(status: status),
        const SizedBox(height: 18),
        Divider(color: luma.border, height: 1),
        const SizedBox(height: 14),
        if (status.discountUnlocked)
          _InfoLine(
            icon: Icons.check_circle_rounded,
            color: luma.success,
            text: t.loyaltyDiscountUnlocked,
            trailing: _DiscountedPrice(plan: plan),
          )
        else ...[
          _InfoLine(
            icon: next == null ? Icons.emoji_events_rounded : next.icon,
            color: luma.accent,
            text: next == null
                ? t.loyaltyTopRank
                : t.loyaltyDaysToRank(status.daysToNextRank, next.name),
          ),
          const SizedBox(height: 8),
          _InfoLine(
            icon: Icons.sell_outlined,
            color: luma.textSecondary,
            text: t.loyaltyDaysToDiscount(status.daysToDiscount),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          t.loyaltyResetNote,
          style: TextStyle(color: luma.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _InactiveLoyalty extends StatelessWidget {
  const _InactiveLoyalty();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _LoyaltyHeader(),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LumaIconBadge(
              icon: Icons.lock_outline_rounded,
              color: luma.textMuted,
              size: 52,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.loyaltyInactiveTitle,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.loyaltyInactiveBody,
                    style: TextStyle(
                      color: luma.textMuted,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _RankLadder(status: null),
        const SizedBox(height: 18),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: LumaGhostButton(
            label: t.loyaltyViewPlans,
            icon: Icons.workspace_premium_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PlanSelectionPage()),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoyaltyHeader extends StatelessWidget {
  const _LoyaltyHeader({this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Expanded(
          child: Text(
            L.of(context).loyaltyTitle,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// The year-long bar with a marker per rank. A null [status] draws the
/// ladder empty and locked, as a preview for accounts on Core.
class _RankLadder extends StatelessWidget {
  const _RankLadder({required this.status});

  final LoyaltyStatus? status;

  static const _markerSize = 26.0;
  static const _trackHeight = 8.0;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final t = L.of(context);
    final status = this.status;
    final progress = status?.yearProgress ?? 0;
    final reachedIndex = status?.rankIndex ?? -1;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final trackRadius = BorderRadius.circular(
      decor.notched ? 1 : _trackHeight / 2,
    );

    return Semantics(
      label: t.loyaltyProgressSemantics(
        (progress * 100).round(),
        status?.rank.name ?? '—',
      ),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _markerSize,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final inner = width - _markerSize;
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    // The fill ends on a marker's centre exactly when the
                    // streak reaches that rank, so the two always agree.
                    final fill = value <= 0
                        ? 0.0
                        : _markerSize / 2 + inner * value;
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: _trackHeight,
                          decoration: BoxDecoration(
                            color: luma.border,
                            borderRadius: trackRadius,
                          ),
                        ),
                        Container(
                          width: fill,
                          height: _trackHeight,
                          decoration: BoxDecoration(
                            borderRadius: trackRadius,
                            gradient: LinearGradient(
                              colors: [
                                luma.accent.withValues(alpha: 0.65),
                                luma.accent,
                              ],
                            ),
                          ),
                        ),
                        for (var i = 0; i < kLoyaltyRanks.length; i++)
                          Positioned(
                            left: inner *
                                kLoyaltyRanks[i].minDays /
                                kLoyaltyDiscountDays,
                            child: _RankMarker(
                              rank: kLoyaltyRanks[i],
                              reached: i <= reachedIndex,
                              current: i == reachedIndex,
                              size: _markerSize,
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 16,
            child: Stack(
              children: [
                for (var i = 0; i < kLoyaltyRanks.length; i++)
                  Align(
                    alignment: Alignment(
                      kLoyaltyRanks[i].minDays / kLoyaltyDiscountDays * 2 - 1,
                      0,
                    ),
                    child: Text(
                      t.loyaltyMilestoneMonths(
                        (kLoyaltyRanks[i].minDays / 30.4).round(),
                      ),
                      style: TextStyle(
                        color: i <= reachedIndex
                            ? luma.textSecondary
                            : luma.textMuted,
                        fontSize: 11,
                        fontWeight:
                            i == reachedIndex ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankMarker extends StatelessWidget {
  const _RankMarker({
    required this.rank,
    required this.reached,
    required this.current,
    required this.size,
  });

  final LoyaltyRank rank;
  final bool reached;
  final bool current;
  final double size;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Tooltip(
      message: rank.name,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: reached ? luma.accent : luma.surface,
          border: Border.all(
            color: reached ? luma.accent : luma.border,
            width: 2,
          ),
          boxShadow: current
              ? [
                  BoxShadow(
                    color: luma.accent.withValues(alpha: 0.45),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Icon(
          rank.icon,
          size: size * 0.5,
          color: reached ? luma.onAccent : luma.textMuted,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.color,
    required this.text,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ],
    );
  }
}

/// "Nova · $7 / month  was $8 / month" — the discounted price next to the
/// list price it replaced.
class _DiscountedPrice extends StatelessWidget {
  const _DiscountedPrice({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${plan.name} · ${plan.priceLabelFor(loyal: true)}  ',
            style: TextStyle(
              color: luma.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: t.loyaltyDiscountedFrom(plan.priceLabel),
            style: TextStyle(
              color: luma.textMuted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      ),
      style: const TextStyle(
        fontSize: 13,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
