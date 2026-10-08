// Auto-ported from Roblox Server Hosting Tycoon

import '../../../../../l10n/current_l.dart';

class License {
  final String id;
  final int cost;
  final List<String> requires;
  final int minReputation;

  const License({
    required this.id,
    required this.cost,
    required this.requires,
    required this.minReputation,
  });

  String get name => switch (id) {
        'GAME_HOSTING' => currentL.serverTycoonLicenseGameHosting,
        'CLOUD_STORAGE' => currentL.serverTycoonLicenseCloudStorage,
        'VPN_HOSTING' => currentL.serverTycoonLicenseVpnHosting,
        'CDN_HOSTING' => currentL.serverTycoonLicenseCdnHosting,
        'EMAIL_HOSTING' => currentL.serverTycoonLicenseEmailHosting,
        'DATABASE_HOSTING' => currentL.serverTycoonLicenseDatabaseHosting,
        'AI_HOSTING' => currentL.serverTycoonLicenseAiHosting,
        'ENTERPRISE_HOSTING' => currentL.serverTycoonLicenseEnterpriseHosting,
        'CONTAINER_HOSTING' => currentL.serverTycoonLicenseContainerHosting,
        'STREAMING_HOSTING' => currentL.serverTycoonLicenseStreamingHosting,
        _ => id,
      };

  String get description => switch (id) {
        'GAME_HOSTING' => currentL.serverTycoonLicenseGameHostingDesc,
        'CLOUD_STORAGE' => currentL.serverTycoonLicenseCloudStorageDesc,
        'VPN_HOSTING' => currentL.serverTycoonLicenseVpnHostingDesc,
        'CDN_HOSTING' => currentL.serverTycoonLicenseCdnHostingDesc,
        'EMAIL_HOSTING' => currentL.serverTycoonLicenseEmailHostingDesc,
        'DATABASE_HOSTING' => currentL.serverTycoonLicenseDatabaseHostingDesc,
        'AI_HOSTING' => currentL.serverTycoonLicenseAiHostingDesc,
        'ENTERPRISE_HOSTING' => currentL.serverTycoonLicenseEnterpriseHostingDesc,
        'CONTAINER_HOSTING' => currentL.serverTycoonLicenseContainerHostingDesc,
        'STREAMING_HOSTING' => currentL.serverTycoonLicenseStreamingHostingDesc,
        _ => '',
      };
}

final Map<String, License> licensesById = {
  'GAME_HOSTING': const License(
    id: 'GAME_HOSTING',
    cost: 400,
    requires: [],
    minReputation: 0,
  ),
  'CLOUD_STORAGE': const License(
    id: 'CLOUD_STORAGE',
    cost: 600,
    requires: [],
    minReputation: 0,
  ),
  'VPN_HOSTING': const License(
    id: 'VPN_HOSTING',
    cost: 1200,
    requires: [],
    minReputation: 10,
  ),
  'CDN_HOSTING': const License(
    id: 'CDN_HOSTING',
    cost: 2500,
    requires: ['VPN_HOSTING'],
    minReputation: 20,
  ),
  'EMAIL_HOSTING': const License(
    id: 'EMAIL_HOSTING',
    cost: 900,
    requires: [],
    minReputation: 10,
  ),
  'DATABASE_HOSTING': const License(
    id: 'DATABASE_HOSTING',
    cost: 1500,
    requires: [],
    minReputation: 15,
  ),
  'AI_HOSTING': const License(
    id: 'AI_HOSTING',
    cost: 8000,
    requires: ['DATABASE_HOSTING'],
    minReputation: 40,
  ),
  'ENTERPRISE_HOSTING': const License(
    id: 'ENTERPRISE_HOSTING',
    cost: 25000,
    requires: ['DATABASE_HOSTING', 'CLOUD_STORAGE'],
    minReputation: 60,
  ),
  'CONTAINER_HOSTING': const License(
    id: 'CONTAINER_HOSTING',
    cost: 2000,
    requires: [],
    minReputation: 15,
  ),
  'STREAMING_HOSTING': const License(
    id: 'STREAMING_HOSTING',
    cost: 3500,
    requires: ['VPN_HOSTING'],
    minReputation: 20,
  ),
};

late final List<License> licenseList = licensesById.values.toList()
  ..sort((a, b) => a.cost.compareTo(b.cost));
