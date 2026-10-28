import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'cs2_inventory_api.dart';

/// Stores a public Steam profile and imports complete snapshots.
class Cs2InventoryController extends ChangeNotifier {
  Cs2InventoryController({
    required Future<void> Function(String, List<Cs2InventoryItem>) importInventory,
    Cs2InventoryApi? api,
    Future<File> Function()? profileFile,
    this.refreshInterval = const Duration(hours: 6),
  })  : _importInventory = importInventory,
        _api = api ?? Cs2InventoryApi(),
        _ownsApi = api == null,
        _profileFile = profileFile ?? _defaultProfileFile;

  final Future<void> Function(String, List<Cs2InventoryItem>) _importInventory;
  final Cs2InventoryApi _api;
  final bool _ownsApi;
  final Future<File> Function() _profileFile;
  final Duration refreshInterval;
  String? _steamId;
  String? _lastError;
  bool _busy = false;
  bool _disposed = false;
  Timer? _timer;

  String? get steamId => _steamId;
  String? get lastError => _lastError;
  bool get busy => _busy;

  static Future<File> _defaultProfileFile() async {
    final dir = await getApplicationSupportDirectory();
    return File([dir.path, 'cs2_inventory_profile.json'].join(Platform.pathSeparator));
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
      }
      _lastError = null;
      final id = _steamId;
      if (id != null && !_disposed) {
        final items = await _api.fetchInventory(id);
        if (!_disposed) await _importInventory(id, items);
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
    try {
      final id = await _api.resolveSteamId(input);
      final items = await _api.fetchInventory(id);
      if (_disposed) return false;
      await _importInventory(id, items);
      if (_disposed) return false;
      final file = await _profileFile();
      await file.parent.create(recursive: true);
      final temporary = File(file.path + '.tmp');
      await temporary.writeAsString(jsonEncode({'steamId': id}), flush: true);
      await temporary.rename(file.path);
      _steamId = id;
      _scheduleRefresh();
      return true;
    } catch (error) {
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
      final items = await _api.fetchInventory(id);
      if (_disposed) return false;
      await _importInventory(id, items);
      return true;
    } catch (error) {
      _lastError = error.toString();
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
      final file = await _profileFile();
      if (await file.exists()) await file.delete();
      _steamId = null;
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
