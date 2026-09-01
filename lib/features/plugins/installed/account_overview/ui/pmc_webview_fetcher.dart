import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:webview_windows/webview_windows.dart' as win;

import '../../_shared/windows_webview.dart';
import '../pmc_extract.dart';

/// Runs an arbitrary script in the embedded page and returns its result.
typedef _JsExec = Future<Object?> Function(String script);

/// Fetches Planet Minecraft pages through an embedded browser engine.
///
/// PMC has no API and Cloudflare rejects every non-browser client — a Dart
/// HTTP GET with full browser headers still returns 403. A real engine is the
/// only thing that gets a page, so this mounts a one-pixel WebView, walks it
/// through the member's submission pages, and runs [pmcExtractorScript] on
/// each one.
///
/// It is a widget because both engines need to be in the tree to exist at
/// all; it registers its fetch function with the repository through
/// [onReady], so the repository can `await` a scrape like any other request
/// without knowing a browser was involved.
class PmcWebViewFetcher extends StatefulWidget {
  const PmcWebViewFetcher({
    super.key,
    required this.member,
    required this.onReady,
  });

  final String member;

  /// Called with a fetch function once the engine is up, and with null when
  /// this widget goes away.
  final void Function(PmcFetchFunction? fetch) onReady;

  /// True where an embedded engine exists at all. Linux has neither backend
  /// wired up in this app, so PMC says so rather than silently reporting no
  /// content.
  static bool get isSupported =>
      Platform.isWindows || Platform.isAndroid || Platform.isIOS ||
      Platform.isMacOS;

  @override
  State<PmcWebViewFetcher> createState() => _PmcWebViewFetcherState();
}

/// Loads a member's pages and returns each one parsed.
typedef PmcFetchFunction = Future<List<PmcPage>> Function(
  String member, {
  int maxPages,
});

class _PmcWebViewFetcherState extends State<PmcWebViewFetcher> {
  win.WebviewController? _windowsController;
  InAppWebViewController? _mobileController;

  /// Serialises scrapes: two refreshes sharing one browser would interleave
  /// navigations and read each other's pages.
  Future<void> _queue = Future.value();

  bool _registered = false;

  /// A blank page to sit on when idle, so no PMC request is in flight unless
  /// a refresh actually asked for one.
  static const _idleUrl = 'about:blank';

  @override
  void didUpdateWidget(PmcWebViewFetcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.member != widget.member) _register();
  }

  @override
  void dispose() {
    widget.onReady(null);
    super.dispose();
  }

  void _register() {
    if (_registered) return;
    _registered = true;
    // Handing the callback up during build would rebuild the parent
    // mid-frame; the repository only needs it before the next refresh.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady(_fetch);
    });
  }

  _JsExec? get _exec {
    final windows = _windowsController;
    if (windows != null) return (script) => windows.executeScript(script);
    final mobile = _mobileController;
    if (mobile != null) {
      return (script) => mobile.evaluateJavascript(source: script);
    }
    return null;
  }

  Future<void> _navigate(String url) async {
    final windows = _windowsController;
    if (windows != null) {
      await windows.loadUrl(url);
      return;
    }
    await _mobileController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(url)),
    );
  }

  Future<List<PmcPage>> _fetch(String member, {int maxPages = 4}) {
    // Chain onto the queue so concurrent callers wait rather than collide.
    final result = _queue.then((_) => _fetchPages(member, maxPages));
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<List<PmcPage>> _fetchPages(String member, int maxPages) async {
    final exec = _exec;
    if (exec == null) {
      throw StateError('The embedded browser is not ready yet.');
    }

    final pages = <PmcPage>[];
    for (final url in pmcPagesFor(member, maxPages: maxPages)) {
      await _navigate(url);
      final page = await _extractWhenReady(exec, member);
      if (page == null) {
        // A page that never resolved is the end of what can be trusted, not
        // a reason to throw away the pages that did.
        if (pages.isEmpty) {
          throw StateError(
            'Planet Minecraft did not finish loading. Cloudflare may be '
            'challenging this device.',
          );
        }
        break;
      }
      pages.add(page);
      if (!page.hasMore || page.projects.isEmpty) break;
    }

    // Park the engine so it is not sitting on a PMC page between refreshes.
    unawaited(_navigate(_idleUrl).catchError((_) {}));
    return pages;
  }

  /// Polls the page until it has resolved into something worth parsing.
  ///
  /// Polling rather than waiting on a load event on purpose: Cloudflare's
  /// interstitial *is* a completed navigation, and the real page arrives a
  /// second or two later without another one. Asking the document what it
  /// currently contains is the only reliable signal.
  Future<PmcPage?> _extractWhenReady(_JsExec exec, String member) async {
    final deadline = DateTime.now().add(const Duration(seconds: 25));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return null;
      try {
        final raw = await exec(pmcExtractorScript);
        final page = parsePmcPayload(raw?.toString(), memberName: member);
        if (page.blocked) continue;
        if (page.projects.isNotEmpty) return page;

        // A member with nothing published is legitimate, so an empty result
        // is accepted once the document itself has finished.
        final ready = await exec('document.readyState');
        if (ready?.toString().contains('complete') ?? false) return page;
      } catch (_) {
        // Scripts thrown at a page mid-navigation fail; keep polling.
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!PmcWebViewFetcher.isSupported) return const SizedBox.shrink();

    // One pixel, laid out and painted so the engine initialises, but far too
    // small to see. It must not be Offstage: an unpainted WebView2 never
    // starts up.
    return SizedBox(
      width: 1,
      height: 1,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: ClipRect(
            child: Platform.isWindows
                ? WindowsWebview(
                    fileUrl: _idleUrl,
                    onController: (controller) {
                      _windowsController = controller;
                      _register();
                    },
                  )
                : InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(_idleUrl)),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      transparentBackground: true,
                    ),
                    onWebViewCreated: (controller) {
                      _mobileController = controller;
                      _register();
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
