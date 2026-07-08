/// A displayable plan tier. Purely cosmetic today — there's no billing, so
/// selecting one only changes which badge is shown; every account still gets
/// the same [StorageGuardService.limitBytes] local storage cap regardless of
/// plan.
class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.shortName,
    required this.priceLabel,
    required this.blurb,
    required this.features,
  });

  final String id;
  final String name;

  /// Short label for tight spaces (nav rail badge, phone "More" sheet row).
  final String shortName;
  final String priceLabel;
  final String blurb;
  final List<String> features;
}

const kPlans = <Plan>[
  Plan(
    id: 'core',
    name: 'Core',
    shortName: 'Core',
    priceLabel: 'Free',
    blurb: 'Everything you need on this device.',
    features: [
      '1 GB local storage',
      'Local + peer-to-peer sync',
      'Every plugin, unlocked',
    ],
  ),
  Plan(
    id: 'orbit',
    name: 'Orbit',
    shortName: 'Orbit',
    priceLabel: '\$2 / month',
    blurb: 'More room to grow, priority sync.',
    features: [
      'Expanded local storage',
      'Priority cloud sync speed',
      'Custom accent themes',
    ],
  ),
  Plan(
    id: 'nova',
    name: 'Nova',
    shortName: 'Nova',
    priceLabel: '\$5 / month',
    blurb: 'The fastest, largest luma yet.',
    features: [
      'Largest local storage',
      'Fastest cloud sync',
      'Early access to new features',
    ],
  ),
];

Plan planById(String id) => kPlans.firstWhere(
      (p) => p.id == id,
      orElse: () => kPlans.first,
    );
