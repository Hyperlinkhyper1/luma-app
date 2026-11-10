import 'dart:typed_data';

import 'package:http/http.dart' as http;

enum GuardedDownloadFailure { insecure, status, tooLarge, incomplete }

class GuardedDownloadException implements Exception {
  const GuardedDownloadException(this.failure, {this.statusCode});

  final GuardedDownloadFailure failure;
  final int? statusCode;

  @override
  String toString() => statusCode == null
      ? 'Download refused: ${failure.name}'
      : 'Download refused: ${failure.name} ($statusCode)';
}

/// Fetches something the app is about to run or unpack: a helper binary, an
/// installer, a runtime.
///
/// The http package follows redirects on its own, including one from https
/// down to plain http, and reads however much the other end sends. Here every
/// hop has to be https, the body may not exceed [maxBytes], and a body shorter
/// than the announced length is an error instead of a truncated executable.
Future<Uint8List> guardedDownload(
  Uri url, {
  required int maxBytes,
  http.Client? client,
  void Function(int received, int? total)? onProgress,
  int maxRedirects = 5,
}) async {
  final inner = client ?? http.Client();
  try {
    var current = url;
    for (var hop = 0; ; hop++) {
      if (current.scheme != 'https' ||
          current.host.isEmpty ||
          current.userInfo.isNotEmpty) {
        throw const GuardedDownloadException(GuardedDownloadFailure.insecure);
      }
      final response = await inner.send(
        http.Request('GET', current)..followRedirects = false,
      );
      final status = response.statusCode;
      if (const {301, 302, 303, 307, 308}.contains(status)) {
        final location = response.headers['location'];
        await response.stream.listen((_) {}).cancel();
        if (location == null || location.isEmpty || hop >= maxRedirects) {
          throw GuardedDownloadException(
            GuardedDownloadFailure.status,
            statusCode: status,
          );
        }
        current = current.resolve(location);
        continue;
      }
      if (status != 200) {
        await response.stream.listen((_) {}).cancel();
        throw GuardedDownloadException(
          GuardedDownloadFailure.status,
          statusCode: status,
        );
      }
      final total = response.contentLength;
      if (total != null && total > maxBytes) {
        await response.stream.listen((_) {}).cancel();
        throw const GuardedDownloadException(GuardedDownloadFailure.tooLarge);
      }
      final builder = BytesBuilder(copy: false);
      var received = 0;
      await for (final chunk in response.stream) {
        received += chunk.length;
        if (received > maxBytes) {
          throw const GuardedDownloadException(GuardedDownloadFailure.tooLarge);
        }
        builder.add(chunk);
        onProgress?.call(received, total);
      }
      if (total != null && received != total) {
        throw const GuardedDownloadException(GuardedDownloadFailure.incomplete);
      }
      return builder.takeBytes();
    }
  } finally {
    if (client == null) inner.close();
  }
}
