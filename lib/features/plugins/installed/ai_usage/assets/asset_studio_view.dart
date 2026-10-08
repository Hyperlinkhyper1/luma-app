import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../l10n/current_l.dart';
import '../../_shared/native_webview.dart';
import '../../_shared/scene_localization_bridge.dart';
import '../../_shared/scene_localizations.dart';
import 'asset_studio.dart';

/// Asks where to save [bytes] and writes them there. Returns the path, or
/// null if the user cancelled.
Future<String?> saveStudioFile(String name, Uint8List bytes) async {
  final dot = name.lastIndexOf('.');
  final path = await FilePicker.saveFile(
    dialogTitle: currentL.aiUsageAssetSaveDialogTitle(name),
    fileName: name,
    type: dot > 0 ? FileType.custom : FileType.any,
    allowedExtensions: dot > 0 ? [name.substring(dot + 1)] : null,
    bytes: bytes,
  );
  if (path == null) return null;
  // Android writes through the storage framework itself; on desktop the
  // plugin only picks the path, so the bytes are written here.
  if (!Platform.isAndroid) {
    final file = File(path);
    if (!await file.exists() || await file.length() != bytes.length) {
      await file.writeAsBytes(bytes, flush: true);
    }
  }
  return path;
}

/// The studio page for one model, hosted in a webview.
///
/// On Windows it is a real WebView2 window ([NativeWebview]) so the WebGL
/// preview runs at full frame rate; that window covers anything Flutter
/// draws, which is why every control lives inside the page and this widget
/// only relays the page's requests to save a file or copy text.
class AssetStudioView extends StatefulWidget {
  const AssetStudioView({super.key, required this.asset});

  final StudioAsset asset;

  @override
  State<AssetStudioView> createState() => _AssetStudioViewState();
}

class _AssetStudioViewState extends State<AssetStudioView> {
  NativeWebviewController? _windows;
  InAppWebViewController? _android;
  String? _html;
  String? _fileUrl;
  String? _error;
  String? _theme;
  String? _locale;

  static bool get _supported => Platform.isWindows || Platform.isAndroid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = L.of(context).localeName;
    final localeChanged = locale != _locale;
    _locale = locale;
    if (localeChanged && _html != null) _pushLocale();
    final theme = Theme.of(context).brightness == Brightness.dark
        ? 'dark'
        : 'light';
    if (theme == _theme) return;
    final first = _theme == null;
    _theme = theme;
    if (!_supported) return;
    if (first) {
      _prepare();
    } else {
      // The page repaints itself; it does not have to be rebuilt.
      _send({'type': 'theme', 'theme': theme});
      setState(() {});
    }
  }

  void _pushLocale() {
    final t = L.of(context);
    _send(SceneLocalizationBridge.payload(
      language: _locale ?? t.localeName,
      strings: {
        ...sceneKeyStrings(t, 'asset_studio'),
        ...sceneDynamicStrings(t, 'asset_studio'),
      },
      sourceStrings: sceneSourceStrings(t, 'asset_studio'),
    ));
  }

  void _send(Map<String, Object?> message) {
    final json = jsonEncode(message);
    unawaited(_windows?.post(json) ?? Future.value());
    unawaited(
      _android?.evaluateJavascript(source: 'window.studioReceive($json);') ??
          Future.value(),
    );
  }

  Future<void> _prepare() async {
    try {
      final html = await buildAssetStudioHtml(
        rootBundle,
        assetId: widget.asset.id,
        embed: true,
        theme: _theme ?? 'auto',
      );
      String? fileUrl;
      if (Platform.isWindows) {
        // WebView2 is handed a file rather than a 900 KB data string.
        final dir = Directory(
          '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}luma_asset_studio',
        );
        await dir.create(recursive: true);
        final file = File(
          '${dir.path}${Platform.pathSeparator}${widget.asset.htmlFileName}',
        );
        await file.writeAsString(html, flush: true);
        fileUrl = Uri.file(file.path).toString();
      }
      if (!mounted) return;
      setState(() {
        _html = html;
        _fileUrl = fileUrl;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = L.of(context).aiUsageAssetStudioPrepareFailed('$e'),
        );
      }
    }
  }

  Future<void> _receive(dynamic raw) async {
    try {
      final value = raw is String ? jsonDecode(raw) : raw;
      if (value is! Map) return;
      switch (value['type']) {
        case 'ready':
          _pushLocale();
          return;
        case 'save':
          final dataUrl = '${value['dataUrl'] ?? ''}';
          final comma = dataUrl.indexOf(',');
          if (comma < 0) return;
          await saveStudioFile(
            '${value['name'] ?? 'asset'}',
            base64Decode(dataUrl.substring(comma + 1)),
          );
        case 'copy':
          await Clipboard.setData(ClipboardData(text: '${value['text'] ?? ''}'));
      }
    } on FormatException {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    if (!_supported) {
      return LumaEmptyState(
        icon: Icons.view_in_ar_rounded,
        title: t.aiUsageAssetStudioUnsupported,
        subtitle: t.aiUsageAssetStudioUnsupportedHint,
      );
    }
    if (_error != null) {
      return LumaEmptyState(
        icon: Icons.warning_amber_rounded,
        title: t.aiUsageAssetStudioUnavailable,
        subtitle: _error,
      );
    }
    if (_html == null) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final dark = _theme == 'dark';
    if (Platform.isWindows) {
      return NativeWebview(
        fileUrl: _fileUrl!,
        background: dark ? const Color(0xFF171A16) : const Color(0xFFF8F9F6),
        onMessage: _receive,
        onCreated: (controller) {
          _windows = controller;
          _send({'type': 'theme', 'theme': _theme});
          _pushLocale();
        },
        onError: (message) {
          if (mounted) setState(() => _error = message);
        },
      );
    }
    return InAppWebView(
      initialData: InAppWebViewInitialData(
        data: _html!,
        baseUrl: WebUri('https://luma.local/asset-studio/'),
      ),
      initialSettings: InAppWebViewSettings(supportZoom: false),
      onWebViewCreated: (controller) {
        _android = controller;
        controller.addJavaScriptHandler(
          handlerName: 'studio',
          callback: (args) {
            if (args.isNotEmpty) _receive(args.first);
            return null;
          },
        );
      },
      onLoadStop: (_, __) => _pushLocale(),
    );
  }
}
