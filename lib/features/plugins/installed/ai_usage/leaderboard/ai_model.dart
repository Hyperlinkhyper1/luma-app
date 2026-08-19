import 'package:flutter/foundation.dart';

/// One reasoning-effort tier a model supports, and what that tier costs.
///
/// A higher effort buys a higher [intelligenceIndex] but spends more
/// [medianOutputTokens] thinking to get there — the trade-off the model
/// detail page plots. Only models whose provider exposes effort levels *and*
/// has measured variants upstream carry these; everything else gets no graph
/// rather than an invented one.
@immutable
class AiEffortProfile {
  const AiEffortProfile({
    required this.effort,
    this.intelligenceIndex,
    this.medianOutputTokens,
  });

  final String effort;
  final double? intelligenceIndex;
  final int? medianOutputTokens;

  /// Title-cased for display: `xhigh` → `Xhigh` reads badly, so the known
  /// tiers get proper labels and anything new falls back to capitalising.
  String get label => switch (effort.toLowerCase()) {
        'minimal' => 'Minimal',
        'low' => 'Low',
        'medium' => 'Medium',
        'high' => 'High',
        'xhigh' => 'Extra high',
        'max' => 'Max',
        _ => effort.isEmpty
            ? effort
            : effort[0].toUpperCase() + effort.substring(1),
      };

  factory AiEffortProfile.fromJson(Map<String, dynamic> j) => AiEffortProfile(
        effort: j['effort'] as String? ?? '',
        intelligenceIndex: (j['intelligenceIndex'] as num?)?.toDouble(),
        medianOutputTokens: (j['medianOutputTokens'] as num?)?.toInt(),
      );
}

/// A model on the leaderboard, as the luma server publishes it.
///
/// Mirrors `server/lib/ai_model_catalog.dart` — the two must stay in step, and
/// the server is the one that decides what a field means. Every rating and
/// price is nullable: a model that one upstream has never scored still belongs
/// on the board, shown as "–" in that column rather than as a zero that would
/// sort it below models that are genuinely worse.
@immutable
class AiModel {
  const AiModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.vendor,
    required this.vendorName,
    this.description,
    this.releasedAt,
    this.contextTokens,
    this.maxOutputTokens,
    this.inputPricePerM,
    this.outputPricePerM,
    this.cacheReadPerM,
    this.cacheWritePerM,
    this.llmStatsIndex,
    this.reasoningIndex,
    this.codingIndex,
    this.agentIndex,
    this.mathIndex,
    this.codeArena,
    this.codeArenaRank,
    this.speedTokensPerSec,
    this.latencyMs,
    this.openWeights = false,
    this.licenseId,
    this.licenseName,
    this.parametersB,
    this.activeParametersB,
    this.huggingFaceId,
    this.inputModalities = const [],
    this.outputModalities = const [],
    this.knowledgeCutoff,
    this.supportedEfforts = const [],
    this.defaultEffort,
    this.effortProfiles = const [],
  });

  final String id;
  final String slug;
  final String name;
  final String vendor;
  final String vendorName;
  final String? description;
  final DateTime? releasedAt;
  final int? contextTokens;
  final int? maxOutputTokens;

  final double? inputPricePerM;
  final double? outputPricePerM;
  final double? cacheReadPerM;
  final double? cacheWritePerM;

  final double? llmStatsIndex;
  final double? reasoningIndex;
  final double? codingIndex;
  final double? agentIndex;
  final double? mathIndex;

  final double? codeArena;
  final int? codeArenaRank;

  final double? speedTokensPerSec;
  final double? latencyMs;

  /// Whether the weights are downloadable — the open padlock in the table.
  final bool openWeights;
  final String? licenseId;
  final String? licenseName;
  final double? parametersB;
  final double? activeParametersB;
  final String? huggingFaceId;

  final List<String> inputModalities;
  final List<String> outputModalities;
  final String? knowledgeCutoff;

  final List<String> supportedEfforts;
  final String? defaultEffort;
  final List<AiEffortProfile> effortProfiles;

  /// The price column: input and output averaged, USD per million tokens.
  /// Null unless both halves are known — averaging against a missing side
  /// would show the model as cheaper than it is.
  double? get avgPricePerM =>
      (inputPricePerM == null || outputPricePerM == null)
          ? null
          : (inputPricePerM! + outputPricePerM!) / 2;

  /// Cost of a realistic 8:1 input:output mix — what the price-vs-performance
  /// frontier is plotted against, since a plain average overweights output.
  double? get blendedPricePerM =>
      (inputPricePerM == null || outputPricePerM == null)
          ? null
          : (inputPricePerM! * 8 + outputPricePerM!) / 9;

  /// Whether the provider lets the caller pick how hard the model thinks.
  bool get hasEffortLevels => supportedEfforts.length > 1;

  /// Whether there are enough measured tiers to draw the effort trade-off
  /// graph — one point is a dot, not a trend.
  bool get hasEffortGraph =>
      effortProfiles.where((e) => e.intelligenceIndex != null).length > 1;

  factory AiModel.fromJson(Map<String, dynamic> j) {
    final releasedAtMs = (j['releasedAtMs'] as num?)?.toInt();
    return AiModel(
      id: j['id'] as String,
      slug: j['slug'] as String? ?? '',
      name: j['name'] as String? ?? '',
      vendor: j['vendor'] as String? ?? '',
      vendorName: j['vendorName'] as String? ?? '',
      description: j['description'] as String?,
      releasedAt: releasedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(releasedAtMs),
      contextTokens: (j['contextTokens'] as num?)?.toInt(),
      maxOutputTokens: (j['maxOutputTokens'] as num?)?.toInt(),
      inputPricePerM: (j['inputPricePerM'] as num?)?.toDouble(),
      outputPricePerM: (j['outputPricePerM'] as num?)?.toDouble(),
      cacheReadPerM: (j['cacheReadPerM'] as num?)?.toDouble(),
      cacheWritePerM: (j['cacheWritePerM'] as num?)?.toDouble(),
      llmStatsIndex: (j['llmStatsIndex'] as num?)?.toDouble(),
      reasoningIndex: (j['reasoningIndex'] as num?)?.toDouble(),
      codingIndex: (j['codingIndex'] as num?)?.toDouble(),
      agentIndex: (j['agentIndex'] as num?)?.toDouble(),
      mathIndex: (j['mathIndex'] as num?)?.toDouble(),
      codeArena: (j['codeArena'] as num?)?.toDouble(),
      codeArenaRank: (j['codeArenaRank'] as num?)?.toInt(),
      speedTokensPerSec: (j['speedTokensPerSec'] as num?)?.toDouble(),
      latencyMs: (j['latencyMs'] as num?)?.toDouble(),
      openWeights: j['openWeights'] as bool? ?? false,
      licenseId: j['licenseId'] as String?,
      licenseName: j['licenseName'] as String?,
      parametersB: (j['parametersB'] as num?)?.toDouble(),
      activeParametersB: (j['activeParametersB'] as num?)?.toDouble(),
      huggingFaceId: j['huggingFaceId'] as String?,
      inputModalities: _stringList(j['inputModalities']),
      outputModalities: _stringList(j['outputModalities']),
      knowledgeCutoff: j['knowledgeCutoff'] as String?,
      supportedEfforts: _stringList(j['supportedEfforts']),
      defaultEffort: j['defaultEffort'] as String?,
      effortProfiles: [
        for (final e in (j['effortProfiles'] as List? ?? const []))
          if (e is Map<String, dynamic>) AiEffortProfile.fromJson(e),
      ],
    );
  }
}

/// One dated item in the leaderboard's news rail.
@immutable
class AiNewsItem {
  const AiNewsItem({
    required this.id,
    required this.title,
    required this.url,
    required this.source,
    required this.publishedAt,
    this.summary,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String url;
  final String source;
  final DateTime? publishedAt;
  final String? summary;

  /// A lead image for the article, or null — most feeds carry none, so the
  /// card always needs a real design for the no-image case, not just an
  /// occasional one.
  final String? imageUrl;

  factory AiNewsItem.fromJson(Map<String, dynamic> j) {
    final ms = (j['publishedAtMs'] as num?)?.toInt();
    return AiNewsItem(
      id: j['id'] as String? ?? '',
      title: j['title'] as String? ?? '',
      url: j['url'] as String? ?? '',
      source: j['source'] as String? ?? '',
      publishedAt: (ms == null || ms == 0)
          ? null
          : DateTime.fromMillisecondsSinceEpoch(ms),
      summary: j['summary'] as String?,
      imageUrl: j['imageUrl'] as String?,
    );
  }
}

/// A whole catalogue: the models, the news rail, and when the server last
/// rebuilt them.
@immutable
class AiCatalog {
  const AiCatalog({
    required this.models,
    required this.news,
    required this.refreshedAt,
  });

  static const AiCatalog empty =
      AiCatalog(models: [], news: [], refreshedAt: null);

  final List<AiModel> models;
  final List<AiNewsItem> news;
  final DateTime? refreshedAt;

  bool get isEmpty => models.isEmpty;

  factory AiCatalog.fromJson(Map<String, dynamic> j) {
    final ms = (j['refreshedAtMs'] as num?)?.toInt();
    return AiCatalog(
      models: [
        for (final m in (j['models'] as List? ?? const []))
          if (m is Map<String, dynamic>) AiModel.fromJson(m),
      ],
      news: [
        for (final n in (j['news'] as List? ?? const []))
          if (n is Map<String, dynamic>) AiNewsItem.fromJson(n),
      ],
      refreshedAt: (ms == null || ms == 0)
          ? null
          : DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }
}

List<String> _stringList(Object? raw) => [
      for (final v in (raw as List? ?? const []))
        if (v is String) v,
    ];
