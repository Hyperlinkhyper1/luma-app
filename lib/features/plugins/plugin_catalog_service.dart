import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../l10n/current_l.dart';

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
    this.i18n = const {},
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

  /// Translated `name` and `description` by language code, from the
  /// entry's optional `i18n` map. English lives in the top-level fields.
  final Map<String, Map<String, String>> i18n;

  /// [name] in the language with code [languageCode], else English.
  String nameIn(String languageCode) =>
      i18n[languageCode]?['name'] ?? name;

  /// [description] in the language with code [languageCode], else English.
  String descriptionIn(String languageCode) =>
      i18n[languageCode]?['description'] ?? description;

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
      i18n: parseI18n(json['i18n']),
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
    this.i18n = const {},
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

  /// Translated `name`, `description` and `details` by language code.
  final Map<String, Map<String, String>> i18n;

  /// [details] in the language with code [languageCode], else English.
  String? detailsIn(String languageCode) =>
      i18n[languageCode]?['details'] ?? details;

  factory PluginManifest.fromJson(Map<String, dynamic> json) => PluginManifest(
    name: json['name'] as String,
    version: json['version'] as String? ?? '1.0.0',
    icon: json['icon'] as String? ?? 'extension',
    details: json['details'] as String?,
    screenshots: (json['screenshots'] as List?)?.cast<String>() ?? const [],
    i18n: parseI18n(json['i18n']),
  );
}

/// Reads a registry or manifest `i18n` map (`{"nl": {"name": …}}`),
/// skipping anything that isn't a string so a malformed entry can't break
/// the marketplace.
Map<String, Map<String, String>> parseI18n(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final MapEntry(:key, :value) in raw.entries)
      if (key is String && value is Map)
        key: {
          for (final MapEntry(key: field, value: text) in value.entries)
            if (field is String && text is String) field: text,
        },
  };
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
  static const _smallGamesManifestAsset = 'plugins/small-games/manifest.json';
  static const _pluginI18nAsset = 'assets/plugin_i18n.json';

  Future<Map<String, dynamic>>? _i18nCatalog;

  Future<Map<String, dynamic>> _loadI18nCatalog() =>
      _i18nCatalog ??= rootBundle
          .loadString(_pluginI18nAsset)
          .then((source) => jsonDecode(source) as Map<String, dynamic>);

  Future<List<PluginCatalogEntry>> fetchCatalog() async {
    final body = await _getJson('$_rawBase/registry.json');
    final list = (body['plugins'] as List).cast<Map<String, dynamic>>();
    final i18n = await _loadI18nCatalog();
    final pluginI18n = (i18n['plugins'] as Map?)?.cast<String, dynamic>() ?? {};
    final smartHome = PluginCatalogEntry.fromJson(await _bundledSmartHome());
    final smallGames = PluginCatalogEntry.fromJson(await _bundledSmallGames());
    return [
      _withCatalogI18n(smartHome, pluginI18n),
      _withCatalogI18n(smallGames, pluginI18n),
      ...list
          .map(PluginCatalogEntry.fromJson)
          .map((entry) => _withCatalogI18n(entry, pluginI18n))
          .where(
            (entry) => entry.id != smartHome.id && entry.id != smallGames.id,
          ),
    ];
  }

  Future<PluginManifest> fetchManifest(String pluginId) async {
    final body = switch (pluginId) {
      'smart-home' => await _bundledSmartHome(),
      'small-games' => await _bundledSmallGames(),
      _ => await _getJson('$_rawBase/$pluginId/manifest.json'),
    };
    final manifest = PluginManifest.fromJson(body);
    final i18n = await _loadI18nCatalog();
    final manifests = (i18n['manifests'] as Map?)?.cast<String, dynamic>() ?? {};
    return PluginManifest(
      name: manifest.name,
      version: manifest.version,
      icon: manifest.icon,
      details: manifest.details,
      screenshots: manifest.screenshots,
      i18n: _mergeI18n(
        manifest.i18n,
        parseI18n(manifests[pluginId]),
      ),
    );
  }

  PluginCatalogEntry _withCatalogI18n(
    PluginCatalogEntry entry,
    Map<String, dynamic> catalog,
  ) =>
      PluginCatalogEntry(
        id: entry.id,
        name: entry.name,
        description: entry.description,
        icon: entry.icon,
        category: entry.category,
        version: entry.version,
        tags: entry.tags,
        free: entry.free,
        requiresAccount: entry.requiresAccount,
        i18n: _mergeI18n(entry.i18n, parseI18n(catalog[entry.id])),
      );

  Map<String, Map<String, String>> _mergeI18n(
    Map<String, Map<String, String>> preferred,
    Map<String, Map<String, String>> fallback,
  ) => {
    for (final locale in {...fallback.keys, ...preferred.keys})
      locale: {
        ...?fallback[locale],
        ...?preferred[locale],
      },
  };

  Future<Map<String, dynamic>> _bundledSmartHome() async =>
      (jsonDecode(await rootBundle.loadString(_smartHomeManifestAsset)) as Map)
          .cast<String, dynamic>();

  Future<Map<String, dynamic>> _bundledSmallGames() async =>
      (jsonDecode(await rootBundle.loadString(_smallGamesManifestAsset)) as Map)
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
        currentL.marketplaceRepoUnreachable('$e'),
      );
    }
    if (res.statusCode != 200) {
      throw PluginCatalogException(
        currentL.marketplaceRepoError(res.statusCode),
      );
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
