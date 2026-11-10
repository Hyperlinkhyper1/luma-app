import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/media_downloader/yt_dlp_manager.dart';
import 'package:luma/security/guarded_download.dart';

/// Everything the app downloads and then runs or unpacks (yt-dlp, ffmpeg,
/// the Forge installer, the Java runtime) goes through [guardedDownload],
/// and every link handed to yt-dlp goes through [normalizeMediaUrl].
void main() {
  Matcher refusedAs(GuardedDownloadFailure failure) => throwsA(
        isA<GuardedDownloadException>()
            .having((e) => e.failure, 'failure', failure),
      );

  http.StreamedResponse body(
    List<int> bytes, {
    int? announced,
    int status = 200,
    Map<String, String> headers = const {},
  }) =>
      http.StreamedResponse(
        Stream.value(bytes),
        status,
        contentLength: announced ?? bytes.length,
        headers: headers,
      );

  group('guardedDownload', () {
    test('returns the body of an https download', () async {
      final seen = <int>[];
      final bytes = await guardedDownload(
        Uri.parse('https://example.com/tool.exe'),
        maxBytes: 16,
        client: MockClient.streaming((request, _) async => body([1, 2, 3])),
        onProgress: (received, total) => seen.add(received),
      );
      expect(bytes, Uint8List.fromList([1, 2, 3]));
      expect(seen, [3]);
    });

    test('refuses a plain http link without sending anything', () async {
      var requests = 0;
      await expectLater(
        guardedDownload(
          Uri.parse('http://example.com/tool.exe'),
          maxBytes: 16,
          client: MockClient.streaming((request, _) async {
            requests++;
            return body([1]);
          }),
        ),
        refusedAs(GuardedDownloadFailure.insecure),
      );
      expect(requests, 0);
    });

    test('refuses a link that carries credentials', () async {
      await expectLater(
        guardedDownload(
          Uri.parse('https://user:pw@example.com/tool.exe'),
          maxBytes: 16,
          client: MockClient.streaming((request, _) async => body([1])),
        ),
        refusedAs(GuardedDownloadFailure.insecure),
      );
    });

    test('follows an https redirect, never one down to http', () async {
      final visited = <String>[];
      http.Client redirecting(String target) =>
          MockClient.streaming((request, _) async {
            visited.add('${request.url}');
            expect(request.followRedirects, isFalse);
            if (request.url.path == '/latest') {
              return body(const [],
                  status: 302, headers: {'location': target});
            }
            return body([7, 7]);
          });

      final bytes = await guardedDownload(
        Uri.parse('https://example.com/latest'),
        maxBytes: 16,
        client: redirecting('https://cdn.example.com/v1/tool.exe'),
      );
      expect(bytes, [7, 7]);
      expect(visited, [
        'https://example.com/latest',
        'https://cdn.example.com/v1/tool.exe',
      ]);

      visited.clear();
      await expectLater(
        guardedDownload(
          Uri.parse('https://example.com/latest'),
          maxBytes: 16,
          client: redirecting('http://cdn.example.com/v1/tool.exe'),
        ),
        refusedAs(GuardedDownloadFailure.insecure),
      );
      expect(visited, ['https://example.com/latest']);
    });

    test('gives up on a redirect loop', () async {
      await expectLater(
        guardedDownload(
          Uri.parse('https://example.com/latest'),
          maxBytes: 16,
          maxRedirects: 3,
          client: MockClient.streaming((request, _) async => body(const [],
              status: 302, headers: {'location': '/latest'})),
        ),
        refusedAs(GuardedDownloadFailure.status),
      );
    });

    test('refuses a body larger than the cap, announced or not', () async {
      await expectLater(
        guardedDownload(
          Uri.parse('https://example.com/tool.exe'),
          maxBytes: 4,
          client: MockClient.streaming(
              (request, _) async => body([1], announced: 5)),
        ),
        refusedAs(GuardedDownloadFailure.tooLarge),
      );
      await expectLater(
        guardedDownload(
          Uri.parse('https://example.com/tool.exe'),
          maxBytes: 4,
          client: MockClient.streaming((request, _) async =>
              http.StreamedResponse(Stream.value([1, 2, 3, 4, 5]), 200)),
        ),
        refusedAs(GuardedDownloadFailure.tooLarge),
      );
    });

    test('refuses a body cut short of its announced length', () async {
      await expectLater(
        guardedDownload(
          Uri.parse('https://example.com/tool.exe'),
          maxBytes: 16,
          client: MockClient.streaming(
              (request, _) async => body([1, 2], announced: 8)),
        ),
        refusedAs(GuardedDownloadFailure.incomplete),
      );
    });

    test('reports the status of a failed download', () async {
      await expectLater(
        guardedDownload(
          Uri.parse('https://example.com/tool.exe'),
          maxBytes: 16,
          client: MockClient.streaming(
              (request, _) async => body(const [], status: 404)),
        ),
        throwsA(isA<GuardedDownloadException>()
            .having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  });

  group('normalizeMediaUrl', () {
    test('keeps ordinary links and completes a bare host', () {
      expect(normalizeMediaUrl(' https://youtu.be/abc123 '),
          'https://youtu.be/abc123');
      expect(normalizeMediaUrl('http://example.com/v?id=1'),
          'http://example.com/v?id=1');
      expect(normalizeMediaUrl('youtube.com/watch?v=abc'),
          'https://youtube.com/watch?v=abc');
    });

    test('refuses anything yt-dlp could read as an option', () {
      expect(normalizeMediaUrl('--exec=calc.exe'), isNull);
      expect(normalizeMediaUrl('-o C:/Windows/x'), isNull);
      expect(normalizeMediaUrl('https://example.com/v --exec calc.exe'),
          isNull);
      expect(normalizeMediaUrl('https://example.com/v\n--exec'), isNull);
    });

    test('refuses non-web schemes and empty input', () {
      expect(normalizeMediaUrl(''), isNull);
      expect(normalizeMediaUrl('   '), isNull);
      expect(normalizeMediaUrl('file:///C:/Users/me/secret.txt'), isNull);
      expect(normalizeMediaUrl('ftp://example.com/v'), isNull);
      expect(normalizeMediaUrl('https:///nohost'), isNull);
    });
  });
}
