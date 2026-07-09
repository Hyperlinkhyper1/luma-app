import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Access codes that unlock paid plans without billing. Only the SHA-256
/// hash is kept in source so the codes aren't sitting in plain text — see
/// [SettingsController.redeemPlanCode]. Each redemption grants the mapped
/// plan for [SettingsController.planCodeDurationDays] days before the user
/// is bumped back to Core.
const Map<String, String> _kPlanCodeHashes = {
  '485f3bb7ac90f976fa41d61715313e92ab62db7aed502d4f197e0c61e32ab749': 'orbit',
  'fa28c62aa8e08a2e98cccdff56f36c3ffed110c37355240d44429e538f9b649b': 'nova',
};

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
    required String? avatarPath,
    required String selectedPlanId,
    required String? planExpiresAt,
    required int aiCallsToday,
    required String? aiCallsResetDate,
    required String aiProviderId,
    required File? file,
  })  : _themeMode = themeMode,
        _accentIndex = accentIndex,
        _startScreen = startScreen,
        _hideAmounts = hideAmounts,
        _lockPasswordHash = lockPasswordHash,
        _avatarPath = avatarPath,
        _selectedPlanId = selectedPlanId,
        _planExpiresAt = planExpiresAt,
        _aiCallsToday = aiCallsToday,
        _aiCallsResetDate = aiCallsResetDate,
        _aiProviderId = aiProviderId,
        _file = file;

  // These fields are deliberately assigned in the initializer list (rather than
  // via initializing formals) so the constructor exposes clean public names.
  // ignore_for_file: prefer_initializing_formals

  ThemeMode _themeMode;
  int _accentIndex;
  StartScreen _startScreen;
  bool _hideAmounts;
  String? _lockPasswordHash;
  String? _avatarPath;
  String _selectedPlanId;

  /// ISO-8601 timestamp of when a code-redeemed plan reverts to Core, or
  /// null if the current plan doesn't expire (Core, or never redeemed).
  String? _planExpiresAt;
  int _aiCallsToday;
  String? _aiCallsResetDate;
  String _aiProviderId;
  final File? _file;

  static const _aiDailyCallLimit = 10;

  ThemeMode get themeMode => _themeMode;
  int get accentIndex => _accentIndex;
  StartScreen get startScreen => _startScreen;

  /// When true, monetary figures on the Home dashboard are masked.
  bool get hideAmounts => _hideAmounts;

  /// The hashed lock PIN, if enabled.
  String? get lockPasswordHash => _lockPasswordHash;

  /// Path to the user's chosen profile picture on disk, if any.
  String? get avatarPath => _avatarPath;

  /// Number of days a redeemed plan code grants before reverting to Core.
  static const planCodeDurationDays = 30;

  /// No billing exists yet — Orbit/Nova are unlocked only via
  /// [redeemPlanCode] and expire automatically after
  /// [planCodeDurationDays]. Defaults to 'core' (free).
  String get selectedPlanId {
    _rolloverPlanExpiryIfNeeded();
    return _selectedPlanId;
  }

  /// When the current plan reverts to Core, or null if it doesn't expire.
  DateTime? get planExpiresAt {
    _rolloverPlanExpiryIfNeeded();
    return _planExpiresAt == null ? null : DateTime.tryParse(_planExpiresAt!);
  }

  void _rolloverPlanExpiryIfNeeded() {
    final expiresAt = _planExpiresAt;
    if (expiresAt == null) return;
    final parsed = DateTime.tryParse(expiresAt);
    if (parsed != null && DateTime.now().isBefore(parsed)) return;
    _selectedPlanId = 'core';
    _planExpiresAt = null;
    _changed();
  }

  /// Validates [code] against the known plan-code hashes and, if it
  /// matches, switches to the corresponding plan for
  /// [planCodeDurationDays] days. Returns the granted plan id, or null if
  /// the code is invalid.
  String? redeemPlanCode(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;
    final hash = sha256.convert(utf8.encode(trimmed)).toString();
    final planId = _kPlanCodeHashes[hash];
    if (planId == null) return null;
    _selectedPlanId = planId;
    _planExpiresAt = DateTime.now()
        .add(const Duration(days: planCodeDurationDays))
        .toIso8601String();
    _changed();
    return planId;
  }

  /// Which AI provider (`AiProviderId.name`) the Assistant tab talks to.
  /// Local-device-only — each device has its own set of saved API keys, so
  /// this isn't synced (see [exportData]).
  String get aiProviderId => _aiProviderId;

  void setAiProviderId(String id) {
    if (id == _aiProviderId) return;
    _aiProviderId = id;
    _changed();
  }

  /// The accent seed to feed the theme, or null for the default lavender.
  Color? get accentSeed => kAccentPresets[_accentIndex].seed;

  /// How many AI assistant messages remain today, out of [_aiDailyCallLimit].
  /// Resets the counter as a side effect if the stored date has rolled over.
  int get aiCallsRemainingToday {
    _rolloverAiCallsIfNeeded();
    return (_aiDailyCallLimit - _aiCallsToday).clamp(0, _aiDailyCallLimit);
  }

  /// Whether another AI assistant message can be sent today. This is a
  /// client-side spend guard on the user's own API key, not a security
  /// boundary — there's no server to enforce it against.
  bool get canSendAiMessage {
    _rolloverAiCallsIfNeeded();
    return _aiCallsToday < _aiDailyCallLimit;
  }

  /// Records that an AI assistant message was successfully sent. Call this
  /// only after a successful send — a failed/errored call shouldn't burn the
  /// user's daily budget.
  void recordAiCall() {
    _rolloverAiCallsIfNeeded();
    _aiCallsToday++;
    _changed();
  }

  void _rolloverAiCallsIfNeeded() {
    final today = _todayIso();
    if (_aiCallsResetDate != today) {
      _aiCallsResetDate = today;
      _aiCallsToday = 0;
    }
  }

  static String _todayIso() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

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

  void setAvatarPath(String? path) {
    if (path == _avatarPath) return;
    _avatarPath = path;
    _changed();
  }

  /// Switches directly to a plan that doesn't require a code (only Core
  /// today). Orbit/Nova must go through [redeemPlanCode].
  void setSelectedPlanId(String id) {
    if (id == _selectedPlanId && _planExpiresAt == null) return;
    _selectedPlanId = id;
    _planExpiresAt = null;
    _changed();
  }

  void resetToDefaults() {
    _themeMode = ThemeMode.dark;
    _accentIndex = 0;
    _startScreen = StartScreen.home;
    _hideAmounts = false;
    _lockPasswordHash = null;
    _avatarPath = null;
    _selectedPlanId = 'core';
    _planExpiresAt = null;
    _aiCallsToday = 0;
    _aiCallsResetDate = null;
    _aiProviderId = 'anthropic';
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
        'avatarPath': _avatarPath,
        'selectedPlanId': _selectedPlanId,
        'planExpiresAt': _planExpiresAt,
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
    _avatarPath = data['avatarPath'] as String?;
    _selectedPlanId = data['selectedPlanId'] as String? ?? 'core';
    _planExpiresAt = data['planExpiresAt'] as String?;
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
        'avatarPath': _avatarPath,
        'selectedPlanId': _selectedPlanId,
        'planExpiresAt': _planExpiresAt,
        // Local-device-only — deliberately not part of exportData/importData
        // (sync), since this is a per-device spend guard, not a preference.
        'aiCallsToday': _aiCallsToday,
        'aiCallsResetDate': _aiCallsResetDate,
        'aiProviderId': _aiProviderId,
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
      avatarPath: data['avatarPath'] as String?,
      selectedPlanId: data['selectedPlanId'] as String? ?? 'core',
      planExpiresAt: data['planExpiresAt'] as String?,
      aiCallsToday: data['aiCallsToday'] as int? ?? 0,
      aiCallsResetDate: data['aiCallsResetDate'] as String?,
      aiProviderId: data['aiProviderId'] as String? ?? 'anthropic',
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
