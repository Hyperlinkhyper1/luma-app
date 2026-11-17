import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import '../_shared/windows_webview.dart';
import 'wiki_site.dart';
import 'wiki_site_server.dart';

/// The wiki website, offline. The copy bundled in `assets/wiki_site/` is
/// served from a loopback [WikiSiteServer] into an embedded WebView, so every
/// page, the search and the fish models work with the wiki's server down.
class WikiPage extends StatefulWidget {
  const WikiPage({super.key});

  @override
  State<WikiPage> createState() => _WikiPageState();
}

class _WikiPageState extends State<WikiPage> {
  WikiSiteServer? _server;
  Object? _error;
  bool _notBundled = false;
  bool _loading = true;

  WebviewController? _windows;
  InAppWebViewController? _android;
  StreamSubscription<dynamic>? _messages;
  StreamSubscription<HistoryChanged>? _history;
  StreamSubscription<String>? _urls;
  bool _canGoBack = false;
  bool _canGoForward = false;
  Uri? _current;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      final data = await rootBundle.load(WikiSite.assetPath);
      final site = WikiSite.fromZipBytes(data.buffer.asUint8List());
      final server = await WikiSiteServer.start(site);
      if (!mounted) {
        unawaited(server.close());
        return;
      }
      setState(() => _server = server);
    } on FlutterError {
      if (mounted) setState(() => _notBundled = true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    unawaited(_messages?.cancel());
    unawaited(_history?.cancel());
    unawaited(_urls?.cancel());
    _android?.dispose();
    unawaited(_server?.close());
    super.dispose();
  }

  bool _isLocal(Uri? uri) =>
      uri != null && uri.host == '127.0.0.1' && uri.port == _server?.port;

  Future<void> _openExternally(Uri uri) async {
    if (!{'http', 'https', 'mailto'}.contains(uri.scheme)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _attachWindows(WebviewController controller) {
    _windows = controller;
    _messages = controller.webMessage.listen((message) {
      final decoded = message is String ? _tryDecode(message) : message;
      if (decoded is Map && decoded['type'] == 'open') {
        final uri = Uri.tryParse('${decoded['url']}');
        if (uri != null) unawaited(_openExternally(uri));
      }
    });
    _history = controller.historyChanged.listen((history) {
      if (!mounted) return;
      setState(() {
        _canGoBack = history.canGoBack;
        _canGoForward = history.canGoForward;
      });
    });
    _urls = controller.url.listen((url) {
      final uri = Uri.tryParse(url);
      if (uri == null || const {'about', 'data', 'blob'}.contains(uri.scheme)) {
        return;
      }
      if (_isLocal(uri)) {
        _current = uri;
        return;
      }
      unawaited(controller.goBack());
      unawaited(_openExternally(uri));
    });
  }

  static Object? _tryDecode(String message) {
    try {
      return jsonDecode(message);
    } on FormatException {
      return null;
    }
  }

  Future<void> _refreshAndroidHistory() async {
    final controller = _android;
    if (controller == null) return;
    final back = await controller.canGoBack();
    final forward = await controller.canGoForward();
    if (!mounted) return;
    setState(() {
      _canGoBack = back;
      _canGoForward = forward;
    });
  }

  void _back() => Platform.isWindows ? _windows?.goBack() : _android?.goBack();

  void _forward() =>
      Platform.isWindows ? _windows?.goForward() : _android?.goForward();

  void _reload() => Platform.isWindows ? _windows?.reload() : _android?.reload();

  void _home() {
    final origin = _server?.origin;
    if (origin == null) return;
    final home = '$origin/';
    if (Platform.isWindows) {
      unawaited(_windows?.loadUrl(home));
    } else {
      unawaited(_android?.loadUrl(urlRequest: URLRequest(url: WebUri(home))));
    }
  }

  void _loaded() {
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    if (_notBundled) {
      return LumaEmptyState(
        icon: Icons.menu_book_rounded,
        title: t.wikiNotBundledTitle,
        subtitle: t.wikiNotBundledSubtitle,
      );
    }
    if (_error != null) {
      return LumaEmptyState(
        icon: Icons.error_outline_rounded,
        title: t.wikiStartFailed,
        subtitle: '$_error',
        action: FilledButton(
          onPressed: () {
            setState(() => _error = null);
            unawaited(_start());
          },
          child: Text(t.commonRetry),
        ),
      );
    }
    final server = _server;
    if (server == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (Platform.isLinux) return _LinuxWiki(server: server);
    final home = '${server.origin}/';
    return Column(
      children: [
        _WikiToolbar(
          site: server.site,
          canGoBack: _canGoBack,
          canGoForward: _canGoForward,
          onBack: _back,
          onForward: _forward,
          onHome: _home,
          onReload: _reload,
          onOpenLive: () =>
              unawaited(_openExternally(WikiSiteServer.liveUrlFor(_current))),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Platform.isWindows
                    ? WindowsWebview(
                        fileUrl: home,
                        onController: _attachWindows,
                        onLoaded: _loaded,
                      )
                    : InAppWebView(
                        initialUrlRequest: URLRequest(url: WebUri(home)),
                        initialSettings: InAppWebViewSettings(
                          useShouldOverrideUrlLoading: true,
                          supportMultipleWindows: false,
                          transparentBackground: true,
                        ),
                        onWebViewCreated: (controller) => _android = controller,
                        shouldOverrideUrlLoading: (controller, action) async {
                          final uri = action.request.url;
                          if (uri == null ||
                              !action.isForMainFrame ||
                              _isLocal(uri)) {
                            return NavigationActionPolicy.ALLOW;
                          }
                          unawaited(_openExternally(uri));
                          return NavigationActionPolicy.CANCEL;
                        },
                        onUpdateVisitedHistory: (controller, url, _) {
                          if (_isLocal(url)) _current = url;
                          unawaited(_refreshAndroidHistory());
                        },
                        onLoadStop: (controller, url) => _loaded(),
                      ),
              ),
              if (_loading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ],
    );
  }
}

class _WikiToolbar extends StatelessWidget {
  const _WikiToolbar({
    required this.site,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onHome,
    required this.onReload,
    required this.onOpenLive,
  });

  final WikiSite site;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onHome;
  final VoidCallback onReload;
  final VoidCallback onOpenLive;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final mirrored = site.mirroredAt;
    final date = mirrored == null
        ? null
        : MaterialLocalizations.of(context).formatMediumDate(mirrored.toLocal());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border(bottom: BorderSide(color: luma.border)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: t.commonBack,
            onPressed: canGoBack ? onBack : null,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          IconButton(
            tooltip: t.wikiForward,
            onPressed: canGoForward ? onForward : null,
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
          IconButton(
            tooltip: t.wikiHome,
            onPressed: onHome,
            icon: const Icon(Icons.home_outlined),
          ),
          IconButton(
            tooltip: t.commonRefresh,
            onPressed: onReload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Icon(Icons.cloud_off_rounded, size: 16, color: luma.textMuted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    date == null
                        ? t.wikiOfflineCopy
                        : t.wikiOfflineCopyFrom(date, site.pageCount),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: luma.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: t.wikiOpenLive,
            onPressed: onOpenLive,
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
    );
  }
}

/// Linux has no embedded WebView yet, so the same offline copy opens in the
/// system browser instead; the loopback server lives as long as this page.
class _LinuxWiki extends StatelessWidget {
  const _LinuxWiki({required this.server});

  final WikiSiteServer server;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return LumaEmptyState(
      icon: Icons.menu_book_rounded,
      title: t.wikiLinuxTitle,
      subtitle: t.wikiLinuxSubtitle,
      action: FilledButton.icon(
        onPressed: () => unawaited(
          launchUrl(
            Uri.parse('${server.origin}/'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        icon: const Icon(Icons.open_in_browser_rounded),
        label: Text(t.wikiLinuxOpen),
      ),
    );
  }
}
