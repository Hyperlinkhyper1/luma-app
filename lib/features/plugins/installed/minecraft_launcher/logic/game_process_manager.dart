import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'mc_paths.dart';

class GameProcessException implements Exception {
  GameProcessException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A running (or just-finished) game launch: live log lines plus the eventual
/// exit code, and a way to force-quit it.
class GameProcessHandle {
  GameProcessHandle({
    required this.logLines,
    required this.exitCode,
    required this.kill,
    required this.logFilePath,
  });

  final Stream<String> logLines;
  final Future<int> exitCode;
  final void Function() kill;
  final String logFilePath;
}

/// Launches the Minecraft client process and streams its combined
/// stdout/stderr, mirroring `YtDlpManager`'s process-piping pattern: start
/// the process, decode+line-split both streams, forward every line to a
/// broadcast controller, and also append it to a per-launch log file under
/// `instances/<id>/logs/`.
class GameProcessManager {
  const GameProcessManager._();

  static Future<GameProcessHandle> launch({
    required String instanceId,
    required String javaPath,
    required List<String> args,
    required String workingDirectory,
  }) async {
    final logsDir = await McPaths.instanceSubDir(instanceId, 'logs');
    final logFile = File(
        '${logsDir.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}.log');
    final logSink = logFile.openWrite();

    final Process process;
    try {
      process = await Process.start(javaPath, args, workingDirectory: workingDirectory);
    } catch (e) {
      await logSink.close();
      throw GameProcessException('Could not start Java: $e');
    }

    final controller = StreamController<String>.broadcast();

    Future<void> forward(Stream<List<int>> source) {
      return source
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .forEach((line) {
        controller.add(line);
        logSink.writeln(line);
      });
    }

    // Both output streams must be fully drained before the sink/controller
    // close — the process's exitCode can complete while lines are still in
    // flight, and writing to a closed sink throws.
    final drained = Future.wait([
      forward(process.stdout).catchError((_) {}),
      forward(process.stderr).catchError((_) {}),
    ]);

    final exitFuture = process.exitCode.then((code) async {
      await drained;
      await controller.close();
      await logSink.flush();
      await logSink.close();
      return code;
    });

    return GameProcessHandle(
      logLines: controller.stream,
      exitCode: exitFuture,
      kill: process.kill,
      logFilePath: logFile.path,
    );
  }
}
