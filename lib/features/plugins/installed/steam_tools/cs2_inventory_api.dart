import 'dart:convert';

import 'package:http/http.dart' as http;

/// A single owned CS2 item. Steam asset IDs identify individual copies.
class Cs2InventoryItem {
  const Cs2InventoryItem({
    required this.assetId,
    required this.marketHashName,
    required this.iconUrl,
  });

  final String assetId;
  final String marketHashName;
  final String iconUrl;
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
  Future<List<Cs2InventoryItem>> fetchInventory(String steamId) async {
    if (!RegExp(r'^\d{17}$').hasMatch(steamId)) {
      throw const Cs2InventoryException('Enter a valid 17-digit Steam ID.');
    }
    final items = <Cs2InventoryItem>[];
    final seenAssets = <String>{};
    final seenCursors = <String>{};
    String? cursor;
    while (true) {
      final uri = Uri.https('steamcommunity.com', '/inventory/$steamId/730/2', {
        'l': 'english',
        'count': '2000',
        if (cursor != null) 'start_assetid': cursor,
      });
      http.Response response;
      try {
        response = await _client.get(uri).timeout(_timeout);
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
      final assets = decoded['assets'];
      final descriptions = decoded['descriptions'];
      // Steam can omit both arrays for an empty inventory.
      if (assets == null && descriptions == null && decoded['total_inventory_count'] == 0) {
        return items;
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
        final tags = description['tags'];
        final isWeapon = tags is List && tags.any((tag) =>
            tag is Map && tag['category'] == 'Type' && _weaponTypes.contains(tag['internal_name']));
        final name = description['market_hash_name'];
        if (!isWeapon || name is! String || name.isEmpty) continue;
        final icon = description['icon_url'];
        items.add(Cs2InventoryItem(
          assetId: assetId,
          marketHashName: name,
          iconUrl: icon is String && icon.isNotEmpty
              ? 'https://community.cloudflare.steamstatic.com/economy/image/$icon'
              : '',
        ));
      }
      final more = decoded['more_items'] == 1 || decoded['more_items'] == true;
      if (!more) return items;
      final next = decoded['last_assetid'];
      if (next is! String || next.isEmpty || !seenCursors.add(next)) {
        throw const Cs2InventoryException('Steam returned an incomplete inventory.');
      }
      cursor = next;
    }
  }

  void close() => _client.close();
}
