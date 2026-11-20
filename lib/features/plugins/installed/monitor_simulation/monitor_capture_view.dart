import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/window_controls.dart';
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

  /// The page goes full screen inside WebView2, which the runner stretches
  /// over the whole window; this takes the window itself full screen too.
  void _onMessage(String message) {
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
      background: const Color(0xFF111821),
      onMessage: _onMessage,
      onError: (error) {
        if (mounted) setState(() => _error = error);
      },
    );
  }
}
