import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// The bundled copy of the wiki website (wiki.luma-app.cc), read straight out
/// of `assets/wiki_site/site.zip`. `tool/wiki_mirror/mirror.mjs` builds that
/// zip from the live site; this class answers requests for it the way the
/// real web server does, so the pages, their scripts and the fish models all
/// work with no server behind them.
class WikiSite {
  WikiSite._(this._files, this.mirroredAt, this.pageCount);

  factory WikiSite.fromZipBytes(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = <String, ArchiveFile>{
      for (final file in archive.files)
        if (file.isFile) file.name: file,
    };
    DateTime? mirroredAt;
    var pageCount = 0;
    final manifest = files.remove(manifestName);
    if (manifest != null) {
      try {
        final decoded = jsonDecode(utf8.decode(_read(manifest)));
        if (decoded is Map) {
          mirroredAt = DateTime.tryParse('${decoded['mirrored']}');
          if (decoded['pages'] is int) pageCount = decoded['pages'] as int;
        }
      } on FormatException {
        mirroredAt = null;
      }
    }
    if (pageCount == 0) {
      pageCount = files.keys.where((name) => name.endsWith('.html')).length;
    }
    return WikiSite._(files, mirroredAt, pageCount);
  }

  static const assetPath = 'assets/wiki_site/site.zip';
  static const manifestName = '_luma_mirror.json';
  static const bridgePath = '/__luma/bridge.js';

  /// Where the copy came from; external links to it are rewritten to local
  /// ones by the mirror tool, and "open the live site" goes here.
  static const liveOrigin = 'https://wiki.luma-app.cc';

  final Map<String, ArchiveFile> _files;

  /// When the copy was taken, or null for a zip without a manifest.
  final DateTime? mirroredAt;
  final int pageCount;

  bool contains(String name) => _files.containsKey(name);

  /// Answers a GET for [path], the decoded URL path (`/wiki/simply-cozy`).
  WikiSiteResponse resolve(String path) {
    if (path == bridgePath) {
      return WikiSiteResponse(
        200,
        Uint8List.fromList(utf8.encode(bridgeScript)),
        'text/javascript; charset=utf-8',
      );
    }
    if (!path.startsWith('/') ||
        path.contains('\\') ||
        path.contains('\u0000') ||
        path.split('/').any((segment) => segment == '..' || segment == '.')) {
      return _notFound();
    }
    var key = path.substring(1);
    if (key.isEmpty || key.endsWith('/')) key = '${key}index.html';
    if (_files[key] case final file?) return _serve(key, file);
    if (_files.containsKey('$key/index.html')) {
      return WikiSiteResponse.redirect('$path/');
    }
    if (_files['$key.html'] case final file?) return _serve('$key.html', file);
    return _notFound();
  }

  WikiSiteResponse _serve(String name, ArchiveFile file, {int status = 200}) {
    var bytes = _read(file);
    final type = contentTypeFor(name);
    if (type.startsWith('text/html')) {
      bytes = Uint8List.fromList(
        utf8.encode(injectBridge(utf8.decode(bytes, allowMalformed: true))),
      );
    }
    return WikiSiteResponse(status, bytes, type);
  }

  WikiSiteResponse _notFound() {
    if (_files['404.html'] case final file?) {
      return _serve('404.html', file, status: 404);
    }
    return WikiSiteResponse(
      404,
      Uint8List.fromList(utf8.encode('Not found')),
      'text/plain; charset=utf-8',
    );
  }

  /// Decompresses without caching, so browsing every fish model doesn't keep
  /// all of them inflated in memory.
  static Uint8List _read(ArchiveFile file) {
    final output = OutputMemoryStream();
    file.writeContent(output);
    return output.getBytes();
  }

  /// Loads [bridgePath] first thing in every page.
  static String injectBridge(String html) {
    const tag = '<script src="$bridgePath"></script>';
    final head = RegExp(r'<head(\s[^>]*)?>', caseSensitive: false);
    final match = head.firstMatch(html);
    if (match == null) return '$tag$html';
    return html.replaceRange(match.end, match.end, tag);
  }

  /// Sends clicks on links that leave the copy to the app, which opens them
  /// in the system browser instead of navigating the embedded page away.
  /// Only WebView2 has `chrome.webview`; Android catches the same
  /// navigations in `shouldOverrideUrlLoading`.
  static const bridgeScript = r'''
(() => {
  const host = window.chrome && window.chrome.webview;
  if (!host) return;
  document.addEventListener('click', (event) => {
    if (event.defaultPrevented || event.button !== 0) return;
    const link = event.target instanceof Element ? event.target.closest('a[href]') : null;
    if (!link) return;
    let url;
    try { url = new URL(link.getAttribute('href'), location.href); } catch (_) { return; }
    if (url.origin === location.origin) return;
    if (!/^(https?|mailto):$/.test(url.protocol)) return;
    event.preventDefault();
    event.stopPropagation();
    host.postMessage(JSON.stringify({ type: 'open', url: url.href }));
  }, true);
})();
''';

  static String contentTypeFor(String name) {
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    return switch (ext) {
      'html' || 'htm' => 'text/html; charset=utf-8',
      'css' => 'text/css; charset=utf-8',
      'js' || 'mjs' => 'text/javascript; charset=utf-8',
      'json' => 'application/json; charset=utf-8',
      'webmanifest' => 'application/manifest+json; charset=utf-8',
      'xml' => 'application/xml; charset=utf-8',
      'txt' => 'text/plain; charset=utf-8',
      'svg' => 'image/svg+xml',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'avif' => 'image/avif',
      'ico' => 'image/x-icon',
      'woff2' => 'font/woff2',
      'woff' => 'font/woff',
      'ttf' => 'font/ttf',
      'otf' => 'font/otf',
      'mp3' => 'audio/mpeg',
      'ogg' => 'audio/ogg',
      'wav' => 'audio/wav',
      'mp4' => 'video/mp4',
      'webm' => 'video/webm',
      'glb' => 'model/gltf-binary',
      'gltf' => 'model/gltf+json',
      _ => 'application/octet-stream',
    };
  }
}

class WikiSiteResponse {
  const WikiSiteResponse(this.status, this.body, this.contentType)
    : location = null;

  WikiSiteResponse.redirect(String this.location)
    : status = 301,
      body = Uint8List(0),
      contentType = 'text/plain; charset=utf-8';

  final int status;
  final Uint8List body;
  final String contentType;
  final String? location;
}
