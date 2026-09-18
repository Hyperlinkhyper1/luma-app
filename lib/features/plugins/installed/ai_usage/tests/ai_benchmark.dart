import 'package:flutter/foundation.dart';

/// One interactive benchmark scene, as the luma server publishes it.
///
/// Mirrors `server/lib/ai_benchmark_store.dart` — the server decides what a
/// field means. Scenes used to ship inside the app bundle, where ~6 MB of
/// self-contained HTML made every install bigger; they live on the server now
/// and the app downloads each one on demand, caching it on disk.
@immutable
class AiBenchmark {
  const AiBenchmark({
    required this.id,
    required this.kind,
    required this.model,
    required this.description,
    required this.sizeBytes,
    required this.sha256,
    this.updatedAt,
    this.hasPreview = false,
  });

  /// File stem of the scene, e.g. `pagoda_haiku45`. Also the cache key the
  /// download is stored under.
  final String id;

  /// `pagoda` or `engine` — which test this scene implements.
  final String kind;

  /// Display name of the benchmarked model, e.g. `Haiku 4.5`.
  final String model;
  final String description;

  /// Expected size and SHA-256 of the scene file. The repository verifies a
  /// download against both before pointing a WebView at it.
  final int sizeBytes;
  final String sha256;
  final DateTime? updatedAt;

  /// Whether the server holds a PNG preview for the model cards. Without one
  /// the UI falls back to the test's generic artwork, then to a plain icon.
  final bool hasPreview;

  bool get isPagoda => kind == 'pagoda';
  bool get isEngine => kind == 'engine';
  bool get isPc => kind == 'pc';

  factory AiBenchmark.fromJson(Map<String, dynamic> j) {
    final updatedAtMs = (j['updatedAtMs'] as num?)?.toInt();
    return AiBenchmark(
      id: j['id'] as String? ?? '',
      kind: j['kind'] as String? ?? 'pagoda',
      model: j['model'] as String? ?? '',
      description: j['description'] as String? ?? '',
      sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
      sha256: j['sha256'] as String? ?? '',
      updatedAt: (updatedAtMs == null || updatedAtMs == 0)
          ? null
          : DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
      hasPreview: j['hasPreview'] as bool? ?? false,
    );
  }
}

/// The roster of downloadable scenes plus the generic tile artwork per test.
@immutable
class AiBenchmarkManifest {
  const AiBenchmarkManifest({
    required this.benchmarks,
    required this.fallbackPreviews,
    required this.refreshedAt,
  });

  static const AiBenchmarkManifest empty = AiBenchmarkManifest(
    benchmarks: [],
    fallbackPreviews: {},
    refreshedAt: null,
  );

  final List<AiBenchmark> benchmarks;

  /// Generic artwork file per test kind, e.g. `{pagoda: pagoda-preview.png}`.
  final Map<String, String> fallbackPreviews;
  final DateTime? refreshedAt;

  bool get isEmpty => benchmarks.isEmpty;

  List<AiBenchmark> ofKind(String kind) =>
      [for (final b in benchmarks) if (b.kind == kind) b];

  AiBenchmark? byId(String id) {
    for (final b in benchmarks) {
      if (b.id == id) return b;
    }
    return null;
  }

  factory AiBenchmarkManifest.fromJson(Map<String, dynamic> j) {
    final ms = (j['refreshedAtMs'] as num?)?.toInt();
    final fallbacks = <String, String>{};
    for (final e in (j['fallbackPreviews'] as Map? ?? const {}).entries) {
      if (e.key is String && e.value is String) {
        fallbacks[e.key as String] = e.value as String;
      }
    }
    return AiBenchmarkManifest(
      benchmarks: [
        for (final b in (j['benchmarks'] as List? ?? const []))
          if (b is Map<String, dynamic>) AiBenchmark.fromJson(b),
      ],
      fallbackPreviews: fallbacks,
      refreshedAt: (ms == null || ms == 0)
          ? null
          : DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }
}
