import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import '../gallery_cache.dart';
import 'gallery_model_store.dart';
import 'imagenet_buckets.dart';

/// What one photo turned into.
@immutable
class OnnxVerdict {
  const OnnxVerdict({required this.buckets, required this.faces});

  /// Smart album names, e.g. `{'Food', 'Nature'}`.
  final Set<String> buckets;

  /// Detected faces, as fractions of the frame's short edge — enough to tell
  /// a selfie (one big face) from a group shot (several small ones).
  final List<double> faces;
}

/// The desktop half of the smart albums: the same two jobs ML Kit does on the
/// phone — label the picture, find the faces — run through ONNX Runtime
/// against downloaded models.
///
/// Everything happens on this machine. The models are files on disk and the
/// runtime is a local library; no photo, thumbnail or label leaves the
/// device.
class GalleryOnnxAnalyser {
  OrtSession? _classifier;
  OrtSession? _faceDetector;
  bool _failed = false;

  /// Only on the desktops that have no ML Kit. Android and iOS keep using
  /// Google's models, which are better tuned and already installed.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  bool get ready => _classifier != null && _faceDetector != null;

  /// Opens both sessions, downloading the models if this is the first run.
  /// Returns false if anything went wrong — the caller leaves the smart
  /// albums alone rather than failing the whole page.
  Future<bool> prepare({
    void Function(String label, double? progress)? onProgress,
  }) async {
    if (ready) return true;
    if (_failed) return false;
    try {
      await GalleryModelStore.instance
          .ensureDownloaded(onProgress: onProgress);
      onProgress?.call('Starting the models', null);

      final runtime = OnnxRuntime();
      _classifier = await runtime.createSession(
        await GalleryModelStore.instance.pathFor(GalleryModelStore.classifier),
      );
      _faceDetector = await runtime.createSession(
        await GalleryModelStore.instance
            .pathFor(GalleryModelStore.faceDetector),
      );
      return true;
    } catch (error) {
      _failed = true;
      lastError = error.toString();
      await dispose();
      return false;
    }
  }

  /// Why [prepare] gave up, for the UI to show.
  String? lastError;

  /// Runs both models over one already-decoded picture and folds the result
  /// into [previous].
  ///
  /// [bytes] is the gallery's own thumbnail — a few hundred pixels, already
  /// made and cached for the grid. Both models want a small square anyway, so
  /// re-reading the full-size file would be wasted work, and a cloud
  /// placeholder (which has no thumbnail) is skipped for free.
  Future<GalleryCacheEntry> analyse(
    Uint8List bytes,
    GalleryCacheEntry previous,
  ) async {
    if (!ready) return previous.copyWith(analysed: true);
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return previous.copyWith(analysed: true);

      final verdict = await run(decoded);
      return previous.copyWith(
        faceCount: verdict.faces.length,
        labels: [
          ...verdict.buckets,
          if (isSelfieShaped(verdict.faces)) selfieLabel,
        ],
        analysed: true,
      );
    } catch (_) {
      // One photo the models choke on shouldn't stop the pass, and shouldn't
      // be retried on every launch either.
      return previous.copyWith(analysed: true);
    }
  }

  /// The inference proper, split out so it can be driven from a test with a
  /// synthetic image.
  Future<OnnxVerdict> run(img.Image image) async {
    final buckets = await _classify(image);
    final faces = await _detectFaces(image);
    return OnnxVerdict(buckets: buckets, faces: faces);
  }

  Future<Set<String>> _classify(img.Image image) async {
    final session = _classifier;
    if (session == null) return {};

    final input = await OrtValue.fromList(
      preprocessClassifier(image),
      [1, 3, classifierSize, classifierSize],
    );
    Map<String, OrtValue>? outputs;
    try {
      outputs = await session.run({session.inputNames.first: input});
      final raw = await outputs[session.outputNames.first]!.asFlattenedList();
      final scores = [for (final value in raw) (value as num).toDouble()];
      return bucketsFromScores(scores);
    } finally {
      await input.dispose();
      for (final value in outputs?.values ?? const <OrtValue>[]) {
        await value.dispose();
      }
    }
  }

  Future<List<double>> _detectFaces(img.Image image) async {
    final session = _faceDetector;
    if (session == null) return const [];

    final input = await OrtValue.fromList(
      preprocessFaceDetector(image),
      [1, 3, faceDetectorHeight, faceDetectorWidth],
    );
    Map<String, OrtValue>? outputs;
    try {
      outputs = await session.run({session.inputNames.first: input});
      // UltraFace emits two tensors: per-anchor confidences (background,
      // face) and per-anchor boxes. Their order in outputNames isn't
      // guaranteed, so they're told apart by shape: 2 values per anchor
      // against 4.
      List<double>? scores;
      List<double>? boxes;
      for (final entry in outputs.entries) {
        final flat = await entry.value.asFlattenedList();
        final values = [for (final v in flat) (v as num).toDouble()];
        final perAnchor = values.length ~/ math.max(1, _anchorCount(values));
        if (perAnchor == 2 || entry.key.toLowerCase().contains('score')) {
          scores ??= values;
        } else {
          boxes ??= values;
        }
      }
      if (scores == null || boxes == null) return const [];
      return facesFromOutputs(scores, boxes);
    } finally {
      await input.dispose();
      for (final value in outputs?.values ?? const <OrtValue>[]) {
        await value.dispose();
      }
    }
  }

  /// Both output tensors share an anchor count; whichever divides evenly by
  /// both 2 and 4 is resolved by taking the larger divisor.
  int _anchorCount(List<double> values) =>
      values.length % 4 == 0 ? values.length ~/ 4 : values.length ~/ 2;

  Future<void> dispose() async {
    await _classifier?.close();
    await _faceDetector?.close();
    _classifier = null;
    _faceDetector = null;
  }
}

/// Marker written alongside the buckets, matching the ML Kit path.
const selfieLabel = '_selfie';

/// MobileNetV2 takes a 224×224 square.
const classifierSize = 224;

/// UltraFace RFB-320 takes 320×240.
const faceDetectorWidth = 320;
const faceDetectorHeight = 240;

/// ImageNet's channel statistics, which the classifier was trained against.
const _mean = [0.485, 0.456, 0.406];
const _std = [0.229, 0.224, 0.225];

/// Turns a picture into MobileNetV2's input: a centre-cropped 224×224 square,
/// scaled to 0..1, normalised per channel, laid out channel-first (NCHW).
Float32List preprocessClassifier(img.Image image) {
  final square = _centreSquare(image, classifierSize);
  final out = Float32List(3 * classifierSize * classifierSize);
  const plane = classifierSize * classifierSize;

  for (var y = 0; y < classifierSize; y++) {
    for (var x = 0; x < classifierSize; x++) {
      final pixel = square.getPixel(x, y);
      final offset = y * classifierSize + x;
      out[offset] = (pixel.rNormalized - _mean[0]) / _std[0];
      out[plane + offset] = (pixel.gNormalized - _mean[1]) / _std[1];
      out[2 * plane + offset] = (pixel.bNormalized - _mean[2]) / _std[2];
    }
  }
  return out;
}

/// UltraFace's input: the whole frame squashed to 320×240, centred on 127 and
/// divided by 128, channel-first.
Float32List preprocessFaceDetector(img.Image image) {
  final resized = img.copyResize(
    image,
    width: faceDetectorWidth,
    height: faceDetectorHeight,
  );
  final out = Float32List(3 * faceDetectorHeight * faceDetectorWidth);
  const plane = faceDetectorHeight * faceDetectorWidth;

  for (var y = 0; y < faceDetectorHeight; y++) {
    for (var x = 0; x < faceDetectorWidth; x++) {
      final pixel = resized.getPixel(x, y);
      final offset = y * faceDetectorWidth + x;
      out[offset] = (pixel.r - 127) / 128;
      out[plane + offset] = (pixel.g - 127) / 128;
      out[2 * plane + offset] = (pixel.b - 127) / 128;
    }
  }
  return out;
}

/// Resizes so the short edge is [size], then crops the middle — the standard
/// ImageNet evaluation transform, and the one that keeps a portrait's subject
/// rather than squashing it.
img.Image _centreSquare(img.Image image, int size) {
  final shortest = math.min(image.width, image.height);
  if (shortest <= 0) return img.Image(width: size, height: size);
  final scale = size / shortest;
  final resized = img.copyResize(
    image,
    width: math.max(size, (image.width * scale).round()),
    height: math.max(size, (image.height * scale).round()),
  );
  return img.copyCrop(
    resized,
    x: (resized.width - size) ~/ 2,
    y: (resized.height - size) ~/ 2,
    width: size,
    height: size,
  );
}

/// How sure the classifier must be before a photo joins an album. ImageNet
/// models are confident when they are right and spread thin when they aren't,
/// so a plain probability floor separates the two well.
const classifierThreshold = 0.22;

/// The albums a classifier output belongs to. [scores] are the raw logits;
/// the softmax and the mapping happen here.
Set<String> bucketsFromScores(List<double> scores) {
  if (scores.isEmpty) return {};
  final probabilities = softmax(scores);
  final buckets = <String>{};
  for (var i = 0; i < probabilities.length; i++) {
    if (probabilities[i] < classifierThreshold) continue;
    final bucket = bucketForImagenetClass(i);
    if (bucket != null) buckets.add(bucket);
  }
  return buckets;
}

List<double> softmax(List<double> logits) {
  var highest = double.negativeInfinity;
  for (final value in logits) {
    if (value > highest) highest = value;
  }
  var total = 0.0;
  final out = List<double>.filled(logits.length, 0);
  for (var i = 0; i < logits.length; i++) {
    final value = math.exp(logits[i] - highest);
    out[i] = value;
    total += value;
  }
  if (total <= 0) return out;
  for (var i = 0; i < out.length; i++) {
    out[i] /= total;
  }
  return out;
}

/// A detection has to beat this to count as a face.
const faceThreshold = 0.7;

/// Two boxes overlapping by more than this are the same face seen by two
/// anchors.
const faceOverlapThreshold = 0.35;

/// Reads UltraFace's two output tensors into a list of face sizes, each as a
/// fraction of the frame's width.
///
/// [scores] is `anchors × 2` — background first, then face. [boxes] is
/// `anchors × 4` — left, top, right, bottom, already in 0..1. Overlapping
/// detections are merged, because every face lights up several anchors.
List<double> facesFromOutputs(List<double> scores, List<double> boxes) {
  final anchors = math.min(scores.length ~/ 2, boxes.length ~/ 4);
  final found = <_Detection>[];

  for (var i = 0; i < anchors; i++) {
    final confidence = scores[i * 2 + 1];
    if (confidence < faceThreshold) continue;
    final left = boxes[i * 4];
    final top = boxes[i * 4 + 1];
    final right = boxes[i * 4 + 2];
    final bottom = boxes[i * 4 + 3];
    if (right <= left || bottom <= top) continue;
    found.add(_Detection(confidence, left, top, right, bottom));
  }

  found.sort((a, b) => b.confidence.compareTo(a.confidence));

  final kept = <_Detection>[];
  for (final candidate in found) {
    var overlaps = false;
    for (final chosen in kept) {
      if (candidate.overlapWith(chosen) > faceOverlapThreshold) {
        overlaps = true;
        break;
      }
    }
    if (!overlaps) kept.add(candidate);
  }

  return [for (final face in kept) face.right - face.left];
}

/// One face filling a good part of the frame is how a selfie looks to a
/// detector — the arm is only so long.
bool isSelfieShaped(List<double> faceWidths) =>
    faceWidths.length == 1 && faceWidths.first >= 0.30;

class _Detection {
  const _Detection(
    this.confidence,
    this.left,
    this.top,
    this.right,
    this.bottom,
  );

  final double confidence;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get area => (right - left) * (bottom - top);

  /// Intersection over union.
  double overlapWith(_Detection other) {
    final x1 = math.max(left, other.left);
    final y1 = math.max(top, other.top);
    final x2 = math.min(right, other.right);
    final y2 = math.min(bottom, other.bottom);
    if (x2 <= x1 || y2 <= y1) return 0;
    final intersection = (x2 - x1) * (y2 - y1);
    final union = area + other.area - intersection;
    return union <= 0 ? 0 : intersection / union;
  }
}
