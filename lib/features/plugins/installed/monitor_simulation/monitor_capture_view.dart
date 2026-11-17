import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
      onMessage: (_) {},
      onError: (error) {
        if (mounted) setState(() => _error = error);
      },
    );
  }
}
