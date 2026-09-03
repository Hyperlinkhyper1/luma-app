import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'mc_paths.dart';
import 'piston_meta_client.dart';

class ResolvedAsset {
  ResolvedAsset({required this.hash, required this.size});
  final String hash;
  final int size;

  /// `resources.download.minecraft.net` keys objects by the first two hex
  /// chars of their hash as a subdirectory, both remotely and in the local
  /// `assets/objects/` cache — this is that shared relative path.
  String get relativePath => '${hash.substring(0, 2)}/$hash';

  String get downloadUrl => 'https://resources.download.minecraft.net/$relativePath';
}

class AssetResolverException implements Exception {
  AssetResolverException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Fetches (and locally caches) a version's asset index, returning the flat
/// list of content-addressed objects it references.
class AssetResolver {
  AssetResolver._();
  static final AssetResolver instance = AssetResolver._();

  Future<List<ResolvedAsset>> resolveAssets(VersionDetail detail) async {
    final dir = await McPaths.assetsIndexes();
    final file = File('${dir.path}${Platform.pathSeparator}${detail.assetIndexId}.json');

    Map<String, dynamic> json;
    if (await file.exists()) {
      json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } else {
      final http.Response res;
      try {
        res = await http
            .get(Uri.parse(detail.assetIndexUrl))
            .timeout(const Duration(seconds: 30));
      } catch (_) {
        throw AssetResolverException('Could not download the asset index.');
      }
      if (res.statusCode != 200) {
        throw AssetResolverException('Asset index request failed (${res.statusCode}).');
      }
      json = jsonDecode(res.body) as Map<String, dynamic>;
      await file.writeAsString(res.body);
    }

    final objects = json['objects'] as Map<String, dynamic>;
    // The hash becomes both a URL segment and an on-disk path — accept only
    // strict lowercase-hex SHA1 so a tampered index can't smuggle path or
    // URL characters through it.
    final sha1Hex = RegExp(r'^[0-9a-f]{40}$');
    return [
      for (final entry in objects.values)
        if (sha1Hex.hasMatch((entry as Map<String, dynamic>)['hash'] as String? ?? ''))
          ResolvedAsset(
            hash: entry['hash'] as String,
            size: (entry['size'] as num).toInt(),
          ),
    ];
  }
}
