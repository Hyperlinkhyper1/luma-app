import 'dart:convert';

/// What a dashboard button starts: a typed command line, or a script file
/// (.bat / .cmd / .ps1) that already lives on disk.
enum CommandKind { shell, script }

/// One button on the Command Dashboard. Commands are machine-specific
/// (paths, installed tools), so they are stored locally and never synced.
class DashCommand {
  const DashCommand({
    required this.id,
    required this.name,
    required this.kind,
    required this.command,
    this.workingDirectory,
    this.runAsAdmin = false,
    this.keepsRunning = false,
    this.port,
    this.ownWindow = false,
    this.icon = 'terminal',
  });

  final String id;
  final String name;
  final CommandKind kind;

  /// The command line for [CommandKind.shell], the file path for
  /// [CommandKind.script].
  final String command;
  final String? workingDirectory;

  /// Started through UAC. Windows asks for permission on every run.
  final bool runAsAdmin;

  /// A host such as `rojo serve` or a dev server: it stays up until stopped,
  /// and the dashboard watches its port for connections.
  final bool keepsRunning;

  /// The port a host listens on. Null means "read it from the output".
  final int? port;

  /// Runs in its own console window instead of piping output into luma.
  final bool ownWindow;
  final String icon;

  bool get isScript => kind == CommandKind.script;

  /// The folder the command runs in: the explicit one, else a script's own
  /// folder (batch files usually expect that), else luma's.
  String? get effectiveWorkingDirectory {
    final dir = workingDirectory?.trim();
    if (dir != null && dir.isNotEmpty) return dir;
    if (isScript) return parentDirectory(command);
    return null;
  }

  DashCommand copyWith({
    String? name,
    CommandKind? kind,
    String? command,
    String? Function()? workingDirectory,
    bool? runAsAdmin,
    bool? keepsRunning,
    int? Function()? port,
    bool? ownWindow,
    String? icon,
  }) =>
      DashCommand(
        id: id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        command: command ?? this.command,
        workingDirectory:
            workingDirectory != null ? workingDirectory() : this.workingDirectory,
        runAsAdmin: runAsAdmin ?? this.runAsAdmin,
        keepsRunning: keepsRunning ?? this.keepsRunning,
        port: port != null ? port() : this.port,
        ownWindow: ownWindow ?? this.ownWindow,
        icon: icon ?? this.icon,
      );

  DashCommand duplicate(String newId, String newName) => DashCommand(
        id: newId,
        name: newName,
        kind: kind,
        command: command,
        workingDirectory: workingDirectory,
        runAsAdmin: runAsAdmin,
        keepsRunning: keepsRunning,
        port: port,
        ownWindow: ownWindow,
        icon: icon,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'command': command,
        if (workingDirectory != null) 'workingDirectory': workingDirectory,
        'runAsAdmin': runAsAdmin,
        'keepsRunning': keepsRunning,
        if (port != null) 'port': port,
        'ownWindow': ownWindow,
        'icon': icon,
      };

  static DashCommand? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final command = raw['command'];
    if (id is! String || name is! String || command is! String) return null;
    return DashCommand(
      id: id,
      name: name,
      kind: raw['kind'] == CommandKind.script.name
          ? CommandKind.script
          : CommandKind.shell,
      command: command,
      workingDirectory: raw['workingDirectory'] as String?,
      runAsAdmin: raw['runAsAdmin'] == true,
      keepsRunning: raw['keepsRunning'] == true,
      port: raw['port'] is int ? raw['port'] as int : null,
      ownWindow: raw['ownWindow'] == true,
      icon: raw['icon'] is String ? raw['icon'] as String : 'terminal',
    );
  }
}

String encodeCommands(List<DashCommand> commands) =>
    const JsonEncoder.withIndent('  ')
        .convert({'version': 1, 'commands': [for (final c in commands) c.toJson()]});

List<DashCommand> decodeCommands(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    return const [];
  }
  final list = decoded is Map ? decoded['commands'] : null;
  if (list is! List) return const [];
  return [
    for (final raw in list)
      ?DashCommand.fromJson(raw),
  ];
}

String? parentDirectory(String path) {
  final cut = path.lastIndexOf(RegExp(r'[\\/]'));
  if (cut <= 0) return null;
  return path.substring(0, cut);
}

String fileName(String path) {
  final cut = path.lastIndexOf(RegExp(r'[\\/]'));
  return cut < 0 ? path : path.substring(cut + 1);
}

/// The cmd.exe line that runs [command]. Script paths are quoted so a folder
/// with spaces still works; PowerShell scripts go through powershell.exe.
String commandLineFor(DashCommand command) {
  if (!command.isScript) return command.command;
  final path = command.command;
  if (path.toLowerCase().endsWith('.ps1')) {
    return 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$path"';
  }
  return 'call "$path"';
}

final _portPatterns = [
  RegExp(r'(?:localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1?\]):(\d{2,5})\b',
      caseSensitive: false),
  RegExp(r'\bport\b\s*[:=]?\s*(\d{2,5})\b', caseSensitive: false),
];

/// Finds the port a host announces in its output, e.g. rojo's
/// `Port: 34872` or a dev server's `http://localhost:5173/`.
int? detectPort(String line) {
  for (final pattern in _portPatterns) {
    final match = pattern.firstMatch(line);
    if (match == null) continue;
    final port = int.tryParse(match.group(1)!);
    if (port != null && port > 0 && port <= 65535) return port;
  }
  return null;
}

/// One established TCP connection to a host's port, from `netstat -ano`.
class HostConnection {
  const HostConnection({required this.remoteAddress, required this.pid});
  final String remoteAddress;
  final int? pid;
}

/// Reads `netstat -ano -p TCP` output and keeps the established connections
/// whose *local* side is [port] — i.e. clients connected to the host, not
/// the host's own outbound sockets.
List<HostConnection> parseEstablished(String netstat, int port) {
  final result = <HostConnection>[];
  for (final line in const LineSplitter().convert(netstat)) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 4 || parts[0].toUpperCase() != 'TCP') continue;
    if (parts[3].toUpperCase() != 'ESTABLISHED') continue;
    final local = parts[1];
    final localPort = int.tryParse(local.substring(local.lastIndexOf(':') + 1));
    if (localPort != port) continue;
    result.add(HostConnection(
      remoteAddress: parts[2],
      pid: parts.length > 4 ? int.tryParse(parts[4]) : null,
    ));
  }
  return result;
}

/// The batch file luma actually runs. Writing the command into a wrapper
/// keeps it away from the argument quoting between Dart, PowerShell and
/// cmd.exe, which disagree about almost everything.
String wrapperBatch(DashCommand command) {
  final dir = command.effectiveWorkingDirectory;
  return [
    '@echo off',
    'chcp 65001 >nul',
    if (dir != null) 'cd /d "$dir"',
    commandLineFor(command),
    'exit /b %errorlevel%',
    '',
  ].join('\r\n');
}

/// The PowerShell that starts a run luma can't pipe directly: an elevated
/// one (UAC can't hand pipes back to an unelevated parent, so the elevated
/// cmd writes to [logPath], which luma tails) or one in its own console
/// window. It prints the started PID so Stop can target it, then waits so
/// luma learns the exit code.
String launcherScript({
  required String batchPath,
  required bool admin,
  required bool ownWindow,
  String? logPath,
}) {
  final args = ownWindow || logPath == null
      ? '/k "$batchPath"'
      : '/s /c ""$batchPath" > "$logPath" 2>&1"';
  final window = ownWindow ? 'Normal' : 'Hidden';
  return [
    r"$ErrorActionPreference = 'Stop'",
    "\$p = Start-Process -FilePath 'cmd.exe'${admin ? ' -Verb RunAs' : ''} "
        "-WindowStyle $window -PassThru -ArgumentList '${_psQuote(args)}'",
    r'Write-Output "LUMA_PID:$($p.Id)"',
    r'$p.WaitForExit()',
    r'exit $p.ExitCode',
  ].join('\n');
}

final _pidLine = RegExp(r'^LUMA_PID:(\d+)\s*$');

/// The PID [launcherScript] reports, if [line] is that report.
int? parseLauncherPid(String line) {
  final match = _pidLine.firstMatch(line.trim());
  return match == null ? null : int.parse(match.group(1)!);
}

String _psQuote(String value) => value.replaceAll("'", "''");

/// PowerShell's -EncodedCommand takes base64 of UTF-16LE, which sidesteps
/// every layer of quoting between Dart, cmd and PowerShell.
String encodePowerShell(String script) {
  final bytes = <int>[];
  for (final unit in script.codeUnits) {
    bytes
      ..add(unit & 0xff)
      ..add(unit >> 8);
  }
  return base64.encode(bytes);
}

/// Ready-made commands offered when adding one.
class CommandPreset {
  const CommandPreset({
    required this.name,
    required this.command,
    this.runAsAdmin = false,
    this.keepsRunning = false,
    this.port,
    this.icon = 'terminal',
  });
  final String name;
  final String command;
  final bool runAsAdmin;
  final bool keepsRunning;
  final int? port;
  final String icon;
}

const commandPresets = [
  CommandPreset(
    name: 'Rojo serve',
    command: 'rojo serve',
    keepsRunning: true,
    port: 34872,
    icon: 'dns',
  ),
  CommandPreset(
    name: 'npm run dev',
    command: 'npm run dev',
    keepsRunning: true,
    icon: 'web',
  ),
  CommandPreset(
    name: 'Flush DNS',
    command: 'ipconfig /flushdns',
    runAsAdmin: true,
    icon: 'wifi',
  ),
];
