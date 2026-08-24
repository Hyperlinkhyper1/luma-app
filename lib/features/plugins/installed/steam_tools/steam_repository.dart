import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../../storage/storage_guard.dart';
import 'data/steam_database.dart';
import 'steam_api.dart';
import 'steam_credentials.dart';
import 'steam_models.dart';
import 'steam_requirements.dart';

/// Owns the Steam library, the store details fetched for it, and the price
/// history this device has recorded.
class SteamRepository extends ChangeNotifier {
  SteamRepository(
    this._db, {
    SteamApi? api,
    SteamCredentialStore? credentialStore,
  })  : _api = api ?? SteamApi(),
        _store = credentialStore;

  final SteamDatabase _db;
  final SteamApi _api;
  SteamCredentialStore? _store;

  SteamCredentials? _credentials;
  bool _loaded = false;
  bool _connecting = false;
  bool _syncing = false;
  String? _error;
  DateTime? _lastSyncAt;

  /// Games whose store page is being fetched right now, so each detail page
  /// can show its own spinner without a rebuild storm across the grid.
  final Set<int> _fetching = {};

  /// How far through a full price refresh we are, for the progress line.
  int _priceChecked = 0;
  int _priceTotal = 0;
  bool _cancelPriceRefresh = false;

  SteamDatabase get db => _db;

  /// False until [load] has run — the UI shows nothing rather than flashing
  /// the connect form at someone who is already connected.
  bool get loaded => _loaded;
  bool get connected => _credentials?.isComplete ?? false;
  SteamCredentials? get credentials => _credentials;
  bool get connecting => _connecting;
  bool get syncing => _syncing;
  String? get error => _error;
  DateTime? get lastSyncAt => _lastSyncAt;
  int get priceChecked => _priceChecked;
  int get priceTotal => _priceTotal;
  bool get refreshingPrices => _priceTotal > 0;

  bool isFetchingDetails(int appId) => _fetching.contains(appId);

  Stream<List<SteamGame>> watchLibrary() => _db.watchLibrary();
  Stream<SteamGame?> watchGame(int appId) => _db.watchGame(appId);
  Stream<List<SteamPricePoint>> watchPriceHistory(int appId) =>
      _db.watchPriceHistory(appId);

  Future<SteamCredentialStore> _credentialStore() async =>
      _store ??= await SteamCredentialStore.load();

  /// Reads the saved credentials. Safe to call more than once.
  Future<void> load() async {
    if (_loaded) return;
    try {
      _credentials = await (await _credentialStore()).read();
    } catch (_) {
      _credentials = null;
    }
    _loaded = true;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// Verifies the key and id by actually reading the library with them, then
  /// saves both.
  ///
  /// Storing credentials that turn out not to work would leave the plugin
  /// looking connected and failing on every screen, so nothing is written
  /// until Steam has answered.
  Future<bool> connect({
    required String apiKey,
    required String steamIdOrUrl,
  }) async {
    if (_connecting) return false;
    _connecting = true;
    _error = null;
    notifyListeners();

    try {
      final key = apiKey.trim();
      if (key.isEmpty) {
        throw const SteamApiException('Enter your Steam Web API key.');
      }
      final steamId = await _api.resolveSteamId(steamIdOrUrl, apiKey: key);
      final games = await _api.ownedGames(apiKey: key, steamId: steamId);

      final credentials = SteamCredentials(apiKey: key, steamId: steamId);
      await (await _credentialStore()).save(credentials);
      _credentials = credentials;

      await _storeLibrary(games);
      _lastSyncAt = DateTime.now();
      return true;
    } on SteamApiException catch (e) {
      _error = e.message;
      return false;
    } on StorageLimitExceededException catch (e) {
      _error = e.toString();
      return false;
    } catch (e) {
      _error = 'Could not connect to Steam: $e';
      return false;
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  /// Forgets the account and everything read with it.
  Future<void> disconnect() async {
    await (await _credentialStore()).clear();
    _credentials = null;
    _lastSyncAt = null;
    _error = null;
    await _db.clearLibrary();
    notifyListeners();
  }

  /// Re-reads the library from Steam.
  Future<void> refreshLibrary() async {
    final credentials = _credentials;
    if (credentials == null || _syncing) return;
    _syncing = true;
    _error = null;
    notifyListeners();

    try {
      final games = await _api.ownedGames(
        apiKey: credentials.apiKey,
        steamId: credentials.steamId,
      );
      await _storeLibrary(games);
      _lastSyncAt = DateTime.now();
    } on SteamApiException catch (e) {
      _error = e.message;
    } on StorageLimitExceededException catch (e) {
      _error = e.toString();
    } catch (e) {
      _error = 'Could not refresh your library: $e';
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _storeLibrary(List<SteamLibraryGame> games) async {
    StorageGuard.instance.ensureWithinLimit();
    await _db.replaceLibrary([
      for (final g in games)
        (appId: g.appId, name: g.name, playtimeMinutes: g.playtimeMinutes),
    ]);
    StorageGuard.instance.scheduleRefresh();
  }

  /// How long a store page is considered current. Descriptions and system
  /// requirements almost never change; the price is the part worth
  /// re-reading, and [refreshAllPrices] does that on demand.
  static const _detailsFreshness = Duration(hours: 12);

  /// Fetches the store page for [appId] if it has never been read or has
  /// gone stale, and records the price if it moved.
  Future<void> ensureDetails(int appId, {bool force = false}) async {
    if (_fetching.contains(appId)) return;

    if (!force) {
      final existing = await (_db.select(_db.steamGames)
            ..where((g) => g.appId.equals(appId)))
          .getSingleOrNull();
      final fetchedAt = existing?.detailsFetchedAt;
      if (fetchedAt != null &&
          DateTime.now().difference(fetchedAt) < _detailsFreshness) {
        return;
      }
    }

    _fetching.add(appId);
    notifyListeners();
    try {
      final details = await _api.appDetails(appId, countryCode: countryCode);
      if (details != null) await _applyDetails(details);
    } on SteamApiException catch (e) {
      _error = e.message;
    } on StorageLimitExceededException {
      // Over the storage cap: skip rather than crash the page.
    } catch (_) {
      // A single unreadable store page is not worth an error banner; the
      // page falls back to what the library already knows.
    } finally {
      _fetching.remove(appId);
      notifyListeners();
    }
  }

  Future<void> _applyDetails(SteamAppDetails details) async {
    StorageGuard.instance.ensureWithinLimit();
    final price = details.price;

    await (_db.update(_db.steamGames)
          ..where((g) => g.appId.equals(details.appId)))
        .write(SteamGamesCompanion(
      name: Value(details.name),
      shortDescription: Value(details.shortDescription),
      headerImage: Value(details.headerImage),
      backgroundImage: Value(details.backgroundImage),
      tags: Value(details.tags.join('\n')),
      requirements: Value(encodeSteamRequirements(details.requirements)),
      developers: Value(details.developers.join(', ')),
      publishers: Value(details.publishers.join(', ')),
      releaseDate: Value(details.releaseDate),
      metacritic: Value(details.metacritic),
      isFree: Value(details.isFree),
      onWindows: Value(details.windows),
      onMac: Value(details.mac),
      onLinux: Value(details.linux),
      lastPriceCents: Value(price?.finalCents),
      lastInitialCents: Value(price?.initialCents),
      lastDiscountPercent: Value(price?.discountPercent),
      currency: Value(price?.currency),
      detailsFetchedAt: Value(DateTime.now()),
    ));

    if (price != null) await _recordPrice(details.appId, price);
  }

  /// Appends a price point, but only when the price actually moved.
  ///
  /// The chart is a step line, so a run of identical observations adds
  /// nothing to it — recording every poll would grow the file without ever
  /// changing what is drawn.
  Future<void> _recordPrice(int appId, SteamPrice price) async {
    final latest = await _db.latestPricePoint(appId);
    if (latest != null &&
        latest.finalCents == price.finalCents &&
        latest.initialCents == price.initialCents &&
        latest.discountPercent == price.discountPercent &&
        latest.currency == price.currency) {
      return;
    }
    await _db.into(_db.steamPricePoints).insert(
          SteamPricePointsCompanion.insert(
            appId: appId,
            observedAt: DateTime.now(),
            finalCents: price.finalCents,
            initialCents: price.initialCents,
            discountPercent: Value(price.discountPercent),
            currency: price.currency,
          ),
        );
    StorageGuard.instance.scheduleRefresh();
  }

  /// Steam's store API allows roughly 200 requests per five minutes per
  /// address. A full refresh spaces its calls to stay well inside that, so a
  /// large library takes a while rather than getting the device throttled.
  static const _storeCallSpacing = Duration(milliseconds: 1600);

  /// Re-reads every game's price, one at a time, to extend the history.
  Future<void> refreshAllPrices() async {
    if (_priceTotal > 0) return;
    final games = await _db.watchLibrary().first;
    if (games.isEmpty) return;

    _cancelPriceRefresh = false;
    _priceChecked = 0;
    _priceTotal = games.length;
    _error = null;
    notifyListeners();

    try {
      for (final game in games) {
        if (_cancelPriceRefresh) break;
        try {
          final details =
              await _api.appDetails(game.appId, countryCode: countryCode);
          if (details != null) await _applyDetails(details);
        } on SteamApiException catch (e) {
          // Rate limiting is the one failure worth stopping for: every
          // remaining call would fail the same way.
          if (e.status == 429) {
            _error = e.message;
            break;
          }
        } catch (_) {
          // Skip this game and keep going.
        }
        _priceChecked++;
        notifyListeners();
        if (!_cancelPriceRefresh) await Future.delayed(_storeCallSpacing);
      }
    } finally {
      _priceChecked = 0;
      _priceTotal = 0;
      notifyListeners();
    }
  }

  void cancelPriceRefresh() {
    if (_priceTotal == 0) return;
    _cancelPriceRefresh = true;
    notifyListeners();
  }

  /// The store region to price in, taken from the device locale — a user in
  /// Amsterdam wants euros, not dollars.
  String get countryCode {
    try {
      final match = RegExp(r'[_-]([A-Za-z]{2})').firstMatch(Platform.localeName);
      if (match != null) return match.group(1)!.toLowerCase();
    } catch (_) {
      // Some platforms have no locale to report.
    }
    return 'us';
  }

  @override
  void dispose() {
    _cancelPriceRefresh = true;
    _api.close();
    super.dispose();
  }
}

/// Serialises parsed requirements for the `requirements` column.
String encodeSteamRequirements(SteamRequirements requirements) => jsonEncode({
      'minimum': [
        for (final line in requirements.minimum)
          {'label': line.label, 'value': line.value},
      ],
      'recommended': [
        for (final line in requirements.recommended)
          {'label': line.label, 'value': line.value},
      ],
    });

/// Reads back what [encodeSteamRequirements] wrote.
SteamRequirements decodeSteamRequirements(String? raw) {
  if (raw == null || raw.isEmpty) return const SteamRequirements();
  try {
    final json = jsonDecode(raw);
    if (json is! Map) return const SteamRequirements();
    return SteamRequirements(
      minimum: _decodeLines(json['minimum']),
      recommended: _decodeLines(json['recommended']),
    );
  } catch (_) {
    return const SteamRequirements();
  }
}

List<SteamRequirementLine> _decodeLines(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final entry in raw)
      if (entry is Map && entry['value'] is String)
        SteamRequirementLine(
          label: entry['label'] is String ? entry['label'] as String : null,
          value: entry['value'] as String,
        ),
  ];
}
