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
    this.tags = const [],
    this.free = true,
  });

  final String id;
  final String name;
  final String description;
  final String icon;
  final String category;
  final String version;

  /// Filterable tags (e.g. "Utility", "Games"). Falls back to [category]
  /// when the registry entry doesn't list any.
  final List<String> tags;

  /// Whether the plugin is free to download. Reserved for a future paid
  /// plugin tier; every plugin in the official registry is free today.
  final bool free;

  factory PluginCatalogEntry.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as String? ?? 'Utility';
    final tags = (json['tags'] as List?)?.cast<String>();
    return PluginCatalogEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? 'extension',
      category: category,
      version: json['version'] as String? ?? '1.0.0',
      tags: tags == null || tags.isEmpty ? [category] : tags,
      free: json['free'] as bool? ?? true,
    );
  }
}

/// A single plugin's manifest, fetched on demand when the user downloads it
/// or opens its detail page. Carries the richer content (long-form details
/// and screenshots) that doesn't fit in the lightweight `registry.json`.
class PluginManifest {
  const PluginManifest({
    required this.name,
    required this.version,
    required this.icon,
    this.details,
    this.screenshots = const [],
  });

  final String name;
  final String version;
  final String icon;

  /// Long-form write-up shown on the plugin's detail page. Paragraphs are
  /// separated by a blank line. Falls back to the registry description when
  /// absent.
  final String? details;

  /// Screenshot filenames, resolved against
  /// `plugins/<id>/screenshots/<filename>` in the catalog repo — see
  /// [PluginCatalogService.screenshotUrl].
  final List<String> screenshots;

  factory PluginManifest.fromJson(Map<String, dynamic> json) => PluginManifest(
    name: json['name'] as String,
    version: json['version'] as String? ?? '1.0.0',
    icon: json['icon'] as String? ?? 'extension',
    details: json['details'] as String?,
    screenshots: (json['screenshots'] as List?)?.cast<String>() ?? const [],
  );
}

/// Talks to the `plugins/` folder of the luma-app GitHub repo. The catalog
/// lives outside the compiled app so it can change without shipping a new
/// build — the marketplace page fetches it live, and downloading a plugin
/// re-fetches its manifest to confirm it's reachable before installing it.
class PluginCatalogService {
  static const _rawBase =
      'http://127.0.0.1:9999'; // TEMP-QA-DECOY: intentionally wrong, isolating a caching bug

  Future<List<PluginCatalogEntry>> fetchCatalog() async {
    final body = await _getJson('$_rawBase/registry.json');
    final list = (body['plugins'] as List).cast<Map<String, dynamic>>();
    return list.map(PluginCatalogEntry.fromJson).toList(growable: false);
  }

  Future<PluginManifest> fetchManifest(String pluginId) async {
    final body = await _getJson('$_rawBase/$pluginId/manifest.json');
    return PluginManifest.fromJson(body);
  }

  /// Resolves a screenshot filename (as listed in a manifest) to the raw
  /// GitHub URL it's served from.
  static String screenshotUrl(String pluginId, String filename) =>
      '$_rawBase/$pluginId/screenshots/$filename';

  Future<Map<String, dynamic>> _getJson(String url) async {
    final http.Response res;
    try {
      res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
    } catch (e) {
      throw PluginCatalogException(
        'Could not reach the plugin repo. Check your connection.\n($e)',
      );
    }
    if (res.statusCode != 200) {
      throw PluginCatalogException(
        'Plugin repo returned an error (${res.statusCode}).',
      );
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
