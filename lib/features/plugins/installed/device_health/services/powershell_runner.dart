import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Result of a PowerShell invocation. [ok] is exit code 0; callers still get
/// [stdout]/[stderr] on failure so they can surface a real reason.
class PowerShellResult {
  const PowerShellResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final String stdout;
  final String stderr;
  final int exitCode;

  bool get ok => exitCode == 0;
}

/// Runs PowerShell scripts for the Device Health plugin. Every script is
/// shipped via `-EncodedCommand` (base64 of UTF-16LE) rather than as a quoted
/// `-Command` string — this sidesteps PowerShell/cmd quoting entirely, which
/// matters here since several scripts embed quotes of their own.
///
/// Windows only, matching the rest of Device Health — every entry point
/// checks [Platform.isWindows] first and returns a clear "unsupported"
/// result rather than attempting to spawn `powershell.exe` elsewhere.
class PowerShellRunner {
  const PowerShellRunner._();

  static const _unsupported = PowerShellResult(
    stdout: '',
    stderr: 'Device Health is Windows only.',
    exitCode: -1,
  );

  /// Runs [script] and waits for it to finish, returning its output.
  static Future<PowerShellResult> run(
    String script, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (!Platform.isWindows) return _unsupported;
    try {
      final result = await Process.run(
        'powershell.exe',
        _argsFor(script),
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(timeout);
      return PowerShellResult(
        stdout: result.stdout as String,
        stderr: result.stderr as String,
        exitCode: result.exitCode,
      );
    } catch (e) {
      return PowerShellResult(stdout: '', stderr: '$e', exitCode: -1);
    }
  }

  /// Starts [script] and returns immediately without waiting for it to
  /// finish — for actions like triggering a Defender scan, which can run for
  /// a long time and shouldn't block the UI on completion. Returns whether
  /// the process was launched at all, not whether it later succeeded.
  static Future<bool> startDetached(String script) async {
    if (!Platform.isWindows) return false;
    try {
      await Process.start(
        'powershell.exe',
        _argsFor(script),
        mode: ProcessStartMode.detached,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static List<String> _argsFor(String script) {
    final withEncoding = '\$OutputEncoding = [System.Text.Encoding]::UTF8; '
        '[Console]::OutputEncoding = [System.Text.Encoding]::UTF8;\n$script';
    final encoded = base64.encode(_utf16leBytes(withEncoding));
    return [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-EncodedCommand',
      encoded,
    ];
  }

  static Uint8List _utf16leBytes(String s) {
    final bytes = Uint8List(s.length * 2);
    for (var i = 0; i < s.length; i++) {
      final unit = s.codeUnitAt(i);
      bytes[i * 2] = unit & 0xFF;
      bytes[i * 2 + 1] = (unit >> 8) & 0xFF;
    }
    return bytes;
  }
}

/// Parses a WCF/JSON.NET date like `/Date(1777507200000)/` — the shape
/// `ConvertTo-Json` produces for `[DateTime]` properties in Windows
/// PowerShell 5.1. Returns null for anything else (including a plain null).
DateTime? parseCimDate(dynamic value) {
  if (value == null) return null;
  final match = RegExp(r'/Date\((-?\d+)\)/').firstMatch(value.toString());
  if (match == null) return null;
  final ms = int.tryParse(match.group(1)!);
  if (ms == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
}
