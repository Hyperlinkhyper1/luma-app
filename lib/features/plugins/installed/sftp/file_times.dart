import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// The dates a file keeps when it is transferred: when it was last changed,
/// last opened, and — where the platform records one — created.
///
/// Without this every copy was stamped with the moment it landed, so a photo
/// taken last summer showed up as made today and sorted to the top of every
/// folder. The bytes (EXIF included) always arrived intact; the file system's
/// own dates did not.
///
/// What each platform can do:
///
/// * **Modified / accessed** — readable and settable everywhere.
/// * **Created** — readable on Windows only (`FileStat.changed` is the
///   creation time there; elsewhere it is the metadata-change time, which is
///   something else). Settable on Windows only, through `SetFileTime`.
///   Android and Linux have no creation time a program can set.
///
/// So when the source has no creation time (a phone, a Linux server), a
/// Windows copy takes the modified time as its creation time: for a photo or
/// a video that *is* when it was made, and it beats Explorer showing the
/// moment of the copy.
class FileTimes {
  const FileTimes({this.modified, this.accessed, this.created});

  final DateTime? modified;
  final DateTime? accessed;
  final DateTime? created;

  bool get isEmpty => modified == null && accessed == null && created == null;

  /// The dates of a local file, or an empty [FileTimes] when it cannot be
  /// stat'd.
  static Future<FileTimes> of(File file) async {
    try {
      final stat = await file.stat();
      if (stat.type == FileSystemEntityType.notFound) return const FileTimes();
      return fromStat(stat);
    } catch (_) {
      return const FileTimes();
    }
  }

  static FileTimes fromStat(FileStat stat) => FileTimes(
        modified: stat.modified,
        accessed: stat.accessed,
        created: Platform.isWindows ? stat.changed : null,
      );

  /// Short keys, like the rest of the host protocol. Milliseconds since the
  /// epoch, UTC, so the two devices' time zones never matter.
  Map<String, dynamic> toWire() => {
        if (modified != null) 'm': modified!.millisecondsSinceEpoch,
        if (accessed != null) 'a': accessed!.millisecondsSinceEpoch,
        if (created != null) 'c': created!.millisecondsSinceEpoch,
      };

  static FileTimes fromWire(Object? raw) {
    if (raw is! Map) return const FileTimes();
    DateTime? read(String key) {
      final value = raw[key];
      if (value is! num) return null;
      final ms = value.toInt();
      // Refuse anything absurd rather than stamp a file with it: before 1980
      // (FAT's floor, and no real photo) or more than a day in the future.
      final earliest = DateTime.utc(1980).millisecondsSinceEpoch;
      final latest = DateTime.now()
          .add(const Duration(days: 1))
          .millisecondsSinceEpoch;
      if (ms < earliest || ms > latest) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }

    return FileTimes(
      modified: read('m'),
      accessed: read('a'),
      created: read('c'),
    );
  }

  /// Stamps these dates onto [file]. Best effort: a file system that will not
  /// take a date (some network shares, some Android storage) still has the
  /// file, and a transfer is never failed over its timestamp.
  Future<void> applyTo(File file) async {
    final modified = this.modified;
    try {
      if (modified != null) await file.setLastModified(modified);
    } catch (_) {}
    try {
      final accessed = this.accessed ?? modified;
      if (accessed != null) await file.setLastAccessed(accessed);
    } catch (_) {}
    if (Platform.isWindows) {
      final created = this.created ?? modified;
      if (created != null) _setWindowsCreationTime(file.path, created);
    }
  }

  /// FILETIME counts 100-nanosecond ticks from 1601-01-01 UTC.
  static const int _fileTimeUnixEpoch = 116444736000000000;

  static void _setWindowsCreationTime(String path, DateTime created) {
    final native = path.toNativeUtf16();
    final time = calloc<FILETIME>();
    var handle = INVALID_HANDLE_VALUE;
    try {
      handle = CreateFile(
        native,
        FILE_WRITE_ATTRIBUTES,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        nullptr,
        OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS,
        NULL,
      );
      if (handle == INVALID_HANDLE_VALUE) return;
      final ticks =
          created.toUtc().microsecondsSinceEpoch * 10 + _fileTimeUnixEpoch;
      time.ref
        ..dwLowDateTime = ticks & 0xFFFFFFFF
        ..dwHighDateTime = (ticks >> 32) & 0xFFFFFFFF;
      // Only the creation time: access and write times were set above
      // through dart:io, and nullptr leaves them as they are.
      SetFileTime(handle, time, nullptr, nullptr);
    } catch (_) {
      // Not worth failing a transfer over.
    } finally {
      if (handle != INVALID_HANDLE_VALUE) CloseHandle(handle);
      calloc.free(time);
      calloc.free(native);
    }
  }
}
