import 'dart:io';

/// Design vs. full-charge capacity, parsed out of `powercfg /batteryreport`.
/// Win32_Battery rarely reports these two fields directly (confirmed absent
/// on test hardware), so this is the only realistic source for battery wear.
class BatteryWear {
  const BatteryWear({
    required this.present,
    this.designCapacity,
    this.fullChargeCapacity,
  });

  final bool present;

  /// Both in mWh. Either can be null even when a battery is present — some
  /// OEM firmware just doesn't report them.
  final int? designCapacity;
  final int? fullChargeCapacity;
}

/// Generates and parses a `powercfg /batteryreport`. No elevation required —
/// `powercfg` writes the report as the current user.
class BatteryReportService {
  const BatteryReportService();

  Future<BatteryWear?> fetchWear() async {
    if (!Platform.isWindows) return null;
    Directory? dir;
    try {
      dir = await Directory.systemTemp.createTemp('luma_battery_report_');
      final path = '${dir.path}${Platform.pathSeparator}battery_report.html';
      final result = await Process.run(
        'powercfg',
        ['/batteryreport', '/output', path],
      ).timeout(const Duration(seconds: 15));
      if (result.exitCode != 0) return null;
      final file = File(path);
      if (!await file.exists()) return null;
      final html = await file.readAsString();
      return parse(html);
    } catch (_) {
      return null;
    } finally {
      if (dir != null) {
        try {
          await dir.delete(recursive: true);
        } catch (_) {
          // Best-effort cleanup of a scratch temp dir; nothing to recover.
        }
      }
    }
  }

  /// Pure parse of the report's HTML — flattens tags to plain text so it
  /// doesn't depend on the exact markup, only on the labels appearing before
  /// their values in reading order (true of every powercfg report layout).
  static BatteryWear parse(String html) {
    final text = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
    if (text.contains('No batteries are currently installed')) {
      return const BatteryWear(present: false);
    }
    return BatteryWear(
      present: true,
      designCapacity: _mwhAfter(text, 'DESIGN CAPACITY'),
      fullChargeCapacity: _mwhAfter(text, 'FULL CHARGE CAPACITY'),
    );
  }

  static int? _mwhAfter(String text, String label) {
    final idx = text.indexOf(label);
    if (idx == -1) return null;
    final match =
        RegExp(r'([\d,]+)\s*mWh').firstMatch(text.substring(idx + label.length));
    if (match == null) return null;
    return int.tryParse(match.group(1)!.replaceAll(',', ''));
  }
}
