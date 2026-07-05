// Auto-ported from Roblox Server Hosting Tycoon

class ResourceCost {
  final double cpu;
  final double ramGB;
  final double storageGB;
  final double bandwidthMbps;

  const ResourceCost({
    required this.cpu,
    required this.ramGB,
    required this.storageGB,
    required this.bandwidthMbps,
  });
}

class ServiceType {
  final String id;
  final String name;
  final String category;
  final String description;
  final String capacityUnitLabel;
  final ResourceCost base;
  final ResourceCost perUnit;
  final double incomePerUnitPerDay;
  final int? maxLatencyMs;
  final String? requiredLicense;

  const ServiceType({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.capacityUnitLabel,
    required this.base,
    required this.perUnit,
    required this.incomePerUnitPerDay,
    this.maxLatencyMs,
    this.requiredLicense,
  });
}

final Map<String, ServiceType> servicesById = {
  'DISCORD_BOT': const ServiceType(
    id: 'DISCORD_BOT',
    name: 'Discord Bot',
    category: 'Automation',
    description: 'Lightweight bots for Discord communities. Barely touches CPU or bandwidth.',
    capacityUnitLabel: 'bot instance',
    base: ResourceCost(cpu: 1, ramGB: 0.1, storageGB: 0.2, bandwidthMbps: 0.05),
    perUnit: ResourceCost(cpu: 1.5, ramGB: 0.15, storageGB: 0.3, bandwidthMbps: 0.1),
    incomePerUnitPerDay: 0.6,
    maxLatencyMs: null,
    requiredLicense: null,
  ),
  'STATIC_WEBSITE': const ServiceType(
    id: 'STATIC_WEBSITE',
    name: 'Static Website',
    category: 'Web',
    description: 'HTML/CSS sites with no backend. Cheap to run at any scale.',
    capacityUnitLabel: '1k monthly visitors',
    base: ResourceCost(cpu: 0.5, ramGB: 0.05, storageGB: 0.5, bandwidthMbps: 0.05),
    perUnit: ResourceCost(cpu: 0.3, ramGB: 0.05, storageGB: 0.2, bandwidthMbps: 0.15),
    incomePerUnitPerDay: 0.25,
    maxLatencyMs: null,
    requiredLicense: null,
  ),
  'DYNAMIC_WEBSITE_API': const ServiceType(
    id: 'DYNAMIC_WEBSITE_API',
    name: 'Dynamic Website / API',
    category: 'Web',
    description: 'Server-rendered sites and API endpoints. Needs real CPU and RAM.',
    capacityUnitLabel: 'request tier',
    base: ResourceCost(cpu: 2, ramGB: 0.5, storageGB: 1, bandwidthMbps: 0.1),
    perUnit: ResourceCost(cpu: 0.8, ramGB: 0.2, storageGB: 0.1, bandwidthMbps: 0.2),
    incomePerUnitPerDay: 0.45,
    maxLatencyMs: 150,
    requiredLicense: null,
  ),
  'MONITORING_SERVER': const ServiceType(
    id: 'MONITORING_SERVER',
    name: 'Monitoring Server',
    category: 'Ops',
    description: "Uptime and metrics monitoring for other people's infrastructure.",
    capacityUnitLabel: 'monitored host',
    base: ResourceCost(cpu: 1.5, ramGB: 0.3, storageGB: 2, bandwidthMbps: 0.1),
    perUnit: ResourceCost(cpu: 0.15, ramGB: 0.02, storageGB: 0.1, bandwidthMbps: 0.02),
    incomePerUnitPerDay: 0.3,
    maxLatencyMs: null,
    requiredLicense: null,
  ),
  'VOICE_SERVER': const ServiceType(
    id: 'VOICE_SERVER',
    name: 'Voice Server',
    category: 'Communication',
    description: 'Low-latency voice chat hosting (TeamSpeak/Mumble-style).',
    capacityUnitLabel: 'concurrent voice user',
    base: ResourceCost(cpu: 2, ramGB: 0.2, storageGB: 0.5, bandwidthMbps: 0.2),
    perUnit: ResourceCost(cpu: 0.4, ramGB: 0.03, storageGB: 0.01, bandwidthMbps: 0.15),
    incomePerUnitPerDay: 0.2,
    maxLatencyMs: 100,
    requiredLicense: null,
  ),
  'MINECRAFT_SERVER': const ServiceType(
    id: 'MINECRAFT_SERVER',
    name: 'Minecraft Server',
    category: 'Game Hosting',
    description: 'Heavy CPU, moderate RAM/storage/network. Latency-sensitive.',
    capacityUnitLabel: 'player slot',
    base: ResourceCost(cpu: 8, ramGB: 0.5, storageGB: 2, bandwidthMbps: 0.2),
    perUnit: ResourceCost(cpu: 2.5, ramGB: 0.12, storageGB: 0.05, bandwidthMbps: 0.25),
    incomePerUnitPerDay: 0.35,
    maxLatencyMs: 80,
    requiredLicense: 'GAME_HOSTING',
  ),
  'GENERIC_GAME_SERVER': const ServiceType(
    id: 'GENERIC_GAME_SERVER',
    name: 'Game Server (Survival/Sandbox)',
    category: 'Game Hosting',
    description: 'Rust/Valheim-style dedicated servers. Heavier than Minecraft per slot.',
    capacityUnitLabel: 'player slot',
    base: ResourceCost(cpu: 12, ramGB: 1, storageGB: 4, bandwidthMbps: 0.3),
    perUnit: ResourceCost(cpu: 3.5, ramGB: 0.2, storageGB: 0.08, bandwidthMbps: 0.3),
    incomePerUnitPerDay: 0.5,
    maxLatencyMs: 60,
    requiredLicense: 'GAME_HOSTING',
  ),
  'CLOUD_STORAGE': const ServiceType(
    id: 'CLOUD_STORAGE',
    name: 'Cloud Storage',
    category: 'Storage',
    description: 'Personal cloud storage and file hosting. Storage-hungry, not CPU-hungry.',
    capacityUnitLabel: 'storage customer (~50GB)',
    base: ResourceCost(cpu: 1, ramGB: 0.2, storageGB: 5, bandwidthMbps: 0.1),
    perUnit: ResourceCost(cpu: 0.2, ramGB: 0.05, storageGB: 50, bandwidthMbps: 0.3),
    incomePerUnitPerDay: 0.9,
    maxLatencyMs: null,
    requiredLicense: 'CLOUD_STORAGE',
  ),
  'VPN_PROVIDER': const ServiceType(
    id: 'VPN_PROVIDER',
    name: 'VPN Provider',
    category: 'Network',
    description: 'Encrypted tunnel endpoints for privacy-focused customers.',
    capacityUnitLabel: 'concurrent VPN user',
    base: ResourceCost(cpu: 2, ramGB: 0.2, storageGB: 0.2, bandwidthMbps: 0.3),
    perUnit: ResourceCost(cpu: 0.5, ramGB: 0.05, storageGB: 0.02, bandwidthMbps: 0.6),
    incomePerUnitPerDay: 0.4,
    maxLatencyMs: 50,
    requiredLicense: 'VPN_HOSTING',
  ),
  'CDN_EDGE': const ServiceType(
    id: 'CDN_EDGE',
    name: 'CDN Edge Node',
    category: 'Network',
    description: "Caches and serves other sites' static assets close to their users.",
    capacityUnitLabel: 'cache tier (~100GB/day)',
    base: ResourceCost(cpu: 3, ramGB: 1, storageGB: 10, bandwidthMbps: 0.5),
    perUnit: ResourceCost(cpu: 0.6, ramGB: 0.3, storageGB: 20, bandwidthMbps: 1.0),
    incomePerUnitPerDay: 1.1,
    maxLatencyMs: 40,
    requiredLicense: 'CDN_HOSTING',
  ),
  'EMAIL_HOSTING': const ServiceType(
    id: 'EMAIL_HOSTING',
    name: 'Email Hosting',
    category: 'Communication',
    description: 'Business email domains and mailboxes. Light load, steady income.',
    capacityUnitLabel: 'mailbox',
    base: ResourceCost(cpu: 1.5, ramGB: 0.3, storageGB: 2, bandwidthMbps: 0.1),
    perUnit: ResourceCost(cpu: 0.1, ramGB: 0.02, storageGB: 0.5, bandwidthMbps: 0.03),
    incomePerUnitPerDay: 0.12,
    maxLatencyMs: null,
    requiredLicense: 'EMAIL_HOSTING',
  ),
  'DATABASE_HOSTING': const ServiceType(
    id: 'DATABASE_HOSTING',
    name: 'Database Hosting',
    category: 'Data',
    description: 'Managed database instances for other businesses.',
    capacityUnitLabel: 'database instance',
    base: ResourceCost(cpu: 3, ramGB: 1, storageGB: 5, bandwidthMbps: 0.2),
    perUnit: ResourceCost(cpu: 1.2, ramGB: 0.5, storageGB: 5, bandwidthMbps: 0.15),
    incomePerUnitPerDay: 0.8,
    maxLatencyMs: 100,
    requiredLicense: 'DATABASE_HOSTING',
  ),
  'AI_INFERENCE': const ServiceType(
    id: 'AI_INFERENCE',
    name: 'AI Inference Hosting',
    category: 'AI',
    description: 'CPU-driven inference workloads. Extremely CPU/RAM hungry.',
    capacityUnitLabel: 'inference request tier',
    base: ResourceCost(cpu: 20, ramGB: 4, storageGB: 20, bandwidthMbps: 0.3),
    perUnit: ResourceCost(cpu: 8, ramGB: 1.5, storageGB: 0.5, bandwidthMbps: 0.3),
    incomePerUnitPerDay: 2.2,
    maxLatencyMs: 200,
    requiredLicense: 'AI_HOSTING',
  ),
};

late final List<ServiceType> serviceList = servicesById.values.toList()
  ..sort((a, b) => a.name.compareTo(b.name));
