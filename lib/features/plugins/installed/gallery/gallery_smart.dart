import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, compute, defaultTargetPlatform, immutable, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import 'package:image/image.dart' as img;

import 'gallery_cache.dart';
import 'gallery_media.dart';
import 'gallery_people.dart';
import 'onnx/gallery_face_embedder.dart';
import 'onnx/gallery_onnx_analyser.dart';

/// A smart category: photos the models (or, where there are none, plain
/// geometry) put together.
@immutable
class GallerySmartGroup {
  const GallerySmartGroup({
    required this.id,
    required this.label,
    required this.icon,
    required this.items,
  });

  final String id;
  final String label;
  final IconData icon;
  final List<GalleryItem> items;

  int get count => items.length;
}

/// Runs Google's on-device vision models over photos. Both models ship inside
/// the app and run offline — nothing about a photo leaves the device.
///
/// Face *detection* is not face *recognition*: ML Kit will say a photo has
/// three faces in it, never whose. So the people groups here are about how a
/// photo was taken (a selfie, a group shot) rather than who is in it. The
/// same is true of the ONNX models the desktop builds use — see
/// [GalleryOnnxAnalyser].
class GallerySmartAnalyser {
  FaceDetector? _faces;
  ImageLabeler? _labeller;

  /// ML Kit is Android/iOS only. Desktop runs equivalent models through ONNX
  /// Runtime instead; [GalleryAnalyser] picks between them.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  FaceDetector get _faceDetector => _faces ??= FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.fast,
          minFaceSize: 0.08,
        ),
      );

  ImageLabeler get _imageLabeller => _labeller ??= ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: 0.65),
      );

  /// Looks at one photo and folds what it finds into [previous]. Returns
  /// [previous] marked analysed when the file can't be read, so a photo that
  /// fails once isn't retried on every pass.
  ///
  /// [embedder] and [people] are the People album's recognition step. ML Kit
  /// itself has no such capability — [_faceDetector] only ever finds boxes,
  /// never who they belong to — so when there is at least one face, the file
  /// is decoded a second time (once, via `package:image`, in the same
  /// coordinate space `Face.boundingBox` reports in) purely to crop faces out
  /// of it for [embedder]. That decode happens on a worker isolate — it is
  /// the single slowest thing this path does, and on the UI thread it froze
  /// the grid for most of a second per photo. Photos with no face skip it
  /// entirely.
  Future<GalleryCacheEntry> analyse(
    String path,
    GalleryCacheEntry previous, {
    required GalleryFaceEmbedder embedder,
    required GalleryPeopleStore people,
    required String cacheKey,
  }) async {
    if (!isSupported) return previous.copyWith(analysed: true);
    try {
      final file = File(path);
      if (!file.existsSync()) {
        return previous.copyWith(analysed: true);
      }
      final input = InputImage.fromFilePath(path);
      // Two independent calls into platform code; run together rather than
      // paying each model's latency after the other's.
      final results = await Future.wait([
        _faceDetector.processImage(input),
        _imageLabeller.processImage(input),
      ]);
      final faces = results[0] as List<Face>;
      final labels = results[1] as List<ImageLabel>;

      var personIds = const <int>[];
      if (faces.isNotEmpty && embedder.ready) {
        final decoded = await compute(
          decodeStillImage,
          await file.readAsBytes(),
        );
        if (decoded != null) {
          personIds = await identifyPeople(
            decoded,
            [for (final face in faces) _asGalleryFace(face, decoded)],
            embedder: embedder,
            people: people,
            coverKey: cacheKey,
          );
        }
      }

      return previous.copyWith(
        faceCount: faces.length,
        labels: [
          for (final label in labels) label.label,
          if (_looksLikeSelfie(faces)) _selfieLabel,
        ],
        personIds: personIds,
        analysed: true,
      );
    } catch (_) {
      return previous.copyWith(analysed: true);
    }
  }

  /// Converts ML Kit's pixel-space box into the fractional box every platform
  /// shares, clamped to the frame — a face right at the edge can otherwise
  /// report a coordinate a hair past it.
  static GalleryFace _asGalleryFace(Face face, img.Image decoded) {
    final box = face.boundingBox;
    double fx(double v) => (v / decoded.width).clamp(0.0, 1.0);
    double fy(double v) => (v / decoded.height).clamp(0.0, 1.0);
    return GalleryFace(
      left: fx(box.left),
      top: fy(box.top),
      right: fx(box.right),
      bottom: fy(box.bottom),
    );
  }

  /// One face filling a good part of the frame is how a selfie looks to a
  /// detector — the arm is only so long.
  static bool _looksLikeSelfie(List<Face> faces) {
    if (faces.length != 1) return false;
    final box = faces.first.boundingBox;
    return box.width >= 220 && box.height >= 220;
  }

  void dispose() {
    _faces?.close();
    _labeller?.close();
    _faces = null;
    _labeller = null;
  }
}

/// Whichever analyser this platform can actually run: ML Kit on the phone,
/// ONNX Runtime on the desktop, nothing on the web.
///
/// The two produce the same thing — a face count, a selfie marker and a set
/// of bucket names — so everything above this line is platform-agnostic and
/// both builds end up with the same albums. Face *recognition* (the People
/// album) sits outside that split entirely: neither platform's own SDK does
/// it, so [GalleryFaceEmbedder] runs identically everywhere, layered on top
/// of whichever detector found the faces in the first place.
class GalleryAnalyser {
  GalleryAnalyser({required this.people});

  final GallerySmartAnalyser _mlKit = GallerySmartAnalyser();
  final GalleryOnnxAnalyser _onnx = GalleryOnnxAnalyser();
  final GalleryFaceEmbedder _embedder = GalleryFaceEmbedder();

  /// Where person clusters live. Owned by [GalleryRepository] — it needs to
  /// be loaded before the first [analyse] and read directly by the People
  /// screen — and handed in here rather than created fresh.
  final GalleryPeopleStore people;

  /// Whether this platform can label photos at all.
  static bool get isSupported =>
      GallerySmartAnalyser.isSupported || GalleryOnnxAnalyser.isSupported;

  /// Whether the label/detection models are on this machine already. ML
  /// Kit's ship inside the app; the ONNX ones are downloaded on first use.
  /// Independent of the embedder below — every platform downloads that one.
  static bool get needsDownload =>
      !GallerySmartAnalyser.isSupported && GalleryOnnxAnalyser.isSupported;

  bool get usesOnnx => GalleryOnnxAnalyser.isSupported;

  String? get lastError => _onnx.lastError ?? _embedder.lastError;

  /// Gets every model this platform needs ready, downloading whichever of
  /// them it fetches rather than ships with. Returns false when any of them
  /// can't be had.
  Future<bool> prepare({
    void Function(String label, double? progress)? onProgress,
  }) async {
    if (GallerySmartAnalyser.isSupported) {
      // ML Kit covers labels and detection; only recognition needs fetching.
      return _embedder.prepare(onProgress: onProgress);
    }
    if (!GalleryOnnxAnalyser.isSupported) return false;
    if (!await _onnx.prepare(onProgress: onProgress)) return false;
    return _embedder.prepare(onProgress: onProgress);
  }

  /// Looks at one photo. [path] is used by ML Kit, which reads the file
  /// itself; [thumbnail] is used by the ONNX path, which wants pixels it can
  /// resize and would rather not re-read a 12 MP original for them.
  Future<GalleryCacheEntry> analyse({
    required GalleryCacheEntry previous,
    required String cacheKey,
    String? path,
    Uint8List? thumbnail,
  }) async {
    if (GallerySmartAnalyser.isSupported) {
      // No file to hand ML Kit, so this photo was never actually looked at.
      if (path == null) {
        return previous.copyWith(analysed: true, skipped: true);
      }
      return _mlKit.analyse(
        path,
        previous,
        embedder: _embedder,
        people: people,
        cacheKey: cacheKey,
      );
    }
    if (GalleryOnnxAnalyser.isSupported) {
      // No thumbnail means a cloud placeholder or a format the decoder
      // doesn't read — again, not looked at rather than found to be nothing.
      if (thumbnail == null) {
        return previous.copyWith(analysed: true, skipped: true);
      }
      return _onnx.analyse(
        thumbnail,
        previous,
        embedder: _embedder,
        people: people,
        cacheKey: cacheKey,
      );
    }
    return previous.copyWith(analysed: true, skipped: true);
  }

  Future<void> dispose() async {
    _mlKit.dispose();
    await _onnx.dispose();
    await _embedder.dispose();
  }
}

/// Marker the analyser writes alongside the model's own labels. Shared with
/// the ONNX path so both write the same thing.
const _selfieLabel = selfieLabel;

/// Buckets ML Kit's label vocabulary into groups a person would look for.
/// The base model emits a few hundred English nouns; these are the ones worth
/// a tab.
const _labelBuckets = <String, List<String>>{
  'Food': [
    'food', 'dessert', 'fruit', 'vegetable', 'baked goods', 'drink',
    'cuisine', 'meal', 'coffee', 'cake', 'bread', 'pizza', 'seafood',
  ],
  'Pets': ['dog', 'cat', 'rabbit', 'pet', 'kitten', 'puppy'],
  'Animals': ['bird', 'horse', 'fish', 'animal', 'wildlife', 'insect', 'butterfly'],
  'Nature': [
    'plant', 'flower', 'tree', 'mountain', 'sunset', 'sunrise', 'snow',
    'forest', 'waterfall', 'garden', 'leaf', 'grass', 'landscape',
  ],
  // Water gets its own album rather than being folded into Nature — a beach
  // holiday and a forest walk are not the same afternoon.
  'Ocean': [
    'beach', 'sea', 'ocean', 'lake', 'river', 'sand', 'wave', 'coast',
    'shore', 'underwater', 'reef', 'harbor', 'harbour',
  ],
  // ML Kit names the sky and the dark directly. The desktop models can't —
  // ImageNet is a list of objects — so there they come from the pixels
  // instead; see hasSky and isNightShot.
  'Sky': ['sky', 'cloud', 'horizon'],
  'Night': ['night', 'moon', 'star', 'nightclub'],
  'Architecture': [
    'building', 'bridge', 'skyscraper', 'monument', 'church', 'castle',
    'tower', 'house', 'street', 'architecture', 'city',
  ],
  'Transport': [
    'car', 'motorcycle', 'bicycle', 'boat', 'airplane', 'bus', 'train',
    'vehicle', 'truck', 'jet', 'aircraft', 'scooter',
  ],
  'Documents': [
    'document', 'text', 'paper', 'whiteboard', 'receipt', 'book', 'menu',
    'newspaper', 'poster', 'screenshot',
  ],
  'Celebrations': [
    'fireworks', 'party', 'concert', 'wedding', 'balloon', 'christmas tree',
    'birthday cake', 'event', 'stage',
  ],
  'Art': ['painting', 'drawing', 'sculpture', 'graffiti', 'art'],
};

const _bucketIcons = <String, IconData>{
  'Food': Icons.restaurant_rounded,
  'Pets': Icons.pets_rounded,
  'Animals': Icons.emoji_nature_rounded,
  'Nature': Icons.park_rounded,
  'Ocean': Icons.waves_rounded,
  'Sky': Icons.cloud_rounded,
  'Night': Icons.nightlight_round,
  'Architecture': Icons.location_city_rounded,
  'Transport': Icons.directions_car_rounded,
  'Documents': Icons.description_rounded,
  'Celebrations': Icons.celebration_rounded,
  'Art': Icons.palette_rounded,
};

/// Builds the smart tabs for [items] from what the analyser has learned so
/// far, plus the two groups that need no model: panoramas (a shape) and
/// places (a GPS tag).
///
/// Groups with fewer than [minimum] photos are dropped — a "Pets" tab holding
/// one blurry cat is worse than no tab.
List<GallerySmartGroup> buildSmartGroups(
  List<GalleryItem> items,
  Map<String, GalleryCacheEntry> cache, {
  int minimum = 3,
}) {
  final people = <GalleryItem>[];
  final selfies = <GalleryItem>[];
  final groupShots = <GalleryItem>[];
  final panoramas = <GalleryItem>[];
  final places = <GalleryItem>[];
  final buckets = <String, List<GalleryItem>>{};

  for (final item in items) {
    if (item.hasLocation) places.add(item);
    if (!item.isVideo && isPanorama(item)) panoramas.add(item);

    final entry = cache[item.cacheKey];
    if (entry == null) continue;
    if (entry.faceCount > 0) people.add(item);
    if (entry.faceCount >= 3) groupShots.add(item);
    if (entry.labels.contains(_selfieLabel)) selfies.add(item);
    // The desktop path reads sky and darkness off the pixels and writes them
    // as markers, because ImageNet has no class for either. They join the
    // same albums ML Kit fills from its own 'sky' and 'night' labels.
    if (entry.labels.contains(skyLabel)) {
      buckets.putIfAbsent('Sky', () => []).add(item);
    }
    if (entry.labels.contains(nightLabel)) {
      buckets.putIfAbsent('Night', () => []).add(item);
    }

    for (final label in entry.labels) {
      final bucket = bucketForLabel(label);
      if (bucket != null) {
        buckets.putIfAbsent(bucket, () => []).add(item);
      }
    }
  }

  final groups = <GallerySmartGroup>[
    GallerySmartGroup(
      id: 'people',
      label: 'People',
      icon: Icons.people_rounded,
      items: people,
    ),
    GallerySmartGroup(
      id: 'selfies',
      label: 'Selfies',
      icon: Icons.face_rounded,
      items: selfies,
    ),
    GallerySmartGroup(
      id: 'groups',
      label: 'Group shots',
      icon: Icons.groups_rounded,
      items: groupShots,
    ),
    for (final entry in buckets.entries)
      GallerySmartGroup(
        id: 'label:${entry.key}',
        label: entry.key,
        icon: _bucketIcons[entry.key] ?? Icons.auto_awesome_rounded,
        items: entry.value,
      ),
    GallerySmartGroup(
      id: 'panoramas',
      label: 'Panoramas',
      icon: Icons.panorama_horizontal_rounded,
      items: panoramas,
    ),
    GallerySmartGroup(
      id: 'places',
      label: 'Places',
      icon: Icons.place_rounded,
      items: places,
    ),
  ];

  final kept = groups.where((g) => g.count >= minimum).toList()
    ..sort((a, b) => b.count.compareTo(a.count));
  for (final group in kept) {
    group.items.sort((a, b) => b.takenAt.compareTo(a.takenAt));
  }
  return kept;
}

/// Which bucket an ML Kit label belongs to, or null for the many labels
/// nobody browses by.
String? bucketForLabel(String label) {
  final lower = label.toLowerCase();
  for (final entry in _labelBuckets.entries) {
    if (entry.value.contains(lower)) return entry.key;
  }
  return null;
}

/// A frame at least twice as wide as it is tall (or the other way up) is a
/// panorama, whatever app stitched it.
bool isPanorama(GalleryItem item) {
  if (item.width <= 0 || item.height <= 0) return false;
  final ratio = item.width / item.height;
  return ratio >= 2.0 || ratio <= 0.5;
}

/// Decodes image bytes into pixels. Top-level so it can run on a worker
/// isolate via [compute] — see [GallerySmartAnalyser.analyse].
img.Image? decodeStillImage(Uint8List bytes) => img.decodeImage(bytes);
