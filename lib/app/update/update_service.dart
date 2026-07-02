import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'app_version.dart';

/// A newer release found on GitHub, ready to be applied.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.tagName,
    required this.notes,
    required this.downloadUrl,
    required this.assetName,
  });

  final String version;
  final String tagName;
  final String notes;
  final String downloadUrl;
  final String assetName;
}

/// Checks GitHub Releases for a newer build and, on Windows, downloads and
/// silently runs the Inno Setup installer to update in place.
///
/// luma installs per-user (to `%LOCALAPPDATA%\Programs\luma`, see
/// `windows/installer/luma.iss`), so the installer needs no admin rights and
/// can be re-run silently by the app itself: `luma-setup.exe /VERYSILENT`
/// closes the running app, overwrites its files, and relaunches it — no
/// manual file copying or elevation needed.
class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _apiBase = 'https://api.github.com';

  /// Returns update details if the latest published release is newer than the
  /// running build, otherwise null. Never throws — network/parse failures just
  /// mean "no update right now".
  Future<UpdateInfo?> checkForUpdate() async {
    if (!AppVersion.isReleaseBuild || !Platform.isWindows) return null;
    try {
      final uri = Uri.parse(
        '$_apiBase/repos/${AppVersion.repoOwner}/${AppVersion.repoName}/releases/latest',
      );
      final res = await _client.get(uri, headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      }).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['draft'] == true || json['prerelease'] == true) return null;

      final tag = (json['tag_name'] as String?)?.trim() ?? '';
      if (tag.isEmpty) return null;
      if (AppVersion.compare(tag, AppVersion.current) <= 0) return null;

      final assets = (json['assets'] as List?) ?? const [];
      Map<String, dynamic>? installerAsset;
      for (final a in assets) {
        if (a is Map<String, dynamic> &&
            (a['name'] as String?)?.toLowerCase().endsWith('setup.exe') ==
                true) {
          installerAsset = a;
          break;
        }
      }
      if (installerAsset == null) return null;

      return UpdateInfo(
        version: tag.replaceFirst(RegExp(r'^[vV]'), ''),
        tagName: tag,
        notes: (json['body'] as String?)?.trim() ?? '',
        downloadUrl: installerAsset['browser_download_url'] as String,
        assetName: installerAsset['name'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  /// Downloads the installer and launches it silently. On success this calls
  /// [exit] and does not return — the installer closes this process, updates
  /// the files, and relaunches the app on its own. Returns false if anything
  /// fails before the hand-off.
  Future<bool> applyUpdate(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final installerPath =
          '${Directory.systemTemp.path}/${info.assetName}';
      final bytes = await _download(info.downloadUrl, onProgress);
      if (bytes == null) return false;
      await File(installerPath).writeAsBytes(bytes);

      // /VERYSILENT: no UI. /SUPPRESSMSGBOXES: no prompts. /NORESTART: never
      // reboot. CloseApplications=yes (set in the .iss) handles closing the
      // running luma.exe, and the [Run] entry relaunches it afterward.
      await Process.start(
        installerPath,
        ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'],
        mode: ProcessStartMode.detached,
      );
      exit(0);
    } catch (_) {
      return false;
    }
  }

  Future<List<int>?> _download(
    String url,
    void Function(double)? onProgress,
  ) async {
    final req = http.Request('GET', Uri.parse(url));
    final res = await _client.send(req);
    if (res.statusCode != 200) return null;
    final total = res.contentLength ?? 0;
    final bytes = <int>[];
    await for (final chunk in res.stream) {
      bytes.addAll(chunk);
      if (total > 0) onProgress?.call(bytes.length / total);
    }
    return bytes;
  }
}
