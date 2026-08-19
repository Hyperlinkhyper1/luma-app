import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'sftp_paths.dart';
import 'sftp_session.dart';

/// Which way a queued transfer moves.
enum TransferDirection { upload, download }

/// Where a queued transfer is in its life.
enum TransferState {
  /// Waiting for a worker slot.
  queued,

  /// Bytes are moving right now.
  running,

  /// Every byte arrived.
  done,

  /// Stopped by the user, or by the connection dropping.
  cancelled,

  /// The server or the local disk refused; [TransferItem.error] says why.
  failed,
}

/// One file on the move. Folders never become items themselves — they are
/// expanded into one item per file before anything is queued, which is what
/// makes the progress total meaningful.
class TransferItem {
  TransferItem({
    required this.id,
    required this.direction,
    required this.localPath,
    required this.remotePath,
    required this.name,
    required this.totalBytes,
  });

  final String id;
  final TransferDirection direction;

  /// Absolute path on this device, in the platform's own separator style.
  final String localPath;

  /// Absolute POSIX path on the server.
  final String remotePath;

  /// File name shown in the queue row.
  final String name;

  /// Size in bytes, known before the transfer starts. Zero when the source
  /// wouldn't report a size, in which case the row shows an indeterminate bar.
  final int totalBytes;

  int transferredBytes = 0;
  TransferState state = TransferState.queued;
  String? error;
  DateTime? startedAt;
  DateTime? finishedAt;

  TransferCancelToken? _token;

  /// 0..1, or null when the total isn't known and the bar should be
  /// indeterminate.
  double? get progress {
    if (totalBytes <= 0) return state == TransferState.done ? 1 : null;
    return (transferredBytes / totalBytes).clamp(0.0, 1.0);
  }

  bool get isFinished =>
      state == TransferState.done ||
      state == TransferState.failed ||
      state == TransferState.cancelled;

  /// Average speed over the life of the transfer, in bytes per second.
  double get bytesPerSecond {
    final started = startedAt;
    if (started == null) return 0;
    final end = finishedAt ?? DateTime.now();
    final seconds = end.difference(started).inMilliseconds / 1000;
    if (seconds <= 0) return 0;
    return transferredBytes / seconds;
  }

  String get rateLabel => formatTransferRate(bytesPerSecond);

  /// Where the file is going, for the queue row's subtitle.
  String get destinationLabel => direction == TransferDirection.upload
      ? RemotePath.parent(remotePath)
      : File(localPath).parent.path;
}

/// Runs queued transfers against a [TransferBackend], a few at a time.
///
/// The queue owns nothing about the connection beyond the backend handed to
/// it — [bind] swaps it when the user connects or disconnects, and unbinding
/// stops everything in flight rather than letting transfers fail one by one
/// against a dead socket.
class SftpTransferQueue extends ChangeNotifier {
  SftpTransferQueue({this.concurrency = 2});

  /// How many files move at once. Two is FileZilla's default and is gentle
  /// enough for the small VPS this usually talks to.
  final int concurrency;

  final List<TransferItem> _items = [];
  TransferBackend? _backend;
  var _nextId = 0;
  var _disposed = false;

  /// Remote directories this queue has already created, so a 500-file folder
  /// upload doesn't re-stat the same parents 500 times.
  final Set<String> _ensuredDirectories = {};

  UnmodifiableListView<TransferItem> get items => UnmodifiableListView(_items);

  bool get isEmpty => _items.isEmpty;

  int get runningCount =>
      _items.where((i) => i.state == TransferState.running).length;

  int get pendingCount => _items
      .where((i) =>
          i.state == TransferState.queued || i.state == TransferState.running)
      .length;

  int get failedCount =>
      _items.where((i) => i.state == TransferState.failed).length;

  bool get hasFinished => _items.any((i) => i.isFinished);

  /// Progress across everything still pending, weighted by size — what the
  /// bar above the queue shows. Null when nothing is pending.
  double? get overallProgress {
    final pending = _items
        .where((i) =>
            i.state == TransferState.queued || i.state == TransferState.running)
        .toList();
    if (pending.isEmpty) return null;
    final total = pending.fold<int>(0, (sum, i) => sum + i.totalBytes);
    if (total <= 0) return null;
    final moved = pending.fold<int>(0, (sum, i) => sum + i.transferredBytes);
    return (moved / total).clamp(0.0, 1.0);
  }

  /// Points the queue at a live connection, or at nothing when [backend] is
  /// null. Swapping backends cancels whatever is in flight — those bytes were
  /// going to the old connection.
  void bind(TransferBackend? backend) {
    if (identical(_backend, backend)) return;
    _backend = backend;
    _ensuredDirectories.clear();
    for (final item in _items) {
      if (item.state == TransferState.running) {
        item._token?.cancel();
      }
    }
    if (backend != null) _pump();
    _notify();
  }

  /// Queues an upload of [source] to [remotePath].
  TransferItem enqueueUpload(File source, String remotePath, {int? size}) {
    final item = TransferItem(
      id: 'transfer-${_nextId++}',
      direction: TransferDirection.upload,
      localPath: source.path,
      remotePath: remotePath,
      name: RemotePath.basename(remotePath),
      totalBytes: size ?? _sizeOf(source),
    );
    _items.add(item);
    _notify();
    _pump();
    return item;
  }

  /// Queues a download of [remotePath] to [destination].
  TransferItem enqueueDownload(
    String remotePath,
    File destination, {
    required int size,
  }) {
    final item = TransferItem(
      id: 'transfer-${_nextId++}',
      direction: TransferDirection.download,
      localPath: destination.path,
      remotePath: remotePath,
      name: RemotePath.basename(remotePath),
      totalBytes: size,
    );
    _items.add(item);
    _notify();
    _pump();
    return item;
  }

  /// Cancelling a transfer at dispose time hands control back to [_run] one
  /// microtask later, so the notification that follows would land on a
  /// disposed notifier. Every update goes through here instead.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  static int _sizeOf(File file) {
    try {
      return file.lengthSync();
    } catch (_) {
      return 0;
    }
  }

  /// Stops one transfer. A queued item is dropped straight to cancelled; a
  /// running one is aborted and its partial file cleaned up by the session.
  void cancel(String id) {
    for (final item in _items) {
      if (item.id != id || item.isFinished) continue;
      item._token?.cancel();
      if (item.state == TransferState.queued) {
        item
          ..state = TransferState.cancelled
          ..finishedAt = DateTime.now();
      }
      _notify();
      _pump();
      return;
    }
  }

  void cancelAll() {
    for (final item in _items) {
      if (item.isFinished) continue;
      item._token?.cancel();
      if (item.state == TransferState.queued) {
        item.state = TransferState.cancelled;
        item.finishedAt = DateTime.now();
      }
    }
    _notify();
  }

  /// Puts a failed or cancelled item back at the end of the queue.
  void retry(String id) {
    for (final item in _items) {
      if (item.id != id || !item.isFinished) continue;
      if (item.state == TransferState.done) return;
      item
        ..state = TransferState.queued
        ..transferredBytes = 0
        ..error = null
        ..startedAt = null
        ..finishedAt = null
        .._token = null;
      _notify();
      _pump();
      return;
    }
  }

  void retryFailed() {
    var changed = false;
    for (final item in _items) {
      if (item.state != TransferState.failed) continue;
      item
        ..state = TransferState.queued
        ..transferredBytes = 0
        ..error = null
        ..startedAt = null
        ..finishedAt = null
        .._token = null;
      changed = true;
    }
    if (!changed) return;
    _notify();
    _pump();
  }

  /// Clears everything that has finished, whichever way it finished.
  void clearFinished() {
    final before = _items.length;
    _items.removeWhere((i) => i.isFinished);
    if (_items.length == before) return;
    _notify();
  }

  /// Called after each transfer finishes so the panes can refresh the
  /// directory the file landed in.
  void Function(TransferItem item)? onItemComplete;

  void _pump() {
    final backend = _backend;
    if (backend == null || _disposed) return;
    while (runningCount < concurrency) {
      TransferItem? next;
      for (final item in _items) {
        if (item.state == TransferState.queued) {
          next = item;
          break;
        }
      }
      if (next == null) return;
      _run(next, backend);
    }
  }

  Future<void> _run(TransferItem item, TransferBackend backend) async {
    final token = TransferCancelToken();
    item
      .._token = token
      ..state = TransferState.running
      ..startedAt = DateTime.now();
    _notify();

    try {
      if (item.direction == TransferDirection.upload) {
        final parent = RemotePath.parent(item.remotePath);
        if (_ensuredDirectories.add(parent)) {
          await backend.makeDirectories(parent);
        }
        if (token.isCancelled) throw const TransferCancelled();
        await backend.upload(
          File(item.localPath),
          item.remotePath,
          cancelToken: token,
          onProgress: (bytes) => _onProgress(item, bytes),
        );
      } else {
        await backend.download(
          item.remotePath,
          File(item.localPath),
          cancelToken: token,
          onProgress: (bytes) => _onProgress(item, bytes),
        );
      }
      item
        ..state = TransferState.done
        ..transferredBytes =
            item.totalBytes > 0 ? item.totalBytes : item.transferredBytes;
    } on TransferCancelled {
      item.state = TransferState.cancelled;
    } catch (e) {
      if (token.isCancelled) {
        item.state = TransferState.cancelled;
      } else {
        item
          ..state = TransferState.failed
          ..error = _describe(e);
      }
    } finally {
      item
        ..finishedAt = DateTime.now()
        .._token = null;
      _notify();
      if (!_disposed) onItemComplete?.call(item);
      _pump();
    }
  }

  void _onProgress(TransferItem item, int bytes) {
    // Progress callbacks arrive per chunk; never let a late one walk the
    // number backwards or past the total.
    item.transferredBytes = item.totalBytes > 0
        ? min(max(item.transferredBytes, bytes), item.totalBytes)
        : max(item.transferredBytes, bytes);
    _notify();
  }

  static String _describe(Object error) {
    if (error is FileSystemException) {
      return error.osError?.message ?? error.message;
    }
    return error.toString();
  }

  @override
  void dispose() {
    cancelAll();
    _disposed = true;
    super.dispose();
  }
}
