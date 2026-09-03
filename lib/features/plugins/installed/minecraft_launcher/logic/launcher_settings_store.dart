import 'dart:convert';
import 'dart:io';

import 'mc_paths.dart';

/// Tiny local JSON key/value store for launcher-wide settings that don't fit
/// the per-instance Drift schema — currently just the user's own Azure AD
/// client ID, which is required before Microsoft (online-mode) sign-in can
/// work (see `microsoft_auth_client.dart`).
class LauncherSettingsStore {
  const LauncherSettingsStore._();

  static Future<File> _file() async {
    final root = await McPaths.root();
    return File('${root.path}${Platform.pathSeparator}launcher_settings.json');
  }

  static Future<Map<String, dynamic>> _read() async {
    final file = await _file();
    if (!await file.exists()) return {};
    try {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _write(Map<String, dynamic> data) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(data));
  }

  static Future<String?> getMicrosoftClientId() async => (await _read())['msClientId'] as String?;

  static Future<void> setMicrosoftClientId(String? clientId) async {
    final data = await _read();
    if (clientId == null || clientId.isEmpty) {
      data.remove('msClientId');
    } else {
      data['msClientId'] = clientId;
    }
    await _write(data);
  }
}
