import 'command_models.dart';

enum RunStatus { idle, starting, running, exited, failed }

/// What a host's port looks like right now. Rebuilt on every poll.
class HostStatus {
  const HostStatus({
    required this.port,
    required this.listening,
    this.clients = const [],
    this.rojoProject,
    this.rojoVersion,
  });

  final int port;

  /// Something accepted a TCP connection on 127.0.0.1:[port].
  final bool listening;

  /// Established connections into the port (Roblox Studio's Rojo plugin,
  /// a browser tab on a dev server, …).
  final List<HostConnection> clients;

  /// Filled when the port answers Rojo's `/api/rojo` info endpoint.
  final String? rojoProject;
  final String? rojoVersion;

  bool get isRojo => rojoVersion != null;
}

/// The live state of one command's latest run.
class CommandRun {
  CommandRun();

  static const maxLines = 2000;

  RunStatus status = RunStatus.idle;
  int? exitCode;
  String? error;
  DateTime? startedAt;
  DateTime? endedAt;

  /// The process Stop has to kill: the cmd.exe luma piped, or the PID the
  /// launcher reported for an elevated / own-window run.
  int? pid;
  bool elevated = false;

  /// Ended because the user pressed Stop, so a non-zero exit isn't a failure.
  bool stopped = false;
  int? detectedPort;
  HostStatus? host;

  final List<String> lines = [];

  bool get isActive =>
      status == RunStatus.starting || status == RunStatus.running;

  void addLine(String line) {
    lines.add(line);
    if (lines.length > maxLines) lines.removeRange(0, lines.length - maxLines);
  }

  void reset() {
    status = RunStatus.starting;
    exitCode = null;
    error = null;
    startedAt = DateTime.now();
    endedAt = null;
    pid = null;
    elevated = false;
    stopped = false;
    detectedPort = null;
    host = null;
    lines.clear();
  }
}
