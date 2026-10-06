import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/benchmark_generate.dart';
import 'package:test/test.dart';

void main() {
  const partial = '<!doctype html><html><style>.nav { color:';
  const page = '<!doctype html><html><body>Coffee</body></html>';
  String chunk(String content) => 'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': content}
              }
            ]
          })}';

  test('recovers from a real HTTP response cut off mid-stream', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    var attempts = 0;
    server.listen((socket) {
      var answered = false;
      socket.listen((_) async {
        if (answered) return;
        answered = true;
        attempts++;
        final body = attempts == 1
            ? '${chunk(partial)}\n\n'
            : '${chunk(page)}\n\ndata: [DONE]\n\n';
        final bytes = utf8.encode(body);
        final length = bytes.length + (attempts == 1 ? 100 : 0);
        socket.add(ascii.encode('HTTP/1.1 200 OK\r\n'
            'Content-Type: text/event-stream\r\n'
            'Content-Length: $length\r\nConnection: close\r\n\r\n'));
        socket.add(bytes);
        await socket.flush();
        await socket.close();
      });
    });
    final acc = ChatStreamAccumulator();
    HttpClient? client;
    try {
      await retryBenchmarkStream(acc, () async {
        client?.close(force: true);
        client = HttpClient();
        final req =
            await client!.getUrl(Uri.parse('http://127.0.0.1:${server.port}'));
        final res = await req.close();
        await for (final line
            in res.transform(utf8.decoder).transform(const LineSplitter())) {
          acc.addLine(line);
        }
        checkBenchmarkStreamEnd(acc);
      }, canRetry: () => true, beforeRetry: () async {});
      expect(attempts, 2);
      expect(acc.content, page);
      expect(acc.done, isTrue);
    } finally {
      client?.close(force: true);
      await server.close();
    }
  });

  test('premature EOF retries even without a transport exception', () async {
    final acc = ChatStreamAccumulator();
    var attempts = 0;
    await retryBenchmarkStream(acc, () async {
      attempts++;
      acc.addLine(chunk(attempts == 1 ? partial : page));
      if (attempts == 2) acc.addLine('data: [DONE]');
      checkBenchmarkStreamEnd(acc);
    }, canRetry: () => true, beforeRetry: () async {});
    expect(attempts, 2);
    expect(acc.content, page);
  });

  test('a terminal finish reason or provider error does not trigger retry',
      () async {
    for (final terminal in [
      'data: {"choices":[{"delta":{},"finish_reason":"length"}]}',
      'data: {"error":{"message":"Rate limited","code":429}}',
      'data: [DONE]',
    ]) {
      final acc = ChatStreamAccumulator()..addLine(terminal);
      checkBenchmarkStreamEnd(acc);
      var attempts = 0;
      await expectLater(
          retryBenchmarkStream(acc, () async {
            attempts++;
            throw const HttpException('Connection closed while receiving data');
          }, canRetry: () => true, beforeRetry: () async {}),
          throwsA(isA<HttpException>()));
      expect(attempts, 1);
    }
  });

  test('restarts a disconnected generation without mixing partial HTML',
      () async {
    final acc = ChatStreamAccumulator();
    var attempts = 0;
    final result = await retryBenchmarkStream<int>(
      acc,
      () async {
        attempts++;
        acc.addLine(chunk(attempts == 1 ? partial : page));
        if (attempts == 1) {
          throw const HttpException('Connection closed while receiving data');
        }
        acc.addLine('data: [DONE]');
        return 200;
      },
      canRetry: () => true,
      beforeRetry: () async {},
    );
    expect(result, 200);
    expect(attempts, 2);
    expect(acc.content, page);
    expect(benchmarkGenerationResult(reply: acc.content).status, 'PASS');
  });

  test('exhausted retries retain the last partial response', () async {
    final acc = ChatStreamAccumulator();
    var attempts = 0;
    await expectLater(
      retryBenchmarkStream<int>(acc, () async {
        attempts++;
        acc.addLine(chunk(partial));
        throw const HttpException('Connection closed while receiving data');
      }, canRetry: () => true, beforeRetry: () async {}),
      throwsA(isA<HttpException>()),
    );
    expect(attempts, 2);
    expect(acc.content, partial);
  });

  test('stopping prevents another request and preserves output', () async {
    final acc = ChatStreamAccumulator();
    var attempts = 0;
    await expectLater(
      retryBenchmarkStream<int>(acc, () async {
        attempts++;
        acc.addLine(chunk(partial));
        throw const HttpException('Connection closed while receiving data');
      }, canRetry: () => false, beforeRetry: () async {}),
      throwsA(isA<HttpException>()),
    );
    expect(attempts, 1);
    expect(acc.content, partial);
  });
}
