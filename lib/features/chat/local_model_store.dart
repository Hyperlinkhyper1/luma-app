import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:llm_llamacpp/llm_llamacpp.dart';
import 'package:crypto/crypto.dart';

import '../../l10n/current_l.dart';
import 'providers/local_qwen_client.dart';

/// Manages the optional, device-local Assistant model.
class LocalModelStore extends ChangeNotifier {
  LocalModelStore._();

  static final LocalModelStore instance = LocalModelStore._();

  /// Phones keep Qwen3.5-0.8B at Q4_0: they run on the CPU, where
  /// generation speed tracks bytes read per token, and llama.cpp repacks
  /// Q4_0 into its fastest ARM kernels. Laptops and desktops get
  /// Qwen3.5-4B at Q4_K_M — the 0.8B model invents facts and reasons
  /// poorly outside English, and 2.7 GB runs well on a GPU and acceptably
  /// on a laptop CPU. Same family, so the chat template, the empty think
  /// block and the qwenXml tool-call format all carry over unchanged.
  static _ModelFile get _file => Platform.isAndroid ? _phone : _desktop;

  // Sizes and SHA-256s published on Hugging Face for these files at the
  // pinned revisions.
  static const _phone = _ModelFile(
    displayName: 'Qwen3.5-0.8B',
    repository: 'ggml-org/Qwen3.5-0.8B-GGUF',
    revision: '9447f74101aeb4e93621884dfa36ee8effb8831b',
    name: 'Qwen3.5-0.8B-Q4_0.gguf',
    bytes: 563036064,
    sha256: '57d1997790d1744fba5b40a7317df71ea5e2acee28c47e78f0cce39c0703f8cf',
  );
  static const _desktop = _ModelFile(
    displayName: 'Qwen3.5-4B',
    repository: 'lmstudio-community/Qwen3.5-4B-GGUF',
    revision: 'f9f88ac3e234be915e23811a6d28ea287bdb927e',
    name: 'Qwen3.5-4B-Q4_K_M.gguf',
    bytes: 2707513696,
    sha256: '25082a7dd3776cc3c741c6347d3bd04523f05796607b3fbc32fa3a25dfa1418c',
  );

  static String get modelDisplayName => _file.displayName;
  static String get modelFileName => _file.name;
  static String get modelSizeLabel => _file.bytes >= 1e9
      ? '${(_file.bytes / 1e9).toStringAsFixed(1)} GB'
      : '${(_file.bytes / 1e6).round()} MB';

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
      _error = currentL.assistantModelDamaged;
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
        _file.repository,
        modelFileName,
        directory,
        revision: _file.revision,
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
        throw StateError(currentL.assistantModelDownloadInvalid);
      }
      await _deleteOtherModels();
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

  /// Deletes every model file in the models folder except this platform's
  /// current one: the 0.8B a laptop used before it moved to 4B, an older
  /// quantization, or an abandoned partial download. Runs once the current
  /// model is verified, so an upgrade never leaves the old one behind.
  @visibleForTesting
  static Future<void> deleteOtherModels(
    Directory directory,
    String keep,
  ) async {
    if (!await directory.exists()) return;
    await for (final entry in directory.list()) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      if (name == keep) continue;
      if (!name.endsWith('.gguf') && !name.endsWith('.gguf.download')) {
        continue;
      }
      try {
        await entry.delete();
      } catch (error) {
        debugPrint('Could not delete old model $name: $error');
      }
    }
  }

  Future<void> _deleteOtherModels() async {
    // Windows won't delete a file that is still memory-mapped.
    await LocalQwenClient.release();
    await deleteOtherModels(Directory(await _modelDirectory()), modelFileName);
  }

  Future<void> remove() async {
    await LocalQwenClient.release();
    final path = await modelPath();
    if (path != null) await File(path).delete();
    await _deleteOtherModels();
    _modelPathCheck = null;
    notifyListeners();
  }
}

class _ModelFile {
  const _ModelFile({
    required this.displayName,
    required this.repository,
    required this.revision,
    required this.name,
    required this.bytes,
    required this.sha256,
  });

  final String displayName;
  final String repository;
  final String revision;
  final String name;
  final int bytes;
  final String sha256;
}
