import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persists the Pagoda Test's List/Banners toggle as a tiny JSON file in the
/// app support directory — the same pattern as the other plugins'
/// `*_settings.json` files (see e.g. Usage's `luma_usage_settings.json`).
class PagodaViewPrefs {
  static File? _file;

  static Future<File> _prefsFile() async {
    final cached = _file;
    if (cached != null) return cached;
    final dir = await getApplicationSupportDirectory();
    return _file = File('${dir.path}/luma_pagoda_view.json');
  }

  /// Whether the banner grid was active the last time the page was left.
  /// Defaults to the list view when nothing was saved (or the file is bad).
  static Future<bool> loadBannerView() async {
    try {
      final file = await _prefsFile();
      if (!await file.exists()) return false;
      final data = jsonDecode(await file.readAsString());
      if (data is Map<String, dynamic>) {
        return data['banners'] as bool? ?? false;
      }
    } catch (_) {
      // Best-effort load; the list default stands on any failure.
    }
    return false;
  }

  static Future<void> saveBannerView(bool banners) async {
    try {
      final file = await _prefsFile();
      await file.writeAsString(jsonEncode({'banners': banners}));
    } catch (_) {
      // Best-effort save; a failure here shouldn't crash the app.
    }
  }
}
