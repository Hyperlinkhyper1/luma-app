import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:llm_llamacpp/llm_llamacpp.dart';
import 'package:crypto/crypto.dart';

import 'providers/local_qwen_client.dart';

/// Manages the optional, device-local Assistant model.
class LocalModelStore extends ChangeNotifier {
  LocalModelStore._();

  static final LocalModelStore instance = LocalModelStore._();

  static const modelRepository = 'ggml-org/Qwen3.5-0.8B-GGUF';
  static const _modelRevision = '9447f74101aeb4e93621884dfa36ee8effb8831b';

  /// Q8_0 on desktop, where the extra 250 MB is nothing and a 0.8B model
  /// loses noticeably less to quantization. Phones keep Q4_0: they run on
  /// the CPU, where generation speed tracks bytes read per token, and
  /// llama.cpp repacks Q4_0 into its fastest ARM kernels.
  static _ModelFile get _file => Platform.isAndroid ? _q4 : _q8;

  // Sizes and SHA-256s published by ggml-org for these files at
  // [_modelRevision].
  static const _q4 = _ModelFile(
    name: 'Qwen3.5-0.8B-Q4_0.gguf',
    bytes: 563036064,
    sha256: '57d1997790d1744fba5b40a7317df71ea5e2acee28c47e78f0cce39c0703f8cf',
  );
  static const _q8 = _ModelFile(
    name: 'Qwen3.5-0.8B-Q8_0.gguf',
    bytes: 811843488,
    sha256: '75526add2fec8543a78d412a5546dd1c13dcf1ade237b245915d0f12dd43bb3d',
  );

  static String get modelFileName => _file.name;
  static String get modelSizeLabel => '${(_file.bytes / 1e6).round()} MB';

  /// False on iOS: llama.cpp is not bundled there (the upstream iOS build is
  /// unusable — see third_party/llm_llamacpp/LUMA_PATCH.md), so the model
  /// could be downloaded but never run.
  static bool get supported => !Platform.isIOS;

  final LlamaCppRepository _repository = LlamaCppRepository();
  bool _downloading = false;
  double? _progress;
  String? _error;
  DateTime _lastProgressNotification = DateTime.fromMillisecondsSinceEpoch(0);
  double _lastNotifiedProgress = -1;
  Future<String?>? _modelPathCheck;

  bool get isDownloading => _downloading;
  double? get progress => _progress;
  String? get error => _error;

  Future<String> _modelDirectory() async {
    final support = await getApplicationSupportDirectory();
    return '${support.path}${Platform.pathSeparator}ai${Platform.pathSeparator}models';
  }

  /// Share the one-time integrity check across chat, settings and
  /// warm-up callers. A new download or removal invalidates this result.
  Future<String?> modelPath() => _modelPathCheck ??= _checkModelPath();

  Future<String?> _checkModelPath() async {
    final path =
        '${await _modelDirectory()}${Platform.pathSeparator}$modelFileName';
    final file = File(path);
    if (!await file.exists()) return null;
    final stat = await file.stat();
    if (stat.size != _file.bytes) {
      await file.delete();
      return null;
    }
    final digest = await sha256.bind(file.openRead()).first;
    if (digest.toString() != _file.sha256) {
      await file.delete();
      _error = 'The model file was incomplete or damaged. Download it again.';
      notifyListeners();
      return null;
    }
    return path;
  }

  Future<bool> get isInstalled async => supported && await modelPath() != null;

  Future<void> download() async {
    if (!supported || _downloading || await isInstalled) return;
    _downloading = true;
    _progress = 0;
    _error = null;
    notifyListeners();
    try {
      final directory = await _modelDirectory();
      await Directory(directory).create(recursive: true);
      await for (final progress in _repository.downloadModel(
        modelRepository,
        modelFileName,
        directory,
        revision: _modelRevision,
      )) {
        _progress = progress.totalBytes == 0 ? null : progress.progress;
        final now = DateTime.now();
        final shouldNotify =
            _progress == null ||
            _progress! >= 1 ||
            _progress! - _lastNotifiedProgress >= 0.01 ||
            now.difference(_lastProgressNotification).inMilliseconds >= 300;
        if (shouldNotify) {
          _lastProgressNotification = now;
          _lastNotifiedProgress = _progress ?? _lastNotifiedProgress;
          notifyListeners();
        }
      }
      _modelPathCheck = null;
      if (await modelPath() == null) {
        throw StateError('The model download did not produce a valid file.');
      }
      await _deleteOtherQuantizations();
    } catch (error) {
      _error = error.toString();
      final partial = File(
        '${await _modelDirectory()}${Platform.pathSeparator}$modelFileName.download',
      );
      if (await partial.exists()) await partial.delete();
    } finally {
      _downloading = false;
      notifyListeners();
    }
  }

  /// Removes the quantization this platform no longer uses, e.g. the Q4_0
  /// a desktop downloaded before it switched to Q8_0.
  Future<void> _deleteOtherQuantizations() async {
    final directory = await _modelDirectory();
    for (final file in [_q4, _q8]) {
      if (file.name == modelFileName) continue;
      final stale = File('$directory${Platform.pathSeparator}${file.name}');
      try {
        if (!await stale.exists()) continue;
        // Windows won't delete a file that is still memory-mapped.
        await LocalQwenClient.release();
        await stale.delete();
      } catch (error) {
        debugPrint('Could not delete ${file.name}: $error');
      }
    }
  }

  Future<void> remove() async {
    await LocalQwenClient.release();
    final path = await modelPath();
    if (path != null) await File(path).delete();
    await _deleteOtherQuantizations();
    _modelPathCheck = null;
    notifyListeners();
  }
}

class _ModelFile {
  const _ModelFile({
    required this.name,
    required this.bytes,
    required this.sha256,
  });

  final String name;
  final int bytes;
  final String sha256;
}
