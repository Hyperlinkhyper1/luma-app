import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../_shared/native_webview.dart';
import '../_shared/windows_webview.dart' show windowsAssetPath;

/// Bundled interactive Crossplane V8 engine study.
class EngineStudyPage extends StatefulWidget {
  const EngineStudyPage({super.key});

  @override
  State<EngineStudyPage> createState() => _EngineStudyPageState();
}

class _EngineStudyPageState extends State<EngineStudyPage> {
  bool _loading = true;

  void _loaded() {
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isLinux) {
      return const Center(
        child: Text(
          'The interactive engine study is available on Windows and Android.',
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Platform.isWindows
              ? NativeWebview(
                  fileUrl: Uri.file(
                    windowsAssetPath('assets/engine_study/index.html'),
                  ).toString(),
                  onMessage: (_) {},
                )
              : InAppWebView(
                  initialFile: 'assets/engine_study/index.html',
                  initialSettings: InAppWebViewSettings(
                    supportZoom: false,
                    disableHorizontalScroll: true,
                    disableVerticalScroll: true,
                  ),
                  onLoadStop: (_, __) => _loaded(),
                ),
        ),
        if (!Platform.isWindows && _loading)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
