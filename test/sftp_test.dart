import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/sftp/sftp_crypto.dart';
import 'package:luma/features/plugins/installed/sftp/sftp_paths.dart';
import 'package:luma/features/plugins/installed/sftp/sftp_session.dart';
import 'package:luma/features/plugins/installed/sftp/sftp_site.dart';
import 'package:luma/features/plugins/installed/sftp/sftp_transfer_queue.dart';

/// A stand-in for a live connection. Every transfer parks on a completer the
/// test controls, so the queue's ordering and concurrency are observable
/// without a server anywhere.
class FakeBackend implements TransferBackend {
  final List<String> started = [];
  final List<String> madeDirectories = [];
  final Map<String, Completer<void>> _gates = {};
  final Map<String, void Function(int)> _progress = {};
  final Map<String, TransferCancelToken?> _tokens = {};

  /// Remote paths that should fail instead of completing.
  final Set<String> failing = {};

  @override
  Future<void> makeDirectories(String path) async {
    madeDirectories.add(path);
  }

  @override
  Future<void> upload(
    File source,
    String remotePath, {
    void Function(int bytes)? onProgress,
    TransferCancelToken? cancelToken,
  }) =>
      _transfer(remotePath, onProgress, cancelToken);

  @override
  Future<void> download(
    String remotePath,
    File destination, {
    void Function(int bytes)? onProgress,
    TransferCancelToken? cancelToken,
  }) =>
      _transfer(remotePath, onProgress, cancelToken);

  Future<void> _transfer(
    String remotePath,
    void Function(int bytes)? onProgress,
    TransferCancelToken? cancelToken,
  ) {
    started.add(remotePath);
    if (onProgress != null) _progress[remotePath] = onProgress;
    _tokens[remotePath] = cancelToken;
    final gate = Completer<void>();
    _gates[remotePath] = gate;
    cancelToken?.attach(() {
      if (!gate.isCompleted) gate.completeError(const TransferCancelled());
    });
    if (failing.contains(remotePath)) {
      gate.completeError(
        const FileSystemException('Permission denied', '/etc/shadow'),
      );
    }
    return gate.future;
  }

  void report(String remotePath, int bytes) => _progress[remotePath]?.call(bytes);

  void finish(String remotePath) {
    final gate = _gates[remotePath];
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  bool isCancelled(String remotePath) =>
      _tokens[remotePath]?.isCancelled ?? false;
}

TransferItem _itemFor(SftpTransferQueue queue, String remotePath) =>
    queue.items.firstWhere((i) => i.remotePath == remotePath);

void main() {
  group('RemotePath', () {
    test('joins without doubling separators', () {
      expect(RemotePath.join('/var/www', 'index.html'), '/var/www/index.html');
      expect(RemotePath.join('/var/www/', 'index.html'), '/var/www/index.html');
      expect(RemotePath.join('/', 'etc'), '/etc');
      expect(RemotePath.join('/var', '/absolute'), '/absolute');
    });

    test('normalizes . and .. without escaping the root', () {
      expect(RemotePath.normalize('/var//www/./'), '/var/www');
      expect(RemotePath.normalize('/var/www/../log'), '/var/log');
      expect(RemotePath.normalize('/../../etc'), '/etc');
      expect(RemotePath.normalize(''), '/');
    });

    test('parent of the root is the root', () {
      expect(RemotePath.parent('/var/www/index.html'), '/var/www');
      expect(RemotePath.parent('/var'), '/');
      expect(RemotePath.parent('/'), '/');
    });

    test('basename returns the last segment', () {
      expect(RemotePath.basename('/var/www/index.html'), 'index.html');
      expect(RemotePath.basename('/var/'), 'var');
      expect(RemotePath.basename('/'), '/');
    });

    test('crumbs walk down from the root', () {
      final crumbs = RemotePath.crumbs('/var/www/html');
      expect(crumbs.map((c) => c.label).toList(), ['/', 'var', 'www', 'html']);
      expect(crumbs.map((c) => c.path).toList(), [
        '/',
        '/var',
        '/var/www',
        '/var/www/html',
      ]);
    });
  });

  group('formatting', () {
    test('file sizes step through units', () {
      expect(formatFileSize(512), '512 B');
      expect(formatFileSize(2048), '2.0 KB');
      expect(formatFileSize(1024 * 1024 * 3), '3.0 MB');
      expect(formatFileSize(1024 * 1024 * 1024 * 5), '5.0 GB');
    });

    test('a stalled transfer shows a dash rather than NaN', () {
      expect(formatTransferRate(0), '—');
      expect(formatTransferRate(double.nan), '—');
      expect(formatTransferRate(2048), '2.0 KB/s');
    });

    test('permissions render and parse both notations', () {
      expect(formatPermissions(int.parse('755', radix: 8)), 'rwxr-xr-x');
      expect(formatPermissions(int.parse('644', radix: 8)), 'rw-r--r--');
      expect(formatPermissions(null), '');

      expect(parsePermissions('755'), int.parse('755', radix: 8));
      expect(parsePermissions('0644'), int.parse('644', radix: 8));
      expect(parsePermissions('rwxr-xr-x'), int.parse('755', radix: 8));
      expect(parsePermissions('nonsense'), isNull);
      expect(parsePermissions('999'), isNull);
    });

    test('parsing round-trips what formatting produced', () {
      for (final mode in ['700', '755', '644', '600', '777', '000']) {
        final value = int.parse(mode, radix: 8);
        expect(parsePermissions(formatPermissions(value)), value);
      }
    });
  });

  group('SftpSecretCrypto', () {
    final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final crypto = SftpSecretCrypto.forTesting(key);

    test('round-trips a secret', () {
      final token = crypto.encrypt('hunter2', siteId: 'site-a', field: 'secret');
      expect(token, isNot(contains('hunter2')));
      expect(
        crypto.decrypt(token, siteId: 'site-a', field: 'secret'),
        'hunter2',
      );
    });

    test('a ciphertext does not decrypt under another site or field', () {
      final token = crypto.encrypt('hunter2', siteId: 'site-a', field: 'secret');
      expect(crypto.decrypt(token, siteId: 'site-b', field: 'secret'), isNull);
      expect(crypto.decrypt(token, siteId: 'site-a', field: 'other'), isNull);
    });

    test('a different key cannot read it', () {
      final token = crypto.encrypt('hunter2', siteId: 'site-a', field: 'secret');
      final other = SftpSecretCrypto.forTesting(
        Uint8List.fromList(List<int>.filled(32, 7)),
      );
      expect(other.decrypt(token, siteId: 'site-a', field: 'secret'), isNull);
    });

    test('tampering with the ciphertext fails the check', () {
      final token = crypto.encrypt('hunter2', siteId: 'site-a', field: 'secret');
      final raw = base64Decode(token);
      raw[raw.length - 3] ^= 0xff;
      expect(
        crypto.decrypt(base64Encode(raw), siteId: 'site-a', field: 'secret'),
        isNull,
      );
      expect(crypto.decrypt('not base64 at all!', siteId: 'a', field: 'b'),
          isNull);
    });

    test('empty secrets survive the round trip', () {
      final token = crypto.encrypt('', siteId: 'site-a', field: 'secret');
      expect(crypto.decrypt(token, siteId: 'site-a', field: 'secret'), '');
    });
  });

  group('SftpSite', () {
    test('round-trips through JSON', () {
      final site = SftpSite(
        id: 'abc',
        name: 'My VPS',
        host: 'example.com',
        port: 2222,
        username: 'deploy',
        authMode: SftpAuthMode.key,
        keyPath: r'C:\keys\id_ed25519',
        saveSecret: true,
        secretToken: 'token',
        remoteDirectory: '/var/www',
        localDirectory: r'C:\site',
        lastUsed: DateTime.utc(2026, 8, 18, 12),
      );

      final restored = SftpSite.fromJson(site.toJson());

      expect(restored.id, site.id);
      expect(restored.name, site.name);
      expect(restored.host, site.host);
      expect(restored.port, 2222);
      expect(restored.username, 'deploy');
      expect(restored.authMode, SftpAuthMode.key);
      expect(restored.keyPath, site.keyPath);
      expect(restored.saveSecret, isTrue);
      expect(restored.secretToken, 'token');
      expect(restored.remoteDirectory, '/var/www');
      expect(restored.localDirectory, site.localDirectory);
      expect(restored.lastUsed, site.lastUsed);
    });

    test('an unnamed site falls back to its host', () {
      const site = SftpSite(
        id: 'a',
        name: '  ',
        host: 'example.com',
        port: 22,
        username: 'root',
      );
      expect(site.displayName, 'example.com');
      expect(site.endpointLabel, 'root@example.com');
    });

    test('a non-default port shows in the endpoint label', () {
      const site = SftpSite(
        id: 'a',
        name: 'VPS',
        host: 'example.com',
        port: 2222,
        username: 'root',
      );
      expect(site.endpointLabel, 'root@example.com:2222');
    });

    test('copyWith can clear a saved secret', () {
      const site = SftpSite(
        id: 'a',
        name: 'VPS',
        host: 'example.com',
        port: 22,
        username: 'root',
        saveSecret: true,
        secretToken: 'token',
      );
      expect(site.copyWith(clearSecretToken: true).secretToken, isNull);
      expect(site.copyWith(name: 'Other').secretToken, 'token');
    });

    test('malformed JSON falls back to workable defaults', () {
      final site = SftpSite.fromJson(const {'host': 'example.com'});
      expect(site.port, 22);
      expect(site.authMode, SftpAuthMode.password);
      expect(site.saveSecret, isFalse);
      expect(site.id, isNotEmpty);
    });
  });

  group('SftpTransferQueue', () {
    late SftpTransferQueue queue;
    late FakeBackend backend;

    setUp(() {
      queue = SftpTransferQueue(concurrency: 2);
      backend = FakeBackend();
      queue.bind(backend);
    });

    tearDown(() => queue.dispose());

    void enqueueUploads(int count) {
      for (var i = 0; i < count; i++) {
        queue.enqueueUpload(File('local$i.txt'), '/remote/file$i.txt',
            size: 1000);
      }
    }

    test('runs no more than the concurrency limit at once', () async {
      enqueueUploads(3);
      await pumpEventQueue();

      expect(queue.runningCount, 2);
      // Order between the two isn't fixed — whichever one had to wait for its
      // parent directory to be created starts a microtask later.
      expect(
        backend.started,
        unorderedEquals(['/remote/file0.txt', '/remote/file1.txt']),
      );
      expect(_itemFor(queue, '/remote/file2.txt').state, TransferState.queued);

      backend.finish('/remote/file0.txt');
      await pumpEventQueue();

      expect(_itemFor(queue, '/remote/file0.txt').state, TransferState.done);
      expect(backend.started, contains('/remote/file2.txt'));
      expect(queue.runningCount, 2);
    });

    test('a finished upload counts its full size', () async {
      enqueueUploads(1);
      await pumpEventQueue();
      backend.report('/remote/file0.txt', 400);
      await pumpEventQueue();

      final item = _itemFor(queue, '/remote/file0.txt');
      expect(item.transferredBytes, 400);
      expect(item.progress, closeTo(0.4, 0.001));

      backend.finish('/remote/file0.txt');
      await pumpEventQueue();

      expect(item.transferredBytes, 1000);
      expect(item.progress, 1);
      expect(queue.pendingCount, 0);
    });

    test('progress never walks backwards or past the total', () async {
      enqueueUploads(1);
      await pumpEventQueue();

      backend.report('/remote/file0.txt', 800);
      backend.report('/remote/file0.txt', 200);
      backend.report('/remote/file0.txt', 5000);
      await pumpEventQueue();

      expect(_itemFor(queue, '/remote/file0.txt').transferredBytes, 1000);
    });

    test('each parent directory is created once', () async {
      queue.enqueueUpload(File('a.txt'), '/remote/site/a.txt', size: 1);
      queue.enqueueUpload(File('b.txt'), '/remote/site/b.txt', size: 1);
      await pumpEventQueue();

      expect(backend.madeDirectories, ['/remote/site']);
    });

    test('a queued transfer can be dropped before it starts', () async {
      enqueueUploads(3);
      await pumpEventQueue();

      queue.cancel(_itemFor(queue, '/remote/file2.txt').id);
      await pumpEventQueue();

      expect(
        _itemFor(queue, '/remote/file2.txt').state,
        TransferState.cancelled,
      );
      expect(backend.started, isNot(contains('/remote/file2.txt')));
    });

    test('a running transfer is aborted, not left hanging', () async {
      enqueueUploads(1);
      await pumpEventQueue();

      queue.cancel(_itemFor(queue, '/remote/file0.txt').id);
      await pumpEventQueue();

      expect(backend.isCancelled('/remote/file0.txt'), isTrue);
      expect(
        _itemFor(queue, '/remote/file0.txt').state,
        TransferState.cancelled,
      );
    });

    test('a failure is reported and can be retried', () async {
      backend.failing.add('/remote/file0.txt');
      enqueueUploads(1);
      await pumpEventQueue();

      final item = _itemFor(queue, '/remote/file0.txt');
      expect(item.state, TransferState.failed);
      expect(item.error, 'Permission denied');
      expect(queue.failedCount, 1);

      backend.failing.clear();
      queue.retryFailed();
      await pumpEventQueue();

      expect(item.state, TransferState.running);
      expect(item.error, isNull);
      expect(item.transferredBytes, 0);
    });

    test('unbinding stops everything in flight', () async {
      enqueueUploads(2);
      await pumpEventQueue();

      queue.bind(null);
      await pumpEventQueue();

      expect(backend.isCancelled('/remote/file0.txt'), isTrue);
      expect(backend.isCancelled('/remote/file1.txt'), isTrue);
      expect(queue.runningCount, 0);
    });

    test('nothing starts while no connection is bound', () async {
      queue.bind(null);
      enqueueUploads(1);
      await pumpEventQueue();

      expect(backend.started, isEmpty);
      expect(_itemFor(queue, '/remote/file0.txt').state, TransferState.queued);
    });

    test('clearing finished rows leaves the pending ones alone', () async {
      enqueueUploads(3);
      await pumpEventQueue();
      backend.finish('/remote/file0.txt');
      await pumpEventQueue();

      queue.clearFinished();

      expect(queue.items.length, 2);
      expect(
        queue.items.any((i) => i.remotePath == '/remote/file0.txt'),
        isFalse,
      );
    });

    test('overall progress weighs the pending transfers by size', () async {
      queue.enqueueUpload(File('a.txt'), '/remote/a.txt', size: 1000);
      queue.enqueueUpload(File('b.txt'), '/remote/b.txt', size: 3000);
      await pumpEventQueue();

      backend.report('/remote/a.txt', 500);
      backend.report('/remote/b.txt', 500);
      await pumpEventQueue();

      expect(queue.overallProgress, closeTo(0.25, 0.001));
    });

    test('downloads land next to their siblings in the queue', () async {
      queue.enqueueDownload('/remote/log.txt', File('local.txt'), size: 10);
      await pumpEventQueue();

      final item = _itemFor(queue, '/remote/log.txt');
      expect(item.direction, TransferDirection.download);
      expect(item.name, 'log.txt');
      expect(backend.madeDirectories, isEmpty);
    });
  });
}
