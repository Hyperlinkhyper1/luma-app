import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/wiki/wiki_site.dart';
import 'package:luma/features/plugins/installed/wiki/wiki_site_server.dart';

Uint8List _zip(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.add(ArchiveFile.string(entry.key, entry.value));
  }
  return ZipEncoder().encodeBytes(archive);
}

WikiSite _site() => WikiSite.fromZipBytes(
  _zip({
    'index.html': '<!doctype html><html><head><title>Home</title></head>'
        '<body>home</body></html>',
    'wiki/index.html': '<html><head lang="en"><title>Wiki</title></head></html>',
    'wiki/mods/index.html': '<html><head></head><body>mods</body></html>',
    'about.html': '<html><head></head><body>about</body></html>',
    '404.html': '<html><head></head><body>lost</body></html>',
    '_astro/page.js': 'console.log(1)',
    'models/fish/cod.json': '{"name":"cod"}',
    WikiSite.manifestName: jsonEncode({
      'origin': 'https://wiki.luma-app.cc',
      'mirrored': '2026-11-17T12:00:00.000Z',
      'pages': 5,
    }),
  }),
);

String _text(WikiSiteResponse response) => utf8.decode(response.body);

void main() {
  group('WikiSite', () {
    test('reads the mirror manifest and hides it from requests', () {
      final site = _site();
      expect(site.mirroredAt, DateTime.utc(2026, 11, 17, 12));
      expect(site.pageCount, 5);
      expect(site.resolve('/${WikiSite.manifestName}').status, 404);
    });

    test('serves directory pages the way the static host does', () {
      final site = _site();
      expect(_text(site.resolve('/')), contains('home'));
      expect(_text(site.resolve('/wiki/mods/')), contains('mods'));
      final redirect = site.resolve('/wiki/mods');
      expect(redirect.status, 301);
      expect(redirect.location, '/wiki/mods/');
      expect(_text(site.resolve('/about')), contains('about'));
    });

    test('answers missing pages with the site 404 page', () {
      final response = _site().resolve('/wiki/sawmill/');
      expect(response.status, 404);
      expect(_text(response), contains('lost'));
    });

    test('refuses paths that climb out of the copy', () {
      final site = _site();
      for (final path in [
        '/../index.html',
        '/wiki/../index.html',
        '/./index.html',
        r'/wiki\..\index.html',
        'index.html',
      ]) {
        expect(site.resolve(path).status, 404, reason: path);
      }
    });

    test('injects the link bridge into every page head', () {
      final site = _site();
      const tag = '<script src="${WikiSite.bridgePath}"></script>';
      expect(_text(site.resolve('/')), contains('<head>$tag<title>'));
      expect(_text(site.resolve('/wiki/')), contains('<head lang="en">$tag'));
      expect(_text(site.resolve('/_astro/page.js')), isNot(contains(tag)));
      expect(_text(site.resolve(WikiSite.bridgePath)), contains('postMessage'));
    });

    test('labels files with their content types', () {
      final site = _site();
      expect(site.resolve('/').contentType, startsWith('text/html'));
      expect(
        site.resolve('/_astro/page.js').contentType,
        startsWith('text/javascript'),
      );
      expect(
        site.resolve('/models/fish/cod.json').contentType,
        startsWith('application/json'),
      );
      expect(WikiSite.contentTypeFor('logo.jpeg'), 'image/jpeg');
      expect(WikiSite.contentTypeFor('font.woff2'), 'font/woff2');
    });
  });

  group('WikiSiteServer', () {
    late WikiSiteServer server;

    setUp(() async {
      server = await WikiSiteServer.start(_site(), port: 0);
    });

    tearDown(() => server.close());

    Future<HttpClientResponse> request(
      String path, {
      String method = 'GET',
      String? host,
    }) async {
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final req = await client.openUrl(method, server.origin.resolve(path));
      req.followRedirects = false;
      if (host != null) req.headers.host = host;
      return req.close();
    }

    test('listens on loopback only', () {
      expect(server.origin.host, '127.0.0.1');
      expect(server.port, greaterThan(0));
    });

    test('serves pages behind a policy that keeps requests local', () async {
      final response = await request('/');
      expect(response.statusCode, 200);
      final csp = response.headers.value('content-security-policy')!;
      expect(csp, contains("default-src 'self'"));
      expect(csp, contains("connect-src 'self' data: blob:"));
      expect(csp, isNot(contains('luma-app.cc')));
      expect(csp, isNot(contains('https:')));
      final body = await utf8.decodeStream(response);
      expect(body, contains(WikiSite.bridgePath));
    });

    test('redirects directory pages to their trailing slash', () async {
      final response = await request('/wiki/mods?q=1');
      expect(response.statusCode, 301);
      expect(response.headers.value('location'), '/wiki/mods/?q=1');
      await response.drain<void>();
    });

    test('refuses other hosts and methods', () async {
      final rebound = await request('/', host: 'evil.example');
      expect(rebound.statusCode, 403);
      await rebound.drain<void>();
      final post = await request('/', method: 'POST');
      expect(post.statusCode, 405);
      await post.drain<void>();
    });

    test('maps a local page to the same page on the live site', () {
      expect(
        WikiSiteServer.liveUrlFor(
          server.origin.resolve('/wiki/mods/#install'),
        ).toString(),
        'https://wiki.luma-app.cc/wiki/mods/#install',
      );
      expect(
        WikiSiteServer.liveUrlFor(null).toString(),
        'https://wiki.luma-app.cc',
      );
    });
  });

  test('the bundled copy has the whole site and stays self-contained', () {
    final file = File(WikiSite.assetPath);
    expect(file.existsSync(), isTrue, reason: 'run tool/wiki_mirror');
    final site = WikiSite.fromZipBytes(file.readAsBytesSync());
    expect(site.mirroredAt, isNotNull);
    expect(site.pageCount, greaterThan(100));
    for (final page in [
      'index.html',
      'wiki/index.html',
      'blog/index.html',
      'luma/index.html',
      'roblox/fishing-waters/fish/index.html',
    ]) {
      expect(site.contains(page), isTrue, reason: page);
    }
    final fishPage = _text(site.resolve('/roblox/fishing-waters/fish/cod/'));
    final slug = RegExp(r'data-fish-slug="([a-z0-9-]+)"').firstMatch(fishPage);
    expect(slug, isNotNull);
    expect(site.contains('models/fish/${slug![1]}.json'), isTrue);
    for (final script in RegExp(
      r'<script[^>]+src="(/[^"]+)"',
    ).allMatches(fishPage)) {
      expect(site.resolve(script[1]!).status, 200, reason: script[1]);
    }
    expect(_text(site.resolve('/')), isNot(contains('https://wiki.luma-app.cc/')));
  });
}
