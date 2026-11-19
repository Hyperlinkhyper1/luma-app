import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/benchmark_generate.dart';
import 'package:test/test.dart';

void main() {
  const partial = '<!doctype html><html><style>.nav { color:';
  const page = '<!doctype html><html><body>Coffee</body></html>';
  const noWait = [Duration.zero, Duration.zero];
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
      }, canRetry: () => true, beforeRetry: () async {}, backoff: noWait);
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
    }, canRetry: () => true, beforeRetry: () async {}, backoff: noWait);
    expect(attempts, 2);
    expect(acc.content, page);
  });

  test('a terminal finish reason or provider error does not trigger retry',
      () async {
    for (final terminal in [
      'data: {"choices":[{"delta":{},"finish_reason":"length"}]}',
      'data: {"error":{"message":"Invalid request","code":400}}',
      'data: [DONE]',
    ]) {
      final acc = ChatStreamAccumulator()..addLine(terminal);
      checkBenchmarkStreamEnd(acc);
      var attempts = 0;
      await expectLater(
          retryBenchmarkStream(acc, () async {
            attempts++;
            throw const HttpException('Connection closed while receiving data');
          }, canRetry: () => true, beforeRetry: () async {}, backoff: noWait),
          throwsA(isA<HttpException>()));
      expect(attempts, 1);
    }
  });

  test('a stream the provider ends with finish reason error starts over',
      () async {
    final acc = ChatStreamAccumulator();
    var attempts = 0;
    final result = await retryBenchmarkStream(acc, () async {
      attempts++;
      acc.addLine(attempts == 1
          ? 'data: {"choices":[{"delta":{"reasoning":"thinking…"},"finish_reason":"error"}]}'
          : chunk(page));
      if (attempts > 1) {
        acc.addLine('data: {"choices":[{"delta":{},"finish_reason":"stop"}]}');
      }
      return 200;
    }, canRetry: () => true, beforeRetry: () async {}, backoff: noWait);
    expect(result, 200);
    expect(attempts, 2);
    expect(acc.content, page);

    final whole = ChatStreamAccumulator();
    var calls = 0;
    await retryBenchmarkStream(whole, () async {
      calls++;
      whole
        ..addLine(chunk(page))
        ..addLine('data: {"choices":[{"delta":{},"finish_reason":"error"}]}');
      return 200;
    }, canRetry: () => true, beforeRetry: () async {}, backoff: noWait);
    expect(calls, 1, reason: 'a complete page is kept, not paid for again');
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
      backoff: noWait,
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
      }, canRetry: () => true, beforeRetry: () async {}, backoff: noWait),
      throwsA(isA<HttpException>()),
    );
    expect(attempts, 3);
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
      }, canRetry: () => false, beforeRetry: () async {}, backoff: noWait),
      throwsA(isA<HttpException>()),
    );
    expect(attempts, 1);
    expect(acc.content, partial);
  });

  test('an upstream server error mid-stream starts the run over', () async {
    for (final failure in [
      'data: {"error":{"message":"Upstream idle timeout exceeded"},'
          '"choices":[{"delta":{},"finish_reason":"error"}]}',
      'data: {"error":{"message":"Upstream error from Ant Digital: Server '
          'error. Please try again later."},'
          '"choices":[{"delta":{},"finish_reason":"error"}]}',
      'data: {"error":{"message":"Gateway Timeout","code":504}}',
    ]) {
      final acc = ChatStreamAccumulator();
      final retries = <int>[];
      var attempts = 0;
      final result = await retryBenchmarkStream<int>(
        acc,
        () async {
          attempts++;
          acc.addLine(chunk(attempts == 1 ? partial : page));
          if (attempts == 1) {
            acc.addLine(failure);
          } else {
            acc.addLine('data: [DONE]');
          }
          checkBenchmarkStreamEnd(acc);
          return 200;
        },
        canRetry: () => true,
        beforeRetry: () async {},
        onRetry: (retry, _) => retries.add(retry),
        backoff: noWait,
      );
      expect(result, 200);
      expect(attempts, 2, reason: failure);
      expect(retries, [1]);
      expect(acc.content, page);
      expect(acc.error, isNull);
      expect(benchmarkGenerationResult(reply: acc.content).status, 'PASS');
    }
  });

  test('a transient HTTP status retries; a request error does not', () async {
    for (final (code, expected) in [(504, 3), (500, 3), (429, 3), (400, 1)]) {
      final acc = ChatStreamAccumulator();
      var attempts = 0;
      final result = await retryBenchmarkStream<int>(
        acc,
        () async {
          attempts++;
          return code;
        },
        canRetry: () => true,
        beforeRetry: () async {},
        failedTransiently: (status) =>
            benchmarkFailureIsTransient(httpStatus: status),
        backoff: noWait,
      );
      expect(result, code);
      expect(attempts, expected, reason: 'HTTP $code');
    }
  });

  test('an idle timeout retries, the overall deadline never does', () async {
    var attempts = 0;
    final acc = ChatStreamAccumulator();
    final result = await retryBenchmarkStream<int>(acc, () async {
      attempts++;
      if (attempts == 1) {
        acc.addLine(chunk(partial));
        throw TimeoutException('No stream event', const Duration(minutes: 8));
      }
      acc.addLine(chunk(page));
      acc.addLine('data: [DONE]');
      return 200;
    }, canRetry: () => true, beforeRetry: () async {}, backoff: noWait);
    expect(result, 200);
    expect(attempts, 2);
    expect(acc.content, page);

    attempts = 0;
    await expectLater(
        retryBenchmarkStream<int>(ChatStreamAccumulator(), () async {
          attempts++;
          throw TimeoutException(kBenchmarkTotalTimeout);
        }, canRetry: () => true, beforeRetry: () async {}, backoff: noWait),
        throwsA(isA<TimeoutException>()));
    expect(attempts, 1);
  });

  test('a persistent upstream failure keeps its last error after retries',
      () async {
    final acc = ChatStreamAccumulator();
    var attempts = 0;
    final result = await retryBenchmarkStream<int>(acc, () async {
      attempts++;
      acc.addLine(chunk(partial));
      acc.addLine('data: {"error":{"message":"Server error","code":502}}');
      return 200;
    }, canRetry: () => true, beforeRetry: () async {}, backoff: noWait);
    expect(result, 200);
    expect(attempts, 3);
    expect(acc.error, 'Server error');
    expect(acc.content, partial);
  });

  test('stopping during the backoff wait sends nothing more', () async {
    var stopped = false, attempts = 0, before = 0;
    final acc = ChatStreamAccumulator();
    await retryBenchmarkStream<int>(acc, () async {
      attempts++;
      acc.addLine('data: {"error":{"message":"Server error","code":500}}');
      return 200;
    },
        canRetry: () => !stopped,
        beforeRetry: () async => before++,
        onRetry: (_, __) => stopped = true,
        backoff: const [Duration(seconds: 5)]);
    expect(attempts, 1);
    expect(before, 0);
    expect(acc.error, 'Server error');
  });
  test('a rate limit waits minutes, honouring Retry-After within a cap', () {
    const planned = Duration(seconds: 20);
    expect(benchmarkRetryWait(attempt: 0, planned: planned, rateLimited: false),
        planned);
    expect(benchmarkRetryWait(attempt: 0, planned: planned, rateLimited: true),
        kBenchmarkRateLimitBackoff[0]);
    expect(benchmarkRetryWait(attempt: 1, planned: planned, rateLimited: true),
        kBenchmarkRateLimitBackoff[1]);
    expect(
        benchmarkRetryWait(
            attempt: 0, planned: planned, rateLimited: true, retryAfter: '90'),
        const Duration(seconds: 90));
    expect(
        benchmarkRetryWait(
            attempt: 0, planned: planned, rateLimited: true, retryAfter: '1'),
        planned);
    expect(
        benchmarkRetryWait(
            attempt: 0,
            planned: planned,
            rateLimited: true,
            retryAfter: '86400'),
        kBenchmarkMaxRetryWait);
    final now = DateTime.utc(2026, 11, 19, 12);
    expect(
        benchmarkRetryWait(
            attempt: 0,
            planned: planned,
            rateLimited: true,
            retryAfter: HttpDate.format(now.add(const Duration(minutes: 3))),
            now: now),
        const Duration(minutes: 3));
  });

  test('the wait a retry uses is what onRetry reports', () async {
    final waits = <Duration>[];
    final acc = ChatStreamAccumulator();
    await retryBenchmarkStream<int>(acc, () async => 429,
        canRetry: () => true,
        beforeRetry: () async {},
        failedTransiently: (status) => status == 429,
        waitFor: (attempt, planned) => Duration.zero,
        onRetry: (_, wait) => waits.add(wait),
        backoff: const [Duration(hours: 1)]);
    expect(waits, [Duration.zero]);
  });

  test('a timed-out run is never blamed on the model', () {
    const idle = Duration(minutes: 8), limit = Duration(minutes: 90);
    final total = benchmarkTimeoutResult(
        total: true,
        idle: idle,
        limit: limit,
        failures: ['Upstream idle timeout exceeded', 'HTTP 503']);
    expect(total.status, 'TIMED_OUT');
    expect(total.reason, contains('90-minute limit'));
    expect(total.reason, contains('after 2 restarts'));
    expect(total.reason, contains('HTTP 503'));
    final quiet =
        benchmarkTimeoutResult(total: false, idle: idle, limit: limit);
    expect(quiet.status, 'PROVIDER_ERROR');
    expect(quiet.reason, 'The upstream sent nothing for 8 minutes.');
  });
}
