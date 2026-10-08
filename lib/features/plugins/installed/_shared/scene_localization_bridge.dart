import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:webview_windows/webview_windows.dart';

import 'native_webview.dart';

/// Pushes the selected app language into an embedded HTML scene.
///
/// The page includes `luma_scene_i18n.js`; callers send its keyed string map
/// after load and whenever Flutter rebuilds for a settings locale change.
class SceneLocalizationBridge {
  const SceneLocalizationBridge._();

  static Map<String, Object?> payload({
    required String language,
    required Map<String, String> strings,
    Map<String, String> sourceStrings = const {},
  }) => {
    'type': 'luma-locale',
    'language': language,
    'strings': strings,
    'sourceStrings': sourceStrings,
  };

  static Future<void> sendWindows(
    WebviewController? controller, {
    required String language,
    required Map<String, String> strings,
    Map<String, String> sourceStrings = const {},
  }) async {
    if (controller == null) return;
    await controller.postWebMessage(jsonEncode(payload(
      language: language,
      strings: strings,
      sourceStrings: sourceStrings,
    )));
  }

  static Future<void> sendNative(
    NativeWebviewController? controller, {
    required String language,
    required Map<String, String> strings,
    Map<String, String> sourceStrings = const {},
  }) async {
    if (controller == null) return;
    await controller.post(jsonEncode(payload(
      language: language,
      strings: strings,
      sourceStrings: sourceStrings,
    )));
  }

  static Future<void> sendAndroid(
    InAppWebViewController? controller, {
    required String language,
    required Map<String, String> strings,
    Map<String, String> sourceStrings = const {},
  }) async {
    if (controller == null) return;
    final encoded = jsonEncode(payload(
      language: language,
      strings: strings,
      sourceStrings: sourceStrings,
    ));
    await controller.evaluateJavascript(
      source: 'window.LumaSceneI18n?.set($encoded);',
    );
  }
}
