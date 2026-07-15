import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../app/widgets.dart';
import '../_shared/windows_webview.dart';

/// City Planner (MetroPlan) is a self-contained HTML5/canvas simulation
/// (bundled as `assets/city_planner/index.html`) rather than a native Dart
/// rewrite, so it runs inside an embedded WebView. The game autosaves its
/// state in the WebView's local storage.
class CityPlannerPage extends StatefulWidget {
  const CityPlannerPage({super.key});

  @override
  State<CityPlannerPage> createState() => _CityPlannerPageState();
}

class _CityPlannerPageState extends State<CityPlannerPage> {
  InAppWebViewController? _controller;
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    if (Platform.isLinux) {
      return const Center(
        child: LumaEmptyState(
          icon: Icons.videogame_asset_off_outlined,
          title: 'Not available on Linux',
          subtitle: 'City Planner requires an embedded WebView that is '
              'not yet supported on this platform.',
        ),
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: Platform.isWindows
              ? WindowsWebview(
                  fileUrl: Uri.file(
                    windowsAssetPath('assets/city_planner/index.html'),
                  ).toString(),
                  onLoaded: () {
                    if (mounted) setState(() => _loading = false);
                  },
                )
              : InAppWebView(
                  initialFile: 'assets/city_planner/index.html',
                  initialSettings: InAppWebViewSettings(
                    transparentBackground: true,
                    supportZoom: false,
                    disableHorizontalScroll: false,
                    disableVerticalScroll: false,
                  ),
                  onWebViewCreated: (controller) => _controller = controller,
                  onLoadStop: (controller, url) {
                    if (mounted) setState(() => _loading = false);
                  },
                ),
        ),
        if (_loading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
