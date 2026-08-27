import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../../../../storage/storage_guard.dart';
import 'cs2_catalog_service.dart';
import 'cs2_market_api.dart';
import 'cs2_models.dart';
import 'data/steam_database.dart';

/// Owns the CS2 item catalog (name, rarity, case, image — read from a
/// community dataset, never Steam) and the Community Market prices read for
/// whatever listings this device is watching.
///
/// Two data sources, two very different shapes: the catalog is a single
/// large fetch, refreshed rarely, held in memory for instant search; prices
/// are one small request per exact listing, fetched on demand and recorded
/// one row at a time — see [Cs2MarketPricePoints] for why that log is the
/// only price history that exists here at all.
class Cs2MarketRepository extends ChangeNotifier {
  Cs2MarketRepository(
    this._db, {
    Cs2CatalogService? catalogService,
    Cs2MarketApi? api,
  })  : _catalogService = catalogService ?? Cs2CatalogService(),
        _api = api ?? Cs2MarketApi();

  final SteamDatabase _db;
  final Cs2CatalogService _catalogService;
  final Cs2MarketApi _api;

  List<Cs2SkinDef> _catalog = const [];
  bool _catalogLoaded = false;
  bool _catalogLoading = false;
  String? _catalogError;
  DateTime? _catalogFetchedAt;

  /// Listings with a price check in flight — keyed by the exact market hash
  /// name, since two variants of the same skin are unrelated requests.
  final Set<String> _fetchingPrice = {};

  String? _error;

  int _priceChecked = 0;
  int _priceTotal = 0;
  bool _cancelPriceRefresh = false;

  bool get catalogLoaded => _catalogLoaded;
  bool get catalogLoading => _catalogLoading;
  String? get catalogError => _catalogError;
  DateTime? get catalogFetchedAt => _catalogFetchedAt;
  List<Cs2SkinDef> get catalog => List.unmodifiable(_catalog);
  int get catalogSize => _catalog.length;

  String? get error => _error;
  int get priceChecked => _priceChecked;
  int get priceTotal => _priceTotal;
  bool get refreshingPrices => _priceTotal > 0;

  bool isFetchingPrice(String marketHashName) =>
      _fetchingPrice.contains(marketHashName);

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// Loads whatever catalog is cached on disk (instant), then refreshes it
  /// in the background if it is missing or older than
  /// [Cs2CatalogService.freshness] — search works the moment a cache exists
  /// at all, rather than blocking on a ~5 MB fetch every launch.
  Future<void> loadCatalog() async {
    if (_catalogLoaded) return;
    try {
      final cached = await _catalogService.readCache();
      if (cached != null) {
        _catalog = cached.items;
        _catalogFetchedAt = cached.fetchedAt;
      }
    } catch (_) {
      // Fall through to a live fetch below.
    }
    _catalogLoaded = true;
    notifyListeners();

    final stale = _catalogFetchedAt == null ||
        DateTime.now().difference(_catalogFetchedAt!) >
            Cs2CatalogService.freshness;
    if (stale || _catalog.isEmpty) unawaited(refreshCatalog());
  }

  Future<void> refreshCatalog({bool force = false}) async {
    if (_catalogLoading) return;
    if (!force &&
        _catalog.isNotEmpty &&
        _catalogFetchedAt != null &&
        DateTime.now().difference(_catalogFetchedAt!) <
            Cs2CatalogService.freshness) {
      return;
    }
    _catalogLoading = true;
    _catalogError = null;
    notifyListeners();
    try {
      _catalog = await _catalogService.refresh();
      _catalogFetchedAt = DateTime.now();
    } on Cs2CatalogException catch (e) {
      _catalogError = e.message;
    } catch (e) {
      _catalogError = 'Could not update the item catalog: $e';
    } finally {
      _catalogLoading = false;
      notifyListeners();
    }
  }

  /// Case-insensitive substring search over name, weapon, rarity and case —
  /// entirely in memory, since the whole catalog is a couple thousand rows
  /// already held for this purpose. Capped at [limit] so a broad term like
  /// "case hardened" does not hand the grid a thousand tiles to lay out.
  List<Cs2SkinDef> search(String query, {int limit = 120}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <Cs2SkinDef>[];
    for (final skin in _catalog) {
      if (out.length >= limit) break;
      if (skin.name.toLowerCase().contains(q) ||
          skin.weaponName.toLowerCase().contains(q) ||
          skin.rarityName.toLowerCase().contains(q) ||
          (skin.caseName?.toLowerCase().contains(q) ?? false)) {
        out.add(skin);
      }
    }
    return out;
  }

  Cs2SkinDef? skinById(String id) {
    for (final skin in _catalog) {
      if (skin.id == id) return skin;
    }
    return null;
  }

  Stream<List<Cs2MarketItem>> watchTrackedItems() => _db.watchTrackedCs2Items();
  Stream<Cs2MarketItem?> watchItem(String marketHashName) =>
      _db.watchCs2Item(marketHashName);
  Stream<List<Cs2MarketPricePoint>> watchPriceHistory(
    String marketHashName,
  ) =>
      _db.watchCs2PriceHistory(marketHashName);

  Future<bool> isTracked(String marketHashName) async =>
      await _db.cs2Item(marketHashName) != null;

  /// Skins pinned to the top of the browse grid — a bookmark on the finish
  /// itself, independent of whether any of its wears are being tracked.
  Stream<Set<String>> watchPinnedSkinIds() => _db.watchPinnedSkinIds();

  Future<void> pinSkin(String skinId) => _db.pinSkin(skinId);
  Future<void> unpinSkin(String skinId) => _db.unpinSkin(skinId);

  Future<void> togglePin(String skinId, {required bool pinned}) =>
      pinned ? unpinSkin(skinId) : pinSkin(skinId);

  /// A one-off price read that is never persisted — how the detail page
  /// shows "price now" for a listing that isn't being watched yet, without
  /// starting a history for something the user was only glancing at.
  Future<Cs2MarketPrice?> checkPriceOnce(String marketHashName) async {
    if (_fetchingPrice.contains(marketHashName)) return null;
    _fetchingPrice.add(marketHashName);
    notifyListeners();
    try {
      return await _api.priceOverview(marketHashName);
    } on Cs2MarketApiException catch (e) {
      _error = e.message;
      return null;
    } catch (e) {
      _error = 'Could not check that price: $e';
      return null;
    } finally {
      _fetchingPrice.remove(marketHashName);
      notifyListeners();
    }
  }

  /// Starts watching one exact listing — a specific finish, wear and
  /// StatTrak state — and fetches its price immediately so the new row has
  /// one right away instead of waiting for the next sweep.
  Future<void> track({
    required Cs2SkinDef skin,
    String? wear,
    required bool statTrak,
  }) async {
    StorageGuard.instance.ensureWithinLimit();
    final marketHashName =
        cs2MarketHashName(baseName: skin.name, wear: wear, statTrak: statTrak);
    await _db.addTrackedCs2Item(Cs2MarketItemsCompanion.insert(
      marketHashName: marketHashName,
      skinId: skin.id,
      displayName: skin.name,
      weaponName: skin.weaponName,
      rarityName: skin.rarityName,
      rarityColor: skin.rarityColor,
      caseName: Value(skin.caseName),
      imageUrl: skin.imageUrl,
      wear: Value(wear),
      statTrak: Value(statTrak),
    ));
    StorageGuard.instance.scheduleRefresh();
    unawaited(refreshPrice(marketHashName, force: true));
  }

  Future<void> untrack(String marketHashName) async {
    await _db.removeTrackedCs2Item(marketHashName);
    StorageGuard.instance.scheduleRefresh();
  }

  /// How long a tracked listing's price is trusted before [refreshPrice]
  /// bothers Steam again. Shorter than the game store's 12h: a market order
  /// book moves through the day in a way a store's list price does not.
  static const _priceFreshness = Duration(hours: 3);

  Future<void> refreshPrice(String marketHashName, {bool force = false}) async {
    if (_fetchingPrice.contains(marketHashName)) return;
    if (!force) {
      final row = await _db.cs2Item(marketHashName);
      final at = row?.priceFetchedAt;
      if (at != null && DateTime.now().difference(at) < _priceFreshness) {
        return;
      }
    }

    _fetchingPrice.add(marketHashName);
    notifyListeners();
    try {
      StorageGuard.instance.ensureWithinLimit();
      final price = await _api.priceOverview(marketHashName);
      await _db.recordCs2Price(
        marketHashName,
        lowestCents: price?.lowestCents,
        medianCents: price?.medianCents,
        currency: 'USD',
      );
      StorageGuard.instance.scheduleRefresh();
    } on Cs2MarketApiException catch (e) {
      _error = e.message;
    } on StorageLimitExceededException {
      // Over the storage cap: skip this reading rather than crash the page.
    } catch (_) {
      // One unreadable price is not worth an error banner.
    } finally {
      _fetchingPrice.remove(marketHashName);
      notifyListeners();
    }
  }

  /// The Community Market rate-limits far more aggressively than the store
  /// API — this spacing is deliberately wider than
  /// `SteamRepository._storeCallSpacing`.
  static const _marketCallSpacing = Duration(milliseconds: 2600);

  Future<void> refreshAllPrices() async {
    if (_priceTotal > 0) return;
    final items = await _db.watchTrackedCs2Items().first;
    if (items.isEmpty) return;

    _cancelPriceRefresh = false;
    _priceChecked = 0;
    _priceTotal = items.length;
    _error = null;
    notifyListeners();

    try {
      for (final item in items) {
        if (_cancelPriceRefresh) break;
        try {
          final price = await _api.priceOverview(item.marketHashName);
          await _db.recordCs2Price(
            item.marketHashName,
            lowestCents: price?.lowestCents,
            medianCents: price?.medianCents,
            currency: 'USD',
          );
        } on Cs2MarketApiException catch (e) {
          if (e.status == 429) {
            _error = e.message;
            break;
          }
        } catch (_) {
          // Skip this listing and keep going.
        }
        _priceChecked++;
        notifyListeners();
        if (!_cancelPriceRefresh) await Future.delayed(_marketCallSpacing);
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

  @override
  void dispose() {
    _cancelPriceRefresh = true;
    _catalogService.close();
    _api.close();
    super.dispose();
  }
}
