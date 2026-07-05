// Auto-ported from Roblox Server Hosting Tycoon

class License {
  final String id;
  final String name;
  final String description;
  final int cost;
  final List<String> requires;
  final int minReputation;

  const License({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.requires,
    required this.minReputation,
  });
}

final Map<String, License> licensesById = {
  'GAME_HOSTING': const License(
    id: 'GAME_HOSTING',
    name: 'Game Hosting License',
    description: 'Legally host Minecraft and other game servers for paying customers.',
    cost: 400,
    requires: [],
    minReputation: 0,
  ),
  'CLOUD_STORAGE': const License(
    id: 'CLOUD_STORAGE',
    name: 'Cloud Storage License',
    description: 'Offer paid personal cloud storage and file hosting.',
    cost: 600,
    requires: [],
    minReputation: 0,
  ),
  'VPN_HOSTING': const License(
    id: 'VPN_HOSTING',
    name: 'VPN Hosting License',
    description: 'Operate a VPN endpoint service for customers.',
    cost: 1200,
    requires: [],
    minReputation: 10,
  ),
  'CDN_HOSTING': const License(
    id: 'CDN_HOSTING',
    name: 'CDN Hosting License',
    description: 'Run a CDN edge caching node for website traffic.',
    cost: 2500,
    requires: ['VPN_HOSTING'],
    minReputation: 20,
  ),
  'EMAIL_HOSTING': const License(
    id: 'EMAIL_HOSTING',
    name: 'Email Hosting License',
    description: 'Host business email domains and mailboxes.',
    cost: 900,
    requires: [],
    minReputation: 10,
  ),
  'DATABASE_HOSTING': const License(
    id: 'DATABASE_HOSTING',
    name: 'Database Hosting License',
    description: 'Offer managed database instances to customers.',
    cost: 1500,
    requires: [],
    minReputation: 15,
  ),
  'AI_HOSTING': const License(
    id: 'AI_HOSTING',
    name: 'AI Hosting License',
    description: 'Run AI inference workloads as a paid service.',
    cost: 8000,
    requires: ['DATABASE_HOSTING'],
    minReputation: 40,
  ),
  'ENTERPRISE_HOSTING': const License(
    id: 'ENTERPRISE_HOSTING',
    name: 'Enterprise Hosting License',
    description: 'Qualify for enterprise and government contracts.',
    cost: 25000,
    requires: ['DATABASE_HOSTING', 'CLOUD_STORAGE'],
    minReputation: 60,
  ),
};

late final List<License> licenseList = licensesById.values.toList()
  ..sort((a, b) => a.cost.compareTo(b.cost));
