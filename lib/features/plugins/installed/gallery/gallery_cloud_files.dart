import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Tells cloud placeholders apart from files that are really on this disk.
///
/// OneDrive (and Dropbox, and iCloud on Windows) can leave a file listed in
/// the folder while its contents live only in the cloud — "Files On-Demand".
/// The placeholder looks like an ordinary file to `dart:io`, and the moment
/// anything *reads* it the OS silently downloads the whole thing. Listing a
/// folder and calling `stat` are safe; opening it is not.
///
/// That matters here more than almost anywhere: a gallery's first instinct is
/// to decode a thumbnail for every picture it finds, which for a OneDrive
/// Pictures folder would quietly pull someone's entire photo library onto
/// their disk. So the scan asks this first, and never opens a file that isn't
/// already local.
class CloudFiles {
  const CloudFiles._();

  /// Attributes Windows sets on a file whose contents have to be fetched
  /// before they can be read.
  ///
  /// * `RECALL_ON_DATA_ACCESS` — a dehydrated OneDrive placeholder.
  /// * `RECALL_ON_OPEN` — the older, whole-file recall flag.
  /// * `OFFLINE` — set by remote-storage and archival filters generally.
  ///
  /// A file that OneDrive has synced down ("Always keep on this device", or
  /// simply one that has been opened) carries none of them and reads without
  /// touching the network.
  static const _recallMask = FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS |
      FILE_ATTRIBUTE_RECALL_ON_OPEN |
      FILE_ATTRIBUTE_OFFLINE;

  /// GetFileAttributesW's failure return — the path is gone, or we aren't
  /// allowed to look at it.
  static const _invalidAttributes = 0xFFFFFFFF;

  /// Whether reading [path] would download it. False on anything that isn't
  /// Windows: no other platform this app ships on has placeholder files.
  ///
  /// Errs towards "local" when the answer can't be had — a file we can't
  /// stat is one the scan will fail on anyway, and refusing to thumbnail
  /// every unreadable file would be worse than trying once.
  static bool isCloudOnly(String path) {
    if (!Platform.isWindows) return false;
    final native = path.toNativeUtf16();
    try {
      final attributes = GetFileAttributes(native);
      if (attributes == _invalidAttributes) return false;
      return attributes & _recallMask != 0;
    } catch (_) {
      return false;
    } finally {
      calloc.free(native);
    }
  }
}
