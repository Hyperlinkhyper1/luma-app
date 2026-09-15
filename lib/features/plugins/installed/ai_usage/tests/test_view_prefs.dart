import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persists each test page's List/Banners toggle as a tiny JSON file in the
/// app support directory — the same pattern as the other plugins'
/// `*_settings.json` files (see e.g. Usage's `luma_usage_settings.json`).
///
/// One entry per test kind (`pagoda`, `engine`, `pc`), so the three screens
/// remember their own view rather than sharing one. The Pagoda Test shipped
/// first with its own file; [loadBannerView] still reads that as the pagoda
/// default so nobody's saved choice is thrown away.
class TestViewPrefs {
  static File? _file;
  static File? _legacyFile;
  static Map<String, bool>? _cache;

  static Future<File> _prefsFile() async {
    final cached = _file;
    if (cached != null) return cached;
    final dir = await getApplicationSupportDirectory();
    _legacyFile = File('${dir.path}/luma_pagoda_view.json');
    return _file = File('${dir.path}/luma_test_views.json');
  }

  static Future<Map<String, bool>> _read() async {
    final cached = _cache;
    if (cached != null) return cached;
    final views = <String, bool>{};
    try {
      final file = await _prefsFile();
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        if (data is Map) {
          for (final entry in data.entries) {
            if (entry.key is String && entry.value is bool) {
              views[entry.key as String] = entry.value as bool;
            }
          }
        }
      } else {
        final legacy = _legacyFile;
        if (legacy != null && await legacy.exists()) {
          final data = jsonDecode(await legacy.readAsString());
          if (data is Map && data['banners'] is bool) {
            views['pagoda'] = data['banners'] as bool;
          }
        }
      }
    } catch (_) {
      // Best-effort load; the list default stands on any failure.
    }
    return _cache = views;
  }

  /// Whether the banner grid was active the last time [kind]'s page was left.
  /// Defaults to the list view when nothing was saved (or the file is bad).
  static Future<bool> loadBannerView(String kind) async =>
      (await _read())[kind] ?? false;

  static Future<void> saveBannerView(String kind, bool banners) async {
    try {
      final views = await _read();
      views[kind] = banners;
      final file = await _prefsFile();
      await file.writeAsString(jsonEncode(views));
    } catch (_) {
      // Best-effort save; a failure here shouldn't crash the app.
    }
  }
}
