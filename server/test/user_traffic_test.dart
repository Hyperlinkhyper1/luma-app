import 'dart:io';

import 'package:luma_sync_server/user_traffic.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  test('shelf exposes known request and response body lengths', () {
    final request = Request('PUT', Uri.parse('http://localhost/sync'),
        body: List.filled(64, 1));
    final response = Response(200, body: List.filled(48, 2));
    expect(request.contentLength, 64);
    expect(response.contentLength, 48);
  });

  test('per-user payload counts persist and deleted users stay removed',
      () async {
    final dir = await Directory.systemTemp.createTemp('luma_user_traffic_test');
    try {
      final traffic = await UserTrafficStore.open(dir.path);
      traffic.record('alice', uploadBytes: 12, downloadBytes: 34);
      traffic.record('alice', uploadBytes: 8, downloadBytes: 6);
      traffic.record('bob', uploadBytes: 3, downloadBytes: 4);
      await traffic.flush();

      final reopened = await UserTrafficStore.open(dir.path);
      expect(reopened.byUser['alice']?.requests, 2);
      expect(reopened.byUser['alice']?.uploadBytes, 20);
      expect(reopened.byUser['alice']?.downloadBytes, 40);
      expect(reopened.byUser['bob']?.requests, 1);

      reopened.remove('alice');
      await reopened.flush();
      final afterDelete = await UserTrafficStore.open(dir.path);
      expect(afterDelete.byUser.containsKey('alice'), isFalse);
      expect(afterDelete.byUser['bob']?.requests, 1);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
