import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../_shared/windows_webview.dart';

/// A local renderer. Only the repository can authorize game commands.
class AirportSceneView extends StatefulWidget {
  const AirportSceneView({
    super.key,
    required this.onMessage,
    required this.snapshot,
  });

  final void Function(Map<String, Object?> message) onMessage;
  final Map<String, Object?> Function() snapshot;

  @override
  State<AirportSceneView> createState() => AirportSceneViewState();
}

class AirportSceneViewState extends State<AirportSceneView>
    with WidgetsBindingObserver {
  WebviewController? _windows;
  InAppWebViewController? _android;
  StreamSubscription<dynamic>? _messages;
  Timer? _timeout;
  bool _ready = false;
  bool _visible = true;
  bool _foreground = true;
  String? _error;
  int _generation = 0;
  static const _asset = 'assets/airline_tycoon/scene/index.html';

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
          () => _error =
              'The airport renderer did not start. Check that WebView2 is installed on Windows, then retry.',
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    _updateVisibility();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateVisibility();
  }

  void _updateVisibility() {
    send({
      'type': 'view',
      'action': 'visible',
      'value': _visible && _foreground,
    });
    if (_visible && _foreground) refresh();
  }

  void refresh() {
    if (_ready && _visible && _foreground) {
      send({'type': 'snapshot', 'world': widget.snapshot()});
    }
  }

  void send(Map<String, Object?> message) {
    if (!_ready) return;
    unawaited(_execute('window.airportReceive(${jsonEncode(message)});'));
  }

  Future<void> _execute(String source) async {
    try {
      if (_windows != null) {
        await _windows!.executeScript(source);
      } else {
        await _android?.evaluateJavascript(source: source);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = 'Airport connection interrupted. Retry to reconnect.',
        );
      }
    }
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
        refresh();
        _updateVisibility();
        widget.onMessage(message);
      } else if (message['type'] == 'error') {
        setState(
          () =>
              _error = '${message['message'] ?? 'WebGL could not initialize.'}',
        );
      } else {
        widget.onMessage(message);
      }
    } on FormatException {
      return;
    } on TypeError {
      return;
    }
  }

  void _retry() {
    _messages?.cancel();
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
            ? WindowsWebview(
                key: ValueKey(_generation),
                fileUrl: Uri.file(windowsAssetPath(_asset)).toString(),
                onController: (controller) {
                  _windows = controller;
                  _messages = controller.webMessage.listen(_receive);
                },
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
                  if (request.isForMainFrame == true && mounted) {
                    setState(
                      () => _error =
                          'Could not load the bundled airport: ${error.description}',
                    );
                  }
                },
              ),
      ),
      if (!_ready && _error == null)
        const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparing your airport…'),
                ],
              ),
            ),
          ),
        ),
      if (_error != null)
        Center(
          child: Card(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded),
                    const SizedBox(height: 12),
                    Text(_error!),
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
    ],
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeout?.cancel();
    _messages?.cancel();
    super.dispose();
  }
}
