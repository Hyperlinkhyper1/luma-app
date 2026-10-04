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
    this.previewSha256 = '',
    this.vendor = '',
    this.tokens = 0,
    this.durationSec = 0,
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

  /// SHA-256 of the preview PNG as the manifest reported it. The repository
  /// re-downloads a cached preview when this changes, so a re-rendered banner
  /// replaces the stale file instead of sitting behind it forever.
  final String previewSha256;

  /// Vendor key of the company behind [model] when the roster names one
  /// (`anthropic`, `openai`, …); '' means work it out from the model name.
  final String vendor;

  /// Tokens the model spent writing the scene and how long it took, in
  /// seconds. 0 when an older server doesn't send them.
  final int tokens;
  final int durationSec;

  bool get hasRunStats => tokens > 0 && durationSec > 0;

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
      previewSha256: j['previewSha256'] as String? ?? '',
      vendor: j['vendor'] as String? ?? '',
      tokens: (j['tokens'] as num?)?.toInt() ?? 0,
      durationSec: (j['durationSec'] as num?)?.toInt() ?? 0,
    );
  }
}

/// `812`, `8.4k`, `48k`, `1.2M` — a token count short enough for a card.
String formatBenchmarkTokens(int tokens) {
  if (tokens < 1000) return '$tokens';
  if (tokens < 10000) return '${(tokens / 1000).toStringAsFixed(1)}k';
  if (tokens < 1000000) return '${(tokens / 1000).round()}k';
  return '${(tokens / 1000000).toStringAsFixed(1)}M';
}

/// `45s`, `6m 12s`, `1h 05m`.
String formatBenchmarkDuration(int seconds) {
  if (seconds < 60) return '${seconds}s';
  if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
  final minutes = (seconds % 3600) ~/ 60;
  return '${seconds ~/ 3600}h ${minutes.toString().padLeft(2, '0')}m';
}

/// The roster of downloadable scenes plus the generic tile artwork per test.
@immutable
class AiBenchmarkManifest {
  const AiBenchmarkManifest({
    required this.benchmarks,
    required this.fallbackPreviews,
    required this.refreshedAt,
    this.previewHashes = const {},
    this.fallbackHashes = const {},
  });

  static const AiBenchmarkManifest empty = AiBenchmarkManifest(
    benchmarks: [],
    fallbackPreviews: {},
    refreshedAt: null,
  );

  final List<AiBenchmark> benchmarks;

  /// Generic artwork file per test kind, e.g. `{pagoda: pagoda-preview.png}`.
  final Map<String, String> fallbackPreviews;

  /// SHA-256 per scene preview, keyed by benchmark id. Absent (or mismatched)
  /// means the cached file is stale and must be re-downloaded.
  final Map<String, String> previewHashes;

  /// SHA-256 per generic artwork file, keyed by file name.
  final Map<String, String> fallbackHashes;
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
    Map<String, String> hashes(Object? node) {
      final out = <String, String>{};
      for (final e in (node as Map? ?? const {}).entries) {
        if (e.key is String && e.value is String) {
          out[e.key as String] = e.value as String;
        }
      }
      return out;
    }

    // Older servers send no hashes at all; newer ones may also send the
    // per-entry hash inline. The inline value wins when both are present.
    final previewHashes = hashes(j['previewHashes']);
    return AiBenchmarkManifest(
      benchmarks: [
        for (final b in (j['benchmarks'] as List? ?? const []))
          if (b is Map<String, dynamic>)
            AiBenchmark.fromJson({
              ...b,
              if ((b['previewSha256'] as String?)?.isNotEmpty != true &&
                  previewHashes[b['id']] is String)
                'previewSha256': previewHashes[b['id']],
            }),
      ],
      fallbackPreviews: fallbacks,
      previewHashes: previewHashes,
      fallbackHashes: hashes(j['fallbackHashes']),
      refreshedAt: (ms == null || ms == 0)
          ? null
          : DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }
}
