import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../app/native_overlay_decoration.dart';
import '../../../../l10n/current_l.dart';

/// A real WebView2 window laid over this widget's rectangle (Windows only).
///
/// Unlike `webview_windows`, which screen-captures WebView2 into a Flutter
/// texture and relays every mouse move over a platform channel, this hosts
/// WebView2 in a child window of the app (see `windows/runner/
/// native_webview.cpp`). It presents straight to the screen and gets input
/// directly, which is what a WebGL game needs.
///
/// Flutter tooltips cut their bounds out of the native window region. The
/// window hides itself while a dialog, menu or another route covers it, or
/// while [TickerMode] is off.
class NativeWebview extends StatefulWidget {
  const NativeWebview({
    super.key,
    required this.fileUrl,
    required this.onMessage,
    this.onError,
    this.onCreated,
    this.visible = true,
    this.background = const Color(0xFFDBE9E5),
  });

  /// A `file:///...` URL to load.
  final String fileUrl;

  /// Strings the page sent with `window.chrome.webview.postMessage`.
  final ValueChanged<String> onMessage;
  final ValueChanged<String>? onError;
  final ValueChanged<NativeWebviewController>? onCreated;

  /// Lets the owner hide the window, e.g. while a full-page panel is open.
  final bool visible;

  /// Painted by Flutter under the window before it first appears.
  final Color background;

  @override
  State<NativeWebview> createState() => _NativeWebviewState();
}

/// Talks to one native WebView2 window.
class NativeWebviewController {
  NativeWebviewController._(this._id);

  static const _channel = MethodChannel('luma/native_webview');
  static final _live = <int, _NativeWebviewState>{};
  static bool _listening = false;

  final int _id;
  bool _disposed = false;

  static void _listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      final args = call.arguments;
      if (args is! Map) return;
      final state = _live[args['id']];
      final data = '${args['data'] ?? ''}';
      if (state == null || !state.mounted) return;
      if (call.method == 'message') {
        state.widget.onMessage(data);
      } else if (call.method == 'error') {
        state.widget.onError?.call(data);
      }
    });
  }

  /// Delivered to the page's `window.chrome.webview` `message` listeners.
  Future<void> post(String data) => _call('post', {'data': data});

  /// Reloads the page, e.g. after it reported an error.
  Future<void> reload() => _call('reload');

  Future<void> _call(String method, [Map<String, Object?> args = const {}]) {
    if (_disposed) return Future.value();
    return _channel.invokeMethod<void>(method, {'id': _id, ...args});
  }

  void _dispose() {
    if (_disposed) return;
    unawaited(_call('dispose'));
    _disposed = true;
    _live.remove(_id);
  }
}

class _NativeWebviewState extends State<NativeWebview>
    with WidgetsBindingObserver {
  NativeWebviewController? _controller;
  Rect? _sentBounds;
  List<RRect> _sentOcclusion = const [];
  bool? _sentVisible;
  bool _routeCurrent = true;
  bool _tickerEnabled = true;
  bool _appVisible = true;
  double _pixelRatio = 1;
  bool _tracking = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_create());
  }

  Future<void> _create() async {
    NativeWebviewController._listen();
    String? folder;
    try {
      final support = await getApplicationSupportDirectory();
      folder = '${support.path}${Platform.pathSeparator}native_webview';
    } catch (_) {
      folder = null;
    }
    int? id;
    try {
      id = await NativeWebviewController._channel.invokeMethod<int>('create', {
        'url': widget.fileUrl,
        'userDataFolder': ?folder,
      });
    } on PlatformException catch (error) {
      if (mounted) widget.onError?.call(error.message ?? error.code);
      return;
    } on MissingPluginException {
      if (mounted) {
        widget.onError?.call(currentL.nativeWebviewNoHost);
      }
      return;
    }
    if (id == null) return;
    final controller = NativeWebviewController._(id);
    if (_disposed) {
      controller._dispose();
      return;
    }
    NativeWebviewController._live[id] = this;
    _controller = controller;
    widget.onCreated?.call(controller);
    _startTracking();
  }

  void _startTracking() {
    if (_tracking) return;
    _tracking = true;
    WidgetsBinding.instance.addPostFrameCallback(_track);
    WidgetsBinding.instance.scheduleFrame();
  }

  /// Runs after every frame: layout can move this widget without rebuilding
  /// it, and the native window has to follow.
  void _track(Duration _) {
    final controller = _controller;
    if (_disposed || controller == null) {
      _tracking = false;
      return;
    }
    final box = context.findRenderObject();
    if (box is RenderBox && box.attached && box.hasSize) {
      final origin = box.localToGlobal(Offset.zero) * _pixelRatio;
      final size = box.size * _pixelRatio;
      final bounds = Rect.fromLTWH(
        origin.dx.roundToDouble(),
        origin.dy.roundToDouble(),
        size.width.roundToDouble(),
        size.height.roundToDouble(),
      );
      if (bounds != _sentBounds) {
        _sentBounds = bounds;
        unawaited(
          controller._call('setBounds', {
            'x': bounds.left.toInt(),
            'y': bounds.top.toInt(),
            'width': bounds.width.toInt(),
            'height': bounds.height.toInt(),
          }),
        );
      }
    }
    _syncVisible();
    _syncOcclusion();
    WidgetsBinding.instance.addPostFrameCallback(_track);
  }

  void _syncOcclusion() {
    final bounds = _sentBounds;
    final controller = _controller;
    if (bounds == null || controller == null || _sentVisible != true) return;
    final overlay = Overlay.maybeOf(
      context,
      rootOverlay: true,
    )?.context.findRenderObject();
    final regions = <RRect>[];
    if (overlay != null) {
      for (final region in NativeOverlayDecoration.regionsIn(overlay)) {
        final rect = Rect.fromLTRB(
          region.left * _pixelRatio - bounds.left,
          region.top * _pixelRatio - bounds.top,
          region.right * _pixelRatio - bounds.left,
          region.bottom * _pixelRatio - bounds.top,
        );
        if (!rect.overlaps(Offset.zero & bounds.size)) continue;
        regions.add(
          RRect.fromRectAndRadius(
            rect,
            Radius.elliptical(
              region.tlRadiusX * _pixelRatio,
              region.tlRadiusY * _pixelRatio,
            ),
          ),
        );
      }
    }
    if (listEquals(regions, _sentOcclusion)) return;
    _sentOcclusion = regions;
    unawaited(
      controller._call('setOcclusionRects', {
        'rects': [
          for (final region in regions)
            {
              'x': region.left.floor(),
              'y': region.top.floor(),
              'width': region.right.ceil() - region.left.floor(),
              'height': region.bottom.ceil() - region.top.floor(),
              'radiusX': region.tlRadiusX.ceil(),
              'radiusY': region.tlRadiusY.ceil(),
            },
        ],
      }),
    );
  }

  /// Hidden windows put the page in the hidden state, which stops its
  /// render loop; the app's WebView2 flags turn off Chromium's own occlusion
  /// detection, so a minimised or tray-hidden luma has to say so itself.
  void _syncVisible() {
    final controller = _controller;
    if (_disposed || controller == null) return;
    final visible =
        widget.visible && _routeCurrent && _tickerEnabled && _appVisible;
    if (visible == _sentVisible) return;
    _sentVisible = visible;
    unawaited(controller._call('setVisible', {'visible': visible}));
    if (visible) unawaited(controller._call('focus'));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible =
        state != AppLifecycleState.hidden && state != AppLifecycleState.paused;
    _syncVisible();
  }

  @override
  Widget build(BuildContext context) {
    _pixelRatio = View.of(context).devicePixelRatio;
    _routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (_controller != null) WidgetsBinding.instance.scheduleFrame();
    return ColoredBox(color: widget.background);
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _controller?._dispose();
    super.dispose();
  }
}
