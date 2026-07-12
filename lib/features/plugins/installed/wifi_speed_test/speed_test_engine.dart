import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

enum SpeedTestPhase { latency, download, upload, done }

class SpeedTestProgress {
  const SpeedTestProgress({
    required this.phase,
    this.fraction = 0,
    this.currentSpeedMbps = 0,
    this.latencyMs = 0,
    this.downloadMbps,
    this.uploadMbps,
  });

  final SpeedTestPhase phase;
  final double fraction;
  final double currentSpeedMbps;
  final int latencyMs;
  final double? downloadMbps;
  final double? uploadMbps;

  SpeedTestProgress copyWith({
    SpeedTestPhase? phase,
    double? fraction,
    double? currentSpeedMbps,
    int? latencyMs,
    double? downloadMbps,
    double? uploadMbps,
  }) =>
      SpeedTestProgress(
        phase: phase ?? this.phase,
        fraction: fraction ?? this.fraction,
        currentSpeedMbps: currentSpeedMbps ?? this.currentSpeedMbps,
        latencyMs: latencyMs ?? this.latencyMs,
        downloadMbps: downloadMbps ?? this.downloadMbps,
        uploadMbps: uploadMbps ?? this.uploadMbps,
      );
}

class SpeedTestEngine {
  static const _baseUrl = 'https://speed.cloudflare.com';
  static const _downloadBytes = 25 * 1024 * 1024;
  static const _uploadBytes = 10 * 1024 * 1024;
  static const _chunkSize = 65536;

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30);

  void dispose() => _client.close(force: true);

  Future<int> _measureLatency() async {
    var total = 0;
    for (var i = 0; i < 3; i++) {
      final sw = Stopwatch()..start();
      final req =
          await _client.getUrl(Uri.parse('$_baseUrl/__down?bytes=1000'));
      final res = await req.close();
      await res.drain();
      sw.stop();
      total += sw.elapsedMilliseconds;
    }
    return (total / 3).round();
  }

  Stream<SpeedTestProgress> _runDownload() async* {
    final req = await _client
        .getUrl(Uri.parse('$_baseUrl/__down?bytes=$_downloadBytes'));
    final res = await req.close();
    final sw = Stopwatch()..start();
    var received = 0;
    await for (final chunk in res) {
      received += chunk.length;
      final elapsed = sw.elapsedMilliseconds / 1000.0;
      final speed = elapsed > 0 ? (received * 8) / (elapsed * 1e6) : 0.0;
      yield SpeedTestProgress(
        phase: SpeedTestPhase.download,
        fraction: received / _downloadBytes,
        currentSpeedMbps: speed,
      );
    }
    sw.stop();
    final elapsed = sw.elapsedMilliseconds / 1000.0;
    final speed = elapsed > 0 ? (received * 8) / (elapsed * 1e6) : 0.0;
    yield SpeedTestProgress(
      phase: SpeedTestPhase.download,
      fraction: 1.0,
      currentSpeedMbps: speed,
      downloadMbps: speed,
    );
  }

  Stream<SpeedTestProgress> _runUpload() async* {
    final req = await _client.postUrl(Uri.parse('$_baseUrl/__up'));
    req.headers.contentLength = _uploadBytes;
    req.headers.set('Content-Type', 'application/octet-stream');
    final sw = Stopwatch()..start();
    final chunk = Uint8List(_chunkSize);
    var sent = 0;

    while (sent < _uploadBytes) {
      final remaining = _uploadBytes - sent;
      final size = remaining < _chunkSize ? remaining : _chunkSize;
      req.add(Uint8List.sublistView(chunk, 0, size));
      await req.flush();
      sent += size;
      final elapsed = sw.elapsedMilliseconds / 1000.0;
      final speed = elapsed > 0 ? (sent * 8) / (elapsed * 1e6) : 0.0;
      yield SpeedTestProgress(
        phase: SpeedTestPhase.upload,
        fraction: sent / _uploadBytes,
        currentSpeedMbps: speed,
      );
    }
    final res = await req.close();
    await res.drain();
    sw.stop();
    final elapsed = sw.elapsedMilliseconds / 1000.0;
    final speed = elapsed > 0 ? (_uploadBytes * 8) / (elapsed * 1e6) : 0.0;
    yield SpeedTestProgress(
      phase: SpeedTestPhase.upload,
      fraction: 1.0,
      currentSpeedMbps: speed,
      uploadMbps: speed,
    );
  }

  Stream<SpeedTestProgress> runTest() async* {
    yield const SpeedTestProgress(phase: SpeedTestPhase.latency);
    final latency = await _measureLatency();

    double? downloadMbps;
    await for (final p in _runDownload()) {
      yield p.copyWith(latencyMs: latency);
      if (p.downloadMbps != null) downloadMbps = p.downloadMbps;
    }

    double? uploadMbps;
    await for (final p in _runUpload()) {
      yield p.copyWith(
        latencyMs: latency,
        downloadMbps: downloadMbps,
      );
      if (p.uploadMbps != null) uploadMbps = p.uploadMbps;
    }

    yield SpeedTestProgress(
      phase: SpeedTestPhase.done,
      fraction: 1.0,
      latencyMs: latency,
      downloadMbps: downloadMbps,
      uploadMbps: uploadMbps,
    );
  }
}
