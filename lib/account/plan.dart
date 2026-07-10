/// A displayable plan tier. The selected plan's [storageMb] is what the
/// app enforces as the local storage cap (see [StorageGuardService]) — the
/// only thing selecting a plan changes today, since there's no billing yet.
class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.shortName,
    required this.priceLabel,
    required this.blurb,
    required this.storageMb,
    required this.maxSyncCollections,
    required this.features,
  });

  final String id;
  final String name;

  /// Short label for tight spaces (nav rail badge, phone "More" sheet row).
  final String shortName;
  final String priceLabel;
  final String blurb;

  /// Local storage cap, in megabytes, this plan grants. User-generated data
  /// only (databases + JSON stores); the app's own binaries and logs don't
  /// count toward it.
  final int storageMb;

  /// How many features (besides the always-on Settings sync) this plan may
  /// sync to the server at once. Null means unlimited. Enforced in
  /// `SyncService.enableCollection`.
  final int? maxSyncCollections;

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
    blurb: 'Everything you need on this device.',
    storageMb: 10,
    maxSyncCollections: 3,
    features: [
      '10 MB local storage',
      'Sync up to 3 features to the server',
      'Free starter plugins',
    ],
  ),
  Plan(
    id: 'orbit',
    name: 'Orbit',
    shortName: 'Orbit',
    priceLabel: '\$2 / month',
    blurb: 'More room to grow, priority sync.',
    storageMb: 25,
    maxSyncCollections: 5,
    features: [
      '25 MB local storage',
      'Sync up to 5 features to the server',
      'Priority cloud sync speed',
      'Free advanced plugins',
      'Custom accent themes',
    ],
  ),
  Plan(
    id: 'nova',
    name: 'Nova',
    shortName: 'Nova',
    priceLabel: '\$5 / month',
    blurb: 'The fastest, largest luma yet.',
    storageMb: 50,
    maxSyncCollections: null,
    features: [
      '50 MB local storage',
      'Sync unlimited features to the server',
      'Fastest cloud sync',
      'All plugins, free',
      'Early access to new features',
    ],
  ),
];

Plan planById(String id) => kPlans.firstWhere(
      (p) => p.id == id,
      orElse: () => kPlans.first,
    );
