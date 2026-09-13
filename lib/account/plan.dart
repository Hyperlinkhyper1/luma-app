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
      '5 MB of synced storage',
      'Take up to 3 things with you to the server',
      'Starter plugins included',
      'Room for 4 in your family',
    ],
  ),
  Plan(
    id: 'orbit',
    name: 'Orbit',
    shortName: 'Orbit',
    priceLabel: '\$2 / month',
    blurb: 'A bit more room, and your stuff syncs first.',
    storageMb: 15,
    maxSyncCollections: 5,
    maxFamilyMembers: 6,
    features: [
      '15 MB of synced storage',
      'Sync up to 5 things to the server',
      'Your sync jumps the queue',
      'Fancy plugins included',
      'Make your own colours',
      'The Coffee theme',
      'Room for 6 in your family',
    ],
  ),
  Plan(
    id: 'nova',
    name: 'Nova',
    shortName: 'Nova',
    priceLabel: '\$5 / month',
    blurb: 'The biggest luma, synced the fastest.',
    storageMb: 30,
    maxSyncCollections: null,
    maxFamilyMembers: 12,
    features: [
      '30 MB of synced storage',
      'Sync everything to the server',
      'The very fastest sync',
      'Every plugin included',
      'The Coffee theme',
      'Try new stuff first',
      'Room for 12 in your family',
    ],
  ),
];

Plan planById(String id) => kPlans.firstWhere(
      (p) => p.id == id,
      orElse: () => kPlans.first,
    );
