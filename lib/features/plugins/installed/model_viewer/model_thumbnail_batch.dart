import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../../../l10n/app_localizations.dart';
import '../_shared/windows_webview.dart';
import 'model_preview_server.dart';
import 'model_viewer_repository.dart';

class ModelThumbnailBatch extends StatefulWidget {
  const ModelThumbnailBatch({
    super.key,
    required this.catalogue,
    required this.models,
    required this.onThumbnail,
  });

  static bool get supported =>
      Platform.isWindows || Platform.isAndroid || Platform.isIOS;

  final ModelCatalogue catalogue;
  final List<RepositoryModel> models;
  final void Function(RepositoryModel, Uint8List?) onThumbnail;

  @override
  State<ModelThumbnailBatch> createState() => _ModelThumbnailBatchState();
}

class _ModelThumbnailBatchState extends State<ModelThumbnailBatch> {
  final _done = Completer<void>();
  late final Timer _debounce;

  @override
  void initState() {
    super.initState();
    _debounce = Timer(const Duration(milliseconds: 300), _render);
  }

  Future<void> _render() async {
    final models = widget.models;
    final catalogue = widget.catalogue;
    final t = L.of(context);
    final windows = Platform.isWindows ? WebviewController() : null;
    HeadlessInAppWebView? mobile;
    ModelPreviewServer? server;
    final timeout = Timer(const Duration(seconds: 45), _finish);
    try {
      if (windows != null) {
        await WindowsWebview.initializeController(windows);
        if (_done.isCompleted) return;
        await windows.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      }
      if (_done.isCompleted) return;
      var remaining = models.length;
      server = await ModelPreviewServer.startThumbnails(catalogue, models, t, (
        model,
        image,
      ) {
        if (_done.isCompleted) return;
        widget.onThumbnail(model, image);
        if (--remaining == 0) _finish();
      });
      if (_done.isCompleted) return;

      final url = server.url.toString();
      if (windows != null) {
        await windows.loadUrl(url);
      } else {
        mobile = HeadlessInAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(url)),
          initialSettings: InAppWebViewSettings(
            useShouldOverrideUrlLoading: true,
            supportMultipleWindows: false,
            allowFileAccess: false,
            allowContentAccess: false,
          ),
          shouldOverrideUrlLoading: (_, action) async =>
              action.request.url?.toString() == url
              ? NavigationActionPolicy.ALLOW
              : NavigationActionPolicy.CANCEL,
          onReceivedError: (_, request, _) {
            if (request.isForMainFrame == true) _finish();
          },
        );
        await mobile.run();
      }
      await _done.future;
    } catch (_) {
      // The catalog remains usable if the embedded renderer is unavailable.
    } finally {
      timeout.cancel();
      await server?.close();
      try {
        await windows?.dispose();
        await mobile?.dispose();
      } catch (_) {
        // Initialization can fail before the platform creates a webview.
      }
    }
  }

  void _finish() {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  void dispose() {
    _debounce.cancel();
    _finish();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
