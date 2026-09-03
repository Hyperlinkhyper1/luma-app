import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import '../gallery_cache.dart';
import '../gallery_people.dart';
import 'gallery_face_embedder.dart';
import 'gallery_model_store.dart';
import 'imagenet_buckets.dart';

/// A decoded picture: its pixels as tightly-packed RGBA, row-major from the
/// top left, with the dimensions to walk them by.
@immutable
class DecodedPixels {
  const DecodedPixels(this.rgba, this.width, this.height);

  final Uint8List rgba;
  final int width;
  final int height;
}

/// Decodes an already-encoded picture (the PNG or JPEG bytes a thumbnail
/// cache stores) into [DecodedPixels].
///
/// This goes through the engine's own codecs rather than `package:image`.
/// The difference is not subtle: a pure-Dart decoder walks every pixel of
/// the picture in Dart, while libjpeg-turbo and friends do the same work an
/// order of magnitude faster and off the UI thread entirely. At a photo a
/// second the slow way, decoding alone was most of the budget.
Future<DecodedPixels?> decodeToRgba(Uint8List bytes) async {
  ui.Codec? codec;
  ui.Image? image;
  try {
    codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    image = frame.image;
    final data =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    return DecodedPixels(
      Uint8List.view(
        data.buffer,
        data.offsetInBytes,
        data.lengthInBytes,
      ),
      image.width,
      image.height,
    );
  } catch (_) {
    return null;
  } finally {
    image?.dispose();
    codec?.dispose();
  }
}

/// Scratch space for [_bilinearSample]; reused across calls so the hot loops
/// never allocate per pixel.
final Float64List _sampled = Float64List(3);

/// Reads the colour at ([fx], [fy]) in source-pixel coordinates, blending the
/// four neighbours — the same resampling `copyResize` does, just without
/// materialising an intermediate image first.
void _bilinearSample(
  Uint8List pixels,
  int width,
  int height,
  int channels,
  double fx,
  double fy,
) {
  final x = fx.clamp(0.0, (width - 1).toDouble());
  final y = fy.clamp(0.0, (height - 1).toDouble());
  final x0 = x.floor();
  final y0 = y.floor();
  final x1 = math.min(x0 + 1, width - 1);
  final y1 = math.min(y0 + 1, height - 1);
  final ax = x - x0;
  final ay = y - y0;

  for (var c = 0; c < 3; c++) {
    final tl = pixels[(y0 * width + x0) * channels + c].toDouble();
    final tr = pixels[(y0 * width + x1) * channels + c].toDouble();
    final bl = pixels[(y1 * width + x0) * channels + c].toDouble();
    final br = pixels[(y1 * width + x1) * channels + c].toDouble();
    final top = tl + (tr - tl) * ax;
    final bottom = bl + (br - bl) * ax;
    _sampled[c] = top + (bottom - top) * ay;
  }
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
  /// The two sessions run together: they are independent models on separate
  /// ORT sessions, so paying the classifier's latency and then the detector's
  /// was half again as long per photo as it needed to be.
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
      final photo = await decodeToRgba(bytes);
      if (photo == null) {
        return previous.copyWith(analysed: true, skipped: true);
      }

      final results = await Future.wait([
        _classify(classifierTensorFromRgba(photo)),
        _detectFaces(detectorTensorFromRgba(photo)),
      ]);
      final buckets = results[0] as Set<String>;
      final faces = results[1] as List<GalleryFace>;

      var personIds = const <int>[];
      if (faces.isNotEmpty && embedder.ready) {
        personIds = await identifyPeopleRgba(
          photo,
          faces,
          embedder: embedder,
          people: people,
          coverKey: cacheKey,
        );
      }

      return previous.copyWith(
        faceCount: faces.length,
        labels: [
          ...buckets,
          if (isSelfieShaped(faces)) selfieLabel,
          if (hasSkyInPixels(photo.rgba, photo.width, photo.height)) skyLabel,
          if (isNightShotInPixels(photo.rgba, photo.width, photo.height))
            nightLabel,
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
bool hasSky(img.Image image) =>
    hasSkyInPixels(
      image.getBytes(order: img.ChannelOrder.rgb),
      image.width,
      image.height,
      channels: 3,
    );

/// Whether the picture was taken in the dark: mostly shadow, but with
/// something bright in it.
bool isNightShot(img.Image image) =>
    isNightShotInPixels(
      image.getBytes(order: img.ChannelOrder.rgb),
      image.width,
      image.height,
      channels: 3,
    );

/// The same two questions, asked of a raw pixel buffer — RGBA or RGB, per
/// [channels]. This is the form the analyser actually has in hand, and
/// walking a `Uint8List` by index is an order of magnitude cheaper than the
/// per-pixel object access a decoded [img.Image] costs.
bool hasSkyInPixels(
  Uint8List pixels,
  int width,
  int height, {
  int channels = 4,
}) {
  if (width < 4 || height < 4) return false;
  final bottom = math.max(1, height ~/ 3);
  // Every fourth pixel is plenty to judge a region this size.
  const step = 4;
  var sampled = 0;
  var skyLike = 0;

  for (var y = 0; y < bottom; y += step) {
    for (var x = 0; x < width; x += step) {
      final offset = (y * width + x) * channels;
      final r = pixels[offset].toDouble();
      final g = pixels[offset + 1].toDouble();
      final b = pixels[offset + 2].toDouble();
      sampled++;
      // Blue ahead of both other channels, and bright enough to be daylight
      // rather than a navy jumper.
      if (b > 90 && b - r > 18 && b >= g) skyLike++;
    }
  }
  if (sampled == 0) return false;
  return skyLike / sampled >= skyCoverage;
}

/// The night test against a raw pixel buffer. See [isNightShot].
bool isNightShotInPixels(
  Uint8List pixels,
  int width,
  int height, {
  int channels = 4,
}) {
  if (width < 2 || height < 2) return false;
  const step = 4;
  var sampled = 0;
  var total = 0.0;
  var brightest = 0.0;

  for (var y = 0; y < height; y += step) {
    for (var x = 0; x < width; x += step) {
      final offset = (y * width + x) * channels;
      // Rec. 601 luma, which is what "how bright does this look" means.
      final luma = 0.299 * pixels[offset] +
          0.587 * pixels[offset + 1] +
          0.114 * pixels[offset + 2];
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

/// [preprocessClassifier]'s transform, straight from RGBA pixels.
///
/// Same maths as the img.Image version — short edge scaled to
/// [classifierSize], middle square cropped, ImageNet-normalised, NCHW — but
/// sampling bilinearly out of the buffer the decoder already produced, with
/// no intermediate image materialised and no per-pixel object access. This is
/// the one the analyser runs; the img.Image form above stays for tests.
Float32List classifierTensorFromRgba(DecodedPixels photo) {
  final out = Float32List(3 * classifierSize * classifierSize);
  const plane = classifierSize * classifierSize;
  final shortest = math.min(photo.width, photo.height);
  if (shortest <= 0) return out;

  final scale = classifierSize / shortest;
  final scaledWidth =
      math.max(classifierSize, (photo.width * scale).round());
  final scaledHeight =
      math.max(classifierSize, (photo.height * scale).round());
  // The crop is taken in resized coordinates; mapping a destination pixel
  // back through it lands directly in source coordinates, so no intermediate
  // resized image is ever built.
  final cropX = (scaledWidth - classifierSize) ~/ 2;
  final cropY = (scaledHeight - classifierSize) ~/ 2;

  for (var y = 0; y < classifierSize; y++) {
    final sy = (y + cropY + 0.5) / scale - 0.5;
    for (var x = 0; x < classifierSize; x++) {
      final sx = (x + cropX + 0.5) / scale - 0.5;
      _bilinearSample(
        photo.rgba,
        photo.width,
        photo.height,
        4,
        sx,
        sy,
      );
      final offset = y * classifierSize + x;
      out[offset] = (_sampled[0] / 255.0 - _mean[0]) / _std[0];
      out[plane + offset] = (_sampled[1] / 255.0 - _mean[1]) / _std[1];
      out[2 * plane + offset] = (_sampled[2] / 255.0 - _mean[2]) / _std[2];
    }
  }
  return out;
}

/// [preprocessFaceDetector]'s transform, straight from RGBA pixels — whole
/// frame squashed to 320×240, centred on 127, channel-first. See
/// [classifierTensorFromRgba] for why this form exists.
Float32List detectorTensorFromRgba(DecodedPixels photo) {
  if (photo.width < 2 || photo.height < 2) {
    return Float32List(3 * faceDetectorHeight * faceDetectorWidth);
  }
  final out = Float32List(3 * faceDetectorHeight * faceDetectorWidth);
  const plane = faceDetectorHeight * faceDetectorWidth;
  final scaleX = photo.width / faceDetectorWidth;
  final scaleY = photo.height / faceDetectorHeight;

  for (var y = 0; y < faceDetectorHeight; y++) {
    final sy = (y + 0.5) * scaleY - 0.5;
    for (var x = 0; x < faceDetectorWidth; x++) {
      final sx = (x + 0.5) * scaleX - 0.5;
      _bilinearSample(photo.rgba, photo.width, photo.height, 4, sx, sy);
      final offset = y * faceDetectorWidth + x;
      out[offset] = (_sampled[0] - 127) / 128;
      out[plane + offset] = (_sampled[1] - 127) / 128;
      out[2 * plane + offset] = (_sampled[2] - 127) / 128;
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
