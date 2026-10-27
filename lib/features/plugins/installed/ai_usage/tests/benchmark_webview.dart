import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../_shared/windows_webview.dart';

/// The Content-Security-Policy a downloaded benchmark scene runs under. Scenes
/// are LLM-written and come from the luma server, so they are untrusted code:
/// they get the CDNs they import from and nothing to send data back with — no
/// fetch, XHR or WebSocket beyond data: and blob: URLs. Mirrors the policy the
/// server's preview renderer (server/tool/renderer_network.mjs) enforces.
const sceneCsp =
    "default-src 'none'; "
    "script-src 'unsafe-inline' 'unsafe-eval' blob: https://cdn.jsdelivr.net "
    'https://unpkg.com https://cdnjs.cloudflare.com https://esm.sh '
    'https://cdn.tailwindcss.com; '
    "style-src 'unsafe-inline' https://fonts.googleapis.com; "
    'font-src data: https://fonts.gstatic.com; '
    'img-src data: blob: https:; '
    'media-src data: blob:; '
    'connect-src data: blob:; '
    'worker-src blob: data:; '
    "frame-src 'none'; "
    "object-src 'none'; "
    "base-uri 'none'; "
    "form-action 'none'";

/// [html] with [sceneCsp] in front of everything but its doctype, so the
/// policy is in force before the scene's first script or stylesheet. The
/// charset comes first because the policy pushes the scene's own
/// `<meta charset>` past the 1024 bytes a browser scans for it.
String withSceneCsp(String html) {
  final source = html.startsWith('﻿') ? html.substring(1) : html;
  final doctype = RegExp(
    r'^\s*<!doctype[^>]*>',
    caseSensitive: false,
  ).firstMatch(source);
  final at = doctype?.end ?? 0;
  return '${source.substring(0, at)}'
      '<meta charset="utf-8">'
      '<meta http-equiv="Content-Security-Policy" content="$sceneCsp">'
      '${source.substring(at)}';
}

/// Writes the scene at [path] next to itself with [withSceneCsp] applied and
/// returns the copy's path. A copy newer than the scene is reused.
Future<String> sandboxedScene(String path) async {
  final source = File(path);
  final copy = File('$path.sandboxed.html');
  if (await copy.exists() &&
      !(await copy.lastModified()).isBefore(await source.lastModified())) {
    return copy.path;
  }
  final html = utf8.decode(await source.readAsBytes(), allowMalformed: true);
  final temp = File('${copy.path}.${DateTime.now().microsecondsSinceEpoch}');
  await temp.writeAsString(withSceneCsp(html), flush: true);
  await temp.rename(copy.path);
  return copy.path;
}

/// Opens a benchmark document from the bundle or download cache. Downloaded
/// scenes and inline HTML run under [sceneCsp], and no scene may read other
/// files: on Android a `file://` page with universal file access could read
/// anything in the app's data directory and post it out.
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

  /// The [sandboxedScene] copy of [BenchmarkWebview.path], once written.
  String? _scenePath;
  int _preparing = 0;

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
  void initState() {
    super.initState();
    _prepare();
  }

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
      if (oldWidget.path != widget.path) _prepare();
    }
  }

  void _prepare() {
    final path = widget.path;
    final generation = ++_preparing;
    _scenePath = null;
    if (path == null || !BenchmarkWebview.supported) return;
    sandboxedScene(path).then(
      (copy) {
        if (mounted && generation == _preparing) {
          setState(() => _scenePath = copy);
        }
      },
      onError: (Object error) {
        if (mounted && generation == _preparing) _fail('$error');
      },
    );
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
    if (_scenePath == null) _prepare();
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
    final path = _scenePath;
    if (widget.path != null && path == null) return const SizedBox.shrink();
    final html = widget.html == null ? null : withSceneCsp(widget.html!);
    final sourceKey = ValueKey((
      widget.path,
      widget.assetPath,
      widget.html,
      _generation,
    ));
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return WindowsWebview(
        key: sourceKey,
        fileUrl: html == null
            ? Uri.file(path ?? windowsAssetPath(widget.assetPath!)).toString()
            : null,
        html: html,
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
    return InAppWebView(
      key: sourceKey,
      initialFile: widget.assetPath,
      initialUrlRequest: path == null
          ? null
          : URLRequest(url: WebUri(Uri.file(path).toString())),
      initialData: html == null ? null : InAppWebViewInitialData(data: html),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        hardwareAcceleration: true,
        supportZoom: false,
        allowFileAccess: html == null,
        allowContentAccess: false,
        allowFileAccessFromFileURLs: false,
        allowUniversalAccessFromFileURLs: false,
        allowingReadAccessTo: path == null
            ? null
            : WebUri(Uri.file(path).toString()),
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
