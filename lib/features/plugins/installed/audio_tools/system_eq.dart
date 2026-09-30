import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'eq.dart';

/// The curve file the system-wide EQ reads (%ProgramData%\luma\apo\eq.bin).
///
/// Fixed-size little-endian binary whose layout mirrors
/// `windows/luma_apo/eq_config.h`, so change both together.
abstract final class SystemEqConfig {
  static const magic = 0x4F50414C;
  static const version = 1;
  static const maxBands = 16;
  static const headerBytes = 20;
  static const bandBytes = 20;
  static const bytes = headerBytes + maxBands * bandBytes;

  static Uint8List encode(EqSettings eq, {required bool enabled}) {
    final data = ByteData(bytes);
    final bands = eq.bands.take(maxBands).toList();
    data
      ..setUint32(0, magic, Endian.little)
      ..setUint32(4, version, Endian.little)
      ..setUint32(8, enabled ? 1 : 0, Endian.little)
      ..setFloat32(12, eq.preampDb, Endian.little)
      ..setUint32(16, bands.length, Endian.little);
    for (var i = 0; i < bands.length; i++) {
      final b = bands[i];
      final o = headerBytes + i * bandBytes;
      data
        ..setUint32(o, b.type.index, Endian.little)
        ..setUint32(o + 4, b.enabled ? 1 : 0, Endian.little)
        ..setFloat32(o + 8, b.frequency, Endian.little)
        ..setFloat32(o + 12, b.gainDb, Endian.little)
        ..setFloat32(o + 16, b.q, Endian.little);
    }
    return data.buffer.asUint8List();
  }
}

/// How an install or uninstall went; mirrors `ExitCode` in
/// `windows/luma_apo/setup.cpp`.
enum SystemEqResult {
  ok,
  restartNeeded,
  cancelled,
  failed,
  missing,
  noDevice,
  incompatible,
  micNotRecording;

  static SystemEqResult fromExitCode(int code) => switch (code) {
    0 => ok,
    3 => cancelled,
    4 => missing,
    5 => restartNeeded,
    6 => noDevice,
    7 => incompatible,
    8 => micNotRecording,
    _ => failed,
  };

  bool get succeeded => this == ok || this == restartNeeded;
}

class SystemEqStatus {
  const SystemEqStatus({
    this.installed = false,
    this.current = true,
    this.endpoints = const {},
  });

  static const none = SystemEqStatus();

  final bool installed;

  /// False when luma was updated but Program Files still holds the older
  /// APO, which only an elevated reinstall can replace.
  final bool current;

  /// Capture device ids (as [AudioDevice.id]) the EQ is attached to.
  final Set<String> endpoints;

  factory SystemEqStatus.fromJson(Map<String, dynamic> json) => SystemEqStatus(
    installed: json['installed'] == true,
    current: json['current'] != false,
    endpoints: {
      for (final e in (json['endpoints'] as List? ?? const []))
        if (e is String) e.toLowerCase(),
    },
  );
}

/// Talks to `luma_apo_setup.exe`, the elevated helper that puts luma's EQ on
/// a microphone inside Windows itself (an Audio Processing Object), so apps
/// like Discord hear it without a virtual cable. The helper raises the UAC
/// prompt itself; everything here runs unelevated.
class SystemEq {
  SystemEq({this.appDirectory, this.configPathOverride});

  final String? appDirectory;
  final String? configPathOverride;

  String get _dir =>
      appDirectory ?? File(Platform.resolvedExecutable).parent.path;

  String get _helper => '$_dir\\luma_apo_setup.exe';

  String get configPath =>
      configPathOverride ??
      '${Platform.environment['ProgramData'] ?? r'C:\ProgramData'}'
          r'\luma\apo\eq.bin';

  /// Only Windows builds ship the APO, and `flutter run` debug builds only
  /// have it once CMake has installed it next to luma.exe.
  bool get available =>
      Platform.isWindows &&
      File(_helper).existsSync() &&
      File('$_dir\\luma_apo.dll').existsSync();

  Future<SystemEqStatus> status() async {
    if (!available) return SystemEqStatus.none;
    try {
      final r = await Process.run(_helper, const ['status']);
      if (r.exitCode != 0) return SystemEqStatus.none;
      final json = jsonDecode((r.stdout as String).trim());
      return json is Map<String, dynamic>
          ? SystemEqStatus.fromJson(json)
          : SystemEqStatus.none;
    } catch (_) {
      return SystemEqStatus.none;
    }
  }

  Future<SystemEqResult> install(String deviceId) =>
      _run(['install', deviceId]);

  Future<SystemEqResult> uninstall(String deviceId) =>
      _run(['uninstall', deviceId]);

  Future<SystemEqResult> _run(List<String> args) async {
    if (!available) return SystemEqResult.missing;
    try {
      final r = await Process.run(_helper, args);
      return SystemEqResult.fromExitCode(r.exitCode);
    } catch (_) {
      return SystemEqResult.failed;
    }
  }

  /// Replaces the curve atomically: the APO polls the file, and a rename
  /// means it never reads a half-written one.
  Future<void> writeConfig(Uint8List bytes) async {
    try {
      final tmp = File('$configPath.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(configPath);
    } catch (_) {
      // Best effort: the directory only exists once the helper made it.
    }
  }
}
