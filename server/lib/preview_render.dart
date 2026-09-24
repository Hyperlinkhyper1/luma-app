import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ai_benchmark_store.dart';

/// Which banners a render job covers.
enum PreviewRenderMode {
  /// Only scenes with no banner in either the data directory or the seed.
  missing,

  /// Every scene, replacing the banners already there.
  all,
}

/// One scene in a render job, as the admin dashboard lists it.
class PreviewRenderItem {
  PreviewRenderItem(this.id);

  final String id;

  /// `queued`, `rendering`, `ok`, `failed` or `skipped` (the job was stopped
  /// before reaching it).
  String state = 'queued';

  /// The renderer's last note on this scene: how it was framed and lit, or
  /// why it failed.
  String detail = '';

  Map<String, dynamic> toJson() => {'id': id, 'state': state, 'detail': detail};
}

/// The current (or last) render job.
class PreviewRenderStatus {
  bool running = false;
  PreviewRenderMode? mode;
  int? startedAtMs;
  int? finishedAtMs;
  bool stopped = false;

  /// Why the job could not start or ended early (tooling missing, renderer
  /// crashed); null when it ran to completion.
  String? error;
  List<PreviewRenderItem> items = [];

  /// The renderer's recent output, for when a row's detail isn't enough.
  final List<String> log = [];

  void addLog(String line) {
    log.add(line);
    if (log.length > 200) log.removeRange(0, log.length - 200);
  }

  Map<String, dynamic> toJson() => {
        'running': running,
        'mode': mode?.name,
        'startedAtMs': startedAtMs,
        'finishedAtMs': finishedAtMs,
        'stopped': stopped,
        'error': error,
        'items': [for (final i in items) i.toJson()],
        'log': log,
      };
}

/// Renders the PNG banners of AI benchmark scenes, driven from the admin
/// dashboard's Control panel ("Render missing banners" / "Re-render all").
///
/// Operators add scenes by dropping HTML files into `<dataDir>/ai_benchmarks/`
/// (see `server/benchmarks/README.md`). A scene without a banner shows the
/// kind's generic artwork in every client until one is rendered.
///
/// Rendering needs node plus a headless Chromium (the Docker image carries
/// both, see the Dockerfile; `LUMA_CHROMIUM_BIN` / `LUMA_NODE_BIN` /
/// `LUMA_PREVIEW_TOOL` point elsewhere). When the tooling is absent a job
/// refuses to start and says what is missing.
///
/// Only ever one job runs at a time, and the tool renders its scenes one by
/// one in a single small tab, reporting each as it goes. Output goes to the
/// data-directory override layer (never the read-only seed), so re-rendering
/// can't clobber checked-in artwork, and a scene that fails to render keeps
/// whatever banner it had.
///
/// Separately from the dashboard, `LUMA_PREVIEW_RENDER=1` lets [kick] render
/// missing banners unprompted.
class PreviewRenderService {
  PreviewRenderService({
    required this.dataDir,
    this.seedDir,
    this.toolScript,
    this.nodeBin,
    this.chromiumBin,
    bool? enabled,
    Map<String, String>? environment,
    Future<ProcessResult> Function(String exe, List<String> args)? runProcess,
    Future<Process> Function(String exe, List<String> args)? startProcess,
    Future<bool> Function(String path)? fileExists,
  })  : _environment = environment ?? Platform.environment,
        _runProcess = runProcess ?? Process.run,
        _startProcess = startProcess ?? Process.start,
        _fileExists = fileExists ?? ((path) => File(path).exists()),
        _enabledOverride = enabled;

  final String dataDir;
  final String? seedDir;

  /// The render script. Defaults to `tool/render_previews.mjs` next to the
  /// server checkout (works for `dart run` from `server/`); the Docker image
  /// sets `LUMA_PREVIEW_TOOL` to where it installed it.
  final String? toolScript;
  final String? nodeBin;
  final String? chromiumBin;

  final Map<String, String> _environment;
  final Future<ProcessResult> Function(String exe, List<String> args)
      _runProcess;
  final Future<Process> Function(String exe, List<String> args) _startProcess;
  final Future<bool> Function(String path) _fileExists;
  final bool? _enabledOverride;

  final PreviewRenderStatus status = PreviewRenderStatus();
  Process? _process;
  bool _loggedUnavailable = false;

  /// Whether [kick] may render unprompted. The dashboard buttons work
  /// either way.
  bool get enabled {
    if (_enabledOverride != null) return _enabledOverride!;
    return _environment['LUMA_PREVIEW_RENDER'] == '1';
  }

  String get _script =>
      toolScript ??
      _environment['LUMA_PREVIEW_TOOL'] ??
      'tool${Platform.pathSeparator}render_previews.mjs';

  String get _node => nodeBin ?? _environment['LUMA_NODE_BIN'] ?? 'node';

  String get _benchmarksDir =>
      '$dataDir${Platform.pathSeparator}${AiBenchmarkStore.dirName}';

  Future<AiBenchmarkStore> _store() =>
      AiBenchmarkStore.open(dataDir, seedDir: seedDir);

  /// Benchmark ids whose scene file exists but whose preview doesn't.
  Future<List<String>> missingIds() async => [
        for (final c in await (await _store()).previewCoverage())
          if (!c.hasPreview) c.id,
      ];

  /// Scene count and how many of those lack a banner, for the dashboard.
  Future<({int scenes, int missing})> coverage() async {
    final all = await (await _store()).previewCoverage();
    return (scenes: all.length, missing: all.where((c) => !c.hasPreview).length);
  }

  /// Render missing banners in the background when [enabled]. Returns
  /// immediately when disabled, already running, or with nothing to do.
  Future<void> kick() async {
    if (!enabled || status.running) return;
    final message = await start(PreviewRenderMode.missing);
    if (message != null && message == status.error) _logUnavailable(message);
  }

  /// Starts a render job and returns once the renderer is launched; the job
  /// itself runs on, reported through [status]. Returns null when it
  /// started, otherwise why not (already running, nothing to render, or
  /// tooling missing — the last also lands in [status.error]).
  ///
  /// [status.running] is set synchronously before the first await, so two
  /// concurrent calls can never both launch a renderer.
  Future<String?> start(PreviewRenderMode mode) async {
    if (status.running) return 'A banner render is already running.';
    status.running = true;
    try {
      final store = await _store();
      final coverage = await store.previewCoverage();
      final ids = [
        for (final c in coverage)
          if (mode == PreviewRenderMode.all || !c.hasPreview) c.id,
      ];
      if (ids.isEmpty) {
        status.running = false;
        return mode == PreviewRenderMode.missing
            ? 'Every scene already has a banner.'
            : 'There are no scenes to render.';
      }
      final problem = await _toolProblem();
      if (problem != null) {
        _reset(mode, const []);
        status
          ..error = problem
          ..running = false
          ..finishedAtMs = DateTime.now().millisecondsSinceEpoch;
        return problem;
      }
      _reset(mode, ids);
      final args = [
        _script,
        '--root',
        seedDir ?? _benchmarksDir,
        '--override',
        _benchmarksDir,
        '--out',
        '$_benchmarksDir${Platform.pathSeparator}previews',
        '--ids',
        ids.join(','),
      ];
      if (chromiumBin ?? _environment['LUMA_CHROMIUM_BIN'] case final bin?) {
        args.addAll(['--chromium-bin', bin]);
      }
      stdout.writeln('[luma] preview-render: rendering ${ids.length} '
          'banner(s) (${mode.name})…');
      final process = await _startProcess(_node, args);
      _process = process;
      unawaited(_follow(process));
      return null;
    } catch (e) {
      status
        ..error = 'Could not start the renderer: $e'
        ..running = false
        ..finishedAtMs = DateTime.now().millisecondsSinceEpoch;
      return status.error;
    }
  }

  /// Stops the running job. The scene being rendered keeps its old banner;
  /// the rest are marked skipped.
  bool stop() {
    final process = _process;
    if (!status.running || process == null) return false;
    status.stopped = true;
    process.kill();
    return true;
  }

  void _reset(PreviewRenderMode mode, List<String> ids) {
    status
      ..mode = mode
      ..startedAtMs = DateTime.now().millisecondsSinceEpoch
      ..finishedAtMs = null
      ..stopped = false
      ..error = null
      ..items = [for (final id in ids) PreviewRenderItem(id)]
      ..log.clear();
  }

  PreviewRenderItem? _item(String id) {
    for (final item in status.items) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Follows the renderer's progress lines (`START id`, `OK   id`,
  /// `FAIL id: reason`, and indented notes about the scene in between).
  Future<void> _follow(Process process) async {
    PreviewRenderItem? current;
    String lastError = '';
    // Node colours its stack traces when it thinks it has a terminal.
    final ansi = RegExp(r'\x1B\[[0-9;]*m');
    final out = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .map((line) => line.replaceAll(ansi, ''))
        .listen((line) {
      status.addLog(line);
      final start = RegExp(r'^START (\S+)').firstMatch(line);
      final ok = RegExp(r'^OK\s+(\S+)').firstMatch(line);
      final fail = RegExp(r'^FAIL (\S+?): (.*)$').firstMatch(line);
      if (start != null) {
        current = _item(start.group(1)!)?..state = 'rendering';
      } else if (ok != null) {
        _item(ok.group(1)!)?.state = 'ok';
        current = null;
      } else if (fail != null) {
        _item(fail.group(1)!)
          ?..state = 'failed'
          ..detail = fail.group(2)!;
        current = null;
      } else if (line.startsWith('  ') && current != null) {
        final note = line.trim();
        current!.detail =
            current!.detail.isEmpty ? note : '${current!.detail} · $note';
      }
    }).asFuture<void>();
    final err = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .map((line) => line.replaceAll(ansi, ''))
        .listen((line) {
      status.addLog(line);
      final text = line.trim();
      // The message, not the stack frames under it.
      if (text.isNotEmpty && !text.startsWith('at ')) lastError = text;
    }).asFuture<void>();
    final code = await process.exitCode;
    await Future.wait([out, err]).catchError((_) => const <void>[]);
    for (final item in status.items) {
      if (item.state == 'queued' || item.state == 'rendering') {
        item.state = status.stopped ? 'skipped' : 'failed';
        if (!status.stopped && item.detail.isEmpty) {
          item.detail = 'renderer exited before this scene';
        }
      }
    }
    if (code != 0 && !status.stopped) {
      status.error = lastError.isNotEmpty
          ? lastError
          : 'The renderer exited with code $code.';
    }
    status
      ..running = false
      ..finishedAtMs = DateTime.now().millisecondsSinceEpoch;
    _process = null;
    final done = status.items.where((i) => i.state == 'ok').length;
    stdout.writeln('[luma] preview-render: finished, $done of '
        '${status.items.length} rendered'
        '${status.stopped ? ' (stopped)' : ''} (exit $code)');
  }

  /// What stops the renderer from running here, or null when it can.
  Future<String?> _toolProblem() async {
    if (!await _fileExists(_script)) {
      return 'The render tool was not found at $_script. Set '
          'LUMA_PREVIEW_TOOL to server/tool/render_previews.mjs.';
    }
    final modules = '${File(_script).parent.path}${Platform.pathSeparator}'
        'node_modules${Platform.pathSeparator}puppeteer-core'
        '${Platform.pathSeparator}package.json';
    if (!await _fileExists(modules)) {
      return "The render tool's dependencies are not installed. Run npm "
          'install in ${File(_script).parent.path}.';
    }
    if (!await _nodeRuns()) {
      return 'Node.js could not be started ($_node). Install nodejs or set '
          'LUMA_NODE_BIN.';
    }
    return null;
  }

  Future<bool> _nodeRuns() async {
    try {
      final result = await _runProcess(_node, const ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  void _logUnavailable(String message) {
    if (_loggedUnavailable) return;
    _loggedUnavailable = true;
    stdout.writeln('[luma] preview-render: $message');
  }
}
