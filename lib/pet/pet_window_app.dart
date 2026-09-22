import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

import '../app/window_controls.dart';
import '../features/plugins/plugin_icons.dart';
import '../l10n/app_localizations.dart';
import '../theme/luma_theme.dart';
import 'luma_pet_panel.dart';
import 'pet_repository.dart';
import 'pet_scope.dart';
import 'pet_search.dart';
import 'pet_window_protocol.dart';

/// Boots the secondary Flutter engine used only by the desktop pet window.
Future<void> runPetWindow(
  WindowController controller,
  Map<String, dynamic> arguments,
) async {
  await controller.setWindowMethodHandler((call) async {
    if (call.method != petWindowMethodClose) {
      throw MissingPluginException('Unknown pet window method ${call.method}');
    }
    try {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } catch (_) {
      await controller.hide();
    }
  });

  try {
    await _setUpPetWindow();
  } catch (_) {
    // window_manager is missing from this engine (the runner did not register
    // plugins for sub-windows). The window was created hidden, so show it
    // through desktop_multi_window rather than leaving it invisible.
    await controller.show();
  }
  runApp(_PetWindowApp(arguments: arguments));
}

Future<void> _setUpPetWindow() async {
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);

  const options = WindowOptions(
    size: kPetPanelSize,
    minimumSize: kPetPanelSize,
    maximumSize: kPetPanelSize,
    center: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    title: 'luma pet',
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setResizable(false);
    await windowManager.show();
    await windowManager.focus();
  });
}

class _PetWindowRepository extends PetRepository {
  _PetWindowRepository({
    required super.initialName,
    required super.initialPats,
    required super.initialRecentIds,
  });

  @override
  Future<void> recordOpen(String id) async {
    await super.recordOpen(id);
    await petMainChannel.invokeMethod<void>(petMethodRecordOpen, id);
  }

  @override
  void pat() {
    super.pat();
    unawaited(petMainChannel.invokeMethod<void>(petMethodPat));
  }

  @override
  Future<void> close({bool navigating = false}) async {
    await petMainChannel.invokeMethod<void>(petMethodDismiss, navigating);
  }
}

class _PetWindowApp extends StatefulWidget {
  const _PetWindowApp({required this.arguments});

  final Map<String, dynamic> arguments;

  @override
  State<_PetWindowApp> createState() => _PetWindowAppState();
}

class _PetWindowAppState extends State<_PetWindowApp> with WindowListener {
  late final _PetWindowRepository _pet = _PetWindowRepository(
    initialName: widget.arguments['name'] as String? ?? kDefaultPetName,
    initialPats: (widget.arguments['pats'] as num?)?.toInt() ?? 0,
    initialRecentIds:
        (widget.arguments['recentIds'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
  );

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _pet.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() => unawaited(_pet.close());

  @override
  Widget build(BuildContext context) {
    final brightness = widget.arguments['brightness'] == 'light'
        ? Brightness.light
        : Brightness.dark;
    final accentValue = (widget.arguments['accent'] as num?)?.toInt();
    final localeName = widget.arguments['locale'] as String?;
    final locale = localeName == null || localeName.isEmpty
        ? null
        : Locale(localeName);
    final targets = _targets(widget.arguments['targets']);
    final initialAuto = Map<String, dynamic>.from(
      widget.arguments['autoClicker'] as Map? ?? const {},
    );

    return PetScope(
      repository: _pet,
      child: MaterialApp(
        title: 'luma pet',
        debugShowCheckedModeBanner: false,
        theme: LumaTheme.from(
          brightness,
          accentValue == null ? null : Color(accentValue),
        ),
        themeMode: brightness == Brightness.light
            ? ThemeMode.light
            : ThemeMode.dark,
        locale: locale,
        supportedLocales: L.supportedLocales,
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: LumaPetPanel(
            fullBleed: true,
            targets: [
              for (final target in targets)
                target.id == 'plugin:auto-clicker'
                    ? PetTarget(
                        id: target.id,
                        label: target.label,
                        icon: target.icon,
                        iconName: target.iconName,
                        kind: target.kind,
                        keywords: target.keywords,
                        open: target.open,
                        compactBuilder: (_, back) => PetAutoClickerPanel(
                          initialState: initialAuto,
                          onBack: back,
                        ),
                      )
                    : target,
            ],
          ),
        ),
      ),
    );
  }

  List<PetTarget> _targets(dynamic rawTargets) {
    final rows = rawTargets is List ? rawTargets : const [];
    return [
      for (final raw in rows)
        if (raw is Map) _targetFromJson(Map<String, dynamic>.from(raw)),
    ];
  }

  PetTarget _targetFromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    return PetTarget(
      id: id,
      label: json['label'] as String? ?? id,
      icon: _iconFor(json['iconName'] as String?),
      iconName: json['iconName'] as String?,
      kind: json['kind'] == PetTargetKind.section.name
          ? PetTargetKind.section
          : PetTargetKind.plugin,
      keywords: (json['keywords'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      open: () => petMainChannel.invokeMethod<void>(petMethodOpenTarget, id),
    );
  }

  IconData _iconFor(String? name) {
    if (name != null && name.startsWith('section:')) {
      final index = int.tryParse(name.substring('section:'.length)) ?? 0;
      const sectionIcons = [
        Icons.dashboard_rounded,
        Icons.swap_horiz_rounded,
        Icons.account_balance_wallet_rounded,
        Icons.lock_rounded,
        Icons.sticky_note_2_rounded,
        Icons.smart_toy_rounded,
        Icons.extension_rounded,
        Icons.settings_rounded,
        Icons.badge_rounded,
      ];
      if (index >= 0 && index < sectionIcons.length) return sectionIcons[index];
    }
    return pluginIconFor(name ?? 'extension');
  }
}

/// Auto Clicker's dense pet-sized controls. The click engine remains in the
/// main window's isolate; every action here is forwarded over the window
/// channel and returns a fresh state snapshot.
class PetAutoClickerPanel extends StatefulWidget {
  const PetAutoClickerPanel({
    super.key,
    required this.initialState,
    required this.onBack,
  });

  final Map<String, dynamic> initialState;
  final VoidCallback onBack;

  @override
  State<PetAutoClickerPanel> createState() => _PetAutoClickerPanelState();
}

class _PetAutoClickerPanelState extends State<PetAutoClickerPanel> {
  late Map<String, dynamic> _state = Map.of(widget.initialState);
  late final TextEditingController _interval = TextEditingController(
    text: '${(_state['intervalMs'] as num?)?.toInt() ?? 100}',
  );
  late final TextEditingController _repeat = TextEditingController(
    text: '${(_state['repeatCount'] as num?)?.toInt() ?? 100}',
  );
  Timer? _refreshTimer;
  Timer? _captureTimer;
  int _captureCountdown = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(milliseconds: 400),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _captureTimer?.cancel();
    _interval.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_busy || !mounted) return;
    try {
      final result = await petMainChannel.invokeMethod<Map<dynamic, dynamic>>(
        petMethodAutoClicker,
        const {'action': 'snapshot'},
      );
      if (result != null && mounted) {
        setState(() => _state = Map<String, dynamic>.from(result));
      }
    } catch (_) {}
  }

  Future<void> _command(String action, [Object? value]) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await petMainChannel.invokeMethod<Map<dynamic, dynamic>>(
        petMethodAutoClicker,
        {'action': action, 'value': ?value},
      );
      if (result != null && mounted) {
        setState(() => _state = Map<String, dynamic>.from(result));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _beginCapture() {
    _captureTimer?.cancel();
    setState(() => _captureCountdown = 3);
    _captureTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = _captureCountdown - 1;
      if (next <= 0) {
        timer.cancel();
        setState(() => _captureCountdown = 0);
        unawaited(_command('captureCursor'));
      } else {
        setState(() => _captureCountdown = next);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final running = _state['isRunning'] == true;
    final clickAtCursor = _state['clickAtCursor'] != false;
    final repeatCount = _state['repeatMode'] == 'count';
    final button = _state['button'] as String? ?? 'left';
    final canStart = clickAtCursor || _state['fixedX'] != null;

    return ColoredBox(
      color: luma.surface,
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => windowStartDrag(),
            child: Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: luma.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: luma.textSecondary,
                    tooltip: 'Back to pet',
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.ads_click_rounded, color: luma.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Auto Clicker',
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => PetScope.read(context).close(),
                    icon: const Icon(Icons.close_rounded, size: 19),
                    color: luma.textMuted,
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _statusCard(luma, running, canStart),
                const SizedBox(height: 12),
                _card(
                  luma,
                  title: 'INTERVAL',
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _interval,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: _input(luma, 'Milliseconds'),
                          onSubmitted: (value) =>
                              _command('setInterval', int.tryParse(value) ?? 1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _command(
                                'setInterval',
                                int.tryParse(_interval.text) ?? 1,
                              ),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  luma,
                  title: 'CLICK',
                  child: Column(
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'left', label: Text('Left')),
                          ButtonSegment(value: 'middle', label: Text('Middle')),
                          ButtonSegment(value: 'right', label: Text('Right')),
                        ],
                        selected: {button},
                        onSelectionChanged: (v) =>
                            _command('setButton', v.first),
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Double click'),
                        value: _state['doubleClick'] == true,
                        onChanged: (v) => _command('setDoubleClick', v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  luma,
                  title: 'LOCATION & REPEAT',
                  child: Column(
                    children: [
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('Cursor')),
                          ButtonSegment(value: false, label: Text('Fixed')),
                        ],
                        selected: {clickAtCursor},
                        onSelectionChanged: (v) =>
                            _command('setClickAtCursor', v.first),
                      ),
                      if (!clickAtCursor)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _state['fixedX'] == null
                                      ? 'No point selected'
                                      : '${_state['fixedX']}, ${_state['fixedY']}',
                                  style: TextStyle(color: luma.textMuted),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _captureCountdown > 0
                                    ? null
                                    : _beginCapture,
                                icon: const Icon(Icons.my_location_rounded),
                                label: Text(
                                  _captureCountdown > 0
                                      ? 'Move cursor… $_captureCountdown'
                                      : 'Pick point',
                                ),
                              ),
                            ],
                          ),
                        ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Stop after a set amount'),
                        value: repeatCount,
                        onChanged: (v) => _command(
                          'setRepeatMode',
                          v ? 'count' : 'untilStopped',
                        ),
                      ),
                      if (repeatCount)
                        TextField(
                          controller: _repeat,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: _input(luma, 'Number of clicks'),
                          onSubmitted: (value) => _command(
                            'setRepeatCount',
                            int.tryParse(value) ?? 1,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(LumaPalette luma, bool running, bool canStart) => _card(
    luma,
    title: running
        ? '${_state['clicksDone'] ?? 0} CLICKS'
        : 'READY · ${_state['hotKey'] ?? 'F6'}',
    child: SizedBox(
      height: 44,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: running ? luma.danger : luma.accent,
          foregroundColor: running ? Colors.white : luma.onAccent,
        ),
        onPressed: _busy || (!running && !canStart)
            ? null
            : () => _command('toggle'),
        icon: Icon(running ? Icons.stop_rounded : Icons.play_arrow_rounded),
        label: Text(running ? 'Stop clicking' : 'Start clicking'),
      ),
    ),
  );

  Widget _card(
    LumaPalette luma, {
    required String title,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: luma.background,
      border: Border.all(color: luma.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            color: luma.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );

  InputDecoration _input(LumaPalette luma, String label) => InputDecoration(
    isDense: true,
    labelText: label,
    filled: true,
    fillColor: luma.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
  );
}

Map<String, dynamic> decodePetWindowArguments(String arguments) {
  if (arguments.isEmpty) return const {};
  try {
    return Map<String, dynamic>.from(jsonDecode(arguments) as Map);
  } catch (_) {
    return const {};
  }
}
