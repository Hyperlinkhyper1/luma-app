import 'package:flutter/material.dart';

import '../l10n/current_l.dart';
import '../settings/settings_controller.dart';
import 'plan.dart';

/// How long a paid plan has to run without a break before its monthly price
/// drops by [kLoyaltyDiscountCents].
const kLoyaltyDiscountDays = 365;

/// The loyalty discount, in cents, taken off a paid plan's monthly price.
const kLoyaltyDiscountCents = 100;

/// One step on the loyalty ladder. Ranks are earned by keeping a paid plan
/// (Orbit or Nova) running; a lapse back to Core starts the ladder over.
class LoyaltyRank {
  const LoyaltyRank({
    required this.id,
    required this.minDays,
    required this.icon,
  });

  final String id;

  /// Days of unbroken paid subscription needed to reach this rank.
  final int minDays;
  final IconData icon;

  String get name => switch (id) {
        'comet' => currentL.loyaltyRankComet,
        'star' => currentL.loyaltyRankStar,
        'constellation' => currentL.loyaltyRankConstellation,
        'galaxy' => currentL.loyaltyRankGalaxy,
        _ => currentL.loyaltyRankStardust,
      };
}

/// The ladder, lowest first. The top rank lands on [kLoyaltyDiscountDays],
/// so reaching it is the same moment the discount unlocks.
const kLoyaltyRanks = <LoyaltyRank>[
  LoyaltyRank(id: 'stardust', minDays: 0, icon: Icons.grain_rounded),
  LoyaltyRank(id: 'comet', minDays: 90, icon: Icons.flare_rounded),
  LoyaltyRank(id: 'star', minDays: 180, icon: Icons.star_rounded),
  LoyaltyRank(
    id: 'constellation',
    minDays: 270,
    icon: Icons.auto_awesome_rounded,
  ),
  LoyaltyRank(
    id: 'galaxy',
    minDays: kLoyaltyDiscountDays,
    icon: Icons.blur_circular_rounded,
  ),
];

/// Where an account stands on the loyalty ladder at [now], given when its
/// current paid streak began. A null [paidSince] means there is no paid
/// streak, so no rank either.
class LoyaltyStatus {
  const LoyaltyStatus({required this.paidSince, required this.now});

  final DateTime? paidSince;
  final DateTime now;

  bool get active => paidSince != null;

  /// Whole days the paid streak has run, never negative.
  int get daysSubscribed {
    final since = paidSince;
    if (since == null) return 0;
    final days = now.difference(since).inDays;
    return days < 0 ? 0 : days;
  }

  int get rankIndex {
    final days = daysSubscribed;
    var index = 0;
    for (var i = 0; i < kLoyaltyRanks.length; i++) {
      if (days >= kLoyaltyRanks[i].minDays) index = i;
    }
    return index;
  }

  LoyaltyRank get rank => kLoyaltyRanks[rankIndex];

  /// The next rank up, or null once the top rank is reached.
  LoyaltyRank? get nextRank => rankIndex + 1 < kLoyaltyRanks.length
      ? kLoyaltyRanks[rankIndex + 1]
      : null;

  int get daysToNextRank {
    final next = nextRank;
    return next == null ? 0 : next.minDays - daysSubscribed;
  }

  /// Progress through the whole first year, 0..1 — what the bar shows.
  double get yearProgress =>
      (daysSubscribed / kLoyaltyDiscountDays).clamp(0.0, 1.0);

  bool get discountUnlocked =>
      active && daysSubscribed >= kLoyaltyDiscountDays;

  int get daysToDiscount =>
      discountUnlocked ? 0 : kLoyaltyDiscountDays - daysSubscribed;

  /// The date the discount unlocks (or unlocked), or null with no streak.
  DateTime? get discountDate =>
      paidSince?.add(const Duration(days: kLoyaltyDiscountDays));
}

/// The loyalty standing of the account [settings] describes, right now. Only
/// a paid effective plan has a streak.
LoyaltyStatus loyaltyStatusOf(SettingsController settings) => LoyaltyStatus(
      paidSince: planById(settings.selectedPlanId).isPaid
          ? settings.paidSince
          : null,
      now: DateTime.now(),
    );
