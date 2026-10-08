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

/// Space Colony is a self-contained HTML5/canvas game (bundled as
/// `assets/space_colony/index.html`) rather than a native Dart rewrite, so it
/// runs inside an embedded WebView. The game keeps its own save state in the
/// WebView's local storage via its in-page Save/Load buttons.
class SpaceColonyPage extends StatefulWidget {
  const SpaceColonyPage({super.key});

  @override
  State<SpaceColonyPage> createState() => _SpaceColonyPageState();
}

class _SpaceColonyPageState extends State<SpaceColonyPage> {
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
    final strings = sceneKeyStrings(t, 'space_colony');
    final sourceStrings = sceneSourceStrings(t, 'space_colony');
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
          subtitle: t.spaceColonyLinuxSubtitle,
        ),
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: Platform.isWindows
              ? WindowsWebview(
                  fileUrl: Uri.file(
                    windowsAssetPath('assets/space_colony/index.html'),
                  ).toString(),
                  onController: (controller) => _windowsController = controller,
                  onLoaded: _loaded,
                )
              : InAppWebView(
                  initialFile: 'assets/space_colony/index.html',
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
