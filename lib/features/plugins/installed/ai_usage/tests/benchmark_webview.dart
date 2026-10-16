import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../_shared/windows_webview.dart';

/// Opens an unchanged benchmark document from the bundle or download cache.
class BenchmarkWebview extends StatefulWidget {
  const BenchmarkWebview({
    super.key,
    this.path,
    this.assetPath,
    this.html,
    this.onLoaded,
    this.onMessage,
    this.onError,
  }) : assert(
         (path != null ? 1 : 0) +
                 (assetPath != null ? 1 : 0) +
                 (html != null ? 1 : 0) ==
             1,
       );

  final String? path;
  final String? assetPath;
  final String? html;
  final VoidCallback? onLoaded;
  final ValueChanged<dynamic>? onMessage;
  final ValueChanged<String>? onError;

  static bool get supported =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.windows ||
        TargetPlatform.android ||
        TargetPlatform.iOS => true,
        _ => false,
      };

  @override
  State<BenchmarkWebview> createState() => _BenchmarkWebviewState();
}

class _BenchmarkWebviewState extends State<BenchmarkWebview> {
  StreamSubscription<dynamic>? _messages;
  Timer? _loadedFallback;
  bool _loadedFired = false;
  bool _failed = false;
  String? _error;
  int _generation = 0;

  // The documents already use WebView2's messaging API. Supplying its mobile
  // equivalent here keeps the benchmark files identical on every platform.
  static const _messageBridge = r'''
(() => {
  const pending = [];
  let ready = !!(window.flutter_inappwebview &&
    window.flutter_inappwebview._platformReady);
  const send = value => {
    const bridge = window.flutter_inappwebview;
    if (!ready || !bridge || typeof bridge.callHandler !== 'function') {
      return false;
    }
    bridge.callHandler('lumaBenchmark', value);
    return true;
  };
  window.chrome = window.chrome || {};
  window.chrome.webview = window.chrome.webview || {};
  window.chrome.webview.postMessage = value => {
    if (!send(value)) pending.push(value);
  };
  window.addEventListener('flutterInAppWebViewPlatformReady', () => {
    ready = true;
    while (pending.length && send(pending[0])) pending.shift();
  });
})();
''';

  @override
  void didUpdateWidget(BenchmarkWebview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.assetPath != widget.assetPath ||
        oldWidget.html != widget.html) {
      _loadedFallback?.cancel();
      unawaited(_messages?.cancel());
      _messages = null;
      _loadedFired = false;
      _failed = false;
      _error = null;
    }
  }

  void _loadStarted() {
    if (_loadedFired || _failed) return;
    _loadedFallback?.cancel();
    _loadedFallback = Timer(const Duration(seconds: 8), _loaded);
  }

  void _loaded() {
    _loadedFallback?.cancel();
    if (!mounted || _loadedFired || _failed) return;
    _loadedFired = true;
    widget.onLoaded?.call();
  }

  void _fail(String message) {
    _loadedFallback?.cancel();
    if (!mounted || _failed) return;
    _loaded();
    _failed = true;
    if (widget.onError case final onError?) {
      onError(message);
    } else {
      setState(() => _error = message);
    }
  }

  void _retry() {
    setState(() {
      _generation++;
      _loadedFired = false;
      _failed = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!BenchmarkWebview.supported) return const SizedBox.shrink();
    if (_error case final error?) {
      final t = L.of(context);
      return LumaEmptyState(
        icon: Icons.error_outline_rounded,
        title: t.commonError,
        subtitle: t.commonErrorDetail(error),
        action: FilledButton.icon(
          onPressed: _retry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(t.commonRetry),
        ),
      );
    }
    final sourceKey = ValueKey((
      widget.path,
      widget.assetPath,
      widget.html,
      _generation,
    ));
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return WindowsWebview(
        key: sourceKey,
        fileUrl: widget.html == null
            ? Uri.file(
                widget.path ?? windowsAssetPath(widget.assetPath!),
              ).toString()
            : null,
        html: widget.html,
        onLoaded: _loaded,
        onController: widget.onMessage == null
            ? null
            : (controller) {
                unawaited(_messages?.cancel());
                _messages = controller.webMessage.listen((message) {
                  if (mounted) widget.onMessage?.call(message);
                });
              },
      );
    }
    final path = widget.path;
    return InAppWebView(
      key: sourceKey,
      initialFile: widget.assetPath,
      initialUrlRequest: path == null
          ? null
          : URLRequest(url: WebUri(Uri.file(path).toString())),
      initialData: widget.html == null
          ? null
          : InAppWebViewInitialData(data: widget.html!),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        hardwareAcceleration: true,
        supportZoom: false,
        allowFileAccess: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
        allowingReadAccessTo: path == null
            ? null
            : WebUri(Uri.directory(File(path).parent.path).toString()),
      ),
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
      initialUserScripts: widget.onMessage == null
          ? null
          : UnmodifiableListView([
              UserScript(
                source: _messageBridge,
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              ),
            ]),
      onWebViewCreated: (controller) {
        if (widget.onMessage == null) return;
        controller.addJavaScriptHandler(
          handlerName: 'lumaBenchmark',
          callback: (arguments) {
            if (mounted && arguments.isNotEmpty) {
              widget.onMessage?.call(arguments.first);
            }
            return null;
          },
        );
      },
      onLoadStart: (_, _) => _loadStarted(),
      onLoadStop: (_, _) => _loaded(),
      onReceivedError: (_, request, error) {
        if (request.isForMainFrame == true) _fail(error.description);
      },
      onReceivedHttpError: (_, request, response) {
        if (request.isForMainFrame == true) {
          _fail(response.reasonPhrase ?? 'HTTP ${response.statusCode}');
        }
      },
    );
  }

  @override
  void dispose() {
    _loadedFallback?.cancel();
    unawaited(_messages?.cancel());
    super.dispose();
  }
}
