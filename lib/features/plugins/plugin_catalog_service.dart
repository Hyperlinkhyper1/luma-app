import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thrown when the plugin catalog or a plugin's manifest can't be fetched.
class PluginCatalogException implements Exception {
  PluginCatalogException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// One entry in the marketplace grid, as listed in `plugins/registry.json`.
class PluginCatalogEntry {
  const PluginCatalogEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.version,
  });

  final String id;
  final String name;
  final String description;
  final String icon;
  final String category;
  final String version;

  factory PluginCatalogEntry.fromJson(Map<String, dynamic> json) =>
      PluginCatalogEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        icon: json['icon'] as String? ?? 'extension',
        category: json['category'] as String? ?? 'Utility',
        version: json['version'] as String? ?? '1.0.0',
      );
}

/// A single plugin's manifest, fetched on demand when the user downloads it.
class PluginManifest {
  const PluginManifest({
    required this.name,
    required this.version,
    required this.icon,
  });

  final String name;
  final String version;
  final String icon;

  factory PluginManifest.fromJson(Map<String, dynamic> json) =>
      PluginManifest(
        name: json['name'] as String,
        version: json['version'] as String? ?? '1.0.0',
        icon: json['icon'] as String? ?? 'extension',
      );
}

/// Talks to the `plugins/` folder of the luma-app GitHub repo. The catalog
/// lives outside the compiled app so it can change without shipping a new
/// build — the marketplace page fetches it live, and downloading a plugin
/// re-fetches its manifest to confirm it's reachable before installing it.
class PluginCatalogService {
  static const _rawBase =
      'https://raw.githubusercontent.com/Hyperlinkhyper1/luma-app/master/plugins';

  Future<List<PluginCatalogEntry>> fetchCatalog() async {
    final body = await _getJson('$_rawBase/registry.json');
    final list = (body['plugins'] as List).cast<Map<String, dynamic>>();
    return list.map(PluginCatalogEntry.fromJson).toList(growable: false);
  }

  Future<PluginManifest> fetchManifest(String pluginId) async {
    final body = await _getJson('$_rawBase/$pluginId/manifest.json');
    return PluginManifest.fromJson(body);
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final http.Response res;
    try {
      res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
    } catch (_) {
      throw PluginCatalogException(
          'Could not reach the plugin repo. Check your connection.');
    }
    if (res.statusCode != 200) {
      throw PluginCatalogException(
          'Plugin repo returned an error (${res.statusCode}).');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
