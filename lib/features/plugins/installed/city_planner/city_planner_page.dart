import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../_shared/scene_localization_bridge.dart';
import '../_shared/scene_localizations.dart';
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
  WebviewController? _windowsController;
  bool _loading = true;
  String? _locale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).languageCode;
    if (_locale != locale) {
      _locale = locale;
      if (!_loading) unawaited(_pushLocale());
    }
  }

  Future<void> _pushLocale() async {
    final t = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final strings = {
      ...sceneKeyStrings(t, 'city_planner'),
      ...sceneDynamicStrings(t, 'city_planner'),
    };
    final sourceStrings = sceneSourceStrings(t, 'city_planner');
    if (Platform.isWindows) {
      await SceneLocalizationBridge.sendWindows(
        _windowsController,
        language: locale,
        strings: strings,
        sourceStrings: sourceStrings,
      );
    } else {
      await SceneLocalizationBridge.sendAndroid(
        _controller,
        language: locale,
        strings: strings,
        sourceStrings: sourceStrings,
      );
    }
  }

  void _loaded() {
    unawaited(_pushLocale());
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    if (Platform.isLinux) {
      return Center(
        child: LumaEmptyState(
          icon: Icons.videogame_asset_off_outlined,
          title: t.cityPlannerLinuxTitle,
          subtitle: t.cityPlannerLinuxSubtitle,
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
                  onController: (controller) => _windowsController = controller,
                  onLoaded: _loaded,
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
                  onLoadStop: (controller, url) => _loaded(),
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
