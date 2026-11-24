import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/window_controls.dart';
import '../../../../theme/luma_theme.dart';
import '../_shared/native_webview.dart';
import '../_shared/windows_webview.dart' show windowsAssetPath;

/// Displays the monitor viewer on Windows. The capture device remains under
/// the user's control and is released when this view becomes hidden.
class MonitorCaptureView extends StatefulWidget {
  const MonitorCaptureView({super.key});

  @override
  State<MonitorCaptureView> createState() => _MonitorCaptureViewState();
}

class _MonitorCaptureViewState extends State<MonitorCaptureView> {
  String? _error;
  bool _fullScreen = false;
  NativeWebviewController? _controller;
  bool _pageReady = false;
  String? _sentTheme;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sendTheme();
  }

  /// The page paints itself with luma's palette, which it learns from the app
  /// once it reports `ready` and again whenever the theme changes.
  void _sendTheme() {
    final controller = _controller;
    if (controller == null || !_pageReady) return;
    final colors = context.luma;
    final message =
        'theme:${jsonEncode({
          'scheme': Theme.of(context).brightness == Brightness.light ? 'light' : 'dark',
          'colors': {'bg': _hex(colors.background), 'surface': _hex(colors.surface), 'surface-hover': _hex(colors.surfaceHover), 'border': _hex(colors.border), 'accent': _hex(colors.accent), 'accent-hover': _hex(colors.accentHover), 'on-accent': _hex(colors.onAccent), 'text': _hex(colors.textPrimary), 'text-secondary': _hex(colors.textSecondary), 'text-muted': _hex(colors.textMuted), 'screen': _hex(Color.alphaBlend(const Color(0xCC000000), colors.rail))},
        })}';
    if (message == _sentTheme) return;
    _sentTheme = message;
    controller.post(message);
  }

  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  /// The page goes full screen inside WebView2, which the runner stretches
  /// over the whole window; this takes the window itself full screen too.
  void _onMessage(String message) {
    if (message == 'ready') {
      _pageReady = true;
      _sentTheme = null;
      _sendTheme();
      return;
    }
    final fullScreen = switch (message) {
      'fullscreen-on' => true,
      'fullscreen-off' => false,
      _ => null,
    };
    if (fullScreen == null || fullScreen == _fullScreen) return;
    _fullScreen = fullScreen;
    windowSetFullScreen(fullScreen);
  }

  @override
  void dispose() {
    if (_fullScreen) windowSetFullScreen(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isWindows) {
      return const Center(
        child: Text('The HDMI capture viewer is available on Windows.'),
      );
    }
    if (_error case final error?) {
      return Center(child: Text(error));
    }
    return NativeWebview(
      fileUrl: 'https://monitor-simulation.luma.example/index.html',
      monitorCaptureFolder: windowsAssetPath('assets/monitor_simulation'),
      background: context.luma.background,
      onCreated: (controller) => _controller = controller,
      onMessage: _onMessage,
      onError: (error) {
        if (mounted) setState(() => _error = error);
      },
    );
  }
}
