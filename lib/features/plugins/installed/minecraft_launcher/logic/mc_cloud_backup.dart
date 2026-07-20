import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../../../../../sync/sync_api.dart';
import '../../../../../sync/sync_crypto.dart';
import '../../../../../sync/sync_service.dart';

/// One world-save or screenshot backed up to the sync server. The actual
/// bytes live as one or more encrypted chunk blobs (same primitives the
/// Cloud Files plugin uses — see `SyncService.putObject`/`getObject`); this
/// record, kept in its own encrypted index (separate from Cloud Files' own
/// index, so save backups don't clutter that plugin's file list), says how
/// to find and reassemble them.
class McCloudBackupEntry {
  const McCloudBackupEntry({
    required this.id,
    required this.instanceId,
    required this.kind,
    required this.label,
    required this.size,
    required this.chunks,
    required this.uploadedAt,
  });

  /// Random hex id; chunk blobs are named `mc_<id>_<n>`.
  final String id;
  final String instanceId;

  /// 'world' or 'screenshot'.
  final String kind;

  /// World name or screenshot file name, shown to the user.
  final String label;
  final int size;
  final int chunks;
  final DateTime uploadedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'instanceId': instanceId,
        'kind': kind,
        'label': label,
        'size': size,
        'chunks': chunks,
        'uploadedAt': uploadedAt.toIso8601String(),
      };

  factory McCloudBackupEntry.fromJson(Map<String, dynamic> j) => McCloudBackupEntry(
        id: j['id'] as String,
        instanceId: j['instanceId'] as String,
        kind: j['kind'] as String,
        label: j['label'] as String,
        size: (j['size'] as num).toInt(),
        chunks: (j['chunks'] as num?)?.toInt() ?? 1,
        uploadedAt: DateTime.tryParse(j['uploadedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class McCloudBackupException implements Exception {
  const McCloudBackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Chunked upload/download of Minecraft world saves and screenshots against
/// the same end-to-end-encrypted sync server the Cloud Files plugin uses,
/// via `SyncService`'s generic per-collection blob primitives directly
/// (rather than going through `CloudFilesController`, so these backups get
/// their own index and don't show up mixed into the user's regular Cloud
/// Files list).
class McCloudBackup {
  McCloudBackup(this._sync);
  final SyncService _sync;

  static const String indexCollection = 'minecraft_cloud_index';
  static const int chunkSize = 8 * 1024 * 1024; // 8 MiB

  bool get signedIn => _sync.signedIn;

  Future<List<McCloudBackupEntry>> list({String? instanceId}) async {
    final entries = await _readIndex();
    if (instanceId == null) return entries;
    return entries.where((e) => e.instanceId == instanceId).toList()
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
  }

  Future<void> uploadFile({
    required String instanceId,
    required String kind,
    required String label,
    required File file,
    void Function(double)? onProgress,
  }) async {
    if (!signedIn) {
      throw const McCloudBackupException('Sign in under Settings → Sync first.');
    }

    final size = await file.length();
    final id = _randomId();
    final chunkCount = size <= 0 ? 1 : ((size + chunkSize - 1) ~/ chunkSize);
    final uploaded = <String>[];

    final raf = await file.open();
    try {
      var sent = 0;
      for (var i = 0; i < chunkCount; i++) {
        final len = size <= 0 ? 0 : min(chunkSize, size - sent);
        final bytes = len == 0 ? Uint8List(0) : await raf.read(len);
        await _sync.putObject(_chunkName(id, i), bytes);
        uploaded.add(_chunkName(id, i));
        sent += len;
        onProgress?.call(size <= 0 ? 1 : sent / size);
      }

      final entry = McCloudBackupEntry(
        id: id,
        instanceId: instanceId,
        kind: kind,
        label: label,
        size: size,
        chunks: chunkCount,
        uploadedAt: DateTime.now(),
      );
      await _commitIndex((list) => [...list, entry]);
    } on SyncApiException catch (e) {
      await _rollback(uploaded);
      throw McCloudBackupException(
          e.code == 'quota_exceeded' ? 'Not enough cloud storage space.' : e.message);
    } catch (e) {
      await _rollback(uploaded);
      throw McCloudBackupException('$e');
    } finally {
      await raf.close();
    }
  }

  Future<void> downloadToFile(
    McCloudBackupEntry entry,
    String savePath, {
    void Function(double)? onProgress,
  }) async {
    if (!signedIn) {
      throw const McCloudBackupException('Sign in under Settings → Sync first.');
    }
    final out = await File(savePath).open(mode: FileMode.write);
    try {
      var written = 0;
      for (var i = 0; i < entry.chunks; i++) {
        final bytes = await _sync.getObject(_chunkName(entry.id, i));
        if (bytes == null) {
          throw const McCloudBackupException('Part of this backup is missing on the server.');
        }
        await out.writeFrom(bytes);
        written += bytes.length;
        onProgress?.call(entry.size <= 0 ? 1 : written / entry.size);
      }
    } on SyncApiException catch (e) {
      throw McCloudBackupException(e.message);
    } on SyncCryptoException catch (e) {
      throw McCloudBackupException(e.message);
    } finally {
      await out.close();
    }
  }

  Future<void> delete(McCloudBackupEntry entry) async {
    await _commitIndex((list) => list.where((e) => e.id != entry.id).toList());
    for (var i = 0; i < entry.chunks; i++) {
      try {
        await _sync.deleteObject(_chunkName(entry.id, i));
      } catch (_) {
        // Best effort; an orphaned chunk only wastes a little quota.
      }
    }
  }

  Future<List<McCloudBackupEntry>> _readIndex() async {
    final res = await _sync.getJsonObject(indexCollection);
    if (res == null || res.data is! List) return const [];
    return (res.data as List)
        .whereType<Map<String, dynamic>>()
        .map(McCloudBackupEntry.fromJson)
        .toList();
  }

  Future<void> _commitIndex(
    List<McCloudBackupEntry> Function(List<McCloudBackupEntry>) transform,
  ) async {
    for (var attempt = 0; attempt < 4; attempt++) {
      final res = await _sync.getJsonObject(indexCollection);
      final version = res?.version ?? 0;
      final current = <McCloudBackupEntry>[];
      if (res != null && res.data is List) {
        current.addAll((res.data as List)
            .whereType<Map<String, dynamic>>()
            .map(McCloudBackupEntry.fromJson));
      }
      final next = transform(current);
      try {
        await _sync.putJsonObject(
          indexCollection,
          next.map((e) => e.toJson()).toList(),
          baseVersion: version,
        );
        return;
      } on SyncApiException catch (e) {
        if (e.isConflict && attempt < 3) continue; // retry on a lost race
        rethrow;
      }
    }
    throw const McCloudBackupException('Could not update the backup list — please try again.');
  }

  Future<void> _rollback(List<String> chunkNames) async {
    for (final c in chunkNames) {
      try {
        await _sync.deleteObject(c);
      } catch (_) {
        // Ignore — rollback is already best-effort cleanup.
      }
    }
  }

  static String _chunkName(String id, int index) => 'mc_${id}_$index';

  static String _randomId() {
    final bytes = SyncCrypto.randomBytes(6);
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
