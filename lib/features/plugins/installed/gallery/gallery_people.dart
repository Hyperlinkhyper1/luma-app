import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// One person the clustering has found — not identified, just grouped: a
/// running average of every face fingerprint assigned to it, a count, and
/// whatever name the user has given it.
///
/// There is no name until someone sets one. This is unsupervised clustering
/// against an on-device model, not a directory lookup — the app has no idea
/// who anyone is, only that these faces look like the same face.
@immutable
class PersonCluster {
  const PersonCluster({
    required this.id,
    required this.centroid,
    required this.count,
    this.name,
    this.coverKey,
  });

  final int id;

  /// The running mean of every embedding assigned here. Comparing a new face
  /// against this, rather than against every past face individually, is what
  /// keeps clustering an O(people) operation instead of an O(photos) one.
  final List<double> centroid;

  final int count;
  final String? name;

  /// Cache key of a photo to show as this person's avatar.
  final String? coverKey;

  String get displayName => (name != null && name!.trim().isNotEmpty)
      ? name!.trim()
      : 'Person $id';

  PersonCluster copyWith({
    List<double>? centroid,
    int? count,
    String? name,
    String? coverKey,
  }) =>
      PersonCluster(
        id: id,
        centroid: centroid ?? this.centroid,
        count: count ?? this.count,
        name: name ?? this.name,
        coverKey: coverKey ?? this.coverKey,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'centroid': centroid,
        'count': count,
        if (name != null) 'name': name,
        if (coverKey != null) 'cover': coverKey,
      };

  factory PersonCluster.fromJson(Map<String, dynamic> json) => PersonCluster(
        id: (json['id'] as num).toInt(),
        centroid: [
          for (final v in (json['centroid'] as List<dynamic>? ?? const []))
            (v as num).toDouble(),
        ],
        count: (json['count'] as num?)?.toInt() ?? 0,
        name: json['name'] as String?,
        coverKey: json['cover'] as String?,
      );
}

/// How many photos a person needs before they earn their own card — the same
/// reasoning as every other minimum in this plugin: one stray misdetection
/// permanently squatting on "Person 4" is worse than making someone wait for
/// a third photo.
const kMinPersonPhotos = 3;

/// How close two fingerprints have to be, by cosine similarity, to be called
/// the same person.
///
/// This is SFace's own published figure for its intended use — matching
/// *aligned* faces (a 5-point landmark warp this app doesn't perform; see
/// [GalleryFaceEmbedder]). Run against the plainer crop this app actually
/// makes, embeddings will be noisier than the benchmark assumed, so expect
/// this to run a little loose (occasionally splitting one person into two
/// clusters) rather than tight (wrongly merging two people) — the safer
/// direction for a feature nobody asked to be watched by.
const kPersonSimilarityThreshold = 0.363;

/// Cosine similarity of [a] and [b]. -1 (as far apart as two vectors can be)
/// for anything degenerate, so a bad embedding always loses a match rather
/// than winning one by accident.
double cosineSimilarity(List<double> a, List<double> b) {
  if (a.isEmpty || a.length != b.length) return -1;
  var dot = 0.0, normA = 0.0, normB = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA <= 0 || normB <= 0) return -1;
  return dot / (math.sqrt(normA) * math.sqrt(normB));
}

/// Assigns [embedding] to whichever cluster in [clusters] it best matches, or
/// starts a new one. Mutates [clusters] in place and returns the id it landed
/// on.
///
/// Greedy and incremental by design: each face is placed once, against the
/// clusters that exist *so far*, and never revisited. That means a person
/// can end up split across two clusters if their early photos and later
/// photos drifted apart (different lighting, years apart, glasses) — there is
/// no merge pass. Cheap and stateless is worth that; a full re-clustering
/// pass is a reasonable follow-up once real photos show whether it is needed.
int assignFaceToCluster(
  List<PersonCluster> clusters,
  List<double> embedding, {
  required int Function() nextId,
  double threshold = kPersonSimilarityThreshold,
}) {
  var bestIndex = -1;
  var bestScore = -2.0;
  for (var i = 0; i < clusters.length; i++) {
    final score = cosineSimilarity(clusters[i].centroid, embedding);
    if (score > bestScore) {
      bestScore = score;
      bestIndex = i;
    }
  }

  if (bestIndex >= 0 && bestScore >= threshold) {
    final cluster = clusters[bestIndex];
    final newCount = cluster.count + 1;
    final blended = [
      for (var i = 0; i < cluster.centroid.length; i++)
        (cluster.centroid[i] * cluster.count + embedding[i]) / newCount,
    ];
    clusters[bestIndex] = cluster.copyWith(centroid: blended, count: newCount);
    return cluster.id;
  }

  final id = nextId();
  clusters.add(PersonCluster(id: id, centroid: List.of(embedding), count: 1));
  return id;
}

/// Persists the clusters the smart-analysis pass has built.
///
/// Deliberately separate from [GalleryCache]: that file is rewritten on
/// every batch of the analysis pass and can run to tens of thousands of
/// entries, while this one holds a handful of clusters (a few dozen people at
/// most) and is rewritten far less often. Keeping them apart means a crash
/// mid-write to one can never corrupt the other.
class GalleryPeopleStore {
  final List<PersonCluster> _clusters = [];
  int _nextId = 1;
  File? _file;
  bool _dirty = false;
  bool _writing = false;

  List<PersonCluster> get clusters => List.unmodifiable(_clusters);

  PersonCluster? byId(int id) {
    for (final cluster in _clusters) {
      if (cluster.id == id) return cluster;
    }
    return null;
  }

  Future<void> load() async {
    try {
      final file = await _open();
      if (!file.existsSync()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return;
      final entries = decoded['clusters'];
      if (entries is List) {
        _clusters
          ..clear()
          ..addAll([
            for (final entry in entries)
              if (entry is Map<String, dynamic>) PersonCluster.fromJson(entry),
          ]);
      }
      _nextId = _clusters.fold(1, (max, c) => c.id >= max ? c.id + 1 : max);
    } catch (_) {
      _clusters.clear();
      _nextId = 1;
    }
  }

  /// Assigns one face's fingerprint to a person, creating a new one if
  /// nothing matches closely enough. [coverKey] is remembered the first time
  /// a cluster is created, so its card has a picture from the start.
  int assign(List<double> embedding, {String? coverKey}) {
    final before = _clusters.length;
    final id = assignFaceToCluster(_clusters, embedding, nextId: () => _nextId++);
    if (_clusters.length != before && coverKey != null) {
      final index = _clusters.indexWhere((c) => c.id == id);
      if (index >= 0) {
        _clusters[index] = _clusters[index].copyWith(coverKey: coverKey);
      }
    }
    _dirty = true;
    return id;
  }

  void rename(int id, String name) {
    final index = _clusters.indexWhere((c) => c.id == id);
    if (index < 0) return;
    _clusters[index] = _clusters[index].copyWith(name: name.trim());
    _dirty = true;
  }

  Future<void> flush() async {
    if (!_dirty || _writing) return;
    _writing = true;
    _dirty = false;
    try {
      final file = await _open();
      await file.writeAsString(jsonEncode({
        'version': 1,
        'clusters': [for (final c in _clusters) c.toJson()],
      }));
    } catch (_) {
      _dirty = true;
    } finally {
      _writing = false;
    }
  }

  Future<File> _open() async {
    final existing = _file;
    if (existing != null) return existing;
    final support = await getApplicationSupportDirectory();
    final separator = Platform.pathSeparator;
    final directory = Directory('${support.path}${separator}gallery_cache');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return _file = File('${directory.path}${separator}people.json');
  }
}
