import 'dart:convert';

import 'package:http/http.dart' as http;

/// A single owned CS2 item. Steam asset IDs identify individual copies.
class Cs2InventoryItem {
  const Cs2InventoryItem({
    required this.assetId,
    required this.marketHashName,
    required this.iconUrl,
    this.typeName = '',
    this.rarityName = '',
    this.rarityColor,
    this.tradeLocked = false,
  });

  factory Cs2InventoryItem.fromJson(Map json) => Cs2InventoryItem(
    assetId: json['assetId'] as String,
    marketHashName: json['marketHashName'] as String,
    iconUrl: json['iconUrl'] as String? ?? '',
    typeName: json['typeName'] as String? ?? '',
    rarityName: json['rarityName'] as String? ?? '',
    rarityColor: json['rarityColor'] as String?,
    tradeLocked: json['tradeLocked'] == true,
  );

  Map<String, Object?> toJson() => {
    'assetId': assetId,
    'marketHashName': marketHashName,
    'iconUrl': iconUrl,
    'typeName': typeName,
    'rarityName': rarityName,
    'rarityColor': rarityColor,
    'tradeLocked': tradeLocked,
  };

  final String assetId;
  final String marketHashName;
  final String iconUrl;

  /// Steam's own "Type" tag, e.g. "Sticker", "Container" or "Rifle" — the
  /// only label there is for items the skin catalog does not cover.
  final String typeName;
  final String rarityName;

  /// "#rrggbb", or null when Steam sent no rarity colour.
  final String? rarityColor;

  /// Steam says this copy cannot be traded right now. Read through the
  /// owner's own session, that is how a trade-protected item shows up — the
  /// same item the public listing leaves out entirely.
  final bool tradeLocked;
}

/// The raw answer to one inventory page request.
class Cs2InventoryPage {
  const Cs2InventoryPage(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

/// Fetches one inventory page. The default goes straight to Steam without a
/// session; the signed-in Steam browser supplies one that reads as the
/// owner, which is the only way trade-protected items are listed.
typedef Cs2InventoryPageLoader = Future<Cs2InventoryPage> Function(Uri uri);

/// One complete read of an inventory.
class Cs2InventorySnapshot {
  const Cs2InventorySnapshot(this.items, {this.hiddenCount = 0});

  final List<Cs2InventoryItem> items;

  /// Items Steam counts but leaves out of the public listing. Since CS2's
  /// trade protection, recently traded or bought items stay hidden from
  /// anyone not signed in as the owner until protection ends (up to 7 days).
  final int hiddenCount;
}

class Cs2InventoryException implements Exception {
  const Cs2InventoryException(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => message;
}

/// Reads a public inventory without requiring a Steam session or API key.
class Cs2InventoryApi {
  Cs2InventoryApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 20);
  static const _weaponTypes = {
    'CSGO_Type_Pistol',
    'CSGO_Type_SMG',
    'CSGO_Type_Rifle',
    'CSGO_Type_SniperRifle',
    'CSGO_Type_Shotgun',
    'CSGO_Type_Machinegun',
    'CSGO_Type_Knife',
    'Type_Hands',
  };

  /// Whether a description is something the Community Market can price:
  /// skins, but also stickers, cases, keys, agents, patches, charms, music
  /// kits and graffiti. Medals, coins and stock items are not. A freshly
  /// traded item is briefly unmarketable while trade protection runs, which
  /// Steam signals with a restriction rather than dropping the flag for good.
  static bool _isPriceable(Map description, List? tags) {
    final marketable = description['marketable'];
    if (marketable == 1 || marketable == true) return true;
    if (description['market_tradable_restriction'] != null ||
        description['market_marketable_restriction'] != null) {
      return true;
    }
    if (_ownerSaysProtected(description)) return true;
    return tags != null && tags.any((tag) =>
        tag is Map && tag['category'] == 'Type' && _weaponTypes.contains(tag['internal_name']));
  }

  /// The owner's own view marks a trade-protected copy with a note like
  /// "Trade Protected" or "Tradable/Marketable After …" while dropping its
  /// marketable flag, so a protected sticker or case would otherwise look
  /// like a medal.
  static bool _ownerSaysProtected(Map description) {
    final notes = description['owner_descriptions'];
    if (notes is! List) return false;
    return notes.any((note) {
      final value = note is Map ? note['value'] : null;
      if (value is! String) return false;
      final text = value.toLowerCase();
      return text.contains('protected') || text.contains('tradable after') ||
          text.contains('marketable after');
    });
  }

  static Map? _tag(List? tags, String category) {
    if (tags == null) return null;
    for (final tag in tags) {
      if (tag is Map && tag['category'] == category) return tag;
    }
    return null;
  }

  /// Resolves a Steam profile URL, vanity name, or SteamID64 without a key.
  Future<String> resolveSteamId(String input) async {
    final value = input.trim();
    if (RegExp(r'^\d{17}$').hasMatch(value)) return value;
    String vanity;
    if (value.contains('/') || value.contains(':')) {
      final uri = Uri.tryParse(value);
      if (uri == null || uri.scheme != 'https' ||
          (uri.host != 'steamcommunity.com' && uri.host != 'www.steamcommunity.com') ||
          uri.userInfo.isNotEmpty || uri.hasPort || uri.query.isNotEmpty || uri.fragment.isNotEmpty) {
        throw const Cs2InventoryException('Enter a valid Steam profile URL or Steam ID.');
      }
      final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
      if (parts.length != 2) {
        throw const Cs2InventoryException('Enter a valid Steam profile URL or Steam ID.');
      }
      if (parts[0] == 'profiles' && RegExp(r'^\d{17}$').hasMatch(parts[1])) {
        return parts[1];
      }
      if (parts[0] != 'id') {
        throw const Cs2InventoryException('Enter a valid Steam profile URL or Steam ID.');
      }
      vanity = parts[1];
    } else {
      vanity = value;
    }
    if (!RegExp(r'^[A-Za-z0-9_-]{2,64}$').hasMatch(vanity)) {
      throw const Cs2InventoryException('Enter a valid Steam profile URL or Steam ID.');
    }
    http.Response response;
    try {
      response = await _client.get(Uri.https(
        'steamcommunity.com', '/id/$vanity/', {'xml': '1'},
      )).timeout(_timeout);
    } catch (_) {
      throw const Cs2InventoryException('Could not reach Steam. Try again later.');
    }
    if (response.statusCode == 429) {
      throw const Cs2InventoryException('Steam is rate limiting requests. Try again later.', status: 429);
    }
    if (response.statusCode != 200) {
      throw Cs2InventoryException('Could not find this Steam profile (${response.statusCode}).', status: response.statusCode);
    }
    final match = RegExp(r'<steamID64>\s*(\d{17})\s*</steamID64>').firstMatch(response.body);
    if (match == null) {
      throw const Cs2InventoryException('Could not find this Steam profile.');
    }
    return match.group(1)!;
  }
  /// Returns a complete snapshot or throws, so callers never mistake a
  /// failed or partial request for an empty inventory.
  Future<List<Cs2InventoryItem>> fetchInventory(String steamId) async =>
      (await fetchSnapshot(steamId)).items;

  Future<Cs2InventoryPage> _load(Uri uri) async {
    final response = await _client.get(uri).timeout(_timeout);
    return Cs2InventoryPage(response.statusCode, response.body);
  }

  /// [loader] replaces the plain request, e.g. with the signed-in Steam
  /// browser; parsing and every completeness check stay the same.
  Future<Cs2InventorySnapshot> fetchSnapshot(
    String steamId, {
    Cs2InventoryPageLoader? loader,
  }) async {
    if (!RegExp(r'^\d{17}$').hasMatch(steamId)) {
      throw const Cs2InventoryException('Enter a valid 17-digit Steam ID.');
    }
    final items = <Cs2InventoryItem>[];
    final seenAssets = <String>{};
    final seenCursors = <String>{};
    String? cursor;
    int? total;
    Cs2InventorySnapshot done() => Cs2InventorySnapshot(
      items,
      hiddenCount: total != null && total > seenAssets.length ? total - seenAssets.length : 0,
    );
    while (true) {
      final uri = Uri.https('steamcommunity.com', '/inventory/$steamId/730/2', {
        'l': 'english',
        'count': '2000',
        if (cursor != null) 'start_assetid': cursor,
      });
      Cs2InventoryPage response;
      try {
        response = await (loader ?? _load)(uri);
      } catch (_) {
        throw const Cs2InventoryException('Could not reach Steam. Try again later.');
      }
      if (response.statusCode == 403 || response.statusCode == 401) {
        throw Cs2InventoryException(
          'Steam could not access this inventory. Set your Steam inventory to Public and try again.',
          status: response.statusCode,
        );
      }
      if (response.statusCode == 429) {
        throw const Cs2InventoryException(
          'Steam is rate limiting inventory requests. Try again later.',
          status: 429,
        );
      }
      if (response.statusCode != 200) {
        throw Cs2InventoryException(
          'Steam returned an inventory error (${response.statusCode}).',
          status: response.statusCode,
        );
      }
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        throw const Cs2InventoryException('Steam returned an unreadable inventory.');
      }
      if (decoded is! Map || (decoded['success'] != 1 && decoded['success'] != true)) {
        throw const Cs2InventoryException(
          'Steam could not load this inventory. Check that it is Public and try again.',
        );
      }
      if (decoded['total_inventory_count'] is int) total = decoded['total_inventory_count'] as int;
      final assets = decoded['assets'];
      final descriptions = decoded['descriptions'];
      // Steam can omit both arrays for an empty inventory.
      if (assets == null && descriptions == null && decoded['total_inventory_count'] == 0) {
        return done();
      }
      if (assets is! List || descriptions is! List) {
        throw const Cs2InventoryException('Steam returned an incomplete inventory.');
      }
      if (assets.isEmpty && decoded['total_inventory_count'] is int &&
          (decoded['total_inventory_count'] as int) > 0 &&
          decoded['more_items'] != 1 && decoded['more_items'] != true) {
        throw const Cs2InventoryException('Steam returned an incomplete inventory.');
      }
      final byClass = <String, Map>{};
      for (final description in descriptions) {
        if (description is Map && description['classid'] is String && description['instanceid'] is String) {
          byClass['${description['classid']}:${description['instanceid']}'] = description;
        }
      }
      for (final asset in assets) {
        if (asset is! Map || asset['assetid'] is! String || asset['classid'] is! String || asset['instanceid'] is! String) {
          throw const Cs2InventoryException('Steam returned an incomplete inventory.');
        }
        final assetId = asset['assetid'] as String;
        final description = byClass['${asset['classid']}:${asset['instanceid']}'];
        if (description == null) {
          throw const Cs2InventoryException('Steam returned an incomplete inventory.');
        }
        if (!seenAssets.add(assetId)) continue;
        final rawTags = description['tags'];
        final tags = rawTags is List ? rawTags : null;
        final name = description['market_hash_name'];
        if (name is! String || name.isEmpty || !_isPriceable(description, tags)) continue;
        final icon = description['icon_url'];
        final tradable = description['tradable'];
        final type = _tag(tags, 'Type')?['localized_tag_name'];
        final rarity = _tag(tags, 'Rarity');
        final rarityName = rarity?['localized_tag_name'];
        final color = rarity?['color'];
        items.add(Cs2InventoryItem(
          assetId: assetId,
          marketHashName: name,
          iconUrl: icon is String && icon.isNotEmpty
              ? 'https://community.cloudflare.steamstatic.com/economy/image/$icon'
              : '',
          typeName: type is String ? type : '',
          rarityName: rarityName is String ? rarityName : '',
          rarityColor: color is String && RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(color)
              ? '#$color'
              : null,
          tradeLocked: tradable == 0 || tradable == false,
        ));
      }
      final more = decoded['more_items'] == 1 || decoded['more_items'] == true;
      if (!more) return done();
      final next = decoded['last_assetid'];
      if (next is! String || next.isEmpty || !seenCursors.add(next)) {
        throw const Cs2InventoryException('Steam returned an incomplete inventory.');
      }
      cursor = next;
    }
  }

  void close() => _client.close();
}
