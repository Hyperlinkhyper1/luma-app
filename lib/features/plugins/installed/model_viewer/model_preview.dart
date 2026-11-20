import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../_shared/windows_webview.dart';
import 'model_preview_server.dart';
import 'model_viewer_repository.dart';

class ModelPreview extends StatefulWidget {
  const ModelPreview({super.key, required this.catalogue, required this.model});

  final ModelCatalogue catalogue;
  final RepositoryModel model;

  @override
  State<ModelPreview> createState() => _ModelPreviewState();
}

class _ModelPreviewState extends State<ModelPreview> {
  ModelPreviewServer? _server;
  String? _error;
  bool _starting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_server == null && !_starting && _error == null) unawaited(_start());
  }

  Future<void> _start() async {
    _starting = true;
    final t = L.of(context);
    try {
      final previous = _server;
      _server = null;
      await previous?.close();
      if (!mounted) return;
      final server = await ModelPreviewServer.start(
        widget.catalogue,
        widget.model,
        t,
      );
      if (!mounted) {
        await server.close();
        return;
      }
      setState(() => _server = server);
    } catch (_) {
      if (mounted) setState(() => _error = t.modelViewerPreviewFailed);
    } finally {
      _starting = false;
    }
  }

  Future<void> _openBrowser(Uri url) async {
    final t = L.of(context);
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.modelViewerOpenBrowserFailed)));
    }
  }

  @override
  void dispose() {
    unawaited(_server?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    if (_error case final error?) {
      return LumaEmptyState(
        icon: Icons.error_outline_rounded,
        title: error,
        action: OutlinedButton(
          onPressed: () {
            setState(() => _error = null);
            unawaited(_start());
          },
          child: Text(t.commonRetry),
        ),
      );
    }
    final url = _server?.url;
    if (url == null) return const Center(child: CircularProgressIndicator());
    if (Platform.isWindows) {
      return WindowsWebview(fileUrl: url.toString());
    }
    if (Platform.isAndroid || Platform.isIOS) {
      return InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url.toString())),
        initialSettings: InAppWebViewSettings(
          useShouldOverrideUrlLoading: true,
          supportMultipleWindows: false,
          allowFileAccess: false,
          allowContentAccess: false,
        ),
        shouldOverrideUrlLoading: (_, action) async =>
            action.request.url?.toString() == url.toString()
            ? NavigationActionPolicy.ALLOW
            : NavigationActionPolicy.CANCEL,
        onReceivedError: (_, request, _) {
          if (request.isForMainFrame == true && mounted) {
            setState(() => _error = t.modelViewerPreviewFailed);
          }
        },
      );
    }
    return LumaEmptyState(
      icon: Icons.view_in_ar_rounded,
      title: widget.model.name,
      action: FilledButton.icon(
        icon: const Icon(Icons.open_in_new_rounded),
        onPressed: () => _openBrowser(url),
        label: Text(t.modelViewerOpenBrowser),
      ),
    );
  }
}
