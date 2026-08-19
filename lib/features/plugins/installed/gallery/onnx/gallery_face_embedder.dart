import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import '../gallery_people.dart';
import 'gallery_model_store.dart';
import 'gallery_onnx_analyser.dart' show GalleryFace;

/// Turns a face crop into a fingerprint — a vector where two photos of the
/// same person land close together and two different people land apart.
///
/// This is the one piece of the smart albums that runs on every platform
/// through ONNX Runtime, including the phone: neither ML Kit nor any bundled
/// SDK does face *recognition* (only detection), so there was nothing to
/// reuse here the way the phone reuses ML Kit for labels and detection.
///
/// The model is SFace, from OpenCV's own zoo. Its reference pipeline expects
/// a face crop *aligned* by a 5-point landmark warp — eyes and mouth rotated
/// onto fixed canonical positions — which needs a landmark model this app
/// doesn't have (UltraFace and ML Kit's fast detector both give a bounding
/// box only). What ships here instead is a padded, un-rotated square crop of
/// that box. This is a real accuracy trade, not a rounding error: an
/// off-angle or tilted face will embed less reliably than the paper's own
/// benchmarks, and the whole feature is unsupervised on top of that, so
/// treat "Person 3" groupings as a good-faith clustering rather than a
/// verified identification.
class GalleryFaceEmbedder {
  OrtSession? _session;
  bool _failed = false;
  String? lastError;

  bool get ready => _session != null;

  /// Downloads the model on first call, then loads it. Safe to call from
  /// every platform — it's the one model the phone builds fetch too.
  Future<bool> prepare({
    void Function(String label, double? progress)? onProgress,
  }) async {
    if (ready) return true;
    if (_failed) return false;
    try {
      await GalleryModelStore.instance.ensureDownloaded(
        [GalleryModelStore.embedder],
        onProgress: onProgress,
      );
      final path = await GalleryModelStore.instance
          .pathFor(GalleryModelStore.embedder);
      _session = await OnnxRuntime().createSession(path);
      return true;
    } catch (error) {
      _failed = true;
      lastError = error.toString();
      return false;
    }
  }

  /// The fingerprint for the face at [box] within [image], or null if the
  /// model isn't ready or the crop is degenerate.
  Future<List<double>?> embed(img.Image image, GalleryFace box) async {
    final session = _session;
    if (session == null) return null;

    final crop = cropFace(image, box);
    if (crop == null) return null;

    final input = await OrtValue.fromList(
      preprocessFaceEmbedding(crop),
      [1, 3, faceEmbedInputSize, faceEmbedInputSize],
    );
    Map<String, OrtValue>? outputs;
    try {
      outputs = await session.run({session.inputNames.first: input});
      final flat =
          await outputs[session.outputNames.first]!.asFlattenedList();
      return [for (final v in flat) (v as num).toDouble()];
    } catch (_) {
      return null;
    } finally {
      await input.dispose();
      for (final value in outputs?.values ?? const <OrtValue>[]) {
        await value.dispose();
      }
    }
  }

  Future<void> dispose() async {
    await _session?.close();
    _session = null;
  }
}

/// Runs [embedder] over each of [faces] found in [image] and assigns each to
/// a person in [people], returning the ids that were found.
///
/// Shared by both platforms: the phone decodes the file and runs ML Kit's
/// detector over it, desktop decodes the thumbnail and runs UltraFace, and
/// both end up here with the same two things — a decoded image and a list of
/// boxes in its coordinate space — so recognition itself needs writing once.
///
/// A face that fails to embed (a degenerate crop, a model hiccup) is simply
/// left out rather than failing the whole photo; the other faces in the same
/// picture still get identified.
Future<List<int>> identifyPeople(
  img.Image image,
  List<GalleryFace> faces, {
  required GalleryFaceEmbedder embedder,
  required GalleryPeopleStore people,
  required String coverKey,
}) async {
  if (!embedder.ready || faces.isEmpty) return const [];
  final ids = <int>[];
  for (final face in faces) {
    final embedding = await embedder.embed(image, face);
    if (embedding == null) continue;
    ids.add(people.assign(embedding, coverKey: coverKey));
  }
  return ids;
}

/// SFace's input square, in pixels.
const faceEmbedInputSize = 112;

/// How much wider than the detected box to crop. A tight box cuts off chin
/// and forehead; real face-recognition pipelines crop generously around the
/// landmarks for exactly this reason.
const faceEmbedMargin = 0.30;

/// Crops the padded square around [box] out of [image] and resizes it to
/// SFace's input size. Returns null if the box has collapsed to nothing —
/// clamping against the frame edge can do that for a face right at a corner.
img.Image? cropFace(img.Image image, GalleryFace box) {
  final centreX = box.centreX * image.width;
  final centreY = box.centreY * image.height;
  final halfSide =
      math.max(box.width * image.width, box.height * image.height) *
          (1 + faceEmbedMargin) /
          2;

  final left = (centreX - halfSide).round().clamp(0, image.width - 1);
  final top = (centreY - halfSide).round().clamp(0, image.height - 1);
  final right = (centreX + halfSide).round().clamp(left + 1, image.width);
  final bottom = (centreY + halfSide).round().clamp(top + 1, image.height);

  final width = right - left;
  final height = bottom - top;
  if (width < 4 || height < 4) return null;

  final cropped = img.copyCrop(
    image,
    x: left,
    y: top,
    width: width,
    height: height,
  );
  return img.copyResize(
    cropped,
    width: faceEmbedInputSize,
    height: faceEmbedInputSize,
  );
}

/// SFace's own preprocessing (`cv::dnn::blobFromImage` with scale 1, mean 0,
/// `swapRB=true`): plain 0..255 RGB values, no normalisation at all — unusual
/// among vision models (most divide by 255 or subtract a mean), but that is
/// what the reference C++ implementation actually does, and guessing
/// otherwise would silently wreck every embedding.
///
/// `blobFromImage` also always emits channel-first (NCHW) — three separate
/// planes, not one interleaved RGB buffer — regardless of the model, so the
/// layout here has to match [preprocessClassifier]'s, not a naive per-pixel
/// write.
Float32List preprocessFaceEmbedding(img.Image face) {
  final out = Float32List(3 * faceEmbedInputSize * faceEmbedInputSize);
  const plane = faceEmbedInputSize * faceEmbedInputSize;
  for (var y = 0; y < faceEmbedInputSize; y++) {
    for (var x = 0; x < faceEmbedInputSize; x++) {
      final pixel = face.getPixel(x, y);
      final offset = y * faceEmbedInputSize + x;
      out[offset] = pixel.r.toDouble();
      out[plane + offset] = pixel.g.toDouble();
      out[2 * plane + offset] = pixel.b.toDouble();
    }
  }
  return out;
}
