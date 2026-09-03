import 'steam_requirements.dart';

/// Steam's image CDN. Every capsule below is addressable from the app id
/// alone, which is what keeps the library grid to zero API calls — the store
/// API is rate limited, so asking it for 300 header images would stall long
/// before the grid finished painting.
const _cdn = 'https://cdn.cloudflare.steamstatic.com/steam/apps';

/// The wide 460x215 capsule, used for the grid tile and the detail hero.
String steamHeaderImage(int appId) => '$_cdn/$appId/header.jpg';

/// One hit from Steam's public store search — no key, no account, which is
/// what makes it the plugin's primary way to start tracking a game rather
/// than a fallback for people without a Steam library connected.
class SteamSearchResult {
  const SteamSearchResult({
    required this.appId,
    required this.name,
    this.tinyImage,
  });

  final int appId;
  final String name;

  /// A small capsule thumbnail for the search result row. Steam's search
  /// response includes this directly rather than the plugin needing a
  /// second request per result.
  final String? tinyImage;

  static SteamSearchResult? fromJson(Map<String, dynamic> json) {
    final appId = switch (json['id']) {
      final int v => v,
      final String v => int.tryParse(v),
      _ => null,
    };
    final name = json['name'];
    if (appId == null || name is! String || name.trim().isEmpty) return null;
    return SteamSearchResult(
      appId: appId,
      name: name.trim(),
      tinyImage: json['tiny_image'] is String
          ? json['tiny_image'] as String
          : null,
    );
  }
}

/// One game in the signed-in account's Steam library, as returned by
/// `IPlayerService/GetOwnedGames`.
class SteamLibraryGame {
  const SteamLibraryGame({
    required this.appId,
    required this.name,
    this.playtimeMinutes = 0,
  });

  final int appId;
  final String name;
  final int playtimeMinutes;

  String get headerImage => steamHeaderImage(appId);

  /// "12.5 h" / "40 min" / "Never played".
  String get playtimeLabel {
    if (playtimeMinutes <= 0) return 'Never played';
    if (playtimeMinutes < 60) return '$playtimeMinutes min';
    final hours = playtimeMinutes / 60;
    if (hours < 10) return '${hours.toStringAsFixed(1)} h';
    return '${hours.round()} h';
  }

  /// Reads one entry of `response.games`. Returns null for a row missing the
  /// two fields that make it addressable at all.
  static SteamLibraryGame? fromJson(Map<String, dynamic> json) {
    final appId = switch (json['appid']) {
      final int v => v,
      final String v => int.tryParse(v),
      _ => null,
    };
    final name = json['name'];
    if (appId == null || name is! String || name.trim().isEmpty) return null;
    return SteamLibraryGame(
      appId: appId,
      name: name.trim(),
      playtimeMinutes: switch (json['playtime_forever']) {
        final int v => v,
        final String v => int.tryParse(v) ?? 0,
        _ => 0,
      },
    );
  }
}

/// A price as Steam quotes it: integer minor units, never a double.
class SteamPrice {
  const SteamPrice({
    required this.finalCents,
    required this.initialCents,
    required this.discountPercent,
    required this.currency,
  });

  /// What it costs right now.
  final int finalCents;

  /// The undiscounted list price. Equal to [finalCents] when not on offer.
  final int initialCents;
  final int discountPercent;
  final String currency;

  bool get onSale => discountPercent > 0 && initialCents > finalCents;

  static SteamPrice? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final finalCents = _asInt(raw['final']);
    if (finalCents == null) return null;
    final initial = _asInt(raw['initial']) ?? finalCents;
    return SteamPrice(
      finalCents: finalCents,
      initialCents: initial,
      discountPercent: _asInt(raw['discount_percent']) ?? 0,
      currency: raw['currency'] is String ? raw['currency'] as String : 'USD',
    );
  }

  static int? _asInt(Object? v) => switch (v) {
        final int i => i,
        final String s => int.tryParse(s),
        final double d => d.round(),
        _ => null,
      };
}

/// The store page for one app, as far as this plugin cares about it.
class SteamAppDetails {
  const SteamAppDetails({
    required this.appId,
    required this.name,
    this.shortDescription = '',
    this.headerImage,
    this.backgroundImage,
    this.tags = const [],
    this.developers = const [],
    this.publishers = const [],
    this.releaseDate,
    this.metacritic,
    this.isFree = false,
    this.price,
    this.requirements = const SteamRequirements(),
    this.windows = true,
    this.mac = false,
    this.linux = false,
  });

  final int appId;
  final String name;
  final String shortDescription;
  final String? headerImage;

  /// The large store-page backdrop. Nicer than the capsule behind the hero,
  /// but not every app has one — the detail page falls back to the capsule.
  final String? backgroundImage;

  /// Genres and store categories, flattened into one list — what the store
  /// page shows as the game's tags.
  final List<String> tags;
  final List<String> developers;
  final List<String> publishers;
  final String? releaseDate;
  final int? metacritic;
  final bool isFree;

  /// Null for a free game, an unreleased one, or a region with no price.
  final SteamPrice? price;
  final SteamRequirements requirements;
  final bool windows;
  final bool mac;
  final bool linux;

  /// Parses one entry of the `appdetails` response body's `data` object.
  static SteamAppDetails? fromJson(int appId, Map<String, dynamic> data) {
    final name = data['name'];
    if (name is! String) return null;

    final tags = <String>[];
    for (final key in const ['genres', 'categories']) {
      final list = data[key];
      if (list is! List) continue;
      for (final entry in list) {
        if (entry is Map && entry['description'] is String) {
          final tag = (entry['description'] as String).trim();
          if (tag.isNotEmpty && !tags.contains(tag)) tags.add(tag);
        }
      }
    }

    return SteamAppDetails(
      appId: appId,
      name: name,
      shortDescription: data['short_description'] is String
          ? (data['short_description'] as String).trim()
          : '',
      headerImage:
          data['header_image'] is String ? data['header_image'] as String : null,
      backgroundImage: data['background_raw'] is String
          ? data['background_raw'] as String
          : null,
      tags: tags,
      developers: _stringList(data['developers']),
      publishers: _stringList(data['publishers']),
      releaseDate: data['release_date'] is Map
          ? (data['release_date'] as Map)['date'] as String?
          : null,
      metacritic: data['metacritic'] is Map
          ? SteamPrice._asInt((data['metacritic'] as Map)['score'])
          : null,
      isFree: data['is_free'] == true,
      price: SteamPrice.fromJson(data['price_overview']),
      requirements: SteamRequirements.fromJson(data['pc_requirements']),
      windows: _platform(data, 'windows', fallback: true),
      mac: _platform(data, 'mac'),
      linux: _platform(data, 'linux'),
    );
  }

  static bool _platform(
    Map<String, dynamic> data,
    String key, {
    bool fallback = false,
  }) {
    final platforms = data['platforms'];
    if (platforms is! Map) return fallback;
    return platforms[key] == true;
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final v in raw)
        if (v is String && v.trim().isNotEmpty) v.trim(),
    ];
  }
}
