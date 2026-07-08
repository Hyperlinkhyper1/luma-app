import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Which destination the app opens on when launched.
enum StartScreen { home, converter, finance }

/// A selectable accent color. A null [seed] keeps luma's default lavender.
class AccentPreset {
  const AccentPreset(this.name, this.seed);
  final String name;
  final Color? seed;
}

/// The palette the user can pick from in Settings. The first entry is the
/// built-in lavender (no override), the rest recolor the accent family.
const List<AccentPreset> kAccentPresets = [
  AccentPreset('Lavender', null),
  AccentPreset('Indigo', Color(0xFF6C7DF0)),
  AccentPreset('Ocean', Color(0xFF3D8BEF)),
  AccentPreset('Teal', Color(0xFF1FB6A6)),
  AccentPreset('Forest', Color(0xFF45B36B)),
  AccentPreset('Amber', Color(0xFFE0A431)),
  AccentPreset('Coral', Color(0xFFF0744E)),
  AccentPreset('Rose', Color(0xFFEC6A8B)),
];

/// App-wide preferences. Mutations notify listeners and are persisted to a
/// small JSON file (best-effort — failures never break the app).
class SettingsController extends ChangeNotifier {
  SettingsController._({
    required ThemeMode themeMode,
    required int accentIndex,
    required StartScreen startScreen,
    required bool hideAmounts,
    required String? lockPasswordHash,
    required File? file,
  })  : _themeMode = themeMode,
        _accentIndex = accentIndex,
        _startScreen = startScreen,
        _hideAmounts = hideAmounts,
        _lockPasswordHash = lockPasswordHash,
        _file = file;

  // These fields are deliberately assigned in the initializer list (rather than
  // via initializing formals) so the constructor exposes clean public names.
  // ignore_for_file: prefer_initializing_formals

  ThemeMode _themeMode;
  int _accentIndex;
  StartScreen _startScreen;
  bool _hideAmounts;
  String? _lockPasswordHash;
  final File? _file;

  ThemeMode get themeMode => _themeMode;
  int get accentIndex => _accentIndex;
  StartScreen get startScreen => _startScreen;

  /// When true, monetary figures on the Home dashboard are masked.
  bool get hideAmounts => _hideAmounts;

  /// The hashed lock PIN, if enabled.
  String? get lockPasswordHash => _lockPasswordHash;

  /// The accent seed to feed the theme, or null for the default lavender.
  Color? get accentSeed => kAccentPresets[_accentIndex].seed;

  // ---- Mutations ------------------------------------------------------------

  void setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
    _changed();
  }

  void setAccentIndex(int index) {
    if (index < 0 || index >= kAccentPresets.length || index == _accentIndex) {
      return;
    }
    _accentIndex = index;
    _changed();
  }

  void setStartScreen(StartScreen screen) {
    if (screen == _startScreen) return;
    _startScreen = screen;
    _changed();
  }

  void setHideAmounts(bool value) {
    if (value == _hideAmounts) return;
    _hideAmounts = value;
    _changed();
  }

  void setLockPasswordHash(String? hash) {
    if (hash == _lockPasswordHash) return;
    _lockPasswordHash = hash;
    _changed();
  }

  void resetToDefaults() {
    _themeMode = ThemeMode.dark;
    _accentIndex = 0;
    _startScreen = StartScreen.home;
    _hideAmounts = false;
    _lockPasswordHash = null;
    _changed();
  }

  void _changed() {
    notifyListeners();
    // Persist in the background; a storage hiccup must not block the UI.
    _persist();
  }

  // ---- Sync (always-on collection — see SyncService/main.dart) --------------

  /// Snapshot for the "settings" sync collection. Same shape as [_persist]'s
  /// local file so nothing is lost translating between the two.
  Map<String, Object?> exportData() => {
        'themeMode': _themeMode.name,
        'accentIndex': _accentIndex,
        'startScreen': _startScreen.name,
        'hideAmounts': _hideAmounts,
        'lockPasswordHash': _lockPasswordHash,
      };

  /// Replaces every preference with a previously exported snapshot.
  Future<void> importData(Object? data) async {
    if (data is! Map<String, dynamic>) return;
    _themeMode = _parseEnum(ThemeMode.values, data['themeMode'], _themeMode);
    _accentIndex = _parseAccentIndex(data['accentIndex']);
    _startScreen =
        _parseEnum(StartScreen.values, data['startScreen'], _startScreen);
    _hideAmounts = data['hideAmounts'] == true;
    _lockPasswordHash = data['lockPasswordHash'] as String?;
    notifyListeners();
    await _persist();
  }

  // ---- Persistence ----------------------------------------------------------

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    try {
      await file.writeAsString(jsonEncode({
        'themeMode': _themeMode.name,
        'accentIndex': _accentIndex,
        'startScreen': _startScreen.name,
        'hideAmounts': _hideAmounts,
        'lockPasswordHash': _lockPasswordHash,
      }));
    } catch (_) {
      // Ignore — preferences just won't survive a restart.
    }
  }

  /// Loads saved preferences, falling back to defaults if anything is missing
  /// or the platform has no writable support directory.
  static Future<SettingsController> load() async {
    File? file;
    Map<String, dynamic> data = const {};
    try {
      final dir = await getApplicationSupportDirectory();
      file = File('${dir.path}/luma_settings.json');
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) data = decoded;
      }
    } catch (_) {
      file = null;
    }

    return SettingsController._(
      themeMode: _parseEnum(ThemeMode.values, data['themeMode'], ThemeMode.dark),
      accentIndex: _parseAccentIndex(data['accentIndex']),
      startScreen:
          _parseEnum(StartScreen.values, data['startScreen'], StartScreen.home),
      hideAmounts: data['hideAmounts'] == true,
      lockPasswordHash: data['lockPasswordHash'] as String?,
      file: file,
    );
  }

  static T _parseEnum<T extends Enum>(List<T> values, Object? raw, T fallback) {
    if (raw is String) {
      for (final v in values) {
        if (v.name == raw) return v;
      }
    }
    return fallback;
  }

  static int _parseAccentIndex(Object? raw) {
    if (raw is int && raw >= 0 && raw < kAccentPresets.length) return raw;
    return 0;
  }
}
