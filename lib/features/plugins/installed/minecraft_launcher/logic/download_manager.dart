import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// One file to fetch: [sha1] is optional (some Mojang metadata omits it) but
/// strongly preferred — without it we can only fall back to a size check to
/// decide whether an existing file is already valid.
class DownloadItem {
  DownloadItem({
    required this.url,
    required this.destPath,
    this.sha1,
    this.size,
    this.label,
  });

  final String url;
  final String destPath;
  final String? sha1;
  final int? size;

  /// Short human-readable name for progress UI (defaults to the file name).
  final String? label;
}

class DownloadManagerException implements Exception {
  DownloadManagerException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DownloadBatchProgress {
  DownloadBatchProgress({
    required this.filesDone,
    required this.filesTotal,
    required this.bytesDone,
    required this.bytesTotal,
    required this.currentFile,
  });

  final int filesDone;
  final int filesTotal;
  final int bytesDone;
  final int bytesTotal;
  final String currentFile;

  double? get fraction => bytesTotal > 0 ? bytesDone / bytesTotal : null;
}

/// Downloads a batch of files with bounded concurrency, verifying content
/// against its expected SHA1 when known, and skipping any file that's
/// already present and valid — so retrying a failed batch (or re-creating an
/// instance that shares libraries/assets with an existing one) is cheap.
class DownloadManager {
  DownloadManager._();
  static final DownloadManager instance = DownloadManager._();

  static const _maxConcurrent = 10;

  Future<void> downloadAll(
    List<DownloadItem> items, {
    void Function(DownloadBatchProgress)? onProgress,
  }) async {
    final totalBytes = items.fold<int>(0, (sum, i) => sum + (i.size ?? 0));
    var doneBytes = 0;
    var doneFiles = 0;
    final totalFiles = items.length;

    void reportDone(DownloadItem item, int bytes) {
      doneFiles++;
      doneBytes += bytes;
      onProgress?.call(DownloadBatchProgress(
        filesDone: doneFiles,
        filesTotal: totalFiles,
        bytesDone: doneBytes,
        bytesTotal: totalBytes,
        currentFile: item.label ?? item.destPath.split(Platform.pathSeparator).last,
      ));
    }

    final queue = List<DownloadItem>.from(items);
    final errors = <String>[];

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final item = queue.removeLast();
        try {
          final bytes = await _downloadOne(item);
          reportDone(item, bytes);
        } catch (e) {
          errors.add('${item.label ?? item.destPath}: $e');
          reportDone(item, item.size ?? 0);
        }
      }
    }

    await Future.wait(List.generate(_maxConcurrent, (_) => worker()));

    if (errors.isNotEmpty) {
      throw DownloadManagerException(
        'Failed to download ${errors.length} file(s):\n${errors.take(5).join('\n')}',
      );
    }
  }

  /// Returns the number of bytes written (0 if the file was already valid
  /// and skipped).
  Future<int> _downloadOne(DownloadItem item) async {
    final file = File(item.destPath);
    if (await _isValid(file, item)) return 0;
    await file.parent.create(recursive: true);

    for (var attempt = 0; attempt < 2; attempt++) {
      final http.Response res;
      try {
        res = await http.get(Uri.parse(item.url)).timeout(const Duration(minutes: 5));
      } catch (_) {
        if (attempt == 1) {
          throw DownloadManagerException('Could not reach ${item.url}.');
        }
        continue;
      }
      if (res.statusCode != 200) {
        if (attempt == 1) {
          throw DownloadManagerException('HTTP ${res.statusCode} for ${item.url}.');
        }
        continue;
      }
      if (item.sha1 != null && item.sha1!.isNotEmpty) {
        final actual = sha1.convert(res.bodyBytes).toString();
        if (actual != item.sha1) {
          if (attempt == 1) {
            throw DownloadManagerException('Checksum mismatch for ${item.destPath}.');
          }
          continue;
        }
      }
      await file.writeAsBytes(res.bodyBytes);
      return res.bodyBytes.length;
    }
    throw DownloadManagerException('Failed to download ${item.url}.');
  }

  Future<bool> _isValid(File file, DownloadItem item) async {
    if (!await file.exists()) return false;
    if (item.sha1 != null && item.sha1!.isNotEmpty) {
      final bytes = await file.readAsBytes();
      return sha1.convert(bytes).toString() == item.sha1;
    }
    if (item.size != null) {
      return await file.length() == item.size;
    }
    return true;
  }
}
