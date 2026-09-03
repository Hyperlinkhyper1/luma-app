import 'dart:convert';

import 'package:http/http.dart' as http;

import 'loader_profile_merger.dart';
import 'piston_meta_client.dart';

class FabricInstallerException implements Exception {
  FabricInstallerException(this.message);
  final String message;
  @override
  String toString() => message;
}

class FabricLoaderVersion {
  FabricLoaderVersion({required this.version, required this.stable});
  final String version;
  final bool stable;
}

/// Fabric is manifest-driven (unlike Forge/NeoForge): `meta.fabricmc.net`
/// serves a ready-to-use "profile json" per Minecraft+loader version pair
/// that [mergeLoaderProfile] layers onto the vanilla version detail — no
/// installer jar or bespoke processor pipeline needed.
class FabricInstaller {
  const FabricInstaller._();

  static Future<List<FabricLoaderVersion>> fetchLoaderVersions(String mcVersion) async {
    final res = await http
        .get(Uri.parse('https://meta.fabricmc.net/v2/versions/loader/$mcVersion'))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw FabricInstallerException(
          'No Fabric loader builds found for Minecraft $mcVersion.');
    }
    final list = jsonDecode(res.body) as List;
    return [
      for (final entry in list)
        FabricLoaderVersion(
          version: ((entry as Map<String, dynamic>)['loader'] as Map<String, dynamic>)['version']
              as String,
          stable: (entry['loader'] as Map<String, dynamic>)['stable'] as bool? ?? false,
        ),
    ];
  }

  static Future<VersionDetail> mergedVersionDetail({
    required String mcVersion,
    required String loaderVersion,
    required VersionDetail vanilla,
  }) async {
    final res = await http
        .get(Uri.parse(
            'https://meta.fabricmc.net/v2/versions/loader/$mcVersion/$loaderVersion/profile/json'))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw FabricInstallerException('Could not fetch the Fabric $loaderVersion profile.');
    }
    return mergeLoaderProfile(vanilla, jsonDecode(res.body) as Map<String, dynamic>);
  }
}
