import 'dart:async';
import 'dart:io';

import 'wiki_site.dart';

/// Serves a [WikiSite] on the loopback interface for the embedded WebView.
///
/// The pages use root-relative links (`/wiki/mods`, `/_astro/…`), which a
/// `file://` URL can't resolve, so they get a real origin instead. The
/// Content-Security-Policy keeps every request on that origin: the copy
/// never reaches wiki.luma-app.cc, the sync server's leaderboard endpoint or
/// anything else, whatever the mirrored scripts try.
class WikiSiteServer {
  WikiSiteServer._(this._server, this.site) {
    _subscription = _server.listen(_handle);
  }

  /// Tried first so the origin, and with it the page's own local storage
  /// (theme, search history), stays the same from one launch to the next.
  static const preferredPort = 47913;

  static Future<WikiSiteServer> start(
    WikiSite site, {
    int port = preferredPort,
  }) async {
    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    } on SocketException {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    }
    return WikiSiteServer._(server, site);
  }

  static const contentSecurityPolicy =
      "default-src 'self'; "
      "script-src 'self' 'unsafe-inline' 'unsafe-eval' blob:; "
      "style-src 'self' 'unsafe-inline'; "
      "img-src 'self' data: blob:; "
      "font-src 'self' data:; "
      "media-src 'self' data: blob:; "
      "connect-src 'self' data: blob:; "
      "worker-src 'self' blob:; "
      "frame-src 'self'; "
      "form-action 'self'; "
      "base-uri 'self'; "
      "object-src 'none'";

  final HttpServer _server;
  final WikiSite site;
  late final StreamSubscription<HttpRequest> _subscription;

  int get port => _server.port;
  Uri get origin => Uri.parse('http://127.0.0.1:$port');

  /// The live-site address of a page served here, for "open the live site".
  static Uri liveUrlFor(Uri? local) {
    final live = Uri.parse(WikiSite.liveOrigin);
    if (local == null || local.host != '127.0.0.1') return live;
    return live.replace(
      path: local.path,
      query: local.hasQuery ? local.query : null,
      fragment: local.hasFragment ? local.fragment : null,
    );
  }

  Future<void> close() async {
    await _subscription.cancel();
    await _server.close(force: true);
  }

  void _handle(HttpRequest request) {
    final response = request.response;
    response.headers
      ..set('Content-Security-Policy', contentSecurityPolicy)
      ..set('X-Content-Type-Options', 'nosniff')
      ..set('Referrer-Policy', 'no-referrer')
      ..set('Cache-Control', 'no-cache');
    final host = request.headers.host;
    if (host != '127.0.0.1' && host != 'localhost') {
      response.statusCode = HttpStatus.forbidden;
      unawaited(response.close());
      return;
    }
    if (request.method != 'GET' && request.method != 'HEAD') {
      response.statusCode = HttpStatus.methodNotAllowed;
      unawaited(response.close());
      return;
    }
    String path;
    try {
      path = Uri.decodeComponent(request.uri.path);
    } on ArgumentError {
      path = '';
    }
    final result = site.resolve(path);
    response.statusCode = result.status;
    if (result.location case final location?) {
      final query = request.uri.hasQuery ? '?${request.uri.query}' : '';
      response.headers.set(HttpHeaders.locationHeader, '$location$query');
    }
    response.headers
      ..set(HttpHeaders.contentTypeHeader, result.contentType)
      ..contentLength = result.body.length;
    if (request.method == 'GET') response.add(result.body);
    unawaited(response.close().catchError((Object _) {}));
  }
}
