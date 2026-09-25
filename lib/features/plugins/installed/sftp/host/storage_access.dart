import 'dart:io';

import 'package:flutter/services.dart';

/// Whether luma may read the files other apps keep in Android's shared
/// storage — the camera's DCIM folder, Download, and so on.
///
/// Without it, scoped storage quietly hides every file another app created:
/// a shared Camera folder lists as empty on the device browsing it, with no
/// error anywhere. On Android 11+ this is the "All files access" setting
/// (`MANAGE_EXTERNAL_STORAGE`); on 10 and older the legacy storage grant.
/// Everywhere else there is nothing to ask for.
class HostStorageAccess {
  const HostStorageAccess._();

  static const _channel = MethodChannel('luma/storage_access');

  /// True when the platform has no such restriction, or it has been granted.
  static Future<bool> granted() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('hasAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Sends the user to the system screen that grants it, and completes with
  /// the answer once they come back.
  static Future<bool> request() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('requestAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Whether [path] is in shared storage, where the grant matters. luma's own
  /// app folders are readable without it.
  static bool isSharedStoragePath(String path) {
    if (!Platform.isAndroid) return false;
    return path.startsWith('/storage/') || path.startsWith('/sdcard');
  }
}
