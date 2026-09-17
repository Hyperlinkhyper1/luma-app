import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../_shared/native_webview.dart';
import '../../_shared/windows_webview.dart' show windowsAssetPath;

/// The airport page: the 3D scene plus its in-page controls.
///
/// A local renderer and control surface only. The page sends commands and the
/// owner decides what happens; nothing here changes the game on its own.
///
/// On Windows it runs in a real WebView2 window ([NativeWebview]) rather than
/// the captured texture `webview_windows` provides, which could not keep a
/// WebGL scene above a handful of frames per second. Because nothing Flutter
/// draws can cover that window, every control lives inside the page.
class AirportSceneView extends StatefulWidget {
  const AirportSceneView({
    super.key,
    required this.onMessage,
    required this.snapshot,
    required this.palette,
    this.visible = true,
  });

  final void Function(Map<String, Object?> message) onMessage;
  final Map<String, Object?> Function() snapshot;

  /// CSS custom properties for the page's controls, e.g. `{'accent': '#…'}`.
  final Map<String, String> palette;

  /// False while a full-page Flutter panel covers the airport.
  final bool visible;

  @override
  State<AirportSceneView> createState() => AirportSceneViewState();
}

class AirportSceneViewState extends State<AirportSceneView>
    with WidgetsBindingObserver {
  NativeWebviewController? _windows;
  InAppWebViewController? _android;
  Timer? _timeout;
  bool _ready = false;
  bool _tickerEnabled = true;
  bool _foreground = true;
  String? _error;
  int _generation = 0;
  static const _asset = 'assets/airline_tycoon/scene/index.html';

  bool get _showing => widget.visible && _tickerEnabled && _foreground;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _armTimeout();
  }

  void _armTimeout() {
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 25), () {
      if (mounted && !_ready) {
        setState(
          () => _error = Platform.isWindows
              ? 'The airport did not start. Check that the Microsoft Edge WebView2 Runtime is installed, then retry.'
              : 'The airport did not start. Update Android System WebView, then retry.',
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = TickerMode.valuesOf(context).enabled;
    if (enabled != _tickerEnabled) {
      _tickerEnabled = enabled;
      _updateVisibility();
    }
  }

  @override
  void didUpdateWidget(AirportSceneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) _updateVisibility();
    if (!_samePalette(oldWidget.palette, widget.palette)) _sendTheme();
  }

  static bool _samePalette(Map<String, String> a, Map<String, String> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground =
        state == AppLifecycleState.resumed ||
        (Platform.isWindows && state == AppLifecycleState.inactive);
    _updateVisibility();
  }

  void _updateVisibility() {
    send({'type': 'view', 'action': 'visible', 'value': _showing});
    refresh();
  }

  /// Pushes the current world to the page, if anyone can see it.
  void refresh() {
    if (_ready && _showing) {
      send({'type': 'snapshot', 'world': widget.snapshot()});
    }
  }

  void _sendTheme() => send({'type': 'theme', 'palette': widget.palette});

  void send(Map<String, Object?> message) {
    if (!_ready) return;
    final json = jsonEncode(message);
    final Future<void> delivery;
    if (_windows != null) {
      delivery = _windows!.post(json);
    } else if (_android != null) {
      delivery = _android!.evaluateJavascript(
        source: 'window.airportReceive($json);',
      );
    } else {
      return;
    }
    unawaited(
      delivery.catchError((Object _) {
        if (mounted) {
          setState(
            () =>
                _error = 'Airport connection interrupted. Retry to reconnect.',
          );
        }
      }),
    );
  }

  void _receive(dynamic raw) {
    if (!mounted) return;
    try {
      final value = raw is String ? jsonDecode(raw) : raw;
      if (value is! Map) return;
      final message = Map<String, Object?>.from(value);
      if (message['type'] == 'ready') {
        _timeout?.cancel();
        setState(() {
          _ready = true;
          _error = null;
        });
        _sendTheme();
        _updateVisibility();
        widget.onMessage(message);
      } else if (message['type'] == 'error') {
        _fail('${message['message'] ?? 'WebGL could not initialize.'}');
      } else {
        widget.onMessage(message);
      }
    } on FormatException {
      return;
    } on TypeError {
      return;
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    _timeout?.cancel();
    setState(() => _error = message);
  }

  void _retry() {
    _windows = null;
    _android = null;
    setState(() {
      _generation++;
      _ready = false;
      _error = null;
    });
    _armTimeout();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: Platform.isWindows
            ? NativeWebview(
                key: ValueKey(_generation),
                fileUrl: Uri.file(windowsAssetPath(_asset)).toString(),
                // The error card is Flutter content, so the window must go.
                visible: widget.visible && _error == null,
                onCreated: (controller) => _windows = controller,
                onMessage: _receive,
                onError: _fail,
              )
            : InAppWebView(
                key: ValueKey(_generation),
                initialFile: _asset,
                initialSettings: InAppWebViewSettings(
                  supportZoom: false,
                  transparentBackground: true,
                ),
                onWebViewCreated: (controller) {
                  _android = controller;
                  controller.addJavaScriptHandler(
                    handlerName: 'airport',
                    callback: (args) {
                      if (args.isNotEmpty) _receive(args.first);
                      return null;
                    },
                  );
                },
                onReceivedError: (_, request, error) {
                  if (request.isForMainFrame == true) {
                    _fail(
                      'Could not load the bundled airport: ${error.description}',
                    );
                  }
                },
              ),
      ),
      if (_error != null)
        Positioned.fill(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reload airport'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeout?.cancel();
    super.dispose();
  }
}
