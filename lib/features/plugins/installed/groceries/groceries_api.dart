import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// A supermarket the search API knows about.
class RemoteMarket {
  const RemoteMarket({
    required this.id,
    required this.slug,
    required this.name,
    this.logoUrl,
  });

  final int id;
  final String slug;
  final String name;
  final String? logoUrl;

  factory RemoteMarket.fromJson(Map<String, dynamic> json) => RemoteMarket(
        id: json['id'] as int,
        slug: json['slug'] as String,
        name: json['name'] as String,
        logoUrl: json['logoUrl'] as String?,
      );
}

/// A product returned by a search, already joined with its latest price and
/// market by the supermarket-db API.
class RemoteProduct {
  const RemoteProduct({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.imageUrl,
    required this.market,
    required this.price,
    required this.oldPrice,
    required this.isDiscounted,
  });

  final String id;
  final String name;
  final String? brand;
  final String? category;
  final String? imageUrl;
  final RemoteMarket market;
  final double? price;
  final double? oldPrice;
  final bool isDiscounted;

  factory RemoteProduct.fromJson(Map<String, dynamic> json) => RemoteProduct(
        id: '${json['id']}',
        name: json['name'] as String,
        brand: json['brand'] as String?,
        category: json['category'] as String?,
        imageUrl: json['imageUrl'] as String?,
        market: RemoteMarket.fromJson(json['market'] as Map<String, dynamic>),
        price: (json['price'] as num?)?.toDouble(),
        oldPrice: (json['oldPrice'] as num?)?.toDouble(),
        isDiscounted: json['isDiscounted'] as bool? ?? false,
      );
}

enum ProductSort { relevance, priceAsc, priceDesc, nameAsc }

extension on ProductSort {
  String get queryValue => switch (this) {
        ProductSort.relevance => 'relevance',
        ProductSort.priceAsc => 'price_asc',
        ProductSort.priceDesc => 'price_desc',
        ProductSort.nameAsc => 'name_asc',
      };
}

class GroceriesApiException implements Exception {
  GroceriesApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Talks to the supermarket-db HTTP API (search/filter/sort across Jumbo,
/// Albert Heijn and Lidl). Defaults to the hosted server so it works out of
/// the box; the address is still user-configurable (gear icon on the search
/// page) and persisted locally in case someone points it at their own
/// deployment instead (see supermarket-db/ at the repo root).
class GroceriesApi extends ChangeNotifier {
  GroceriesApi({http.Client? client}) : _client = client ?? http.Client() {
    _load();
  }

  static const _defaultBaseUrl = 'https://groceries.luma-app.cc';

  /// The old placeholder default, before the hosted server existed. A saved
  /// settings file holding exactly this value was never a deliberate user
  /// choice — it's the previous default going stale — so [_load] treats it
  /// as unset rather than making everyone who ran an earlier build manually
  /// re-enter the new address.
  static const _legacyDefaultBaseUrl = 'http://localhost:3000';

  /// Groceries servers must use HTTPS; plain HTTP is only tolerated for
  /// localhost and private-LAN addresses (matches [SyncApi.validateServerUrl]).
  static String? validateServerUrl(String raw) {
    final trimmed = raw.trim();
    final withoutSlash =
        trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
    final uri = Uri.tryParse(withoutSlash);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Enter the full server address, e.g. https://groceries.example.com';
    }
    if (uri.scheme == 'https') return null;
    if (uri.scheme != 'http') return 'Only http(s) addresses are supported.';
    final host = uri.host;
    final isPrivate = host == 'localhost' ||
        host.endsWith('.local') ||
        RegExp(r'^127\.').hasMatch(host) ||
        RegExp(r'^10\.').hasMatch(host) ||
        RegExp(r'^192\.168\.').hasMatch(host) ||
        RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(host);
    return isPrivate
        ? null
        : 'Plain http is only allowed for local/home-network servers. '
            'Use https:// for servers on the internet.';
  }

  final http.Client _client;
  String _baseUrl = _defaultBaseUrl;
  String get baseUrl => _baseUrl;

  File? _file;

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}/luma_groceries_settings.json');
    return _file!;
  }

  Future<void> _load() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final stored = raw['baseUrl'] as String?;
        if (stored != null && stored.isNotEmpty && stored != _legacyDefaultBaseUrl) {
          _baseUrl = stored;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.trim().isEmpty ? _defaultBaseUrl : url.trim();
    notifyListeners();
    try {
      final file = await _getFile();
      await file.writeAsString(jsonEncode({'baseUrl': _baseUrl}));
    } catch (_) {}
  }

  Uri _uri(String path, Map<String, String> query) {
    final base = Uri.parse(_baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl);
    return base.replace(
      path: '${base.path}$path',
      queryParameters: query.isEmpty ? null : query,
    );
  }

  Future<T> _get<T>(
    Uri uri,
    T Function(Map<String, dynamic> body) parse,
  ) async {
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw GroceriesApiException(
            'The groceries server returned an error (${response.statusCode}).');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return parse(body);
    } on GroceriesApiException {
      rethrow;
    } on TimeoutException {
      throw GroceriesApiException('The groceries server took too long to respond.');
    } on SocketException {
      throw GroceriesApiException(
          'Could not reach the groceries server at $_baseUrl. Check the address in settings.');
    } on FormatException {
      throw GroceriesApiException('The groceries server sent back an unexpected response.');
    } catch (_) {
      throw GroceriesApiException('Could not reach the groceries server.');
    }
  }

  Future<List<RemoteMarket>> fetchMarkets() {
    return _get(_uri('/api/markets', const {}), (body) {
      final list = body['markets'] as List<dynamic>? ?? const [];
      return list
          .map((e) => RemoteMarket.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    });
  }

  Future<List<RemoteProduct>> search({
    String? query,
    List<String>? marketSlugs,
    ProductSort sort = ProductSort.relevance,
    int limit = 40,
    int offset = 0,
  }) {
    final params = <String, String>{
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (marketSlugs != null && marketSlugs.isNotEmpty) 'market': marketSlugs.join(','),
      'sort': sort.queryValue,
      'limit': '$limit',
      'offset': '$offset',
    };
    return _get(_uri('/api/products/search', params), (body) {
      final list = body['products'] as List<dynamic>? ?? const [];
      return list
          .map((e) => RemoteProduct.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    });
  }
}
