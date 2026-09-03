import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'cs2_models.dart';

/// Raised when the item catalog can't be read from the network or the disk
/// cache.
class Cs2CatalogException implements Exception {
  const Cs2CatalogException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Loads the full CS2 item schema — every weapon, knife and glove finish,
/// with its rarity, the case it drops from, and a render.
///
/// Steam's own APIs have no such endpoint: the store and market only ever
/// answer for one item you already know the exact name of. This instead
/// reads ByMykel/CSGO-API, a community-maintained JSON dataset built from
/// the game's own client files and kept current by its own CI — the same
/// kind of "fetch a JSON file over HTTPS, no key" source this app already
/// uses for `plugins/registry.json`. It carries no prices; those still come
/// from Steam, per item, in [Cs2MarketApi].
class Cs2CatalogService {
  Cs2CatalogService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _datasetUrl =
      'https://cdn.jsdelivr.net/gh/ByMykel/CSGO-API@main/public/api/en/skins.json';
  static const _cacheFileName = 'luma_cs2_catalog.json';
  static const _timeout = Duration(seconds: 30);

  /// How long a cached catalog is trusted before a refresh is attempted.
  /// Skins ship a handful of times a year, so this is generous on purpose —
  /// there is nothing here worth spending a 5&nbsp;MB fetch on daily.
  static const freshness = Duration(days: 7);

  /// Reads whatever is cached on disk, ignoring [freshness] — callers decide
  /// whether that is good enough to show immediately while a refresh (if
  /// any) happens in the background. Null means nothing has ever been
  /// cached.
  Future<({List<Cs2SkinDef> items, DateTime fetchedAt})?> readCache() async {
    final file = await _cacheFile();
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final fetchedAtRaw = decoded['fetchedAt'];
      final itemsRaw = decoded['items'];
      if (fetchedAtRaw is! String || itemsRaw is! List) return null;
      final fetchedAt = DateTime.tryParse(fetchedAtRaw);
      if (fetchedAt == null) return null;
      final items = <Cs2SkinDef>[
        for (final entry in itemsRaw)
          if (entry is Map)
            if (Cs2SkinDef.fromCacheJson(entry.cast<String, dynamic>())
                case final skin?)
              skin,
      ];
      return (items: items, fetchedAt: fetchedAt);
    } catch (_) {
      return null;
    }
  }

  /// Fetches the live dataset and replaces the on-disk cache with it.
  Future<List<Cs2SkinDef>> refresh() async {
    http.Response response;
    try {
      response = await _client.get(Uri.parse(_datasetUrl)).timeout(_timeout);
    } catch (e) {
      throw const Cs2CatalogException(
        'Could not reach the item catalog. Check your connection and try '
        'again.',
      );
    }
    if (response.statusCode != 200) {
      throw Cs2CatalogException(
        'The item catalog returned an error (HTTP ${response.statusCode}).',
      );
    }

    List<dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as List;
    } catch (_) {
      throw const Cs2CatalogException(
        'The item catalog sent back something unreadable.',
      );
    }

    final items = <Cs2SkinDef>[
      for (final entry in decoded)
        if (entry is Map)
          if (Cs2SkinDef.fromCatalogJson(entry.cast<String, dynamic>())
              case final skin?)
            skin,
    ];
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final fetchedAt = DateTime.now();
    try {
      final file = await _cacheFile();
      await file.writeAsString(jsonEncode({
        'fetchedAt': fetchedAt.toIso8601String(),
        'items': [for (final item in items) item.toCacheJson()],
      }));
    } catch (_) {
      // A failed cache write is not worth losing an otherwise-good fetch
      // over — the catalog just refetches next launch instead of reading a
      // saved copy.
    }

    return items;
  }

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_cacheFileName');
  }

  void close() => _client.close();
}
