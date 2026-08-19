import 'dart:convert';
import 'dart:io';

import 'util.dart';

/// How many news items the catalogue keeps.
const int kAiNewsRetained = 40;

/// One reasoning-effort tier a model supports, with what that tier costs in
/// thinking: a higher effort buys a higher [intelligenceIndex] but burns more
/// [medianOutputTokens] to get there. Populated from Artificial Analysis,
/// which publishes both numbers per model variant; models whose provider
/// exposes effort levels but has no measured variants keep an empty list and
/// the app draws no effort graph for them rather than inventing one.
class AiEffortProfile {
  const AiEffortProfile({
    required this.effort,
    this.intelligenceIndex,
    this.medianOutputTokens,
  });

  /// Provider's own label — `minimal`, `low`, `medium`, `high`, `xhigh`.
  final String effort;
  final double? intelligenceIndex;
  final int? medianOutputTokens;

  factory AiEffortProfile.fromJson(Map<String, dynamic> j) => AiEffortProfile(
        effort: j['effort'] as String,
        intelligenceIndex: (j['intelligenceIndex'] as num?)?.toDouble(),
        medianOutputTokens: (j['medianOutputTokens'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'effort': effort,
        if (intelligenceIndex != null) 'intelligenceIndex': intelligenceIndex,
        if (medianOutputTokens != null) 'medianOutputTokens': medianOutputTokens,
      };
}

/// A single model on the leaderboard, merged from every upstream that knows
/// something about it (see ai_model_sources.dart):
///
/// * **OpenRouter** is the spine — the only source that enumerates every
///   model, and it carries pricing, context, modalities and effort support.
/// * **Artificial Analysis** contributes the four index columns, the openness
///   index, speed/latency, and the per-effort measurements.
/// * **Hugging Face** contributes the real licence and parameter count for
///   open-weight models, which is what makes [openWeights] a fact rather than
///   a guess and what the hardware calculator sizes VRAM against.
///
/// Every scored field is nullable on purpose: a model missing from one
/// upstream still belongs on the board with that source's columns shown as
/// "–", never as a zero that would sort it to the bottom.
class AiModel {
  const AiModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.vendor,
    required this.vendorName,
    required this.updatedAtMs,
    this.description,
    this.releasedAtMs,
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
    this.licenseCheckedAtMs,
    this.inputModalities = const [],
    this.outputModalities = const [],
    this.knowledgeCutoff,
    this.supportedEfforts = const [],
    this.defaultEffort,
    this.effortProfiles = const [],
    this.sources = const [],
  });

  /// Upstream canonical id, e.g. `anthropic/claude-opus-5`. Stable across
  /// refreshes and used as the merge key and the client's detail-route key.
  final String id;

  /// The id's last segment, for display and for the app's own deep links.
  final String slug;
  final String name;

  /// Lowercase vendor key from the id's first segment (`anthropic`, `x-ai`,
  /// `z-ai`, `moonshotai`, …) and its display form.
  final String vendor;
  final String vendorName;
  final String? description;
  final int? releasedAtMs;
  final int? contextTokens;
  final int? maxOutputTokens;

  /// USD per million tokens. Cache rates are null for providers that don't
  /// bill caching separately.
  final double? inputPricePerM;
  final double? outputPricePerM;
  final double? cacheReadPerM;
  final double? cacheWritePerM;

  /// The four composite ratings shown as leaderboard columns. [llmStatsIndex]
  /// is the overall composite; the other three are per-discipline splits.
  final double? llmStatsIndex;
  final double? reasoningIndex;
  final double? codingIndex;
  final double? agentIndex;
  final double? mathIndex;

  /// Head-to-head coding arena rating (Elo-style) and the model's rank in it.
  final double? codeArena;
  final int? codeArenaRank;

  final double? speedTokensPerSec;
  final double? latencyMs;

  /// True only when a real licence was resolved from Hugging Face — the lock
  /// icon in the table is open for these and closed for everything else.
  final bool openWeights;
  final String? licenseId;
  final String? licenseName;

  /// Total and active (per-token, for MoE) parameters in billions. The
  /// hardware calculator needs both: VRAM for weights follows total, while
  /// throughput follows active.
  final double? parametersB;
  final double? activeParametersB;
  final String? huggingFaceId;

  /// When Hugging Face was last asked about this model, whatever the answer.
  ///
  /// Without this, a repo that is gated, renamed or simply has no licence in
  /// its card would be re-requested on every refresh forever, and — because
  /// lookups are capped per run — would permanently crowd out the models
  /// still waiting for their first check.
  final int? licenseCheckedAtMs;

  final List<String> inputModalities;
  final List<String> outputModalities;
  final String? knowledgeCutoff;

  final List<String> supportedEfforts;
  final String? defaultEffort;
  final List<AiEffortProfile> effortProfiles;

  /// Which upstreams contributed to this row, so the app can say where a
  /// number came from instead of presenting everything as equally sourced.
  final List<String> sources;

  final int updatedAtMs;

  /// The plain average of input and output price, in USD per million tokens —
  /// the single "price" column on the leaderboard. Null unless both sides are
  /// known, since averaging against a missing half would understate the cost.
  double? get avgPricePerM =>
      (inputPricePerM == null || outputPricePerM == null)
          ? null
          : (inputPricePerM! + outputPricePerM!) / 2;

  /// Cost of a realistic 8:1 input:output mix, which is what the
  /// price-vs-performance frontier is plotted against — a plain average
  /// overweights output tokens relative to how models are actually used.
  double? get blendedPricePerM =>
      (inputPricePerM == null || outputPricePerM == null)
          ? null
          : (inputPricePerM! * 8 + outputPricePerM!) / 9;

  factory AiModel.fromJson(Map<String, dynamic> j) => AiModel(
        id: j['id'] as String,
        slug: j['slug'] as String,
        name: j['name'] as String,
        vendor: j['vendor'] as String,
        vendorName: j['vendorName'] as String,
        updatedAtMs: (j['updatedAtMs'] as num?)?.toInt() ?? 0,
        description: j['description'] as String?,
        releasedAtMs: (j['releasedAtMs'] as num?)?.toInt(),
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
        licenseCheckedAtMs: (j['licenseCheckedAtMs'] as num?)?.toInt(),
        inputModalities: _stringList(j['inputModalities']),
        outputModalities: _stringList(j['outputModalities']),
        knowledgeCutoff: j['knowledgeCutoff'] as String?,
        supportedEfforts: _stringList(j['supportedEfforts']),
        defaultEffort: j['defaultEffort'] as String?,
        effortProfiles: [
          for (final e in (j['effortProfiles'] as List? ?? const []))
            if (e is Map<String, dynamic>) AiEffortProfile.fromJson(e),
        ],
        sources: _stringList(j['sources']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'vendor': vendor,
        'vendorName': vendorName,
        'updatedAtMs': updatedAtMs,
        if (description != null) 'description': description,
        if (releasedAtMs != null) 'releasedAtMs': releasedAtMs,
        if (contextTokens != null) 'contextTokens': contextTokens,
        if (maxOutputTokens != null) 'maxOutputTokens': maxOutputTokens,
        if (inputPricePerM != null) 'inputPricePerM': inputPricePerM,
        if (outputPricePerM != null) 'outputPricePerM': outputPricePerM,
        if (cacheReadPerM != null) 'cacheReadPerM': cacheReadPerM,
        if (cacheWritePerM != null) 'cacheWritePerM': cacheWritePerM,
        if (llmStatsIndex != null) 'llmStatsIndex': llmStatsIndex,
        if (reasoningIndex != null) 'reasoningIndex': reasoningIndex,
        if (codingIndex != null) 'codingIndex': codingIndex,
        if (agentIndex != null) 'agentIndex': agentIndex,
        if (mathIndex != null) 'mathIndex': mathIndex,
        if (codeArena != null) 'codeArena': codeArena,
        if (codeArenaRank != null) 'codeArenaRank': codeArenaRank,
        if (speedTokensPerSec != null) 'speedTokensPerSec': speedTokensPerSec,
        if (latencyMs != null) 'latencyMs': latencyMs,
        'openWeights': openWeights,
        if (licenseId != null) 'licenseId': licenseId,
        if (licenseName != null) 'licenseName': licenseName,
        if (parametersB != null) 'parametersB': parametersB,
        if (activeParametersB != null) 'activeParametersB': activeParametersB,
        if (huggingFaceId != null) 'huggingFaceId': huggingFaceId,
        if (licenseCheckedAtMs != null)
          'licenseCheckedAtMs': licenseCheckedAtMs,
        if (inputModalities.isNotEmpty) 'inputModalities': inputModalities,
        if (outputModalities.isNotEmpty) 'outputModalities': outputModalities,
        if (knowledgeCutoff != null) 'knowledgeCutoff': knowledgeCutoff,
        if (supportedEfforts.isNotEmpty) 'supportedEfforts': supportedEfforts,
        if (defaultEffort != null) 'defaultEffort': defaultEffort,
        if (effortProfiles.isNotEmpty)
          'effortProfiles': [for (final e in effortProfiles) e.toJson()],
        if (sources.isNotEmpty) 'sources': sources,
      };

  /// Returns a copy with every non-null field of [other] laid over this one.
  /// Merge order is OpenRouter → Artificial Analysis → Hugging Face, so a
  /// later source refines earlier values but never blanks them.
  AiModel mergedWith(AiModel other) => AiModel(
        id: id,
        slug: slug,
        name: other.name.isNotEmpty ? other.name : name,
        vendor: vendor,
        vendorName: vendorName,
        updatedAtMs: other.updatedAtMs,
        description: other.description ?? description,
        releasedAtMs: other.releasedAtMs ?? releasedAtMs,
        contextTokens: other.contextTokens ?? contextTokens,
        maxOutputTokens: other.maxOutputTokens ?? maxOutputTokens,
        inputPricePerM: other.inputPricePerM ?? inputPricePerM,
        outputPricePerM: other.outputPricePerM ?? outputPricePerM,
        cacheReadPerM: other.cacheReadPerM ?? cacheReadPerM,
        cacheWritePerM: other.cacheWritePerM ?? cacheWritePerM,
        llmStatsIndex: other.llmStatsIndex ?? llmStatsIndex,
        reasoningIndex: other.reasoningIndex ?? reasoningIndex,
        codingIndex: other.codingIndex ?? codingIndex,
        agentIndex: other.agentIndex ?? agentIndex,
        mathIndex: other.mathIndex ?? mathIndex,
        codeArena: other.codeArena ?? codeArena,
        codeArenaRank: other.codeArenaRank ?? codeArenaRank,
        speedTokensPerSec: other.speedTokensPerSec ?? speedTokensPerSec,
        latencyMs: other.latencyMs ?? latencyMs,
        openWeights: other.openWeights || openWeights,
        licenseId: other.licenseId ?? licenseId,
        licenseName: other.licenseName ?? licenseName,
        parametersB: other.parametersB ?? parametersB,
        activeParametersB: other.activeParametersB ?? activeParametersB,
        huggingFaceId: other.huggingFaceId ?? huggingFaceId,
        licenseCheckedAtMs: other.licenseCheckedAtMs ?? licenseCheckedAtMs,
        inputModalities: other.inputModalities.isNotEmpty
            ? other.inputModalities
            : inputModalities,
        outputModalities: other.outputModalities.isNotEmpty
            ? other.outputModalities
            : outputModalities,
        knowledgeCutoff: other.knowledgeCutoff ?? knowledgeCutoff,
        supportedEfforts: other.supportedEfforts.isNotEmpty
            ? other.supportedEfforts
            : supportedEfforts,
        defaultEffort: other.defaultEffort ?? defaultEffort,
        effortProfiles: other.effortProfiles.isNotEmpty
            ? other.effortProfiles
            : effortProfiles,
        sources: {...sources, ...other.sources}.toList(),
      );
}

/// One dated item in the leaderboard's news rail, aggregated from the model
/// vendors' own feeds (see `kAiNewsFeeds`) — never from another leaderboard.
class AiNewsItem {
  const AiNewsItem({
    required this.id,
    required this.title,
    required this.url,
    required this.source,
    required this.publishedAtMs,
    this.summary,
  });

  /// Stable hash of the item's link, so re-polling a feed doesn't duplicate.
  final String id;
  final String title;
  final String url;

  /// Display name of the feed it came from, e.g. "Anthropic".
  final String source;
  final int publishedAtMs;
  final String? summary;

  factory AiNewsItem.fromJson(Map<String, dynamic> j) => AiNewsItem(
        id: j['id'] as String,
        title: j['title'] as String,
        url: j['url'] as String,
        source: j['source'] as String,
        publishedAtMs: (j['publishedAtMs'] as num?)?.toInt() ?? 0,
        summary: j['summary'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'source': source,
        'publishedAtMs': publishedAtMs,
        if (summary != null) 'summary': summary,
      };
}

/// Outcome of one upstream inside a refresh, for the admin dashboard's log.
class AiRefreshSourceResult {
  const AiRefreshSourceResult({
    required this.source,
    required this.ok,
    this.fetched = 0,
    this.applied = 0,
    this.error,
  });

  final String source;
  final bool ok;

  /// Records read from the upstream, and how many of them landed on a model
  /// already in the catalogue — a large gap means the id mapping drifted.
  final int fetched;
  final int applied;
  final String? error;

  Map<String, dynamic> toJson() => {
        'source': source,
        'ok': ok,
        'fetched': fetched,
        'applied': applied,
        if (error != null) 'error': error,
      };
}

/// State of the catalogue refresh the admin dashboard drives. Held in memory
/// only: a refresh interrupted by a restart is simply re-run, and the
/// catalogue it was rebuilding is left at its last good version on disk.
class AiRefreshStatus {
  const AiRefreshStatus({
    required this.running,
    this.startedAtMs,
    this.finishedAtMs,
    this.modelsBefore = 0,
    this.modelsAfter = 0,
    this.modelsAdded = const [],
    this.newsCount = 0,
    this.results = const [],
    this.error,
  });

  const AiRefreshStatus.idle() : this(running: false);

  final bool running;
  final int? startedAtMs;
  final int? finishedAtMs;
  final int modelsBefore;
  final int modelsAfter;

  /// Ids that were not in the catalogue before this refresh — this is the
  /// "did it find new models?" answer, surfaced verbatim in the dashboard.
  final List<String> modelsAdded;
  final int newsCount;
  final List<AiRefreshSourceResult> results;
  final String? error;

  Map<String, dynamic> toJson() => {
        'running': running,
        if (startedAtMs != null) 'startedAtMs': startedAtMs,
        if (finishedAtMs != null) 'finishedAtMs': finishedAtMs,
        'modelsBefore': modelsBefore,
        'modelsAfter': modelsAfter,
        'modelsAdded': modelsAdded,
        'newsCount': newsCount,
        'results': [for (final r in results) r.toJson()],
        if (error != null) 'error': error,
      };
}

/// The server's copy of the AI model leaderboard, persisted as one JSON file
/// in the data directory.
///
/// Unlike the sync collections in store.dart this is deliberately *public*
/// data — identical for every account, carrying nothing a user typed — so it
/// is stored in the clear and served whole to any signed-in client, mirroring
/// recipe_store.dart's plain-store convention. Clients cache it by [etag] and
/// skip the download entirely when nothing changed.
class AiModelCatalogStore {
  AiModelCatalogStore._(
      this._file, this._models, this._news, this._refreshedAtMs) {
    _recomputeEtag();
  }

  final File _file;
  final Map<String, AiModel> _models;
  List<AiNewsItem> _news;
  int _refreshedAtMs;
  String _etag = '';
  final AsyncLock _lock = AsyncLock();

  AiRefreshStatus _status = const AiRefreshStatus.idle();

  static Future<AiModelCatalogStore> open(String dataDir) async {
    final file = File('$dataDir${Platform.pathSeparator}ai_models.json');
    final models = <String, AiModel>{};
    var news = <AiNewsItem>[];
    var refreshedAtMs = 0;
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) {
          refreshedAtMs = (decoded['refreshedAtMs'] as num?)?.toInt() ?? 0;
          for (final m in (decoded['models'] as List? ?? const [])) {
            if (m is Map<String, dynamic>) {
              final model = AiModel.fromJson(m);
              models[model.id] = model;
            }
          }
          news = [
            for (final n in (decoded['news'] as List? ?? const []))
              if (n is Map<String, dynamic>) AiNewsItem.fromJson(n),
          ];
        }
      } catch (_) {
        // Corrupt catalogue — start empty rather than refusing to boot. The
        // next admin refresh rebuilds it from the upstreams.
      }
    }
    return AiModelCatalogStore._(file, models, news, refreshedAtMs);
  }

  /// Every model, best-rated first, with unrated models after the rated ones
  /// rather than interleaved at zero.
  List<AiModel> get models {
    final all = _models.values.toList()
      ..sort((a, b) {
        final ai = a.llmStatsIndex;
        final bi = b.llmStatsIndex;
        if (ai == null && bi == null) return a.name.compareTo(b.name);
        if (ai == null) return 1;
        if (bi == null) return -1;
        return bi.compareTo(ai);
      });
    return all;
  }

  List<AiNewsItem> get news => List.unmodifiable(_news);
  int get refreshedAtMs => _refreshedAtMs;
  int get modelCount => _models.length;

  /// Content tag of the served payload. Clients send it back as
  /// `If-None-Match` and get a 304 when the catalogue hasn't moved.
  String get etag => _etag;

  AiRefreshStatus get status => _status;
  void setStatus(AiRefreshStatus status) => _status = status;

  AiModel? byId(String id) => _models[id];

  /// Folds [incoming] into the catalogue, returning the ids that weren't
  /// present before. Models that vanish upstream are kept — a provider
  /// dropping a model from its list shouldn't erase it from the leaderboard
  /// mid-refresh — but their [AiModel.updatedAtMs] stops advancing, which is
  /// how the app can tell a row has gone stale.
  Future<List<String>> upsertModels(Iterable<AiModel> incoming) =>
      _lock.synchronized(() async {
        final added = <String>[];
        for (final model in incoming) {
          final existing = _models[model.id];
          if (existing == null) {
            added.add(model.id);
            _models[model.id] = model;
          } else {
            _models[model.id] = existing.mergedWith(model);
          }
        }
        _refreshedAtMs = DateTime.now().millisecondsSinceEpoch;
        await _persist();
        return added;
      });

  Future<void> upsertNews(Iterable<AiNewsItem> items) =>
      _lock.synchronized(() async {
        final byId = {for (final n in _news) n.id: n};
        for (final item in items) {
          byId[item.id] = item;
        }
        final merged = byId.values.toList()
          ..sort((a, b) => b.publishedAtMs.compareTo(a.publishedAtMs));
        // A rail, not an archive: keep the most recent slice so the payload
        // stays small and the app never has to paginate it.
        _news = merged.take(kAiNewsRetained).toList();
        await _persist();
      });

  Map<String, dynamic> toJson() => {
        'refreshedAtMs': _refreshedAtMs,
        'models': [for (final m in models) m.toJson()],
        'news': [for (final n in _news) n.toJson()],
      };

  Future<void> _persist() async {
    await atomicWriteString(_file.path, jsonEncode(toJson()));
    _recomputeEtag();
  }

  void _recomputeEtag() {
    // Cheap but sufficient: the catalogue only changes through a refresh, so
    // count and timestamp move together, and a collision would need two
    // refreshes in the same millisecond producing identical totals.
    _etag = '"$_refreshedAtMs-${_models.length}-${_news.length}"';
  }
}

List<String> _stringList(Object? raw) => [
      for (final v in (raw as List? ?? const []))
        if (v is String) v,
    ];
