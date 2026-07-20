import 'dart:convert';

import 'package:http/http.dart' as http;

import 'loader_profile_merger.dart';
import 'piston_meta_client.dart';

class QuiltInstallerException implements Exception {
  QuiltInstallerException(this.message);
  final String message;
  @override
  String toString() => message;
}

class QuiltLoaderVersion {
  QuiltLoaderVersion({required this.version});
  final String version;
}

/// Quilt is a Fabric fork with an almost identical meta API (v3 instead of
/// v2, hosted at meta.quiltmc.org) — same manifest-driven profile-json
/// approach as [FabricInstaller], no installer jar involved.
class QuiltInstaller {
  const QuiltInstaller._();

  static Future<List<QuiltLoaderVersion>> fetchLoaderVersions(String mcVersion) async {
    final res = await http
        .get(Uri.parse('https://meta.quiltmc.org/v3/versions/loader/$mcVersion'))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw QuiltInstallerException('No Quilt loader builds found for Minecraft $mcVersion.');
    }
    final list = jsonDecode(res.body) as List;
    return [
      for (final entry in list)
        QuiltLoaderVersion(
          version: ((entry as Map<String, dynamic>)['loader'] as Map<String, dynamic>)['version']
              as String,
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
            'https://meta.quiltmc.org/v3/versions/loader/$mcVersion/$loaderVersion/profile/json'))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw QuiltInstallerException('Could not fetch the Quilt $loaderVersion profile.');
    }
    return mergeLoaderProfile(vanilla, jsonDecode(res.body) as Map<String, dynamic>);
  }
}
