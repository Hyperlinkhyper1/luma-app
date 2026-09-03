import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;

/// Resolves a Flutter asset's on-disk path for a Windows desktop build.
///
/// Flutter's Windows runner ships assets as loose files next to the exe
/// (`data/flutter_assets/...`), rather than packed into an archive the way
/// mobile does — so bundled HTML/JS can be pointed at directly with a
/// `file://` URL instead of needing to be copied out at runtime.
String windowsAssetPath(String assetPath) {
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  return '$exeDir\\data\\flutter_assets\\$assetPath';
}

/// A minimal Windows-only local-file webview, used in place of
/// flutter_inappwebview for plugins that just need to render a bundled or
/// on-disk HTML page — see the comment on the `webview_windows` dependency
/// in pubspec.yaml for why.
class WindowsWebview extends StatefulWidget {
  const WindowsWebview({
    super.key,
    required this.fileUrl,
    this.onLoaded,
    this.onController,
  });

  /// A `file:///...` URL to load.
  final String fileUrl;
  final VoidCallback? onLoaded;

  /// Fired once with the underlying [WebviewController] right after it's
  /// initialized (before the page loads), for callers that need to talk to
  /// the page's JS — e.g. `controller.webMessage` (JS→Dart, via
  /// `window.chrome.webview.postMessage`) and `controller.postWebMessage`
  /// (Dart→JS, delivered to `window.chrome.webview.addEventListener
  /// ('message', ...)`). Both are plain `webview_windows` APIs; this widget
  /// otherwise stays a dumb page-loader, so opting into a bridge is the
  /// caller's choice.
  final void Function(WebviewController controller)? onController;

  @override
  State<WindowsWebview> createState() => _WindowsWebviewState();
}

class _WindowsWebviewState extends State<WindowsWebview> {
  final _controller = WebviewController();
  bool _ready = false;

  /// WebView2 in composition mode is often flagged as occluded by Chromium's
  /// native-window occlusion tracker, which marks the page hidden and freezes
  /// requestAnimationFrame — WebGL content (e.g. Subway Builder's map) then
  /// never renders. These browser arguments disable that. Must be set before
  /// the process's first WebView2 environment is created; harmless after.
  static bool _envConfigured = false;
  static void _configureWebview2Env() {
    if (_envConfigured) return;
    _envConfigured = true;
    final name = 'WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS'.toNativeUtf16();
    final value =
        '--disable-features=CalculateNativeWinOcclusion '
                '--disable-background-timer-throttling '
                '--disable-renderer-backgrounding'
            .toNativeUtf16();
    win32.SetEnvironmentVariable(name, value);
    calloc.free(name);
    calloc.free(value);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    _configureWebview2Env();
    await _controller.initialize();
    await _controller.setBackgroundColor(Colors.transparent);
    await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    widget.onController?.call(_controller);
    _controller.loadingState
        .firstWhere((s) => s == LoadingState.navigationCompleted)
        .then((_) {
      if (mounted) widget.onLoaded?.call();
    });
    await _controller.loadUrl(widget.fileUrl);
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();
    return Webview(_controller);
  }
}
