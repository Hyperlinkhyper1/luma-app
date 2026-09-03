import 'dart:io';

import '../device_health_models.dart';

/// App updates, entirely through `winget` — Windows' own package manager,
/// which verifies publisher signatures before installing anything. luma
/// never downloads or runs an installer itself for this category.
///
/// `winget upgrade` has no `--output json` in the installed version (checked
/// directly: `winget upgrade --help` lists no such flag), so this parses its
/// column-aligned table output instead, using the header row itself to find
/// each column's offset rather than hardcoding widths.
class WingetService {
  const WingetService();

  /// Null means winget isn't available on this machine at all (not
  /// installed, or too old to run) — different from "no updates found",
  /// which is an empty list.
  Future<List<AppUpdateInfo>?> listUpgrades() async {
    try {
      final result = await Process.run(
        'winget',
        [
          'upgrade',
          '--include-unknown',
          '--accept-source-agreements',
        ],
      ).timeout(const Duration(seconds: 30));
      final stdout = result.stdout is String
          ? result.stdout as String
          : result.stdout.toString();
      return parseUpgradeList(stdout);
    } catch (_) {
      return null;
    }
  }

  /// Applies one update. `silentEligible` (plain `winget` source) upgrades
  /// end to end unattended; anything else (e.g. `msstore`) may still prompt —
  /// callers should surface that rather than assume silence.
  Future<AppUpdateJobState> upgrade(AppUpdateInfo info) async {
    try {
      final result = await Process.run(
        'winget',
        [
          'upgrade',
          '--id', info.id,
          '--silent',
          '--accept-package-agreements',
          '--accept-source-agreements',
          '--disable-interactivity',
        ],
      ).timeout(const Duration(minutes: 5));
      if (result.exitCode == 0) return AppUpdateJobState.done;
      return AppUpdateJobState.needsElevationOrManual;
    } catch (_) {
      return AppUpdateJobState.failed;
    }
  }

  /// Pure parse of `winget upgrade`'s table — public so it can be unit
  /// tested against real captured output.
  static List<AppUpdateInfo> parseUpgradeList(String stdout) {
    final lines = stdout.split(RegExp(r'\r?\n'));
    final headerIndex = lines.indexWhere((l) {
      final t = l.trimRight();
      return t.startsWith('Name') && t.contains('Id') &&
          t.contains('Version') && t.contains('Available') &&
          t.contains('Source');
    });
    if (headerIndex == -1) return const [];

    final header = lines[headerIndex];
    final nameIdx = header.indexOf('Name');
    final idIdx = header.indexOf('Id', nameIdx + 4);
    final versionIdx = header.indexOf('Version', idIdx + 2);
    final availableIdx = header.indexOf('Available', versionIdx + 7);
    final sourceIdx = header.indexOf('Source', availableIdx + 9);
    if ([idIdx, versionIdx, availableIdx, sourceIdx].contains(-1)) {
      return const [];
    }

    final results = <AppUpdateInfo>[];
    // Row 1 after the header is the '---' separator; data starts at +2.
    for (var i = headerIndex + 2; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) break;
      if (line.length < availableIdx) break;
      // Pad rather than slice-out-of-range: a row whose Source column is
      // empty can be shorter than the header once trailing spaces are gone.
      final padded = line.length < sourceIdx ? line.padRight(sourceIdx) : line;

      final name = padded.substring(nameIdx, idIdx).trim();
      final id = padded.substring(idIdx, versionIdx).trim();
      final version = padded.substring(versionIdx, availableIdx).trim();
      final available = padded.substring(availableIdx, sourceIdx).trim();
      final source = line.length > sourceIdx ? line.substring(sourceIdx).trim() : '';

      if (name.isEmpty || id.isEmpty) continue;
      results.add(AppUpdateInfo(
        id: id,
        name: name,
        currentVersion: version,
        availableVersion: available,
        source: switch (source.toLowerCase()) {
          'winget' => UpdateSource.winget,
          'msstore' => UpdateSource.msstore,
          _ => UpdateSource.other,
        },
      ));
    }
    return results;
  }
}
