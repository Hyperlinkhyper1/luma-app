import 'dart:io';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, immutable, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import 'gallery_cache.dart';
import 'gallery_media.dart';

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
/// photo was taken (a selfie, a group shot) rather than who is in it.
class GallerySmartAnalyser {
  FaceDetector? _faces;
  ImageLabeler? _labeller;

  /// The models are Android/iOS only. Desktop keeps the geometry-based
  /// groups, which need no model at all.
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
  Future<GalleryCacheEntry> analyse(
    String path,
    GalleryCacheEntry previous,
  ) async {
    if (!isSupported) return previous.copyWith(analysed: true);
    try {
      if (!File(path).existsSync()) {
        return previous.copyWith(analysed: true);
      }
      final input = InputImage.fromFilePath(path);
      final faces = await _faceDetector.processImage(input);
      final labels = await _imageLabeller.processImage(input);
      return previous.copyWith(
        faceCount: faces.length,
        labels: [
          for (final label in labels) label.label,
          if (_looksLikeSelfie(faces)) _selfieLabel,
        ],
        analysed: true,
      );
    } catch (_) {
      return previous.copyWith(analysed: true);
    }
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

/// Marker the analyser writes alongside the model's own labels.
const _selfieLabel = '_selfie';

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
    'plant', 'flower', 'tree', 'mountain', 'beach', 'sky', 'sunset',
    'sunrise', 'snow', 'forest', 'waterfall', 'lake', 'garden', 'leaf',
    'grass', 'cloud', 'landscape', 'river', 'sand', 'sea',
  ],
  'City': [
    'building', 'bridge', 'skyscraper', 'monument', 'church', 'castle',
    'tower', 'house', 'street', 'architecture', 'city',
  ],
  'Vehicles': [
    'car', 'motorcycle', 'bicycle', 'boat', 'airplane', 'bus', 'train',
    'vehicle', 'truck',
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
  'City': Icons.location_city_rounded,
  'Vehicles': Icons.directions_car_rounded,
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
