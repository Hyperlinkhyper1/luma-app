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
    this.fileUrl,
    this.html,
    this.onLoaded,
    this.onController,
  });

  /// A `file:///...` URL to load.
  final String? fileUrl;
  final String? html;
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

  static bool _envConfigured = false;

  /// WebView2 composition windows can be flagged as occluded before they
  /// render. Set the browser flags before creating the first controller.
  static Future<void> initializeController(WebviewController controller) {
    if (!_envConfigured) {
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
    return controller.initialize();
  }

  @override
  State<WindowsWebview> createState() => _WindowsWebviewState();
}

class _WindowsWebviewState extends State<WindowsWebview>
    with WidgetsBindingObserver {
  final _controller = WebviewController();
  bool _ready = false;

  /// The flags below stop Chromium from ever throttling this page on its
  /// own, so a WebGL scene would keep rendering flat out in a background tab
  /// or with luma minimised to the tray. The page is suspended instead
  /// whenever nobody can see it: [TickerMode] is off (another tab is in
  /// front) or the app window is hidden.
  bool _tickerEnabled = true;
  bool _appVisible = true;
  bool _suspended = false;
  Future<void> _visibilityChange = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appVisible = _isAppVisible(WidgetsBinding.instance.lifecycleState);
    unawaited(_init());
  }

  static bool _isAppVisible(AppLifecycleState? state) =>
      state != AppLifecycleState.hidden && state != AppLifecycleState.paused;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible = _isAppVisible(state);
    _syncSuspended();
  }

  void _syncSuspended() {
    if (!_ready) return;
    final suspend = !(_tickerEnabled && _appVisible);
    if (suspend == _suspended) return;
    _suspended = suspend;
    _visibilityChange = _visibilityChange
        .then((_) => suspend ? _controller.suspend() : _controller.resume())
        .catchError((Object _) {});
  }

  Future<void> _init() async {
    await WindowsWebview.initializeController(_controller);
    await _controller.setBackgroundColor(Colors.transparent);
    await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    widget.onController?.call(_controller);
    _controller.loadingState
        .firstWhere((s) => s == LoadingState.navigationCompleted)
        .then((_) => _loaded(), onError: (_) => _loaded());
    // navigationCompleted waits for the load event, which a page stalled on
    // one slow CDN script never fires; by now it has painted something of
    // its own, so a caller's spinner must not keep covering it.
    _loadedFallback = Timer(const Duration(seconds: 8), _loaded);
    try {
      if (widget.html case final html?) {
        await _controller.loadStringContent(html);
      } else if (widget.fileUrl case final fileUrl?) {
        await _controller.loadUrl(fileUrl);
      }
    } finally {
      if (mounted) {
        setState(() => _ready = true);
        _syncSuspended();
      }
    }
  }

  Timer? _loadedFallback;
  bool _loadedFired = false;

  void _loaded() {
    _loadedFallback?.cancel();
    if (_loadedFired || !mounted) return;
    _loadedFired = true;
    widget.onLoaded?.call();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loadedFallback?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _syncSuspended();
    if (!_ready) return const SizedBox.shrink();
    return Webview(_controller);
  }
}
