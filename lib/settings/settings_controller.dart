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

/// The app-wide language preference. `system` follows the OS locale,
/// falling back to English (the template/default) when unsupported.
enum AppLanguage { system, english, dutch, chinese, spanish, french }

/// Maps [AppLanguage] to a [Locale], or null for `system` (let MaterialApp
/// resolve from the platform).
Locale? localeForLanguage(AppLanguage lang) => switch (lang) {
      AppLanguage.english => const Locale('en'),
      AppLanguage.dutch => const Locale('nl'),
      AppLanguage.chinese => const Locale('zh'),
      AppLanguage.spanish => const Locale('es'),
      AppLanguage.french => const Locale('fr'),
      AppLanguage.system => null,
    };

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
    required AppLanguage appLanguage,
    required bool hideAmounts,
    required String? lockPasswordHash,
    required String? avatarPath,
    required String selectedPlanId,
    required String? planExpiresAt,
    required String adminPlanId,
    required int aiCallsToday,
    required String? aiCallsResetDate,
    required String aiProviderId,
    required String aiMode,
    required List<String> navOrder,
    required bool useAmericanGpaScale,
    required File? file,
  })  : _themeMode = themeMode,
        _accentIndex = accentIndex,
        _startScreen = startScreen,
        _appLanguage = appLanguage,
        _hideAmounts = hideAmounts,
        _lockPasswordHash = lockPasswordHash,
        _avatarPath = avatarPath,
        _selectedPlanId = selectedPlanId,
        _planExpiresAt = planExpiresAt,
        _adminPlanId = adminPlanId,
        _aiCallsToday = aiCallsToday,
        _aiCallsResetDate = aiCallsResetDate,
        _aiProviderId = aiProviderId,
        _aiMode = aiMode,
        _navOrder = navOrder,
        _useAmericanGpaScale = useAmericanGpaScale,
        _file = file;

  // These fields are deliberately assigned in the initializer list (rather than
  // via initializing formals) so the constructor exposes clean public names.
  // ignore_for_file: prefer_initializing_formals

  ThemeMode _themeMode;
  int _accentIndex;
  StartScreen _startScreen;
  AppLanguage _appLanguage;
  bool _hideAmounts;
  String? _lockPasswordHash;
  String? _avatarPath;
  String _selectedPlanId;

  /// ISO-8601 timestamp of when a code-redeemed plan reverts to Core, or
  /// null if the current plan doesn't expire (Core, or never redeemed).
  String? _planExpiresAt;

  /// Plan tier granted to this account by an admin on the dashboard (see
  /// Api._adminSetPlan server-side), refreshed from /account on every sync.
  /// Defaults to 'core'. Unlike a code-redeemed plan it never expires, and
  /// the effective plan is the higher of this and [_selectedPlanId] — so an
  /// admin-granted subscription can't be lost by picking the free plan.
  /// Local-only (persisted, not synced): each device learns it from the
  /// server directly.
  String _adminPlanId;
  int _aiCallsToday;
  String? _aiCallsResetDate;
  String _aiProviderId;
  String _aiMode;
  List<String> _navOrder;
  bool _useAmericanGpaScale;
  final File? _file;

  static const _aiDailyCallLimit = 10;

  ThemeMode get themeMode => _themeMode;
  int get accentIndex => _accentIndex;
  StartScreen get startScreen => _startScreen;
  AppLanguage get appLanguage => _appLanguage;

  /// When true, monetary figures on the Home dashboard are masked.
  bool get hideAmounts => _hideAmounts;

  /// The hashed lock PIN, if enabled.
  String? get lockPasswordHash => _lockPasswordHash;

  /// Path to the user's chosen profile picture on disk, if any.
  String? get avatarPath => _avatarPath;

  /// When true, the School plugin's GPA calculator uses the US 4.0 scale
  /// instead of the Dutch 1-10 grading scale, which is the default.
  bool get useAmericanGpaScale => _useAmericanGpaScale;

  /// Number of days a redeemed plan code grants before reverting to Core.
  static const planCodeDurationDays = 30;

  /// No billing exists yet — Orbit/Nova are unlocked only via
  /// [redeemPlanCode] and expire automatically after
  /// [planCodeDurationDays]. Defaults to 'core' (free). An admin-granted
  /// plan ([_adminPlanId]) takes precedence when it's the higher tier, so a
  /// subscription assigned on the dashboard can't be dropped by picking the
  /// free plan locally.
  String get selectedPlanId {
    _rolloverPlanExpiryIfNeeded();
    return _effectivePlanId;
  }

  /// When the current plan reverts to Core, or null if it doesn't expire.
  DateTime? get planExpiresAt {
    _rolloverPlanExpiryIfNeeded();
    // The admin-granted plan never expires; only surface a reversion date
    // when the effective plan is the locally-redeemed one.
    if (_effectivePlanId != _selectedPlanId) return null;
    return _planExpiresAt == null ? null : DateTime.tryParse(_planExpiresAt!);
  }

  /// The higher of the admin-granted and locally-selected tiers. Tiers:
  /// core < orbit < nova. Unknown ids fall back to core.
  String get _effectivePlanId =>
      _tierIndex(_adminPlanId) > _tierIndex(_selectedPlanId)
          ? _adminPlanId
          : _selectedPlanId;

  static int _tierIndex(String id) => switch (id) {
        'nova' => 2,
        'orbit' => 1,
        _ => 0,
      };

  /// Records the plan tier the server has on file for this account, learned
  /// from /account on every sync. Idempotent. Passing null/empty clears it
  /// back to 'core' (covers admin revocation and older servers).
  void setAdminPlan(String? planId) {
    final next = (planId == null || planId.isEmpty) ? 'core' : planId;
    if (next == _adminPlanId) return;
    _adminPlanId = next;
    _changed();
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

  /// Which "Luma AI" intelligence mode is selected (`AiMode.name`:
  /// normal/smarter/smartest — shown as Aurora/Nebula/Pulsar). Only
  /// meaningful for the Google provider; like the provider id, this is a
  /// local per-device choice, not synced.
  String get aiMode => _aiMode;

  void setAiMode(String mode) {
    if (mode == _aiMode) return;
    _aiMode = mode;
    _changed();
  }

  /// Custom display order of nav-rail items. Each entry is either
  /// `"fixed:<index>"` (one of the six built-in destinations) or
  /// `"plugin:<pluginId>"`. An empty list means the default order.
  List<String> get navOrder => List.unmodifiable(_navOrder);

  void setNavOrder(List<String> order) {
    if (order.length == _navOrder.length &&
        _listEquals(order, _navOrder)) {
      return;
    }
    _navOrder = List.of(order);
    _changed();
  }

  static bool _listEquals<T>(List<T> a, List<T> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
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

  void setAppLanguage(AppLanguage lang) {
    if (lang == _appLanguage) return;
    _appLanguage = lang;
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

  void setUseAmericanGpaScale(bool value) {
    if (value == _useAmericanGpaScale) return;
    _useAmericanGpaScale = value;
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
    _appLanguage = AppLanguage.system;
    _hideAmounts = false;
    _lockPasswordHash = null;
    _avatarPath = null;
    _selectedPlanId = 'core';
    _planExpiresAt = null;
    _aiCallsToday = 0;
    _aiCallsResetDate = null;
    _aiProviderId = 'anthropic';
    _aiMode = 'normal';
    _navOrder = const [];
    _useAmericanGpaScale = false;
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
        'appLanguage': _appLanguage.name,
        'hideAmounts': _hideAmounts,
        'lockPasswordHash': _lockPasswordHash,
        'avatarPath': _avatarPath,
        'selectedPlanId': _selectedPlanId,
        'planExpiresAt': _planExpiresAt,
        'navOrder': _navOrder,
        'useAmericanGpaScale': _useAmericanGpaScale,
      };

  /// Replaces every preference with a previously exported snapshot.
  Future<void> importData(Object? data) async {
    if (data is! Map<String, dynamic>) return;
    _themeMode = _parseEnum(ThemeMode.values, data['themeMode'], _themeMode);
    _accentIndex = _parseAccentIndex(data['accentIndex']);
    _startScreen =
        _parseEnum(StartScreen.values, data['startScreen'], _startScreen);
    _appLanguage =
        _parseEnum(AppLanguage.values, data['appLanguage'], _appLanguage);
    _hideAmounts = data['hideAmounts'] == true;
    _lockPasswordHash = data['lockPasswordHash'] as String?;
    _avatarPath = data['avatarPath'] as String?;
    _selectedPlanId = data['selectedPlanId'] as String? ?? 'core';
    _planExpiresAt = data['planExpiresAt'] as String?;
    _navOrder = _parseNavOrder(data['navOrder']);
    _useAmericanGpaScale = data['useAmericanGpaScale'] == true;
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
        'appLanguage': _appLanguage.name,
        'hideAmounts': _hideAmounts,
        'lockPasswordHash': _lockPasswordHash,
        'avatarPath': _avatarPath,
        'selectedPlanId': _selectedPlanId,
        'planExpiresAt': _planExpiresAt,
        // Local-device-only — deliberately not part of exportData/importData
        // (sync): each device learns its admin-granted plan from /account.
        'adminPlanId': _adminPlanId,
        'aiCallsToday': _aiCallsToday,
        'aiCallsResetDate': _aiCallsResetDate,
        'aiProviderId': _aiProviderId,
        'aiMode': _aiMode,
        'navOrder': _navOrder,
        'useAmericanGpaScale': _useAmericanGpaScale,
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
      appLanguage:
          _parseEnum(AppLanguage.values, data['appLanguage'], AppLanguage.system),
      hideAmounts: data['hideAmounts'] == true,
      lockPasswordHash: data['lockPasswordHash'] as String?,
      avatarPath: data['avatarPath'] as String?,
      selectedPlanId: data['selectedPlanId'] as String? ?? 'core',
      planExpiresAt: data['planExpiresAt'] as String?,
      adminPlanId: data['adminPlanId'] as String? ?? 'core',
      aiCallsToday: data['aiCallsToday'] as int? ?? 0,
      aiCallsResetDate: data['aiCallsResetDate'] as String?,
      aiProviderId: data['aiProviderId'] as String? ?? 'anthropic',
      aiMode: data['aiMode'] as String? ?? 'normal',
      navOrder: _parseNavOrder(data['navOrder']),
      useAmericanGpaScale: data['useAmericanGpaScale'] == true,
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

  static List<String> _parseNavOrder(Object? raw) {
    if (raw is List) {
      return raw.whereType<String>().toList(growable: true);
    }
    return const [];
  }
}
