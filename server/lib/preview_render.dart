import 'dart:async';
import 'dart:io';

import 'ai_benchmark_store.dart';

/// Renders PNG banners for benchmark scenes that don't have one yet.
///
/// Operators add scenes by dropping HTML files into `<dataDir>/ai_benchmarks/`
/// (see `server/benchmarks/README.md`). Without this service those scenes
/// serve no preview and every client shows the kind's generic artwork until
/// someone renders the banners by hand. With it, the first manifest fetch
/// after a scene lands kicks off a background render and the banners appear
/// on their own a few minutes later.
///
/// Rendering needs node plus a headless Chromium — neither ships in the
/// server image, so this is strictly opt-in via `LUMA_PREVIEW_RENDER=1` (plus
/// optional `LUMA_CHROMIUM_BIN` / `LUMA_NODE_BIN` / `LUMA_PREVIEW_TOOL`). When
/// the tooling is absent the service logs once and stays out of the way; the
/// store keeps serving scenes with `hasPreview: false` as before.
///
/// Only ever one render runs at a time, scenes are captured sequentially in a
/// single small tab, and output goes to the data-directory override layer
/// (never the read-only seed), so a render can neither overload the host nor
/// clobber checked-in artwork.
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
  })  : _environment = environment ?? Platform.environment,
        _runProcess = runProcess ?? Process.run,
        _enabledOverride = enabled;

  final String dataDir;
  final String? seedDir;

  /// The render script. Defaults to `tool/render_previews.mjs` next to the
  /// server checkout (works for `dart run` from `server/`); bundled
  /// deployments set `LUMA_PREVIEW_TOOL` to wherever they placed it.
  final String? toolScript;
  final String? nodeBin;
  final String? chromiumBin;

  final Map<String, String> _environment;
  final Future<ProcessResult> Function(String exe, List<String> args)
      _runProcess;
  final bool? _enabledOverride;

  bool _running = false;
  bool _loggedUnavailable = false;
  bool? _nodeOk;

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

  /// Benchmark ids whose scene file exists but whose preview doesn't.
  Future<List<String>> missingIds() async {
    final store =
        await AiBenchmarkStore.open(dataDir, seedDir: seedDir);
    final missing = <String>[];
    for (final entry in await store.list()) {
      if (!entry.hasPreview) missing.add(entry.id);
    }
    return missing;
  }

  /// Render whatever is missing, in the background. Safe to call on every
  /// manifest fetch: it returns immediately when disabled, already running,
  /// or with nothing to do.
  ///
  /// Strictly one render at a time: the flag is set synchronously before the
  /// first await, so two concurrent kicks can never both start a renderer,
  /// and the tool script itself captures scenes sequentially in a single tab.
  Future<void> kick() async {
    if (_running || !enabled) return;
    _running = true;
    try {
      final ids = await missingIds();
      if (ids.isEmpty) return;
      if (!await _toolReady(ids.length)) return;
      stdout.writeln(
          '[luma] preview-render: capturing ${ids.length} missing banners…');
      final args = [
        _script,
        '--root',
        seedDir ?? _benchmarksDir,
        '--out',
        '$_benchmarksDir${Platform.pathSeparator}previews',
        '--ids',
        ids.join(','),
      ];
      if (chromiumBin ?? _environment['LUMA_CHROMIUM_BIN'] case final bin?) {
        args.addAll(['--chromium-bin', bin]);
      }
      final result = await _runProcess(_node, args);
      stdout.writeln('[luma] preview-render: done (exit ${result.exitCode})');
      final out = '${result.stdout}'.trim();
      if (out.isNotEmpty) {
        stdout.writeln('[luma] preview-render: ${out.split('\n').last}');
      }
    } catch (e) {
      stdout.writeln('[luma] preview-render: failed: $e');
    } finally {
      _running = false;
    }
  }

  /// The script exists and node runs. Checked once; paths don't change under
  /// a running server.
  Future<bool> _toolReady(int missing) async {
    if (!await File(_script).exists()) {
      _logUnavailable(
          'preview rendering is enabled but the tool script was not found '
          'at $_script — set LUMA_PREVIEW_TOOL or run '
          'node tool/render_previews.mjs by hand.');
      return false;
    }
    _nodeOk ??= await _checkNode();
    if (_nodeOk != true) {
      _logUnavailable(
          'preview rendering is enabled but node could not be started '
          '($_node) — install nodejs (npm install in server/tool) or unset '
          'LUMA_PREVIEW_RENDER. $missing banner(s) still missing.');
      return false;
    }
    return true;
  }

  Future<bool> _checkNode() async {
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
