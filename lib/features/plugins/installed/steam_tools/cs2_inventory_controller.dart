import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'cs2_inventory_api.dart';
import 'cs2_steam_session.dart';

/// How the last inventory read went with respect to the Steam sign-in.
enum Cs2SteamSessionStatus {
  /// The user has not chosen to sign in.
  off,

  /// Read as the owner; trade-protected items are included.
  active,

  /// Sign-in is on, but Steam says nobody is signed in any more.
  signedOut,

  /// Signed in to Steam as an account other than the connected profile.
  otherAccount,

  /// The Steam browser failed; the public listing was used instead.
  failed,
}

/// Stores a public Steam profile and imports complete snapshots.
///
/// With the optional Steam sign-in, reads go through the user's own session
/// so trade-protected items are listed too. Should that session lapse, the
/// public listing is used and the protected items already seen are kept for
/// as long as protection can last, so the costs set on them survive.
class Cs2InventoryController extends ChangeNotifier {
  Cs2InventoryController({
    required Future<void> Function(String, List<Cs2InventoryItem>) importInventory,
    Cs2InventoryApi? api,
    Future<File> Function()? profileFile,
    this.refreshInterval = const Duration(hours: 6),
    this.sessionWait = const Duration(seconds: 15),
    DateTime Function()? now,
  })  : _importInventory = importInventory,
        _api = api ?? Cs2InventoryApi(),
        _ownsApi = api == null,
        _profileFile = profileFile ?? _defaultProfileFile,
        _now = now ?? DateTime.now;

  /// Steam's trade protection lasts up to seven days; a day of slack covers
  /// clock and refresh-interval drift.
  static const protectionWindow = Duration(days: 8);

  final Future<void> Function(String, List<Cs2InventoryItem>) _importInventory;
  final Cs2InventoryApi _api;
  final bool _ownsApi;
  final Future<File> Function() _profileFile;
  final DateTime Function() _now;
  final Duration refreshInterval;

  /// How long a read waits for the Steam browser to come up before falling
  /// back to the public listing.
  final Duration sessionWait;

  String? _steamId;
  String? _lastError;
  bool _busy = false;
  bool _disposed = false;
  Timer? _timer;
  int _hiddenCount = 0;
  bool _sessionEnabled = false;
  Cs2SteamSessionStatus _sessionStatus = Cs2SteamSessionStatus.off;
  Cs2SteamSession? _session;
  Completer<void>? _sessionArrived;

  /// Trade-locked copies seen through the session, with when each was first
  /// seen locked.
  final Map<String, ({Cs2InventoryItem item, DateTime seen})> _protected = {};

  String? get steamId => _steamId;
  String? get lastError => _lastError;
  bool get busy => _busy;

  /// Trade-protected items the last snapshot could not see.
  int get hiddenCount => _hiddenCount;

  /// Whether the user chose to read the inventory through a Steam sign-in.
  /// The tab mounts the Steam browser only while this is true.
  bool get sessionEnabled => _sessionEnabled;
  Cs2SteamSessionStatus get sessionStatus => _sessionStatus;

  /// Hands over the Steam browser's session, or null when it goes away.
  void attachSession(Cs2SteamSession? session) {
    _session = session;
    if (session != null) {
      _sessionArrived?.complete();
      _sessionArrived = null;
    }
  }

  Future<Cs2SteamSession?> _waitForSession() async {
    final ready = _session;
    if (ready != null) return ready;
    final arrived = _sessionArrived ??= Completer<void>();
    try {
      await arrived.future.timeout(sessionWait);
    } on TimeoutException {
      return null;
    }
    return _session;
  }

  Future<void> _fetchAndImport(String id) async {
    Cs2InventorySnapshot? owned;
    if (_sessionEnabled) owned = await _readAsOwner(id);
    final snapshot = owned ?? await _api.fetchSnapshot(id);
    if (_disposed) return;
    if (owned != null) {
      await _importInventory(id, snapshot.items);
      _rememberProtected(snapshot.items);
      _hiddenCount = snapshot.hiddenCount;
      return;
    }
    final kept = _keptProtected(snapshot);
    await _importInventory(id, [...snapshot.items, ...kept]);
    _hiddenCount = snapshot.hiddenCount > kept.length
        ? snapshot.hiddenCount - kept.length
        : 0;
  }

  /// A snapshot read as the owner, or null to fall back to the public one.
  Future<Cs2InventorySnapshot?> _readAsOwner(String id) async {
    final session = await _waitForSession();
    if (session == null) {
      _sessionStatus = Cs2SteamSessionStatus.failed;
      return null;
    }
    try {
      final who = await session.signedInSteamId();
      if (who == null) {
        _sessionStatus = Cs2SteamSessionStatus.signedOut;
        return null;
      }
      if (who != id) {
        _sessionStatus = Cs2SteamSessionStatus.otherAccount;
        return null;
      }
      final snapshot = await _api.fetchSnapshot(id, loader: session.load);
      _sessionStatus = Cs2SteamSessionStatus.active;
      return snapshot;
    } catch (_) {
      _sessionStatus = Cs2SteamSessionStatus.failed;
      return null;
    }
  }

  void _rememberProtected(List<Cs2InventoryItem> items) {
    final now = _now();
    final next = <String, ({Cs2InventoryItem item, DateTime seen})>{
      for (final item in items)
        if (item.tradeLocked)
          item.assetId: (item: item, seen: _protected[item.assetId]?.seen ?? now),
    };
    _protected
      ..clear()
      ..addAll(next);
  }

  /// Protected copies the public listing is missing while Steam still says
  /// something is hidden. A copy that really left would otherwise come back
  /// as a new one, losing its cost, the moment the session reads it again.
  List<Cs2InventoryItem> _keptProtected(Cs2InventorySnapshot snapshot) {
    if (snapshot.hiddenCount == 0) return const [];
    final present = {for (final item in snapshot.items) item.assetId};
    final cutoff = _now().subtract(protectionWindow);
    return [
      for (final entry in _protected.values)
        if (!present.contains(entry.item.assetId) && entry.seen.isAfter(cutoff))
          entry.item,
    ];
  }

  static Future<File> _defaultProfileFile() async {
    final dir = await getApplicationSupportDirectory();
    return File([dir.path, 'cs2_inventory_profile.json'].join(Platform.pathSeparator));
  }

  Future<void> _saveProfile(String id) async {
    final file = await _profileFile();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode({
      'steamId': id,
      if (_sessionEnabled) 'steamSession': true,
      if (_protected.isNotEmpty)
        'protected': [
          for (final entry in _protected.values)
            {...entry.item.toJson(), 'seen': entry.seen.toUtc().toIso8601String()},
        ],
    }), flush: true);
    await temporary.rename(file.path);
  }

  void _restoreProtected(Object? raw) {
    _protected.clear();
    if (raw is! List) return;
    for (final entry in raw) {
      if (entry is! Map) continue;
      final seen = DateTime.tryParse(entry['seen'] is String ? entry['seen'] as String : '');
      if (seen == null || entry['assetId'] is! String || entry['marketHashName'] is! String) {
        continue;
      }
      final item = Cs2InventoryItem.fromJson(entry);
      _protected[item.assetId] = (item: item, seen: seen);
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _scheduleRefresh() {
    _timer?.cancel();
    if (_disposed || _steamId == null || refreshInterval <= Duration.zero) return;
    _timer = Timer.periodic(refreshInterval, (_) {
      if (!_busy) unawaited(refresh());
    });
  }

  /// Restore and refresh under one guard, then retry on the next interval.
  Future<void> startup() async {
    if (_busy || _disposed) return;
    _busy = true;
    _notify();
    try {
      final file = await _profileFile();
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        if (data is! Map || data['steamId'] is! String ||
            !RegExp(r'^\d{17}$').hasMatch(data['steamId'] as String)) {
          throw const FormatException('Saved Steam profile is invalid.');
        }
        _steamId = data['steamId'] as String;
        _sessionEnabled = data['steamSession'] == true;
        _restoreProtected(data['protected']);
        // Mounts the Steam browser before the read below waits for it.
        _notify();
      }
      _lastError = null;
      final id = _steamId;
      if (id != null && !_disposed) {
        await _fetchAndImport(id);
        if (!_disposed) await _saveProfile(id);
      }
    } catch (error) {
      _lastError = error.toString();
    } finally {
      _busy = false;
      _scheduleRefresh();
      _notify();
    }
  }

  /// Imports before recording a profile as connected.
  Future<bool> connect(String input) async {
    if (_busy || _disposed) return false;
    _busy = true;
    _lastError = null;
    _notify();
    final previousProtected = Map.of(_protected);
    try {
      final id = await _api.resolveSteamId(input);
      if (id != _steamId) _protected.clear();
      await _fetchAndImport(id);
      if (_disposed) return false;
      await _saveProfile(id);
      _steamId = id;
      _scheduleRefresh();
      return true;
    } catch (error) {
      _protected
        ..clear()
        ..addAll(previousProtected);
      _lastError = error.toString();
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Only complete successful snapshots reach the importer.
  Future<bool> refresh() async {
    final id = _steamId;
    if (_busy || _disposed || id == null) return false;
    _busy = true;
    _lastError = null;
    _notify();
    try {
      await _fetchAndImport(id);
      if (_disposed) return false;
      await _saveProfile(id);
      return true;
    } catch (error) {
      _lastError = error.toString();
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Turns on reading as the owner after the user signed in to Steam as
  /// [signedInId], connecting that account if it is not the current one.
  Future<bool> signIn(String signedInId) async {
    if (_busy || _disposed) return false;
    final wasEnabled = _sessionEnabled;
    _sessionEnabled = true;
    _notify();
    final ok = _steamId == signedInId ? await refresh() : await connect(signedInId);
    if (!ok && !wasEnabled) {
      _sessionEnabled = false;
      _sessionStatus = Cs2SteamSessionStatus.off;
      _notify();
    }
    return ok;
  }

  Future<void> _endSession() async {
    final session = _sessionEnabled ? await _waitForSession() : null;
    await session?.signOut();
    _sessionEnabled = false;
    _sessionStatus = Cs2SteamSessionStatus.off;
  }

  /// Signs out of Steam and goes back to the public listing.
  Future<bool> signOut() async {
    if (_busy || _disposed) return false;
    _busy = true;
    _lastError = null;
    _notify();
    try {
      await _endSession();
      final id = _steamId;
      if (id != null) await _saveProfile(id);
      return true;
    } catch (error) {
      _lastError = 'Could not sign out of Steam: $error';
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Stop refreshing; previously imported entries are retained.
  Future<bool> disconnect() async {
    if (_busy || _disposed) return false;
    _busy = true;
    _lastError = null;
    _notify();
    try {
      if (_sessionEnabled) {
        try {
          await _endSession();
        } catch (_) {
          _sessionEnabled = false;
          _sessionStatus = Cs2SteamSessionStatus.off;
        }
      }
      final file = await _profileFile();
      if (await file.exists()) await file.delete();
      _steamId = null;
      _protected.clear();
      _hiddenCount = 0;
      _timer?.cancel();
      _timer = null;
      return true;
    } catch (error) {
      _lastError = 'Could not disconnect Steam: $error';
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_ownsApi) _api.close();
    super.dispose();
  }
}
