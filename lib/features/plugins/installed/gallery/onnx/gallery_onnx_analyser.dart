import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import '../gallery_cache.dart';
import '../gallery_people.dart';
import 'gallery_face_embedder.dart';
import 'gallery_model_store.dart';
import 'imagenet_buckets.dart';

/// Everything one photo needs, built in a worker isolate by
/// [_preparePhoto]: a ready tensor per model, the two pixel-read markers,
/// and the decoded pixels themselves for the face-recognition crops.
class _PreparedPhoto {
  const _PreparedPhoto({
    required this.classifier,
    required this.detector,
    required this.sky,
    required this.night,
    required this.pixels,
  });

  final Float32List classifier;
  final Float32List detector;
  final bool sky;
  final bool night;

  /// The decoded thumbnail. Small — it was a few hundred pixels before it
  /// was ever decoded — so handing it back across the isolate boundary costs
  /// nothing next to what made it.
  final img.Image pixels;
}

/// The CPU half of one photo's analysis: decode, both models' input tensors,
/// and the sky/night heuristics. Runs on a worker isolate via [compute] —
/// see [GalleryOnnxAnalyser.analyse].
_PreparedPhoto? _preparePhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  return _PreparedPhoto(
    classifier: preprocessClassifier(decoded),
    detector: preprocessFaceDetector(decoded),
    sky: hasSky(decoded),
    night: isNightShot(decoded),
    pixels: decoded,
  );
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
      await GalleryModelStore.instance.ensureDownloaded(
        GalleryModelStore.labelModels,
        onProgress: onProgress,
      );
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
  ///
  /// Decoding the thumbnail, building both input tensors and reading the sky
  /// and night markers are all pixel loops that take longer than the models
  /// themselves on the UI thread — a photo every couple of seconds is fine,
  /// but a jank frame per photo is what made the pass feel like a crawl. They
  /// run in a worker isolate instead; only the sessions, which must stay on
  /// the isolate that opened them, run here.
  ///
  /// [embedder] and [people] are the cross-platform recognition step (see
  /// [GalleryFaceEmbedder]) — passed in rather than owned here, since the
  /// phone's ML Kit path needs the exact same two objects.
  Future<GalleryCacheEntry> analyse(
    Uint8List bytes,
    GalleryCacheEntry previous, {
    required GalleryFaceEmbedder embedder,
    required GalleryPeopleStore people,
    required String cacheKey,
  }) async {
    if (!ready) return previous.copyWith(analysed: true, skipped: true);
    try {
      final prepared = await compute(_preparePhoto, bytes);
      if (prepared == null) {
        return previous.copyWith(analysed: true, skipped: true);
      }

      final buckets = await _classify(prepared.classifier);
      final faces = await _detectFaces(prepared.detector);
      final personIds = await identifyPeople(
        prepared.pixels,
        faces,
        embedder: embedder,
        people: people,
        coverKey: cacheKey,
      );
      return previous.copyWith(
        faceCount: faces.length,
        labels: [
          ...buckets,
          if (isSelfieShaped(faces)) selfieLabel,
          if (prepared.sky) skyLabel,
          if (prepared.night) nightLabel,
        ],
        personIds: personIds,
        analysed: true,
      );
    } catch (_) {
      // One photo the models choke on shouldn't stop the pass, and shouldn't
      // be retried on every launch either.
      return previous.copyWith(analysed: true);
    }
  }

  Future<Set<String>> _classify(Float32List tensor) async {
    final session = _classifier;
    if (session == null) return {};

    final input = await OrtValue.fromList(
      tensor,
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

  Future<List<GalleryFace>> _detectFaces(Float32List tensor) async {
    final session = _faceDetector;
    if (session == null) return const [];

    final input = await OrtValue.fromList(
      tensor,
      [1, 3, faceDetectorHeight, faceDetectorWidth],
    );
    Map<String, OrtValue>? outputs;
    try {
      outputs = await session.run({session.inputNames.first: input});
      // UltraFace emits two tensors: per-anchor confidences (background,
      // face) at [1, anchors, 2] and per-anchor boxes at [1, anchors, 4].
      // Their order in outputNames isn't guaranteed, so they are told apart
      // by the last dimension of their shape.
      //
      // Not by their flattened length: 4420 anchors × 2 scores is 8840, which
      // divides by four just as neatly as the boxes do, so counting values
      // gets it backwards. The shape is unambiguous.
      List<double>? scores;
      List<double>? boxes;
      for (final value in outputs.values) {
        final flat = await value.asFlattenedList();
        final numbers = [for (final v in flat) (v as num).toDouble()];
        final trailing = value.shape.isEmpty ? 0 : value.shape.last;
        if (trailing == 2) {
          scores ??= numbers;
        } else if (trailing == 4) {
          boxes ??= numbers;
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

  Future<void> dispose() async {
    await _classifier?.close();
    await _faceDetector?.close();
    _classifier = null;
    _faceDetector = null;
  }
}

/// Markers written alongside the buckets, matching the ML Kit path.
const selfieLabel = '_selfie';

/// Sky and night are qualities of a scene, not objects in it, and ImageNet
/// has no class for either — it is a list of a thousand *things*. They are
/// read straight off the pixels instead, from the thumbnail the analyser has
/// already decoded, which costs nothing next to running a model.
const skyLabel = '_sky';
const nightLabel = '_night';

/// A photo counts as having sky when this much of its top third is sky-
/// coloured. Less than a third and it is a patch of blue behind a building,
/// which is most outdoor photographs.
const skyCoverage = 0.55;

/// Mean brightness (0–255) below which a picture was taken in the dark.
const nightLuminance = 62.0;

/// A night shot still has lights in it. Without this a scan of a black
/// screenshot, a lens cap or an underexposed failure joins the album.
const nightHighlight = 150.0;

/// Whether the top of the frame is open sky.
///
/// Only blue sky is claimed. Overcast white would need separating from walls,
/// ceilings and paper, and a Sky album full of indoor shots is worse than one
/// that misses grey days.
bool hasSky(img.Image image) {
  if (image.width < 4 || image.height < 4) return false;
  final bottom = math.max(1, image.height ~/ 3);
  // Every fourth pixel is plenty to judge a region this size.
  const step = 4;
  var sampled = 0;
  var skyLike = 0;

  for (var y = 0; y < bottom; y += step) {
    for (var x = 0; x < image.width; x += step) {
      final pixel = image.getPixel(x, y);
      final r = pixel.r.toDouble();
      final g = pixel.g.toDouble();
      final b = pixel.b.toDouble();
      sampled++;
      // Blue ahead of both other channels, and bright enough to be daylight
      // rather than a navy jumper.
      if (b > 90 && b - r > 18 && b >= g) skyLike++;
    }
  }
  if (sampled == 0) return false;
  return skyLike / sampled >= skyCoverage;
}

/// Whether the picture was taken in the dark: mostly shadow, but with
/// something bright in it.
bool isNightShot(img.Image image) {
  if (image.width < 2 || image.height < 2) return false;
  const step = 4;
  var sampled = 0;
  var total = 0.0;
  var brightest = 0.0;

  for (var y = 0; y < image.height; y += step) {
    for (var x = 0; x < image.width; x += step) {
      final pixel = image.getPixel(x, y);
      // Rec. 601 luma, which is what "how bright does this look" means.
      final luma =
          0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
      total += luma;
      if (luma > brightest) brightest = luma;
      sampled++;
    }
  }
  if (sampled == 0) return false;
  return (total / sampled) < nightLuminance && brightest > nightHighlight;
}

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

/// How sure the classifier must be before a photo joins an album.
///
/// Spread over a thousand classes, a correct answer is often only 0.15–0.4 —
/// a 1000-way softmax rarely produces the 0.9 a binary classifier would. A
/// floor set for the latter is why a 23 000-photo library first produced
/// albums with three items in them.
const classifierThreshold = 0.10;

/// How far down the ranking to look. The right answer for a photo of a dog on
/// a beach might be split between several dog breeds and "seashore", none of
/// them individually dominant, and both albums are ones a person would want
/// it in.
const classifierTopK = 5;

/// The albums a classifier output belongs to. [scores] are the raw logits;
/// the softmax, the ranking and the mapping happen here.
Set<String> bucketsFromScores(List<double> scores) {
  if (scores.isEmpty) return {};
  final probabilities = softmax(scores);

  // Rank the classes, then walk the best few.
  final ranked = List<int>.generate(probabilities.length, (i) => i)
    ..sort((a, b) => probabilities[b].compareTo(probabilities[a]));

  final buckets = <String>{};
  for (final index in ranked.take(classifierTopK)) {
    if (probabilities[index] < classifierThreshold) break;
    final bucket = bucketForImagenetClass(index);
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
///
/// UltraFace is a 1 MB model and it is generous: at the 0.7 the reference
/// code uses it will find a face in a plate of eggs. Since a false positive
/// here doesn't just mislabel one photo but drops it into the People album —
/// and a lone big one makes it a "selfie" — the bar is set high. Missing a
/// face in a dim group shot is the cheaper mistake.
const faceThreshold = 0.9;

/// A face has to be at least this wide, as a fraction of the frame. Below it
/// the detector is picking texture out of the background.
const minimumFaceWidth = 0.04;

/// Real faces are roughly as tall as they are wide — between these, allowing
/// for hair, chins and a tilted head. Spurious boxes tend to be long thin
/// slivers of pattern, and this is what rejects them.
const minimumFaceAspect = 0.7;
const maximumFaceAspect = 2.2;

/// Two boxes overlapping by more than this are the same face seen by two
/// anchors.
const faceOverlapThreshold = 0.35;

/// Reads UltraFace's two output tensors into a list of face sizes, each as a
/// fraction of the frame's width.
///
/// [scores] is `anchors × 2` — background first, then face. [boxes] is
/// `anchors × 4` — left, top, right, bottom, already in 0..1. Overlapping
/// detections are merged, because every face lights up several anchors.
List<GalleryFace> facesFromOutputs(List<double> scores, List<double> boxes) {
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

    final width = right - left;
    final height = bottom - top;
    if (width < minimumFaceWidth) continue;
    final aspect = height / width;
    if (aspect < minimumFaceAspect || aspect > maximumFaceAspect) continue;

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

  return [
    for (final face in kept)
      GalleryFace(
        left: face.left,
        top: face.top,
        right: face.right,
        bottom: face.bottom,
      ),
  ];
}

/// A detected face's box, as fractions of the frame (0..1). Carries the full
/// box rather than just a size — [width]/[centreX]/[centreY] cover the
/// selfie/group-shot heuristics, and the box itself is what a crop for
/// [GalleryFaceEmbedder] is taken from.
@immutable
class GalleryFace {
  const GalleryFace({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  double get centreX => (left + right) / 2;
  double get centreY => (top + bottom) / 2;
}

/// One big face near the middle of the frame is how a selfie looks to a
/// detector — the arm is only so long, and people point the camera at
/// themselves. Requiring the position as well as the size is what keeps a
/// stray detection in the corner of a landscape from being called one.
bool isSelfieShaped(List<GalleryFace> faces) {
  if (faces.length != 1) return false;
  final face = faces.first;
  return face.width >= 0.28 &&
      face.centreX > 0.2 &&
      face.centreX < 0.8 &&
      face.centreY < 0.85;
}

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
