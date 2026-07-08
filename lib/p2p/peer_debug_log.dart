import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A small rotating debug log for diagnosing P2P connection issues on builds
/// with no visible console (an installed/release build, or an IDE run
/// without an attached terminal). Lives at `luma_p2p_debug.log` next to
/// `luma_p2p.json`, capped in size, and surfaced in the Devices settings
/// section via [readP2pDebugLog] so it can be copied out without needing
/// file-system access.
const _fileName = 'luma_p2p_debug.log';
const _maxBytes = 128 * 1024;

Future<File?>? _fileFuture;

Future<File?> _file() => _fileFuture ??= () async {
      try {
        final dir = await getApplicationSupportDirectory();
        return File('${dir.path}${Platform.pathSeparator}$_fileName');
      } catch (_) {
        return null;
      }
    }();

// Multiple PeerLinks/connections can log concurrently (that's the whole
// point of this log). Without serializing the actual file appends, two
// concurrent writeAsString(..., mode: append) calls race and interleave,
// producing garbled lines — observed in practice as one log line's tail
// splicing into the middle of another. Same Future-chaining pattern as
// PeerLink's own `_writeQueue`.
Future<void> _writeTail = Future.value();

Future<void> _enqueue(Future<void> Function() action) {
  final result = _writeTail.then((_) => action());
  _writeTail = result.then((_) {}, onError: (_) {});
  return result;
}

/// Appends a timestamped line. Best-effort and fire-and-forget: failures are
/// swallowed, and callers never await this — it must never slow down or
/// break the actual P2P read/write path it's diagnosing.
void logP2pDebug(String line) {
  unawaited(_enqueue(() async {
    try {
      final file = await _file();
      if (file == null) return;
      await file.writeAsString('${DateTime.now().toIso8601String()} $line\n',
          mode: FileMode.append, flush: true);
      if (await file.length() > _maxBytes) {
        final content = await file.readAsString();
        await file.writeAsString(
            content.substring(content.length - _maxBytes ~/ 2));
      }
    } catch (_) {
      // Best effort only — never let logging itself throw.
    }
  }));
}

/// Reads the current log content, or a placeholder if there isn't one yet.
Future<String> readP2pDebugLog() async {
  try {
    final file = await _file();
    if (file == null || !await file.exists()) return 'No debug log yet.';
    final content = await file.readAsString();
    return content.trim().isEmpty ? 'No debug log yet.' : content;
  } catch (e) {
    return 'Could not read debug log: $e';
  }
}

/// Clears the log (e.g. right before reproducing an issue, to cut noise).
Future<void> clearP2pDebugLog() => _enqueue(() async {
      try {
        final file = await _file();
        if (file != null && await file.exists()) await file.writeAsString('');
      } catch (_) {
        // Best effort only.
      }
    });
