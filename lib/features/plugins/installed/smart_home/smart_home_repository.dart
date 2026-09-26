import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../security/secure_secret_store.dart';
import 'dirigera_api.dart';
import 'dirigera_discovery.dart';
import 'smart_light.dart';
import 'smart_home_preset.dart';

abstract class SmartHomeCredentialStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class SecureSmartHomeCredentialStore implements SmartHomeCredentialStore {
  const SecureSmartHomeCredentialStore();

  static const _key = 'smart_home.dirigera';

  @override
  Future<String?> read() => SecureSecretStore.instance.read(_key);

  @override
  Future<void> write(String value) =>
      SecureSecretStore.instance.write(_key, value);

  @override
  Future<void> delete() => SecureSecretStore.instance.delete(_key);
}

class SmartHomeRepository extends ChangeNotifier {
  SmartHomeRepository({
    DirigeraApi? api,
    SmartHomeCredentialStore? credentials,
    SmartHomePresetStore? presetStore,
    DirigeraDiscovery? discovery,
  }) : _api = api ?? LocalDirigeraApi(),
       _discovery = discovery ?? const NsdDirigeraDiscovery(),
       _credentials = credentials ?? const SecureSmartHomeCredentialStore(),
       _presetStore = presetStore ?? const FileSmartHomePresetStore() {
    _load();
  }

  final DirigeraApi _api;
  final DirigeraDiscovery _discovery;
  final SmartHomeCredentialStore _credentials;
  final SmartHomePresetStore _presetStore;
  HubConnection? _connection;
  HubPairingChallenge? _challenge;
  List<SmartLight> _lights = const [];
  List<SmartHomePreset> _presets = const [];
  List<DiscoveredDirigeraHub> _discoveredHubs = const [];
  bool _discovering = false;
  bool _discoveryAttempted = false;
  String? _activatingPresetId;
  final Set<String> _busyLights = {};
  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool get loading => _loading;
  bool get busy => _busy || _busyLights.isNotEmpty;
  bool get paired => _connection != null;
  bool get pairingStarted => _challenge != null;
  String? get host => _connection?.host;
  String? get error => _error;
  List<SmartLight> get lights => List.unmodifiable(_lights);
  List<SmartHomePreset> get presets => List.unmodifiable(_presets);
  List<DiscoveredDirigeraHub> get discoveredHubs =>
      List.unmodifiable(_discoveredHubs);
  bool get discovering => _discovering;
  bool get discoveryAttempted => _discoveryAttempted;
  String? get activatingPresetId => _activatingPresetId;
  bool isBusy(String id) => _busyLights.contains(id);

  Future<void> _load() async {
    String? presetLoadError;
    try {
      _presets = await _presetStore.load();
    } catch (_) {
      presetLoadError = 'Could not load saved Smart Home presets.';
    }
    try {
      final saved = await _credentials.read();
      if (saved != null) {
        _connection = HubConnection.fromJson(
          (jsonDecode(saved) as Map).cast<String, dynamic>(),
        );
        await refresh();
      }
    } catch (_) {
      _error = 'Could not read the saved hub connection from secure storage.';
    } finally {
      _error ??= presetLoadError;
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> beginPairing(String host) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    _challenge = null;
    notifyListeners();
    try {
      _challenge = await _api.beginPairing(host.trim());
    } catch (error) {
      _error = _message(error);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> discoverHubs() async {
    if (_discovering || paired) return;
    _discovering = true;
    _discoveryAttempted = true;
    _discoveredHubs = const [];
    _error = null;
    notifyListeners();
    try {
      _discoveredHubs = await _discovery.findHubs();
    } catch (_) {
      _error =
          'Could not search the local network for a DIRIGERA hub. '
          'Check local network permission, then try again or enter its IP address.';
    } finally {
      _discovering = false;
      notifyListeners();
    }
  }

  Future<void> completePairing() async {
    final challenge = _challenge;
    if (_busy || challenge == null) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final connection = await _api.completePairing(challenge);
      final lights = await _api.listLights(connection);
      await _credentials.write(jsonEncode(connection.toJson()));
      _connection = connection;
      _lights = lights;
      _challenge = null;
    } catch (error) {
      _error = _message(error);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final connection = _connection;
    if (busy || connection == null) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _lights = await _api.listLights(connection);
    } catch (error) {
      _error = _message(error);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _credentials.delete();
      _connection = null;
      _challenge = null;
      _lights = const [];
      _activatingPresetId = null;
    } catch (error) {
      _error = _message(error);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> setOn(SmartLight light, bool value) =>
      _set(light, 'isOn', value, light.canToggle);

  Future<void> setBrightness(SmartLight light, int value) => _set(
    light,
    'lightLevel',
    value,
    light.canDim && value >= 1 && value <= 100,
  );

  Future<void> setTemperature(SmartLight light, int value) => _set(
    light,
    'colorTemperature',
    value,
    light.canSetTemperature &&
        value >= light.colorTemperatureMax! &&
        value <= light.colorTemperatureMin!,
  );

  Future<void> setColor(SmartLight light, int hue, double saturation) async {
    if (!light.canSetColor ||
        hue < 0 ||
        hue > 359 ||
        saturation < 0 ||
        saturation > 1) {
      return;
    }
    await _setAttributes(light, {
      'colorHue': hue,
      'colorSaturation': saturation,
    });
  }

  Future<bool> savePreset({
    String? id,
    required String name,
    required List<PresetLightSetting> lights,
  }) async {
    if (busy || !paired) return false;
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || lights.isEmpty) {
      _error = 'Give the preset a name and select at least one lamp.';
      notifyListeners();
      return false;
    }
    final available = {for (final light in _lights) light.id: light};
    final selectedIds = <String>{};
    for (final setting in lights) {
      final light = available[setting.lightId];
      if (!selectedIds.add(setting.lightId) ||
          light == null ||
          !light.canToggle ||
          setting.brightness != null &&
              (!light.canDim ||
                  setting.brightness! < 1 ||
                  setting.brightness! > 100) ||
          setting.hue != null &&
              (!light.canSetColor || setting.hue! < 0 || setting.hue! > 359) ||
          setting.saturation != null &&
              (!light.canSetColor ||
                  setting.saturation! < 0 ||
                  setting.saturation! > 1) ||
          (setting.hue == null) != (setting.saturation == null)) {
        _error =
            'A selected lamp has settings it does not support. Refresh the lamps and try again.';
        notifyListeners();
        return false;
      }
    }
    final preset = SmartHomePreset(
      id:
          id ??
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
      name: trimmedName,
      lights: List.unmodifiable(lights),
    );
    final next = [..._presets];
    final index = id == null ? -1 : next.indexWhere((p) => p.id == id);
    if (id != null && index < 0) return false;
    if (index < 0) {
      next.add(preset);
    } else {
      next[index] = preset;
    }
    try {
      await _presetStore.save(next);
      _presets = next;
      _error = null;
      notifyListeners();
      return true;
    } catch (error) {
      _error = 'Could not save the preset. ($error)';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePreset(String id) async {
    if (busy) return false;
    final next = _presets.where((preset) => preset.id != id).toList();
    if (next.length == _presets.length) return false;
    try {
      await _presetStore.save(next);
      _presets = next;
      _error = null;
      notifyListeners();
      return true;
    } catch (error) {
      _error = 'Could not delete the preset. ($error)';
      notifyListeners();
      return false;
    }
  }

  Future<void> activatePreset(SmartHomePreset preset) async {
    final connection = _connection;
    if (busy || connection == null || !_presets.any((p) => p.id == preset.id)) {
      return;
    }
    _busy = true;
    _activatingPresetId = preset.id;
    _error = null;
    notifyListeners();
    final available = {for (final light in _lights) light.id: light};
    final failed = <String>[];
    try {
      for (final setting in preset.lights) {
        final light = available[setting.lightId];
        if (light == null || !light.isReachable || !light.canToggle) {
          failed.add(light?.name ?? 'Missing lamp');
          continue;
        }
        try {
          await _api.setAttributes(connection, light.id, {'isOn': true});
          if (setting.brightness != null && light.canDim) {
            await _api.setAttributes(connection, light.id, {
              'lightLevel': setting.brightness!,
            });
          }
          if (setting.hue != null &&
              setting.saturation != null &&
              light.canSetColor) {
            await _api.setAttributes(connection, light.id, {
              'colorHue': setting.hue!,
              'colorSaturation': setting.saturation!,
            });
          }
          if (setting.brightness != null && !light.canDim ||
              setting.hue != null && !light.canSetColor) {
            failed.add('${light.name} (settings changed)');
          }
        } catch (_) {
          failed.add(light.name);
        }
      }
      try {
        _lights = await _api.listLights(connection);
      } catch (_) {
        failed.add('status refresh');
      }
      if (failed.isNotEmpty) {
        _error =
            'Preset "${preset.name}" could not fully apply: ${failed.join(', ')}.';
      }
    } finally {
      _busy = false;
      _activatingPresetId = null;
      notifyListeners();
    }
  }

  Future<void> _set(
    SmartLight light,
    String key,
    Object value,
    bool supported,
  ) => supported ? _setAttributes(light, {key: value}) : Future.value();

  Future<void> _setAttributes(
    SmartLight light,
    Map<String, Object> attributes,
  ) async {
    final connection = _connection;
    if (connection == null ||
        !light.isReachable ||
        !_busyLights.add(light.id)) {
      return;
    }
    _error = null;
    notifyListeners();
    try {
      await _api.setAttributes(connection, light.id, attributes);
      _lights = await _api.listLights(connection);
    } catch (error) {
      _error = _message(error);
    } finally {
      _busyLights.remove(light.id);
      notifyListeners();
    }
  }

  String _message(Object error) {
    if (error is FormatException) return error.message;
    if (error is TimeoutException || error is SocketException) {
      return 'The DIRIGERA hub did not respond. Make sure this device and the hub '
          'are on the same home network, then find the hub again. Guest Wi-Fi '
          'or a VPN can prevent a connection.';
    }
    return 'Could not reach the DIRIGERA hub. Check its connection and try again.';
  }
}
