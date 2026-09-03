import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// One of the two models the desktop analyser runs.
class GalleryModel {
  const GalleryModel({
    required this.fileName,
    required this.url,
    required this.approximateBytes,
    required this.description,
  });

  final String fileName;
  final String url;

  /// Only for the "this will download about N MB" line — the real size comes
  /// from the response.
  final int approximateBytes;

  final String description;
}

/// Where the gallery's on-device models come from.
///
/// Nothing is bundled with the app. Files are pulled on first use and cached
/// under the app's support directory, exactly as the Media Downloader
/// plugin does with yt-dlp and ffmpeg — it keeps the weights out of the
/// installer and out of git, and someone who never opens a smart album never
/// downloads them at all.
///
/// Two groups, downloaded independently because they're needed by different
/// platforms:
///  * [labelModels] — the classifier and face detector. Desktop-only: the
///    phone builds already have Google's ML Kit for this, bundled in the app.
///  * [embedder] — turns a face crop into a fingerprint for the People
///    album. Neither ML Kit nor the platform SDKs do this, so *every*
///    platform downloads this one small model.
///
/// Everything lands in `tools/`, which [StorageGuardService] leaves out of
/// the local storage cap: these are program files, not the user's data.
class GalleryModelStore {
  GalleryModelStore._();
  static final GalleryModelStore instance = GalleryModelStore._();

  /// ImageNet-1k classifier, Apache-2.0, from the ONNX Model Zoo mirror on
  /// Hugging Face. This is what names what is in a photo.
  static const classifier = GalleryModel(
    fileName: 'mobilenetv2-12.onnx',
    url: 'https://huggingface.co/onnxmodelzoo/mobilenetv2-12/resolve/main/'
        'mobilenetv2-12.onnx',
    approximateBytes: 14 * 1024 * 1024,
    description: 'image labelling',
  );

  /// UltraFace RFB-320, MIT, same mirror. Finds faces; like ML Kit it does
  /// not recognise them.
  static const faceDetector = GalleryModel(
    fileName: 'version-RFB-320.onnx',
    url: 'https://huggingface.co/onnxmodelzoo/version-RFB-320/resolve/main/'
        'version-RFB-320.onnx',
    approximateBytes: 1280 * 1024,
    description: 'face detection',
  );

  /// SFace, Apache-2.0, from OpenCV's own model zoo — the block-quantised
  /// build, a third the size of the reference file with the same graph.
  /// Turns a face crop into a fingerprint two photos of the same person land
  /// close together in; that's what the People album clusters on.
  static const embedder = GalleryModel(
    fileName: 'face_recognition_sface_2021dec_int8bq.onnx',
    url: 'https://huggingface.co/opencv/face_recognition_sface/resolve/main/'
        'face_recognition_sface_2021dec_int8bq.onnx',
    approximateBytes: 11 * 1024 * 1024,
    description: 'face recognition',
  );

  /// Desktop-only: what [GalleryOnnxAnalyser] needs for labels and detection.
  static const labelModels = [classifier, faceDetector];

  /// Every model this build might need to fetch. Used to size the "about N
  /// MB" line; which of them are actually downloaded is decided per platform
  /// by which list is passed to [ensureDownloaded].
  static const allModels = [classifier, faceDetector, embedder];

  static int bytesFor(List<GalleryModel> models) =>
      models.fold(0, (sum, model) => sum + model.approximateBytes);

  Directory? _directory;

  Future<Directory> _toolsDirectory() async {
    final existing = _directory;
    if (existing != null) return existing;
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}${Platform.pathSeparator}tools',
    );
    if (!directory.existsSync()) await directory.create(recursive: true);
    return _directory = directory;
  }

  Future<String> pathFor(GalleryModel model) async =>
      '${(await _toolsDirectory()).path}'
      '${Platform.pathSeparator}${model.fileName}';

  Future<bool> isDownloaded(GalleryModel model) async =>
      File(await pathFor(model)).exists();

  Future<bool> readyFor(List<GalleryModel> models) async {
    for (final model in models) {
      if (!await isDownloaded(model)) return false;
    }
    return true;
  }

  /// Fetches whichever of [models] are missing, reporting 0..1 across the
  /// whole job. Throws [GalleryModelException] if a download fails; the
  /// caller shows the message as-is.
  Future<void> ensureDownloaded(
    List<GalleryModel> models, {
    void Function(String label, double? progress)? onProgress,
  }) async {
    for (var i = 0; i < models.length; i++) {
      final model = models[i];
      final file = File(await pathFor(model));
      if (file.existsSync() && await file.length() > 0) continue;

      final label = 'Downloading the ${model.description} model';
      onProgress?.call(label, i / models.length);
      await _download(model, file, (fraction) {
        onProgress?.call(label, (i + fraction) / models.length);
      });
    }
    onProgress?.call('Ready', 1);
  }

  Future<void> _download(
    GalleryModel model,
    File target,
    void Function(double fraction) onProgress,
  ) async {
    final client = http.Client();
    // Written beside the target and renamed at the end, so an interrupted
    // download can never be mistaken for a usable model on the next run.
    final partial = File('${target.path}.part');
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(model.url));
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw GalleryModelException(
          'The ${model.description} model could not be downloaded '
          '(HTTP ${response.statusCode}).',
        );
      }

      final total = response.contentLength ?? model.approximateBytes;
      var received = 0;
      sink = partial.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress((received / total).clamp(0, 1));
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (await partial.length() <= 0) {
        throw GalleryModelException(
          'The ${model.description} model downloaded as an empty file.',
        );
      }
      if (target.existsSync()) await target.delete();
      await partial.rename(target.path);
    } on GalleryModelException {
      rethrow;
    } catch (error) {
      throw GalleryModelException(
        'The ${model.description} model could not be downloaded: $error',
      );
    } finally {
      await sink?.close();
      if (partial.existsSync()) {
        try {
          await partial.delete();
        } catch (_) {
          // A leftover .part is harmless; the next run overwrites it.
        }
      }
      client.close();
    }
  }

  /// Deletes every model this store knows about. Offered in the UI so the
  /// space can be reclaimed.
  Future<void> deleteAll() async {
    for (final model in allModels) {
      final file = File(await pathFor(model));
      if (file.existsSync()) await file.delete();
    }
  }
}

class GalleryModelException implements Exception {
  const GalleryModelException(this.message);
  final String message;

  @override
  String toString() => message;
}
