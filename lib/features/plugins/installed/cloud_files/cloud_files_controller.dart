import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../sync/sync_api.dart';
import '../../../../sync/sync_crypto.dart';
import '../../../../sync/sync_service.dart';

/// Metadata for one file stored in the cloud. The file's bytes live on the
/// server as one or more encrypted chunk blobs; this record (kept in an
/// encrypted index) says how to find and reassemble them.
class CloudFile {
  const CloudFile({
    required this.id,
    required this.name,
    required this.size,
    required this.chunks,
    required this.uploadedAt,
  });

  /// Random hex id; the chunk blobs are named `cf_<id>_<n>`.
  final String id;

  /// Original file name (shown to the user; the server never sees it).
  final String name;

  /// Plaintext size in bytes.
  final int size;

  /// Number of chunk blobs.
  final int chunks;

  final DateTime uploadedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'size': size,
        'chunks': chunks,
        'uploadedAt': uploadedAt.toIso8601String(),
      };

  factory CloudFile.fromJson(Map<String, dynamic> j) => CloudFile(
        id: j['id'] as String,
        name: j['name'] as String,
        size: (j['size'] as num).toInt(),
        chunks: (j['chunks'] as num?)?.toInt() ?? 1,
        uploadedAt: DateTime.tryParse(j['uploadedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// A user-facing failure with a friendly message.
class CloudFilesException implements Exception {
  const CloudFilesException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum CloudTransferKind { none, uploading, downloading }

/// Manages the user's cloud files: listing, chunked upload/download, and
/// deletion. Everything is end-to-end encrypted by [SyncService]; the server
/// only stores ciphertext, and every byte counts against the account quota.
class CloudFilesController extends ChangeNotifier {
  CloudFilesController(this._sync) {
    _sync.addListener(_onSyncChanged);
  }

  final SyncService _sync;

  /// Collection holding the encrypted file index (the manifest).
  static const String indexCollection = 'cloud_files_index';

  /// Chunk size before encryption. Bounded so neither the client nor the
  /// server has to hold a whole (potentially multi-GB) file in memory.
  static const int chunkSize = 8 * 1024 * 1024; // 8 MiB

  List<CloudFile> _files = const [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  CloudTransferKind _transfer = CloudTransferKind.none;
  String? _transferName;
  double _progress = 0;

  // ---- Public state ----------------------------------------------------------

  bool get signedIn => _sync.signedIn;
  RemoteAccount? get account => _sync.account;
  List<CloudFile> get files => List.unmodifiable(_files);
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  bool get busy => _transfer != CloudTransferKind.none;
  CloudTransferKind get transfer => _transfer;
  String? get transferName => _transferName;
  double get progress => _progress;

  int get usedBytes => _sync.account?.usedBytes ?? 0;
  int get quotaBytes => _sync.account?.quotaBytes ?? (3 * 1024 * 1024 * 1024);
  int get freeBytes => (quotaBytes - usedBytes).clamp(0, quotaBytes);

  @override
  void dispose() {
    _sync.removeListener(_onSyncChanged);
    super.dispose();
  }

  void _onSyncChanged() {
    if (!_sync.signedIn && _loaded) {
      _files = const [];
      _loaded = false;
      notifyListeners();
    }
  }

  // ---- Listing ---------------------------------------------------------------

  /// Loads the file index from the server (and refreshes usage). Safe to call
  /// repeatedly; does nothing while a transfer is running.
  Future<void> refresh() async {
    if (!_sync.signedIn) {
      _files = const [];
      _loaded = true;
      _error = null;
      notifyListeners();
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _sync.refreshCloudAccount();
      _files = await _readIndex();
      _files = [..._files]..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      _loaded = true;
    } on SyncApiException catch (e) {
      _error = e.isUnauthorized
          ? 'Your session expired — sign in again under Settings → Sync.'
          : e.message;
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ---- Upload ----------------------------------------------------------------

  /// Uploads the file at [path] under [displayName]. Chunks are encrypted and
  /// uploaded one at a time; a failure part-way rolls back every uploaded
  /// chunk so no orphaned data lingers on the server.
  Future<void> upload(String path, String displayName) async {
    if (!_sync.signedIn) {
      throw const CloudFilesException('Sign in under Settings → Sync first.');
    }
    if (busy) {
      throw const CloudFilesException('Another transfer is already running.');
    }

    final file = File(path);
    final size = await file.length();

    // Fail fast if it clearly won't fit (the server enforces this too).
    final acct = _sync.account;
    if (acct != null && acct.usedBytes + size > acct.quotaBytes) {
      throw CloudFilesException(
          'Not enough space: "$displayName" needs ${formatBytes(size)} but '
          'only ${formatBytes(freeBytes)} is free.');
    }

    final id = _randomId();
    final chunkCount = size <= 0 ? 1 : ((size + chunkSize - 1) ~/ chunkSize);
    final uploaded = <String>[];

    _transfer = CloudTransferKind.uploading;
    _transferName = displayName;
    _progress = 0;
    _error = null;
    notifyListeners();

    final raf = await file.open();
    try {
      var sent = 0;
      for (var i = 0; i < chunkCount; i++) {
        final len = size <= 0 ? 0 : min(chunkSize, size - sent);
        final bytes = len == 0 ? Uint8List(0) : await raf.read(len);
        await _sync.putObject(_chunkName(id, i), bytes);
        uploaded.add(_chunkName(id, i));
        sent += len;
        _progress = size <= 0 ? 1 : sent / size;
        notifyListeners();
      }

      // Only record the file once every chunk is safely stored.
      final entry = CloudFile(
        id: id,
        name: displayName,
        size: size,
        chunks: chunkCount,
        uploadedAt: DateTime.now(),
      );
      await _commitIndex((list) => [...list, entry]);
    } on SyncApiException catch (e) {
      await _rollback(uploaded);
      throw CloudFilesException(e.code == 'quota_exceeded'
          ? 'The server is out of space for your account.'
          : e.message);
    } catch (e) {
      await _rollback(uploaded);
      throw CloudFilesException(_friendly(e));
    } finally {
      await raf.close();
      _transfer = CloudTransferKind.none;
      _transferName = null;
      _progress = 0;
      notifyListeners();
    }

    await refresh();
  }

  // ---- Download --------------------------------------------------------------

  /// Downloads [file] to [savePath], decrypting each chunk and streaming it to
  /// disk so memory stays bounded even for large files.
  Future<void> download(CloudFile file, String savePath) async {
    if (!_sync.signedIn) {
      throw const CloudFilesException('Sign in under Settings → Sync first.');
    }
    if (busy) {
      throw const CloudFilesException('Another transfer is already running.');
    }

    _transfer = CloudTransferKind.downloading;
    _transferName = file.name;
    _progress = 0;
    _error = null;
    notifyListeners();

    final out = await File(savePath).open(mode: FileMode.write);
    try {
      var written = 0;
      for (var i = 0; i < file.chunks; i++) {
        final bytes = await _sync.getObject(_chunkName(file.id, i));
        if (bytes == null) {
          throw const CloudFilesException(
              'Part of this file is missing on the server.');
        }
        await out.writeFrom(bytes);
        written += bytes.length;
        _progress = file.size <= 0 ? 1 : written / file.size;
        notifyListeners();
      }
    } on SyncApiException catch (e) {
      throw CloudFilesException(e.message);
    } on SyncCryptoException catch (e) {
      throw CloudFilesException(e.message);
    } finally {
      await out.close();
      _transfer = CloudTransferKind.none;
      _transferName = null;
      _progress = 0;
      notifyListeners();
    }
  }

  // ---- Delete ----------------------------------------------------------------

  /// Removes [file]: drops it from the index first (so it disappears even if a
  /// chunk delete fails), then deletes its chunk blobs.
  Future<void> delete(CloudFile file) async {
    if (!_sync.signedIn) return;
    try {
      await _commitIndex((list) => list.where((f) => f.id != file.id).toList());
      for (var i = 0; i < file.chunks; i++) {
        try {
          await _sync.deleteObject(_chunkName(file.id, i));
        } catch (_) {
          // Best effort; an orphaned chunk only wastes a little quota.
        }
      }
    } on SyncApiException catch (e) {
      throw CloudFilesException(e.message);
    }
    await refresh();
  }

  // ---- Index helpers ---------------------------------------------------------

  Future<List<CloudFile>> _readIndex() async {
    final res = await _sync.getJsonObject(indexCollection);
    if (res == null || res.data is! List) return const [];
    return (res.data as List)
        .whereType<Map<String, dynamic>>()
        .map(CloudFile.fromJson)
        .toList();
  }

  /// Reads the index, applies [transform], and writes it back with optimistic
  /// locking, retrying if another device changed it in between.
  Future<void> _commitIndex(
      List<CloudFile> Function(List<CloudFile>) transform) async {
    for (var attempt = 0; attempt < 4; attempt++) {
      final res = await _sync.getJsonObject(indexCollection);
      final version = res?.version ?? 0;
      final current = <CloudFile>[];
      if (res != null && res.data is List) {
        current.addAll((res.data as List)
            .whereType<Map<String, dynamic>>()
            .map(CloudFile.fromJson));
      }
      final next = transform(current);
      try {
        await _sync.putJsonObject(
          indexCollection,
          next.map((f) => f.toJson()).toList(),
          baseVersion: version,
        );
        _files = [...next]..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        return;
      } on SyncApiException catch (e) {
        if (e.isConflict && attempt < 3) continue; // retry on a lost race
        rethrow;
      }
    }
    throw const CloudFilesException(
        'Could not update the file list — please try again.');
  }

  Future<void> _rollback(List<String> collections) async {
    for (final c in collections) {
      try {
        await _sync.deleteObject(c);
      } catch (_) {}
    }
  }

  static String _chunkName(String id, int index) => 'cf_${id}_$index';

  static String _randomId() {
    final bytes = SyncCrypto.randomBytes(6);
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _friendly(Object e) =>
      e is CloudFilesException ? e.message : e.toString();

  /// Human-readable byte size (e.g. "2.4 MB").
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
