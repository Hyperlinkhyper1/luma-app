import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../app/window_controls.dart';

/// How the pet is feeling. Drives both the face it paints and the line it
/// says — see [PetSprite] and [LumaPetPanel].
enum PetMood {
  /// Nothing going on: slow bob, occasional blink.
  idle,

  /// The user is typing — it leans in towards the search field.
  curious,

  /// Just been patted.
  happy,

  /// Patted several times in a row.
  delighted,

  /// Late at night. Still opens things, just less enthusiastically.
  sleepy,
}

/// The default name, used until the user renames the pet.
const String kDefaultPetName = 'Luma';

/// How many recently opened targets the pet remembers for its "nothing typed
/// yet" list.
const int kPetRecentLimit = 6;

/// Owns everything about the luma pet: whether the global hotkey is armed,
/// whether the panel is up, the persisted name/pats/recents, and — on
/// desktop — the window juggling that turns the one app window into a small
/// floating panel while the pet is summoned.
///
/// Lives for the app's lifetime (created in `main.dart`), not the panel's:
/// the hotkey has to work while the app is minimised, which is exactly when
/// no panel widget exists.
class PetRepository extends ChangeNotifier {
  File? _file;
  bool _loaded = false;

  bool _enabled = true;
  String _name = kDefaultPetName;
  int _pats = 0;
  List<String> _recentIds = const [];

  bool _visible = false;
  bool _windowMode = false;
  bool _hotKeyRegistered = false;
  String? _hotKeyError;

  DateTime? _lastPatAt;
  int _patStreak = 0;
  String _query = '';

  StreamSubscription<bool>? _focusSub;

  /// Blur arriving while the window is still being resized and raised is the
  /// pet's own doing, not the user clicking away, so dismissal only starts
  /// listening once the panel has settled.
  bool _acceptBlur = false;
  Timer? _blurArmTimer;

  /// Alt+Space. Windows hands this to the focused window's system menu by
  /// default, but a registered global hotkey is dispatched first, so that
  /// menu never opens while the pet is armed.
  static final HotKey summonHotKey = HotKey(
    identifier: 'luma_pet_summon',
    key: PhysicalKeyboardKey.space,
    modifiers: const [HotKeyModifier.alt],
    scope: HotKeyScope.system,
  );

  bool get loaded => _loaded;

  /// Whether the global hotkey is armed. Turning it off leaves the pet
  /// reachable from the title bar and from Settings.
  bool get enabled => _enabled;

  String get name => _name;
  int get pats => _pats;
  List<String> get recentIds => _recentIds;

  /// Whether the panel is currently up.
  bool get visible => _visible;

  /// True while the desktop window itself is shrunk into the panel, which is
  /// the normal case. False when the pet is layered over the running app
  /// instead (phones, and any desktop where the resize was refused).
  bool get windowMode => _windowMode;

  bool get hotKeyRegistered => _hotKeyRegistered;

  /// Set when the hotkey could not be registered — almost always because
  /// another app already holds Alt+Space.
  String? get hotKeyError => _hotKeyError;

  /// Whether a global hotkey is possible at all here. Android and iOS have no
  /// such thing, so the pet is opened by hand there.
  static bool get supportsGlobalHotKey =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// Loads the saved pet and arms the hotkey. Call once from the app root.
  Future<void> init() async {
    await _load();
    if (_enabled) await _registerHotKey();
    if (hasCustomTitleBar) {
      _focusSub = windowFocusEvents.listen((focused) {
        if (focused || !_visible || !_windowMode || !_acceptBlur) return;
        // Clicked away to another app: dismiss, the way every other summoned
        // launcher behaves.
        unawaited(close());
      });
    }
  }

  Future<void> _load() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}/luma_pet.json');
      if (await _file!.exists()) {
        final data =
            jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        _enabled = data['enabled'] as bool? ?? true;
        final name = (data['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) _name = name;
        _pats = (data['pats'] as num?)?.toInt() ?? 0;
        final recents = data['recentIds'];
        if (recents is List) {
          _recentIds = [
            for (final id in recents)
              if (id is String) id,
          ].take(kPetRecentLimit).toList(growable: false);
        }
      }
    } catch (_) {
      // Best-effort: a missing or corrupt file just means a brand new pet.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null) return;
    try {
      await file.writeAsString(jsonEncode({
        'enabled': _enabled,
        'name': _name,
        'pats': _pats,
        'recentIds': _recentIds,
      }));
    } catch (_) {
      // Best-effort; the pet just forgets on the next launch.
    }
  }

  Future<void> _registerHotKey() async {
    if (!supportsGlobalHotKey) return;
    try {
      await hotKeyManager.register(summonHotKey, keyDownHandler: (_) {
        unawaited(toggle());
      });
      _hotKeyRegistered = true;
      _hotKeyError = null;
    } catch (_) {
      _hotKeyRegistered = false;
      _hotKeyError = 'alreadyTaken';
    }
    notifyListeners();
  }

  Future<void> _unregisterHotKey() async {
    if (!_hotKeyRegistered) return;
    try {
      await hotKeyManager.unregister(summonHotKey);
    } catch (_) {}
    _hotKeyRegistered = false;
    notifyListeners();
  }

  /// Arms or disarms the global hotkey.
  Future<void> setEnabled(bool value) async {
    if (value == _enabled) return;
    _enabled = value;
    if (value) {
      await _registerHotKey();
    } else {
      await _unregisterHotKey();
    }
    notifyListeners();
    await _save();
  }

  /// Renames the pet. An empty name falls back to [kDefaultPetName] rather
  /// than leaving a blank speech bubble.
  Future<void> setName(String value) async {
    final trimmed = value.trim();
    final name = trimmed.isEmpty ? kDefaultPetName : trimmed;
    if (name == _name) return;
    _name = name;
    notifyListeners();
    await _save();
  }

  /// Summons the pet, shrinking the desktop window into the panel.
  Future<void> open() async {
    if (_visible) return;
    _visible = true;
    _query = '';
    _patStreak = 0;
    notifyListeners();
    if (hasCustomTitleBar) {
      try {
        await enterPetWindow();
        _windowMode = true;
      } catch (_) {
        // Resize refused (an unusual compositor, a locked session). The panel
        // still works layered over the app as it stands.
        _windowMode = false;
      }
      notifyListeners();
    }
    _armBlurDismissal();
  }

  /// Dismisses the pet and puts the window back.
  ///
  /// [navigating] is set when the user picked something: the app is about to
  /// show that screen, so the window is raised rather than returned to
  /// whatever hidden or minimised state it was summoned from.
  Future<void> close({bool navigating = false}) async {
    if (!_visible) return;
    _visible = false;
    _acceptBlur = false;
    _blurArmTimer?.cancel();
    notifyListeners();
    if (_windowMode) {
      _windowMode = false;
      try {
        await exitPetWindow(bringToFront: navigating);
      } catch (_) {
        // Nothing sensible to do — the app is usable either way.
      }
      notifyListeners();
    }
  }

  Future<void> toggle() => _visible ? close() : open();

  void _armBlurDismissal() {
    _acceptBlur = false;
    _blurArmTimer?.cancel();
    _blurArmTimer = Timer(const Duration(milliseconds: 500), () {
      _acceptBlur = true;
    });
  }

  /// Records that [id] was opened, so it floats to the top of the pet's list
  /// next time.
  Future<void> recordOpen(String id) async {
    final next = [id, ..._recentIds.where((e) => e != id)]
        .take(kPetRecentLimit)
        .toList(growable: false);
    if (listEquals(next, _recentIds)) return;
    _recentIds = next;
    notifyListeners();
    await _save();
  }

  /// How long after a pat another one still counts towards the streak.
  static const _patStreakWindow = Duration(seconds: 4);

  /// The user patted the pet. Repeated pats inside [_patStreakWindow] build a
  /// streak, which is what tips it from happy into delighted.
  void pat() {
    final now = DateTime.now();
    final last = _lastPatAt;
    _patStreak = (last != null && now.difference(last) < _patStreakWindow)
        ? _patStreak + 1
        : 1;
    _lastPatAt = now;
    _pats++;
    notifyListeners();
    unawaited(_save());
  }

  /// Lets the pet know something is being typed, so it can look interested.
  void setQuery(String value) {
    if (value == _query) return;
    final wasEmpty = _query.isEmpty;
    _query = value;
    if (wasEmpty != value.isEmpty) notifyListeners();
  }

  /// How the pet should look right now. [now] is a parameter so the sleepy
  /// window can be tested without waiting for midnight.
  PetMood moodAt(DateTime now) {
    final last = _lastPatAt;
    if (last != null && now.difference(last) < const Duration(seconds: 3)) {
      return _patStreak >= 3 ? PetMood.delighted : PetMood.happy;
    }
    if (_query.isNotEmpty) return PetMood.curious;
    if (now.hour >= 23 || now.hour < 6) return PetMood.sleepy;
    return PetMood.idle;
  }

  PetMood get mood => moodAt(DateTime.now());

  @override
  void dispose() {
    _blurArmTimer?.cancel();
    unawaited(_focusSub?.cancel());
    unawaited(_unregisterHotKey());
    super.dispose();
  }
}
