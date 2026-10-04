import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ai_benchmark_store.dart';
import 'util.dart';

/// How many scenes may render side by side, and how many do by default.
const kMinPreviewWorkers = 1;
const kMaxPreviewWorkers = 6;
const kDefaultPreviewWorkers = 2;

/// Which banners a render job covers.
enum PreviewRenderMode {
  /// Only scenes with no banner in either the data directory or the seed.
  missing,

  /// Every scene, replacing the banners already there.
  all,

  /// The scenes the operator picked in the dashboard's catalog, or the one
  /// whose framing was just saved.
  selected,
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

  /// How far into this scene the renderer is (0–1) and what it is doing
  /// right now, from its `STEP` lines, so the dashboard's bar moves during
  /// a scene rather than only between scenes.
  double progress = 0;
  String stage = '';

  /// When the renderer started and finished this scene, so the dashboard
  /// can estimate how long the rest of the job will take.
  int? startedAtMs;
  int? finishedAtMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'state': state,
        'detail': detail,
        'progress': progress,
        'stage': stage,
        if (startedAtMs != null) 'startedAtMs': startedAtMs,
        if (finishedAtMs != null) 'finishedAtMs': finishedAtMs,
      };
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

  /// The WebGL backend the renderer settled on, e.g. `gpu · Mesa Intel(R)
  /// Graphics` or `software · SwiftShader`; null until it says.
  String? renderer;
  List<PreviewRenderItem> items = [];

  /// Scenes asked for while a job was running; they get a job of their own
  /// as soon as this one ends.
  final List<String> queued = [];

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
        'renderer': renderer,
        'items': [for (final i in items) i.toJson()],
        'queued': queued,
        'log': log,
      };
}

/// Renders the PNG banners of AI benchmark scenes, driven from the admin
/// dashboard's Control panel ("Render missing banners" / "Re-render all").
///
/// Operators add scenes by dropping HTML or GLB files into
/// `<dataDir>/ai_benchmarks/` (see `server/benchmarks/README.md`). A scene
/// without a banner shows the kind's generic artwork in every client until
/// one is rendered.
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
/// Where a scene's script first fails to parse, counted in the HTML file.
typedef SourceProblem = ({int line, int column, String message});

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
  int? _workers;

  File get _settingsFile => File('$dataDir${Platform.pathSeparator}'
      'preview_render.json');

  static bool validWorkers(int n) =>
      n >= kMinPreviewWorkers && n <= kMaxPreviewWorkers;

  /// Scenes rendered side by side. The dashboard's cog sets it; each worker is
  /// a Chromium of its own, so the right number depends on the GPU.
  int get workers {
    final cached = _workers;
    if (cached != null) return cached;
    var n = kDefaultPreviewWorkers;
    try {
      final file = _settingsFile;
      if (file.existsSync()) {
        final raw = jsonDecode(file.readAsStringSync());
        final saved = raw is Map ? raw['workers'] : null;
        if (saved is int && validWorkers(saved)) n = saved;
      }
    } catch (_) {
      // Unreadable settings: use the default.
    }
    return _workers = n;
  }

  /// Applies from the next job; one already running keeps its workers.
  Future<void> setWorkers(int n) async {
    if (!validWorkers(n)) {
      throw ArgumentError(
          'Workers must be $kMinPreviewWorkers–$kMaxPreviewWorkers.');
    }
    await atomicWriteString(_settingsFile.path, jsonEncode({'workers': n}));
    _workers = n;
  }

  bool _loggedUnavailable = false;

  /// The first syntax error in [bytes]'s inline scripts, or null when they
  /// parse (or this can't be checked here). The renderer reports a syntax
  /// mistake as a bare "Unexpected token", with no position; this finds it
  /// without a browser, in about a tenth of a second.
  Future<SourceProblem?> findSyntaxError(List<int> bytes) async {
    final tool = '${File(_script).parent.path}${Platform.pathSeparator}'
        'check_syntax.mjs';
    Directory? scratch;
    try {
      if (!await _fileExists(tool)) return null;
      scratch = await Directory.systemTemp.createTemp('luma_syntax_');
      final file = File('${scratch.path}${Platform.pathSeparator}scene.html');
      await file.writeAsBytes(bytes);
      final result = await _runProcess(_node, [tool, file.path])
          .timeout(const Duration(seconds: 30));
      if (result.exitCode != 0) return null;
      final raw = jsonDecode('${result.stdout}'.trim().split('\n').last);
      if (raw is! Map || raw['ok'] != false) return null;
      final line = raw['line'];
      final column = raw['column'];
      if (line is! int || line < 1) return null;
      return (
        line: line,
        column: column is int ? column : 1,
        message: '${raw['message'] ?? 'SyntaxError'}',
      );
    } catch (_) {
      return null;
    } finally {
      try {
        await scratch?.delete(recursive: true);
      } catch (_) {
        // A leftover temp directory is harmless.
      }
    }
  }

  /// Checks an on-demand repair in an isolated override directory. It cannot
  /// replace a live scene or its banner until the candidate renders.
  Future<String?> validateRepair(String id, List<int> bytes) {
    final result = _validations.then((_) => _validateRepairNow(id, bytes));
    _validations = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Candidate renders take turns. Repairs run side by side, but each
  /// candidate launches a browser on the one GPU, and renders that share it
  /// time out on slow-loading scenes that render fine alone.
  static Future<void> _validations = Future<void>.value();

  Future<String?> _validateRepairNow(String id, List<int> bytes) async {
    final parent = await Directory('$dataDir/benchmark_repair_checks')
        .create(recursive: true);
    final scratch = await parent.createTemp('candidate_');
    PreviewRenderService? candidate;
    try {
      final live = await _store();
      final entry =
          (await live.editableEntries()).firstWhere((e) => e['id'] == id);
      final staged =
          await AiBenchmarkStore.open(scratch.path, seedDir: seedDir);
      await staged.saveUpload(
          kind: entry['kind'] as String,
          id: id,
          model: entry['model'] as String,
          vendor: entry['vendor'] as String? ?? '',
          description: entry['description'] as String? ?? '',
          bytes: bytes);
      final framing = await live.readFraming(id);
      if (framing != null) {
        await staged.writeFraming(id, framing);
      }
      candidate = PreviewRenderService(
        dataDir: scratch.path,
        seedDir: seedDir,
        toolScript: toolScript,
        nodeBin: nodeBin,
        chromiumBin: chromiumBin,
        environment: _environment,
        runProcess: _runProcess,
        startProcess: _startProcess,
        fileExists: _fileExists,
        enabled: false,
      );
      final problem =
          await candidate.start(PreviewRenderMode.selected, only: [id]);
      if (problem != null) return problem;
      final deadline = DateTime.now().add(const Duration(minutes: 10));
      while (candidate.status.running) {
        if (DateTime.now().isAfter(deadline)) {
          candidate.stop();
          return 'Candidate render timed out; the live test was kept.';
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      final items = candidate.status.items;
      if (items.length != 1 || items.single.state != 'ok') {
        return candidate.status.error ??
            (items.isEmpty ? 'Candidate did not render.' : items.single.detail);
      }
      return null;
    } finally {
      candidate?.stop();
      if (await scratch.exists()) await scratch.delete(recursive: true);
    }
  }

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
    return (
      scenes: all.length,
      missing: all.where((c) => !c.hasPreview).length
    );
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
  ///
  /// [PreviewRenderMode.selected] renders [only], in catalog order; ids that
  /// name no scene are dropped.
  Future<String?> start(PreviewRenderMode mode, {List<String>? only}) async {
    if (status.running) return 'A banner render is already running.';
    status.running = true;
    try {
      final store = await _store();
      final coverage = await store.previewCoverage();
      final picked = only?.toSet() ?? const <String>{};
      final ids = [
        for (final c in coverage)
          if (switch (mode) {
            PreviewRenderMode.all => true,
            PreviewRenderMode.missing => !c.hasPreview,
            PreviewRenderMode.selected => picked.contains(c.id),
          })
            c.id,
      ];
      if (ids.isEmpty) {
        status.running = false;
        return switch (mode) {
          PreviewRenderMode.missing => 'Every scene already has a banner.',
          PreviewRenderMode.selected => 'None of those scenes exist.',
          PreviewRenderMode.all => 'There are no scenes to render.',
        };
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
      args.addAll(['--jobs', '$workers']);
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

  /// Renders [ids] now, or right after the running job when there is one.
  /// Returns null when a job started, `'queued'` when they wait for the
  /// running one, otherwise why nothing will render.
  Future<String?> enqueue(List<String> ids) async {
    if (status.running) {
      for (final id in ids) {
        if (!status.queued.contains(id)) status.queued.add(id);
      }
      return 'queued';
    }
    return start(PreviewRenderMode.selected, only: ids);
  }

  /// Stops the running job. The scene being rendered keeps its old banner;
  /// the rest are marked skipped, and nothing queued behind it runs.
  bool stop() {
    final process = _process;
    if (!status.running || process == null) return false;
    status.stopped = true;
    status.queued.clear();
    process.kill();
    return true;
  }

  Map<String, String>? _failures;

  File get _failuresFile => File('$dataDir${Platform.pathSeparator}'
      'preview_render_failures.json');

  Map<String, String> get _failureMap {
    final cached = _failures;
    if (cached != null) return cached;
    final loaded = <String, String>{};
    try {
      final file = _failuresFile;
      if (file.existsSync()) {
        final raw = jsonDecode(file.readAsStringSync());
        if (raw is Map) {
          for (final e in raw.entries) {
            if (e.key is String && e.value is String) {
              loaded[e.key as String] = e.value as String;
            }
          }
        }
      }
    } catch (_) {
      // Unreadable: start with no recorded errors.
    }
    return _failures = loaded;
  }

  /// The error a scene's last render ended with, or null once it has
  /// rendered since. Kept on disk because a render job's own status is
  /// replaced by the next job (a repaired scene queues one), and a repair
  /// needs the error long after the job that hit it.
  String? failureFor(String id) => _failureMap[id];

  /// Recorded errors for scenes that still exist, so a deleted test doesn't
  /// linger as something to repair.
  Future<Map<String, String>> recordedFailures() async {
    final known = {
      for (final c in await (await _store()).previewCoverage()) c.id,
    };
    return {
      for (final e in _failureMap.entries)
        if (known.contains(e.key)) e.key: e.value,
    };
  }

  void recordFailure(String id, String? detail) {
    final map = _failureMap;
    final text = detail?.trim() ?? '';
    if (text.isEmpty) {
      if (map.remove(id) == null) return;
    } else {
      if (map[id] == text) return;
      map[id] = text;
    }
    try {
      final tmp = File('${_failuresFile.path}.tmp');
      tmp.writeAsStringSync(jsonEncode(map), flush: true);
      tmp.renameSync(_failuresFile.path);
    } catch (_) {
      // Still remembered in memory; the next change tries the disk again.
    }
  }

  void _reset(PreviewRenderMode mode, List<String> ids) {
    status
      ..mode = mode
      ..startedAtMs = DateTime.now().millisecondsSinceEpoch
      ..finishedAtMs = null
      ..stopped = false
      ..error = null
      ..renderer = null
      ..items = [for (final id in ids) PreviewRenderItem(id)]
      ..log.clear();
  }

  PreviewRenderItem? _item(String id) {
    for (final item in status.items) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _addNote(PreviewRenderItem? item, String note) {
    if (item == null) return;
    item.detail = item.detail.isEmpty ? note : '${item.detail} · $note';
  }

  /// Follows the renderer's progress lines (`START id`, `OK   id`,
  /// `FAIL id: reason`, `STEP id fraction what`, `NOTE id text`,
  /// `RENDERER backend`, and indented notes about the scene in between, the
  /// older form that assumes one scene at a time).
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
      final start = RegExp(r'^START (\S+)').firstMatch(line);
      final ok = RegExp(r'^OK\s+(\S+)').firstMatch(line);
      final fail = RegExp(r'^FAIL (\S+?): (.*)$').firstMatch(line);
      final step = RegExp(r'^STEP (\S+) ([\d.]+) ?(.*)$').firstMatch(line);
      final renderer = RegExp(r'^RENDERER (.+)$').firstMatch(line);
      final noted = RegExp(r'^NOTE (\S+) (.+)$').firstMatch(line);
      // Steps arrive several times a second; they'd crowd out the log.
      if (step == null) status.addLog(line);
      final now = DateTime.now().millisecondsSinceEpoch;
      if (start != null) {
        current = _item(start.group(1)!)
          ?..state = 'rendering'
          ..startedAtMs = now;
      } else if (ok != null) {
        _item(ok.group(1)!)
          ?..state = 'ok'
          ..progress = 1
          ..stage = ''
          ..finishedAtMs = now;
        recordFailure(ok.group(1)!, null);
        current = null;
      } else if (fail != null) {
        _item(fail.group(1)!)
          ?..state = 'failed'
          ..detail = fail.group(2)!
          ..stage = ''
          ..finishedAtMs = now;
        recordFailure(fail.group(1)!, fail.group(2)!);
        current = null;
      } else if (step != null) {
        _item(step.group(1)!)
          ?..progress = (double.tryParse(step.group(2)!) ?? 0).clamp(0.0, 1.0)
          ..stage = step.group(3)!;
      } else if (renderer != null) {
        status.renderer = renderer.group(1)!.trim();
      } else if (noted != null) {
        _addNote(_item(noted.group(1)!), noted.group(2)!);
      } else if (line.startsWith('  ') && current != null) {
        _addNote(current, line.trim());
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
    if (status.queued.isNotEmpty) {
      final next = List<String>.of(status.queued);
      status.queued.clear();
      await start(PreviewRenderMode.selected, only: next);
    }
  }

  /// The in-page half of the framing editor: the renderer's shot control in
  /// interactive mode (real clock, the scene's own controls), ready to
  /// inline into a scene as a classic script. Null when the tool isn't
  /// installed beside the render script.
  Future<String?> editorScript() async {
    final path = '${File(_script).parent.path}${Platform.pathSeparator}'
        'shot_control.mjs';
    if (!await _fileExists(path)) return null;
    final source = await File(path).readAsString();
    return '${source.replaceFirst('export function', 'function')}\n'
        'installShotControl({ interactive: true });\n';
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
