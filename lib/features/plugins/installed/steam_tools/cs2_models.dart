/// One weapon/knife/glove finish from the community-maintained CS2 item
/// schema (ByMykel/CSGO-API) — name, rarity, the case it drops from, and a
/// render, none of which Steam's own APIs expose in one place. Steam
/// publishes prices, not item metadata; this dataset is what fills that gap.
class Cs2SkinDef {
  const Cs2SkinDef({
    required this.id,
    required this.name,
    required this.weaponName,
    required this.rarityName,
    required this.rarityColor,
    required this.imageUrl,
    required this.wears,
    required this.stattrak,
    required this.souvenir,
    this.caseName,
  });

  /// The dataset's own id, e.g. "skin-91a429af4a60" — stable across a
  /// catalog refresh, so a tracked item can be matched back to it.
  final String id;

  /// "AK-47 | Redline" — no wear suffix and no StatTrak/Souvenir prefix;
  /// those are applied only when building one specific market listing's
  /// name, since a single finish can be several different listings.
  final String name;
  final String weaponName;
  final String rarityName;

  /// A hex string straight from the dataset, e.g. "#d32ce6".
  final String rarityColor;

  final String imageUrl;

  /// Wear conditions this finish actually ships in, Factory New first. Empty
  /// for the handful of skins with no wear variants at all (vanilla knives),
  /// in which case the base name is itself the whole market listing.
  final List<String> wears;

  /// Whether a StatTrak™ / Souvenir version of this finish exists at all —
  /// not whether one specific listing is that version.
  final bool stattrak;
  final bool souvenir;

  /// The case this skin drops from, if any. Null for a collection-only or
  /// promotional item, which is rare but real — the UI says "No case" rather
  /// than inventing one.
  final String? caseName;

  static Cs2SkinDef? fromCatalogJson(Map<String, dynamic> json) {
    final name = json['name'];
    final rarity = json['rarity'];
    final image = json['image'];
    if (name is! String || rarity is! Map || image is! String) return null;
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return null;

    final weapon = json['weapon'];
    final weaponName = weapon is Map && weapon['name'] is String
        ? (weapon['name'] as String).trim()
        : trimmedName;
    final rarityName =
        rarity['name'] is String ? rarity['name'] as String : 'Unknown';
    final rarityColor =
        rarity['color'] is String ? rarity['color'] as String : '#b0c3d9';

    final wearsRaw = json['wears'];
    final wears = <String>[
      if (wearsRaw is List)
        for (final w in wearsRaw)
          if (w is Map && w['name'] is String) w['name'] as String,
    ];

    final crates = json['crates'];
    String? caseName;
    if (crates is List && crates.isNotEmpty) {
      final first = crates.first;
      if (first is Map && first['name'] is String) {
        caseName = first['name'] as String;
      }
    }

    return Cs2SkinDef(
      id: json['id'] is String ? json['id'] as String : trimmedName,
      name: trimmedName,
      weaponName: weaponName,
      rarityName: rarityName,
      rarityColor: rarityColor,
      imageUrl: image,
      wears: wears,
      stattrak: json['stattrak'] == true,
      souvenir: json['souvenir'] == true,
      caseName: caseName,
    );
  }

  /// A compact round-trip form for the on-disk catalog cache — the raw
  /// dataset carries a lot (descriptions, floats, patterns, team) that this
  /// plugin never reads, and skipping it keeps the cache file a fraction of
  /// the ~5 MB the live fetch costs.
  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'name': name,
        'weapon': weaponName,
        'rarity': rarityName,
        'color': rarityColor,
        'image': imageUrl,
        'wears': wears,
        'st': stattrak,
        'sv': souvenir,
        if (caseName != null) 'case': caseName,
      };

  static Cs2SkinDef? fromCacheJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String || name.isEmpty) return null;
    return Cs2SkinDef(
      id: json['id'] is String ? json['id'] as String : name,
      name: name,
      weaponName: json['weapon'] is String ? json['weapon'] as String : name,
      rarityName:
          json['rarity'] is String ? json['rarity'] as String : 'Unknown',
      rarityColor:
          json['color'] is String ? json['color'] as String : '#b0c3d9',
      imageUrl: json['image'] is String ? json['image'] as String : '',
      wears: (json['wears'] is List)
          ? (json['wears'] as List).whereType<String>().toList()
          : const [],
      stattrak: json['st'] == true,
      souvenir: json['sv'] == true,
      caseName: json['case'] is String ? json['case'] as String : null,
    );
  }
}

/// Builds the exact string Steam's market identifies one listing by.
///
/// StatTrak™ (and, on the store, Souvenir) sit between the star and the
/// weapon name for knives and gloves, and right at the start otherwise —
/// splitting on the star handles both without special-casing every weapon
/// type. This is Steam's own convention, not this plugin's invention: get it
/// wrong and the market simply has no listing under the built name.
String cs2MarketHashName({
  required String baseName,
  String? wear,
  bool statTrak = false,
}) {
  final wearSuffix = (wear == null || wear.isEmpty) ? '' : ' ($wear)';
  if (!statTrak) return '$baseName$wearSuffix';

  const star = '★ ';
  if (baseName.startsWith(star)) {
    return '$star${'StatTrak™ '}${baseName.substring(star.length)}$wearSuffix';
  }
  return 'StatTrak™ $baseName$wearSuffix';
}

/// A snapshot of what Steam's Community Market quotes for one listing right
/// now. Steam publishes no history behind this — only the current figure —
/// which is why the chart behind it is built locally from repeated reads of
/// exactly this.
class Cs2MarketPrice {
  const Cs2MarketPrice({
    required this.lowestCents,
    this.medianCents,
    this.volume,
  });

  /// The cheapest active listing. Null on the rare item with no active
  /// listings at all, where Steam answers with only a median (or nothing).
  final int? lowestCents;
  final int? medianCents;

  /// How many sold in the last 24h, when Steam reports it.
  final int? volume;

  static Cs2MarketPrice? fromJson(Map<String, dynamic> json) {
    if (json['success'] != true) return null;
    final lowest = _parseMoney(json['lowest_price']);
    final median = _parseMoney(json['median_price']);
    if (lowest == null && median == null) return null;
    return Cs2MarketPrice(
      lowestCents: lowest,
      medianCents: median,
      volume: switch (json['volume']) {
        final int v => v,
        final String v => int.tryParse(v.replaceAll(',', '')),
        _ => null,
      },
    );
  }

  /// Turns Steam's locale-formatted string ("$37.09", "1.785,34€", "€41,50")
  /// into integer cents. Only the digits and the last separator matter — the
  /// currency symbol and thousands grouping are noise for this purpose.
  static int? _parseMoney(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    final digitsAndSeparators = raw.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (digitsAndSeparators.isEmpty) return null;

    final lastDot = digitsAndSeparators.lastIndexOf('.');
    final lastComma = digitsAndSeparators.lastIndexOf(',');
    final decimalAt = lastDot > lastComma ? lastDot : lastComma;

    String normalized;
    if (decimalAt == -1) {
      normalized = digitsAndSeparators;
    } else {
      final whole =
          digitsAndSeparators.substring(0, decimalAt).replaceAll(RegExp(r'[.,]'), '');
      final fraction = digitsAndSeparators
          .substring(decimalAt + 1)
          .replaceAll(RegExp(r'[.,]'), '');
      normalized = '$whole.$fraction';
    }

    final value = double.tryParse(normalized);
    if (value == null) return null;
    return (value * 100).round();
  }
}
