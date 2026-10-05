/// A displayable plan tier. The selected plan's [storageMb] is the server-side
/// sync storage quota this plan grants — how much of the user's synced data
/// the luma server will hold for this account, enforced server-side (see
/// `kPlanQuotaBytes` in `server/lib/store.dart`). It has nothing to do with
/// how much purely local data sits on this device; selecting a plan is the
/// only thing that changes today, since there's no billing yet.
class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.shortName,
    required this.priceLabel,
    required this.blurb,
    required this.storageMb,
    required this.maxSyncCollections,
    required this.maxFamilyMembers,
    required this.features,
  });

  final String id;
  final String name;

  /// Short label for tight spaces (nav rail badge, phone "More" sheet row).
  final String shortName;
  final String priceLabel;
  final String blurb;

  /// Server-side sync storage quota, in megabytes, this plan grants — how
  /// much of what's actually synced to the luma server counts against the
  /// account, enforced server-side. Unrelated to how much purely local data
  /// (never synced) sits on this device.
  final int storageMb;

  /// How many features (besides the always-on Settings sync) this plan may
  /// sync to the server at once. Null means unlimited. Enforced in
  /// `SyncService.enableCollection`.
  final int? maxSyncCollections;

  /// How many people (including the owner) may belong to one family at once.
  /// Enforced server-side (see kFamilyMemberLimit in server/lib/family_store.dart,
  /// which must stay in sync with this).
  final int maxFamilyMembers;

  final List<String> features;

  /// Whether picking this plan requires redeeming an access code (see
  /// [SettingsController.redeemPlanCode]). False for the free default plan.
  bool get requiresCode => id != 'core';
}

const kPlans = <Plan>[
  Plan(
    id: 'core',
    name: 'Core',
    shortName: 'Core',
    priceLabel: 'Free',
    blurb: 'All the basics, right on your device.',
    storageMb: 5,
    maxSyncCollections: 3,
    maxFamilyMembers: 4,
    features: [
      'Keep up to 3 features in sync across your devices, end-to-end encrypted',
      'Every plugin works on your device, free',
      'Room for 4 in your family',
      'AI Detector reviews: exchange 10% of your weekly AI limit each',
      '5 MB of sync storage',
    ],
  ),
  Plan(
    id: 'orbit',
    name: 'Orbit',
    shortName: 'Orbit',
    priceLabel: '\$3 / month',
    blurb: 'More synced features, SFTP, Groceries List and the Coffee theme.',
    storageMb: 15,
    maxSyncCollections: 5,
    maxFamilyMembers: 6,
    features: [
      'Keep up to 5 features in sync across your devices, end-to-end encrypted',
      'Carry your Airline Tycoon airline between devices',
      'CS2 market prices in Steam Tools',
      'SFTP client and shared folder between your devices',
      'Groceries List with prices from Jumbo, Albert Heijn, Hoogvliet and Lidl',
      'The Coffee theme',
      'Room for 6 in your family',
      '10 AI Detector reviews a week, then 4% of your weekly AI limit each',
      '15 MB of sync storage',
    ],
  ),
  Plan(
    id: 'nova',
    name: 'Nova',
    shortName: 'Nova',
    priceLabel: '\$6 / month',
    blurb: 'Everything in sync on every device, plus the premium tools.',
    storageMb: 30,
    maxSyncCollections: null,
    maxFamilyMembers: 12,
    features: [
      'Keep everything in sync across all your devices, end-to-end encrypted',
      'Assistant plan mode, deep research and picture creation',
      'Gallery People and Categories',
      'Classroom tutor in the Text Library hall',
      'Everything in Orbit, including the Coffee theme',
      'Room for 12 in your family',
      '30 AI Detector reviews a week, then 2% of your weekly AI limit each',
      '30 MB of sync storage',
    ],
  ),
];

Plan planById(String id) => kPlans.firstWhere(
      (p) => p.id == id,
      orElse: () => kPlans.first,
    );

/// Plan tiers, lowest first. The single source of truth for "is this plan at
/// least X" — [themeStyleUnlocked] and `SyncService` both defer to this
/// rather than keeping their own copy of the ordering.
int planTierIndex(String? id) => switch (id) {
      'nova' => 2,
      'orbit' => 1,
      _ => 0,
    };

/// Whether [planId] is at or above [minPlanId]. A null [minPlanId] means the
/// thing is free, so every plan clears it; Nova clears everything Orbit does.
bool planAtLeast(String? planId, String? minPlanId) =>
    minPlanId == null || planTierIndex(planId) >= planTierIndex(minPlanId);

/// A one-time pack of extra Luma AI tokens. Credits never expire and are only
/// used once the plan's own 5-hour or weekly budget runs out. The server
/// (kAiCreditPacks in server/lib/ai_usage_store.dart) is the source of truth
/// for what each pack grants; keep the two lists in step.
class AiCreditPack {
  const AiCreditPack({
    required this.id,
    required this.tokens,
    required this.priceCents,
  });

  final String id;
  final int tokens;
  final int priceCents;

  String get tokensLabel => tokens % 1000000 == 0
      ? '${tokens ~/ 1000000}M'
      : '${tokens / 1000000}M';

  String get priceLabel => priceCents % 100 == 0
      ? '\$${priceCents ~/ 100}'
      : '\$${(priceCents / 100).toStringAsFixed(2)}';
}

const kAiCreditPacks = <AiCreditPack>[
  AiCreditPack(id: 'credits_1m', tokens: 1000000, priceCents: 200),
  AiCreditPack(id: 'credits_2_5m', tokens: 2500000, priceCents: 400),
  AiCreditPack(id: 'credits_5m', tokens: 5000000, priceCents: 750),
  AiCreditPack(id: 'credits_10m', tokens: 10000000, priceCents: 1400),
];
