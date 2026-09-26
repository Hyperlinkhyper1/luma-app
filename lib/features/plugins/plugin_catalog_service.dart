import 'dart:convert';

import 'package:flutter/services.dart';
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
    this.requiresAccount = false,
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

  /// Whether the plugin does nothing without an approved luma account,
  /// because everything it does runs through the server. Drives the
  /// marketplace's "Account required" badge; the gate that actually stops it
  /// running is compiled in (`AppShell.serverOnlyPluginIds`), not read from
  /// this fetched file.
  final bool requiresAccount;

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
      requiresAccount: json['requiresAccount'] as bool? ?? false,
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

/// Reads the published catalog and adds plugins bundled with this build that
/// have not reached the published registry yet.
class PluginCatalogService {
  PluginCatalogService({Future<http.Response> Function(Uri)? get})
    : _get = get ?? ((uri) => http.get(uri));

  final Future<http.Response> Function(Uri) _get;

  static const _rawBase =
      'https://raw.githubusercontent.com/Hyperlinkhyper1/luma-app/master/plugins';
  static const _smartHomeManifestAsset = 'plugins/smart-home/manifest.json';

  Future<List<PluginCatalogEntry>> fetchCatalog() async {
    final body = await _getJson('$_rawBase/registry.json');
    final list = (body['plugins'] as List).cast<Map<String, dynamic>>();
    final smartHome = PluginCatalogEntry.fromJson(await _bundledSmartHome());
    return [
      smartHome,
      ...list
          .map(PluginCatalogEntry.fromJson)
          .where((entry) => entry.id != smartHome.id),
    ];
  }

  Future<PluginManifest> fetchManifest(String pluginId) async {
    final body = pluginId == 'smart-home'
        ? await _bundledSmartHome()
        : await _getJson('$_rawBase/$pluginId/manifest.json');
    return PluginManifest.fromJson(body);
  }

  Future<Map<String, dynamic>> _bundledSmartHome() async =>
      (jsonDecode(await rootBundle.loadString(_smartHomeManifestAsset)) as Map)
          .cast<String, dynamic>();

  /// Resolves a screenshot filename (as listed in a manifest) to the raw
  /// GitHub URL it's served from.
  static String screenshotUrl(String pluginId, String filename) =>
      '$_rawBase/$pluginId/screenshots/$filename';

  Future<Map<String, dynamic>> _getJson(String url) async {
    final http.Response res;
    try {
      res = await _get(Uri.parse(url)).timeout(const Duration(seconds: 12));
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
