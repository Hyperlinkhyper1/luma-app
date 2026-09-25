import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:llm_llamacpp/llm_llamacpp.dart';

/// Manages the optional, device-local Assistant model.
class LocalModelStore extends ChangeNotifier {
  LocalModelStore._();

  static final LocalModelStore instance = LocalModelStore._();

  static const modelRepository = 'ggml-org/Qwen3.5-0.8B-GGUF';
  static const modelFileName = 'Qwen3.5-0.8B-Q4_0.gguf';
  static const modelSizeLabel = '563 MB';
  static const _minimumModelBytes = 500 * 1024 * 1024;

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

  bool get isDownloading => _downloading;
  double? get progress => _progress;
  String? get error => _error;

  Future<String> _modelDirectory() async {
    final support = await getApplicationSupportDirectory();
    return '${support.path}${Platform.pathSeparator}ai${Platform.pathSeparator}models';
  }

  Future<String?> modelPath() async {
    final path =
        '${await _modelDirectory()}${Platform.pathSeparator}$modelFileName';
    final file = File(path);
    if (!await file.exists()) return null;
    if (await file.length() < _minimumModelBytes) {
      await file.delete();
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
      if (await modelPath() == null) {
        throw StateError('The model download did not produce a valid file.');
      }
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

  Future<void> remove() async {
    final path = await modelPath();
    if (path != null) await File(path).delete();
    notifyListeners();
  }
}
