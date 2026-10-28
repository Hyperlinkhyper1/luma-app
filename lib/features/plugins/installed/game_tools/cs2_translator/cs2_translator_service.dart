import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// What the user can tune about the translator. Each field maps to one of
/// the bundled script's parameters, so [toArgs] is the whole contract.
@immutable
class Cs2TranslatorOptions {
  const Cs2TranslatorOptions({
    this.targetLang = 'en',
    this.hideAfterSeconds = 20,
    this.maxLines = 8,
    this.overlayX = 20,
    this.overlayY,
    this.logPath = '',
    this.overlay = true,
  });

  final String targetLang;
  final int hideAfterSeconds;
  final int maxLines;
  final int overlayX;

  /// Null places the overlay automatically, bottom-left above CS2's chat.
  final int? overlayY;

  /// Empty lets the script find `console.log` through Steam's libraries.
  final String logPath;
  final bool overlay;

  Cs2TranslatorOptions copyWith({
    String? targetLang,
    int? hideAfterSeconds,
    int? maxLines,
    int? overlayX,
    int? Function()? overlayY,
    String? logPath,
    bool? overlay,
  }) => Cs2TranslatorOptions(
    targetLang: targetLang ?? this.targetLang,
    hideAfterSeconds: hideAfterSeconds ?? this.hideAfterSeconds,
    maxLines: maxLines ?? this.maxLines,
    overlayX: overlayX ?? this.overlayX,
    overlayY: overlayY != null ? overlayY() : this.overlayY,
    logPath: logPath ?? this.logPath,
    overlay: overlay ?? this.overlay,
  );

  List<String> toArgs() => [
    '-TargetLang',
    targetLang.trim().isEmpty ? 'en' : targetLang.trim(),
    '-HideAfterSeconds',
    '${hideAfterSeconds.clamp(1, 3600)}',
    '-MaxLines',
    '${maxLines.clamp(1, 30)}',
    '-OverlayX',
    '$overlayX',
    '-OverlayY',
    '${overlayY ?? -1}',
    if (logPath.trim().isNotEmpty) ...['-LogPath', logPath.trim()],
    if (!overlay) '-NoOverlay',
  ];

  Map<String, Object?> toJson() => {
    'targetLang': targetLang,
    'hideAfterSeconds': hideAfterSeconds,
    'maxLines': maxLines,
    'overlayX': overlayX,
    'overlayY': overlayY,
    'logPath': logPath,
    'overlay': overlay,
  };

  factory Cs2TranslatorOptions.fromJson(Map<String, Object?> json) =>
      Cs2TranslatorOptions(
        targetLang: json['targetLang'] as String? ?? 'en',
        hideAfterSeconds: (json['hideAfterSeconds'] as num?)?.toInt() ?? 20,
        maxLines: (json['maxLines'] as num?)?.toInt() ?? 8,
        overlayX: (json['overlayX'] as num?)?.toInt() ?? 20,
        overlayY: (json['overlayY'] as num?)?.toInt(),
        logPath: json['logPath'] as String? ?? '',
        overlay: json['overlay'] as bool? ?? true,
      );
}

/// The Steam library folders listed in `libraryfolders.vdf`, with the
/// file's doubled backslashes undone.
List<String> parseSteamLibraryPaths(String vdf) => [
  for (final m in RegExp(r'"path"\s+"([^"]+)"').allMatches(vdf))
    m.group(1)!.replaceAll(r'\\', r'\'),
];

/// Runs the CS2 chat translator: the PowerShell script bundled in
/// `assets/cs2_translator/`, which tails the `console.log` CS2 writes under
/// `-condebug` and draws translations in its own layered overlay window.
///
/// The game itself is never touched — no memory reads, no injection, no
/// game files changed — which is what keeps it VAC-safe. One instance for
/// the whole app, so the overlay keeps running while the user is elsewhere
/// in luma, and the section shows it as running when they come back.
class Cs2TranslatorService extends ChangeNotifier {
  Cs2TranslatorService._();

  static final instance = Cs2TranslatorService._();

  static const _assetPath = 'assets/cs2_translator/cs2-translator.ps1';
  static const _maxOutputLines = 200;

  Process? _process;
  Directory? _voiceInbox;
  int _voiceSequence = 0;
  bool _testing = false;
  final List<String> _output = [];

  bool get running => _process != null && !_testing;
  bool get testing => _testing;
  List<String> get output => List.unmodifiable(_output);

  static bool get supported => Platform.isWindows;

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}cs2_translator',
    );
    await dir.create(recursive: true);
    return dir;
  }

  /// Writes the bundled script out on every start, so an app update that
  /// changes it never leaves an older copy running.
  Future<String> _writeScript() async {
    final dir = await _dir();
    final file = File('${dir.path}${Platform.pathSeparator}cs2-translator.ps1');
    final data = await rootBundle.load(_assetPath);
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return file.path;
  }

  Future<Cs2TranslatorOptions> loadOptions() async {
    try {
      final file = File(
        '${(await _dir()).path}${Platform.pathSeparator}options.json',
      );
      if (!await file.exists()) return const Cs2TranslatorOptions();
      return Cs2TranslatorOptions.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, Object?>,
      );
    } catch (_) {
      return const Cs2TranslatorOptions();
    }
  }

  Future<void> saveOptions(Cs2TranslatorOptions options) async {
    try {
      final file = File(
        '${(await _dir()).path}${Platform.pathSeparator}options.json',
      );
      await file.writeAsString(jsonEncode(options.toJson()));
    } catch (_) {}
  }

  /// Finds `game\csgo\console.log` the same way the script does: Steam's
  /// install path from the registry, then every library it lists.
  Future<String?> findConsoleLog() async {
    if (!supported) return null;
    final roots = <String>{};
    try {
      final reg = await Process.run('reg', [
        'query',
        r'HKCU\Software\Valve\Steam',
        '/v',
        'SteamPath',
      ]);
      final m = RegExp(
        r'SteamPath\s+REG_SZ\s+(.+)',
      ).firstMatch('${reg.stdout}');
      if (m != null) roots.add(m.group(1)!.trim().replaceAll('/', r'\'));
    } catch (_) {}
    roots.add(r'C:\Program Files (x86)\Steam');

    final libraries = <String>{};
    for (final root in roots) {
      libraries.add(root);
      final vdf = File('$root\\steamapps\\libraryfolders.vdf');
      try {
        if (await vdf.exists()) {
          libraries.addAll(parseSteamLibraryPaths(await vdf.readAsString()));
        }
      } catch (_) {}
    }
    for (final lib in libraries) {
      final csgo = Directory(
        '$lib\\steamapps\\common\\Counter-Strike Global Offensive\\game\\csgo',
      );
      if (await csgo.exists()) return '${csgo.path}\\console.log';
    }
    return null;
  }

  /// Starts the overlay. Returns an error message, or null once it is up.
  Future<String?> start(Cs2TranslatorOptions options) async {
    if (!supported || _process != null) return null;
    return _launch(options.toArgs(), testing: false);
  }

  /// Runs the script's built-in `-Test`: a handful of sample chat lines
  /// parsed and translated, printed to the output panel, no overlay.
  Future<String?> runTest(Cs2TranslatorOptions options) async {
    if (!supported || _process != null) return null;
    return _launch(['-TargetLang', options.targetLang, '-Test'], testing: true);
  }

  Future<String?> _launch(List<String> args, {required bool testing}) async {
    try {
      final script = await _writeScript();
      final inbox = testing
          ? null
          : await Directory.systemTemp.createTemp('luma-cs2-chat-');
      _voiceInbox = inbox;
      _output.clear();
      _testing = testing;
      final process = await Process.start('powershell.exe', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        script,
        ...args,
        if (inbox != null) ...['-VoiceInbox', inbox.path],
      ]);
      _process = process;
      notifyListeners();
      for (final stream in [process.stdout, process.stderr]) {
        stream
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter())
            .listen(_addLine);
      }
      unawaited(
        process.exitCode.then((_) {
          if (identical(_process, process)) {
            _process = null;
            _testing = false;
            _voiceInbox = null;
            if (inbox != null) unawaited(_deleteInbox(inbox));
            notifyListeners();
          }
        }),
      );
      return null;
    } catch (e) {
      final inbox = _voiceInbox;
      _voiceInbox = null;
      if (inbox != null) unawaited(_deleteInbox(inbox));
      _process = null;
      _testing = false;
      notifyListeners();
      return '$e';
    }
  }

  Future<void> _deleteInbox(Directory inbox) async {
    try {
      await inbox.delete(recursive: true);
    } catch (_) {}
  }

  Future<void> showVoiceLine(String transcript, String translation) async {
    final inbox = _voiceInbox;
    if (!running || inbox == null) {
      throw StateError('Start the chat translator first.');
    }
    final stem = '${DateTime.now().microsecondsSinceEpoch}-${_voiceSequence++}';
    final pending = File('${inbox.path}${Platform.pathSeparator}$stem.tmp');
    await pending.writeAsString(
      jsonEncode({'transcript': transcript, 'translation': translation}),
      flush: true,
    );
    if (!running || !identical(inbox, _voiceInbox)) {
      if (await pending.exists()) await pending.delete();
      return;
    }
    await pending.rename('${inbox.path}${Platform.pathSeparator}$stem.json');
  }

  void _addLine(String line) {
    if (line.trim().isEmpty) return;
    _output.add(line);
    if (_output.length > _maxOutputLines) {
      _output.removeRange(0, _output.length - _maxOutputLines);
    }
    notifyListeners();
  }

  /// Closes the overlay. Right-clicking its dot does the same from the game.
  void stop() {
    _process?.kill();
  }
}
