// Auto-ported from Roblox Server Hosting Tycoon

import '../../../../../l10n/current_l.dart';

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
  final ResourceCost base;
  final ResourceCost perUnit;
  final double incomePerUnitPerDay;
  final int? maxLatencyMs;
  final String? requiredLicense;

  const ServiceType({
    required this.id,
    required this.base,
    required this.perUnit,
    required this.incomePerUnitPerDay,
    this.maxLatencyMs,
    this.requiredLicense,
  });

  String get name => switch (id) {
        'DISCORD_BOT' => currentL.serverTycoonServiceDiscordBotName,
        'STATIC_WEBSITE' => currentL.serverTycoonServiceStaticWebsiteName,
        'DYNAMIC_WEBSITE_API' => currentL.serverTycoonServiceDynamicWebsiteApiName,
        'MONITORING_SERVER' => currentL.serverTycoonServiceMonitoringServerName,
        'VOICE_SERVER' => currentL.serverTycoonServiceVoiceServerName,
        'MINECRAFT_SERVER' => currentL.serverTycoonServiceMinecraftServerName,
        'GENERIC_GAME_SERVER' => currentL.serverTycoonServiceGenericGameServerName,
        'CLOUD_STORAGE' => currentL.serverTycoonServiceCloudStorageName,
        'VPN_PROVIDER' => currentL.serverTycoonServiceVpnProviderName,
        'CDN_EDGE' => currentL.serverTycoonServiceCdnEdgeName,
        'EMAIL_HOSTING' => currentL.serverTycoonServiceEmailHostingName,
        'DATABASE_HOSTING' => currentL.serverTycoonServiceDatabaseHostingName,
        'AI_INFERENCE' => currentL.serverTycoonServiceAiInferenceName,
        'CONTAINER_HOSTING' => currentL.serverTycoonServiceContainerHostingName,
        'STREAMING_RELAY' => currentL.serverTycoonServiceStreamingRelayName,
        'CI_CD_RUNNER' => currentL.serverTycoonServiceCiCdRunnerName,
        _ => id,
      };

  String get description => switch (id) {
        'DISCORD_BOT' => currentL.serverTycoonServiceDiscordBotDesc,
        'STATIC_WEBSITE' => currentL.serverTycoonServiceStaticWebsiteDesc,
        'DYNAMIC_WEBSITE_API' => currentL.serverTycoonServiceDynamicWebsiteApiDesc,
        'MONITORING_SERVER' => currentL.serverTycoonServiceMonitoringServerDesc,
        'VOICE_SERVER' => currentL.serverTycoonServiceVoiceServerDesc,
        'MINECRAFT_SERVER' => currentL.serverTycoonServiceMinecraftServerDesc,
        'GENERIC_GAME_SERVER' => currentL.serverTycoonServiceGenericGameServerDesc,
        'CLOUD_STORAGE' => currentL.serverTycoonServiceCloudStorageDesc,
        'VPN_PROVIDER' => currentL.serverTycoonServiceVpnProviderDesc,
        'CDN_EDGE' => currentL.serverTycoonServiceCdnEdgeDesc,
        'EMAIL_HOSTING' => currentL.serverTycoonServiceEmailHostingDesc,
        'DATABASE_HOSTING' => currentL.serverTycoonServiceDatabaseHostingDesc,
        'AI_INFERENCE' => currentL.serverTycoonServiceAiInferenceDesc,
        'CONTAINER_HOSTING' => currentL.serverTycoonServiceContainerHostingDesc,
        'STREAMING_RELAY' => currentL.serverTycoonServiceStreamingRelayDesc,
        'CI_CD_RUNNER' => currentL.serverTycoonServiceCiCdRunnerDesc,
        _ => id,
      };

  String get capacityUnitLabel => switch (id) {
        'DISCORD_BOT' => currentL.serverTycoonServiceDiscordBotCapacity,
        'STATIC_WEBSITE' => currentL.serverTycoonServiceStaticWebsiteCapacity,
        'DYNAMIC_WEBSITE_API' => currentL.serverTycoonServiceDynamicWebsiteApiCapacity,
        'MONITORING_SERVER' => currentL.serverTycoonServiceMonitoringServerCapacity,
        'VOICE_SERVER' => currentL.serverTycoonServiceVoiceServerCapacity,
        'MINECRAFT_SERVER' => currentL.serverTycoonServiceMinecraftServerCapacity,
        'GENERIC_GAME_SERVER' => currentL.serverTycoonServiceGenericGameServerCapacity,
        'CLOUD_STORAGE' => currentL.serverTycoonServiceCloudStorageCapacity,
        'VPN_PROVIDER' => currentL.serverTycoonServiceVpnProviderCapacity,
        'CDN_EDGE' => currentL.serverTycoonServiceCdnEdgeCapacity,
        'EMAIL_HOSTING' => currentL.serverTycoonServiceEmailHostingCapacity,
        'DATABASE_HOSTING' => currentL.serverTycoonServiceDatabaseHostingCapacity,
        'AI_INFERENCE' => currentL.serverTycoonServiceAiInferenceCapacity,
        'CONTAINER_HOSTING' => currentL.serverTycoonServiceContainerHostingCapacity,
        'STREAMING_RELAY' => currentL.serverTycoonServiceStreamingRelayCapacity,
        'CI_CD_RUNNER' => currentL.serverTycoonServiceCiCdRunnerCapacity,
        _ => id,
      };

  String get category => switch (id) {
        'DISCORD_BOT' => currentL.serverTycoonServiceCategoryAutomation,
        'STATIC_WEBSITE' => currentL.serverTycoonServiceCategoryWeb,
        'DYNAMIC_WEBSITE_API' => currentL.serverTycoonServiceCategoryWeb,
        'MONITORING_SERVER' => currentL.serverTycoonServiceCategoryOps,
        'VOICE_SERVER' => currentL.serverTycoonServiceCategoryCommunication,
        'MINECRAFT_SERVER' => currentL.serverTycoonServiceCategoryGameHosting,
        'GENERIC_GAME_SERVER' => currentL.serverTycoonServiceCategoryGameHosting,
        'CLOUD_STORAGE' => currentL.serverTycoonServiceCategoryStorage,
        'VPN_PROVIDER' => currentL.serverTycoonServiceCategoryNetwork,
        'CDN_EDGE' => currentL.serverTycoonServiceCategoryNetwork,
        'EMAIL_HOSTING' => currentL.serverTycoonServiceCategoryCommunication,
        'DATABASE_HOSTING' => currentL.serverTycoonServiceCategoryData,
        'AI_INFERENCE' => currentL.serverTycoonServiceCategoryAi,
        'CONTAINER_HOSTING' => currentL.serverTycoonServiceCategoryCloud,
        'STREAMING_RELAY' => currentL.serverTycoonServiceCategoryMedia,
        'CI_CD_RUNNER' => currentL.serverTycoonServiceCategoryDevops,
        _ => id,
      };
}

final Map<String, ServiceType> servicesById = {
  'DISCORD_BOT': const ServiceType(
    id: 'DISCORD_BOT',
    base: ResourceCost(cpu: 1, ramGB: 0.1, storageGB: 0.2, bandwidthMbps: 0.05),
    perUnit: ResourceCost(cpu: 1.5, ramGB: 0.15, storageGB: 0.3, bandwidthMbps: 0.1),
    incomePerUnitPerDay: 0.6,
    maxLatencyMs: null,
    requiredLicense: null,
  ),
  'STATIC_WEBSITE': const ServiceType(
    id: 'STATIC_WEBSITE',
    base: ResourceCost(cpu: 0.5, ramGB: 0.05, storageGB: 0.5, bandwidthMbps: 0.05),
    perUnit: ResourceCost(cpu: 0.3, ramGB: 0.05, storageGB: 0.2, bandwidthMbps: 0.15),
    incomePerUnitPerDay: 0.25,
    maxLatencyMs: null,
    requiredLicense: null,
  ),
  'DYNAMIC_WEBSITE_API': const ServiceType(
    id: 'DYNAMIC_WEBSITE_API',
    base: ResourceCost(cpu: 2, ramGB: 0.5, storageGB: 1, bandwidthMbps: 0.1),
    perUnit: ResourceCost(cpu: 0.8, ramGB: 0.2, storageGB: 0.1, bandwidthMbps: 0.2),
    incomePerUnitPerDay: 0.45,
    maxLatencyMs: 150,
    requiredLicense: null,
  ),
  'MONITORING_SERVER': const ServiceType(
    id: 'MONITORING_SERVER',
    base: ResourceCost(cpu: 1.5, ramGB: 0.3, storageGB: 2, bandwidthMbps: 0.1),
    perUnit: ResourceCost(cpu: 0.15, ramGB: 0.02, storageGB: 0.1, bandwidthMbps: 0.02),
    incomePerUnitPerDay: 0.3,
    maxLatencyMs: null,
    requiredLicense: null,
  ),
  'VOICE_SERVER': const ServiceType(
    id: 'VOICE_SERVER',
    base: ResourceCost(cpu: 2, ramGB: 0.2, storageGB: 0.5, bandwidthMbps: 0.2),
    perUnit: ResourceCost(cpu: 0.4, ramGB: 0.03, storageGB: 0.01, bandwidthMbps: 0.15),
    incomePerUnitPerDay: 0.2,
    maxLatencyMs: 100,
    requiredLicense: null,
  ),
  'MINECRAFT_SERVER': const ServiceType(
    id: 'MINECRAFT_SERVER',
    base: ResourceCost(cpu: 8, ramGB: 0.5, storageGB: 2, bandwidthMbps: 0.2),
    perUnit: ResourceCost(cpu: 2.5, ramGB: 0.12, storageGB: 0.05, bandwidthMbps: 0.25),
    incomePerUnitPerDay: 0.35,
    maxLatencyMs: 80,
    requiredLicense: 'GAME_HOSTING',
  ),
  'GENERIC_GAME_SERVER': const ServiceType(
    id: 'GENERIC_GAME_SERVER',
    base: ResourceCost(cpu: 12, ramGB: 1, storageGB: 4, bandwidthMbps: 0.3),
    perUnit: ResourceCost(cpu: 3.5, ramGB: 0.2, storageGB: 0.08, bandwidthMbps: 0.3),
    incomePerUnitPerDay: 0.5,
    maxLatencyMs: 60,
    requiredLicense: 'GAME_HOSTING',
  ),
  'CLOUD_STORAGE': const ServiceType(
    id: 'CLOUD_STORAGE',
    base: ResourceCost(cpu: 1, ramGB: 0.2, storageGB: 5, bandwidthMbps: 0.1),
    perUnit: ResourceCost(cpu: 0.2, ramGB: 0.05, storageGB: 50, bandwidthMbps: 0.3),
    incomePerUnitPerDay: 0.9,
    maxLatencyMs: null,
    requiredLicense: 'CLOUD_STORAGE',
  ),
  'VPN_PROVIDER': const ServiceType(
    id: 'VPN_PROVIDER',
    base: ResourceCost(cpu: 2, ramGB: 0.2, storageGB: 0.2, bandwidthMbps: 0.3),
    perUnit: ResourceCost(cpu: 0.5, ramGB: 0.05, storageGB: 0.02, bandwidthMbps: 0.6),
    incomePerUnitPerDay: 0.4,
    maxLatencyMs: 50,
    requiredLicense: 'VPN_HOSTING',
  ),
  'CDN_EDGE': const ServiceType(
    id: 'CDN_EDGE',
    base: ResourceCost(cpu: 3, ramGB: 1, storageGB: 10, bandwidthMbps: 0.5),
    perUnit: ResourceCost(cpu: 0.6, ramGB: 0.3, storageGB: 20, bandwidthMbps: 1.0),
    incomePerUnitPerDay: 1.1,
    maxLatencyMs: 40,
    requiredLicense: 'CDN_HOSTING',
  ),
  'EMAIL_HOSTING': const ServiceType(
    id: 'EMAIL_HOSTING',
    base: ResourceCost(cpu: 1.5, ramGB: 0.3, storageGB: 2, bandwidthMbps: 0.1),
    perUnit: ResourceCost(cpu: 0.1, ramGB: 0.02, storageGB: 0.5, bandwidthMbps: 0.03),
    incomePerUnitPerDay: 0.12,
    maxLatencyMs: null,
    requiredLicense: 'EMAIL_HOSTING',
  ),
  'DATABASE_HOSTING': const ServiceType(
    id: 'DATABASE_HOSTING',
    base: ResourceCost(cpu: 3, ramGB: 1, storageGB: 5, bandwidthMbps: 0.2),
    perUnit: ResourceCost(cpu: 1.2, ramGB: 0.5, storageGB: 5, bandwidthMbps: 0.15),
    incomePerUnitPerDay: 0.8,
    maxLatencyMs: 100,
    requiredLicense: 'DATABASE_HOSTING',
  ),
  'AI_INFERENCE': const ServiceType(
    id: 'AI_INFERENCE',
    base: ResourceCost(cpu: 20, ramGB: 4, storageGB: 20, bandwidthMbps: 0.3),
    perUnit: ResourceCost(cpu: 8, ramGB: 1.5, storageGB: 0.5, bandwidthMbps: 0.3),
    incomePerUnitPerDay: 2.2,
    maxLatencyMs: 200,
    requiredLicense: 'AI_HOSTING',
  ),
  'CONTAINER_HOSTING': const ServiceType(
    id: 'CONTAINER_HOSTING',
    base: ResourceCost(cpu: 6, ramGB: 1, storageGB: 3, bandwidthMbps: 0.2),
    perUnit: ResourceCost(cpu: 2, ramGB: 0.5, storageGB: 0.3, bandwidthMbps: 0.15),
    incomePerUnitPerDay: 1.4,
    maxLatencyMs: 120,
    requiredLicense: 'CONTAINER_HOSTING',
  ),
  'STREAMING_RELAY': const ServiceType(
    id: 'STREAMING_RELAY',
    base: ResourceCost(cpu: 5, ramGB: 0.8, storageGB: 2, bandwidthMbps: 1.0),
    perUnit: ResourceCost(cpu: 1.5, ramGB: 0.2, storageGB: 0.1, bandwidthMbps: 2.5),
    incomePerUnitPerDay: 1.8,
    maxLatencyMs: 60,
    requiredLicense: 'STREAMING_HOSTING',
  ),
  'CI_CD_RUNNER': const ServiceType(
    id: 'CI_CD_RUNNER',
    base: ResourceCost(cpu: 10, ramGB: 2, storageGB: 5, bandwidthMbps: 0.15),
    perUnit: ResourceCost(cpu: 4, ramGB: 0.8, storageGB: 1.5, bandwidthMbps: 0.1),
    incomePerUnitPerDay: 1.6,
    maxLatencyMs: null,
    requiredLicense: null,
  ),
};

List<ServiceType> get serviceList => servicesById.values.toList()
  ..sort((a, b) => a.name.compareTo(b.name));
