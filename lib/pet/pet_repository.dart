import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../app/window_controls.dart';
import 'hotkey_probe.dart';

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

  /// Shift+Alt+Space.
  ///
  /// Windows can only register a chord of modifiers plus exactly one key, so
  /// the modifier is not optional. This particular one is unclaimed by the OS
  /// and impossible to hit while typing, unlike the tempting ones: Win+Space
  /// is the input-language switcher, Alt+Space opens the window menu, and
  /// Shift+Space fires every time you type a capital before a space.
  static HotKey defaultHotKey({HotKeyScope scope = HotKeyScope.system}) =>
      HotKey(
        identifier: scope == HotKeyScope.system
            ? _systemIdentifier
            : _inAppIdentifier,
        key: PhysicalKeyboardKey.space,
        modifiers: const [HotKeyModifier.shift, HotKeyModifier.alt],
        scope: scope,
      );

  /// The chord written the way a person reads it — "Win + Space". Built here
  /// rather than from `HotKey.debugName`, which spells out "Meta Left".
  String get hotKeyLabel => [
        for (final modifier in _hotKey.modifiers ?? const <HotKeyModifier>[])
          switch (modifier) {
            HotKeyModifier.alt => 'Alt',
            HotKeyModifier.control => 'Ctrl',
            HotKeyModifier.shift => 'Shift',
            HotKeyModifier.meta => Platform.isMacOS ? 'Cmd' : 'Win',
            HotKeyModifier.capsLock => 'Caps Lock',
            HotKeyModifier.fn => 'Fn',
          },
        _hotKey.physicalKey.debugName ?? '?',
      ].join(' + ');

  static const _systemIdentifier = 'luma_pet_summon';
  static const _inAppIdentifier = 'luma_pet_summon_inapp';

  HotKey _hotKey = defaultHotKey();

  /// Whether [_hotKey] is the user's own choice rather than the built-in
  /// default — see [_load].
  bool _hotKeyCustom = false;

  /// The chord that summons the pet. Rebindable, because the good launcher
  /// chords are popular and the first claim wins.
  HotKey get hotKey => _hotKey;

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
  /// the OS or another app already holds the chord.
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
        _hasFocus = focused;
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
        // Only a chord the user picked themselves is restored. The saved copy
        // of the built-in default is ignored on purpose, so changing that
        // default reaches devices that already have a pet file — otherwise
        // the first run would freeze whatever the default happened to be
        // that day.
        _hotKeyCustom = data['hotKeyCustom'] == true;
        final hotKeyJson = _hotKeyCustom ? data['hotKey'] : null;
        if (hotKeyJson is Map) {
          try {
            final parsed = HotKey.fromJson(hotKeyJson.cast<String, dynamic>());
            _hotKey = HotKey(
              identifier: _systemIdentifier,
              key: parsed.key,
              modifiers: parsed.modifiers ?? const [],
              scope: HotKeyScope.system,
            );
          } catch (_) {
            // Keep the default chord if the saved one cannot be read.
          }
        }
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
        'hotKey': _hotKey.toJson(),
        'hotKeyCustom': _hotKeyCustom,
      }));
    } catch (_) {
      // Best-effort; the pet just forgets on the next launch.
    }
  }

  Future<void> _registerHotKey() async {
    // The in-app copy first, and always: it runs off the keyboard stream
    // rather than the focus tree, so it fires wherever the user happens to be
    // in luma. It is also the only thing that works when the global
    // registration below is refused.
    try {
      await hotKeyManager.register(
        _inAppTwin(_hotKey),
        keyDownHandler: (_) => unawaited(toggle()),
      );
    } catch (_) {
      // Nothing to do — the global hotkey may still come through.
    }

    if (!supportsGlobalHotKey) {
      notifyListeners();
      return;
    }

    // Ask the OS whether the chord is free before claiming it. The Windows
    // plugin reports success whether or not RegisterHotKey worked, so without
    // this a chord another app owns looks registered and silently never
    // fires — see isGlobalHotKeyAvailable.
    final available = await isGlobalHotKeyAvailable(_hotKey);
    if (!available) {
      _hotKeyRegistered = false;
      _hotKeyError = 'taken';
      notifyListeners();
      return;
    }

    try {
      await hotKeyManager.register(
        _hotKey,
        keyDownHandler: (_) => unawaited(toggle()),
      );
      _hotKeyRegistered = true;
      _hotKeyError = null;
    } catch (_) {
      _hotKeyRegistered = false;
      _hotKeyError = 'taken';
    }
    notifyListeners();
  }

  /// The same chord as an in-app hotkey. `hotkey_manager` keys its handlers
  /// by identifier, so the twin needs its own.
  static HotKey _inAppTwin(HotKey hotKey) => HotKey(
        identifier: _inAppIdentifier,
        key: hotKey.key,
        modifiers: hotKey.modifiers,
        scope: HotKeyScope.inapp,
      );

  Future<void> _unregisterHotKey() async {
    try {
      await hotKeyManager.unregister(_inAppTwin(_hotKey));
    } catch (_) {}
    if (_hotKeyRegistered) {
      try {
        await hotKeyManager.unregister(_hotKey);
      } catch (_) {}
    }
    _hotKeyRegistered = false;
    notifyListeners();
  }

  /// Rebinds the summon chord, saving it and re-arming.
  Future<void> setHotKey(HotKey newHotKey) async {
    await _unregisterHotKey();
    _hotKeyCustom = true;
    _hotKey = HotKey(
      identifier: _systemIdentifier,
      key: newHotKey.key,
      // A null modifiers list crashes the native Windows plugin on register —
      // the same trap Auto Clicker hit.
      modifiers: newHotKey.modifiers ?? const [],
      scope: HotKeyScope.system,
    );
    if (_enabled) await _registerHotKey();
    notifyListeners();
    await _save();
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

  DateTime? _lastToggleAt;

  Future<void> toggle() async {
    // The chord can reach us twice — the OS hotkey and the in-app one are
    // both armed, and a held key repeats — which would open and immediately
    // close the pet, looking exactly like nothing happened.
    final now = DateTime.now();
    final last = _lastToggleAt;
    if (last != null && now.difference(last) < const Duration(milliseconds: 350)) {
      return;
    }
    _lastToggleAt = now;
    return _visible ? close() : open();
  }

  /// Arms click-away dismissal, but only once the window has actually taken
  /// focus. Windows can refuse to bring a background process to the front, and
  /// a pet that dismissed itself on the blur it was born with would flick open
  /// and shut again before the user saw it.
  void _armBlurDismissal() {
    _acceptBlur = false;
    _blurArmTimer?.cancel();
    if (!hasCustomTitleBar) return;
    _blurArmTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!_visible) {
        timer.cancel();
        return;
      }
      if (_hasFocus) {
        _acceptBlur = true;
        timer.cancel();
      }
    });
  }

  bool _hasFocus = false;

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
