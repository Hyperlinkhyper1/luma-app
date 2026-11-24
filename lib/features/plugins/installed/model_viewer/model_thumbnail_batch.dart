import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../l10n/app_localizations.dart';
import '../_shared/windows_webview.dart';
import 'model_preview_server.dart';
import 'model_viewer_repository.dart';

/// Renders catalogue thumbnails for [models] in a hidden webview, one model
/// at a time, and hands each image (or null when it could not be drawn) to
/// [onThumbnail]. The batch is fixed when the widget first starts: the page
/// gives it a new key whenever the set of models it wants changes.
class ModelThumbnailBatch extends StatefulWidget {
  const ModelThumbnailBatch({
    super.key,
    required this.catalogue,
    required this.models,
    required this.onThumbnail,
  });

  final ModelCatalogue catalogue;
  final List<RepositoryModel> models;
  final void Function(RepositoryModel model, Uint8List? image) onThumbnail;

  static bool get supported =>
      Platform.isWindows || Platform.isAndroid || Platform.isIOS;

  @override
  State<ModelThumbnailBatch> createState() => _ModelThumbnailBatchState();
}

class _ModelThumbnailBatchState extends State<ModelThumbnailBatch> {
  ModelPreviewServer? _server;
  bool _started = false;
  bool _disposed = false;
  final _delivered = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_start(L.of(context)));
  }

  Future<void> _start(L t) async {
    final models = List.of(widget.models);
    try {
      final server = await ModelPreviewServer.startThumbnails(
        widget.catalogue,
        models,
        t,
        _deliver,
      );
      if (_disposed) {
        await server.close();
        return;
      }
      setState(() => _server = server);
    } catch (_) {
      if (_disposed) return;
      for (final model in models) {
        _deliver(model, null);
      }
    }
  }

  void _deliver(RepositoryModel model, Uint8List? image) {
    if (_disposed || !_delivered.add(model.path)) return;
    widget.onThumbnail(model, image);
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_server?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = _server?.url.toString();
    if (url == null) return const SizedBox.shrink();
    // One pixel, laid out and painted so the engine starts, but too small to
    // see. It must not be Offstage: an unpainted WebView2 never starts up.
    // The viewer draws into its own fixed-size canvas, not the viewport.
    return SizedBox(
      width: 1,
      height: 1,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: ClipRect(
            child: Platform.isWindows
                ? WindowsWebview(fileUrl: url)
                : InAppWebView(
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
                  ),
          ),
        ),
      ),
    );
  }
}
