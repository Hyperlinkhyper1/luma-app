import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'ai_model_catalog.dart';

/// The catalogue's spine: the only upstream that enumerates every model, and
/// the source of pricing, context, modalities and effort support. Free and
/// unauthenticated, so a self-hosted luma server gets a working leaderboard
/// with no keys configured at all.
const String kOpenRouterModelsUrl = 'https://openrouter.ai/api/v1/models';

/// Artificial Analysis' data API. Optional — set LUMA_AA_API_KEY to fill in
/// the reasoning column, the per-effort measurements and the speed figures
/// that OpenRouter doesn't carry. Free tier is 1000 requests/day; a refresh
/// spends exactly one.
const String kArtificialAnalysisUrl =
    'https://artificialanalysis.ai/api/v2/data/llms/models';

/// Where an open-weight model's real licence and parameter count come from.
const String kHuggingFaceModelUrl = 'https://huggingface.co/api/models/';

/// Upper bound on Hugging Face lookups per refresh. Each model needs its own
/// request, so without a cap a first run would fire hundreds at an
/// unauthenticated endpoint; models already carrying a licence are skipped,
/// which means successive refreshes walk through the backlog instead of
/// re-asking about the same ones.
const int kHuggingFaceLookupsPerRefresh = 120;

/// How many Hugging Face lookups run at once.
const int kHuggingFaceConcurrency = 6;

/// How long a fruitless Hugging Face lookup (gated repo, renamed model, card
/// with no licence field) is remembered before it is worth asking again.
const Duration kHuggingFaceRecheck = Duration(days: 30);

const Duration _timeout = Duration(seconds: 30);

/// Display names for the vendor keys OpenRouter uses as id prefixes. Anything
/// not listed falls back to a title-cased form of the key itself, so a vendor
/// that appears between releases still reads correctly on the leaderboard.
const Map<String, String> kAiVendorNames = {
  'openai': 'OpenAI',
  'anthropic': 'Anthropic',
  'google': 'Google',
  'x-ai': 'xAI',
  'z-ai': 'Z.ai',
  'qwen': 'Qwen',
  'deepseek': 'DeepSeek',
  'meta-llama': 'Meta',
  'meta': 'Meta',
  'moonshotai': 'Moonshot AI',
  'mistralai': 'Mistral',
  'nvidia': 'NVIDIA',
  'minimax': 'MiniMax',
  'microsoft': 'Microsoft',
  'amazon': 'Amazon',
  'cohere': 'Cohere',
  'perplexity': 'Perplexity',
  'ai21': 'AI21',
  'liquid': 'Liquid AI',
  'bytedance': 'ByteDance',
  'bytedance-seed': 'ByteDance Seed',
  'baidu': 'Baidu',
  'tencent': 'Tencent',
  'stepfun': 'StepFun',
  'inclusionai': 'InclusionAI',
  'allenai': 'Allen AI',
  'ibm-granite': 'IBM Granite',
  'nousresearch': 'Nous Research',
  'arcee-ai': 'Arcee AI',
  'upstage': 'Upstage',
  'writer': 'Writer',
  'xiaomi': 'Xiaomi',
  'thinkingmachines': 'Thinking Machines',
  'sakana': 'Sakana AI',
  'reka': 'Reka',
  'rekaai': 'Reka',
  'cognitivecomputations': 'Cognitive Computations',
  'deepcogito': 'Deep Cogito',
  'openrouter': 'OpenRouter',
};

/// The only vendors the leaderboard shows. OpenRouter carries dozens of
/// smaller labs and research groups; the app deliberately narrows that down
/// to the names people actually recognize, so every refresh re-applies this
/// filter rather than it being a one-time trim.
///
/// `meta` and `meta-llama` both appear on OpenRouter for different Meta
/// releases; both map to the same brand here.
const Set<String> kAllowedVendors = {
  'openai',
  'anthropic',
  'google',
  'x-ai',
  'z-ai',
  'qwen',
  'deepseek',
  'meta',
  'meta-llama',
  'moonshotai',
  'mistralai',
  'nvidia',
  'minimax',
};

/// One vendor blog polled for the leaderboard's news rail.
///
/// Only feeds that actually exist are listed — Anthropic, Meta, Mistral and
/// xAI publish no public RSS at the time of writing, so their releases reach
/// the rail through Hugging Face's blog and the aggregators rather than
/// first-party. A feed that starts 404ing contributes nothing and shows as
/// failed in the admin refresh log; it never fails the refresh as a whole.
class AiNewsFeed {
  const AiNewsFeed(this.source, this.url);

  final String source;
  final String url;
}

const List<AiNewsFeed> kAiNewsFeeds = [
  AiNewsFeed('OpenAI', 'https://openai.com/news/rss.xml'),
  AiNewsFeed('Google AI', 'https://blog.google/technology/ai/rss/'),
  AiNewsFeed('Google DeepMind', 'https://deepmind.google/blog/rss.xml'),
  AiNewsFeed('Hugging Face', 'https://huggingface.co/blog/feed.xml'),
  AiNewsFeed('Qwen', 'https://qwenlm.github.io/blog/index.xml'),
];

/// Most recent items taken from any one feed.
///
/// Several of these serve their whole archive — OpenAI's is over a thousand
/// entries — and without a per-feed cap the busiest publisher would fill the
/// rail on its own. Capping before the merge keeps it a cross-vendor view.
const int kAiNewsPerFeed = 12;

/// Fetches and normalises every upstream the catalogue is built from.
///
/// Each `fetch*` returns both the records it parsed and a
/// [AiRefreshSourceResult] describing how it went, so a partial failure is
/// reported in the admin dashboard rather than silently producing a thinner
/// leaderboard. No fetcher throws: an upstream being down degrades the
/// refresh, it doesn't fail it.
class AiCatalogFetcher {
  AiCatalogFetcher({HttpClient? client}) : _client = client ?? HttpClient() {
    _client.connectionTimeout = _timeout;
    _client.userAgent = 'luma-server/1.0 (+https://luma-app.cc)';
  }

  final HttpClient _client;

  void close() => _client.close(force: true);

  // ---- OpenRouter ---------------------------------------------------------

  /// Every model OpenRouter lists, minus two kinds of row that would show up
  /// as duplicates on a leaderboard rather than as separate models:
  ///
  /// * `~vendor/model-latest` aliases, which are pointers at whichever model
  ///   is newest rather than models in their own right.
  /// * `:free` / `:batch` / `:thinking` routing variants of a model already
  ///   listed — a $0 free-tier row in particular would sit at the origin of
  ///   the price-vs-performance chart and distort the whole frontier.
  Future<({List<AiModel> models, AiRefreshSourceResult result})>
      fetchOpenRouter() async {
    try {
      final decoded = await _getJson(Uri.parse(kOpenRouterModelsUrl));
      final raw = (decoded is Map<String, dynamic> ? decoded['data'] : null);
      if (raw is! List) {
        return (
          models: <AiModel>[],
          result: const AiRefreshSourceResult(
            source: 'openrouter',
            ok: false,
            error: 'Unexpected response shape (no "data" array).',
          ),
        );
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final models = <AiModel>[];
      for (final entry in raw) {
        if (entry is! Map<String, dynamic>) continue;
        final model = parseOpenRouterModel(entry, nowMs: now);
        if (model != null && kAllowedVendors.contains(model.vendor)) {
          models.add(model);
        }
      }
      return (
        models: models,
        result: AiRefreshSourceResult(
          source: 'openrouter',
          ok: true,
          fetched: raw.length,
          applied: models.length,
        ),
      );
    } catch (e) {
      return (
        models: <AiModel>[],
        result: AiRefreshSourceResult(
          source: 'openrouter',
          ok: false,
          error: '$e',
        ),
      );
    }
  }

  // ---- Artificial Analysis ------------------------------------------------

  /// Overlays Artificial Analysis' indices, speed figures and per-effort
  /// measurements onto models already in [known].
  ///
  /// AA has no id in common with OpenRouter, so models are matched on a
  /// normalised display name (see [_normalizeName]). AA also publishes each
  /// reasoning-effort tier as its own row — "GPT-5.6 (high)" — which is
  /// exactly the data the effort graph needs: those rows are folded into
  /// their base model's [AiModel.effortProfiles] instead of becoming
  /// leaderboard rows of their own.
  Future<({List<AiModel> overlays, AiRefreshSourceResult result})>
      fetchArtificialAnalysis(String apiKey, List<AiModel> known) async {
    try {
      final decoded = await _getJson(
        Uri.parse(kArtificialAnalysisUrl),
        headers: {'x-api-key': apiKey},
      );
      final raw = (decoded is Map<String, dynamic> ? decoded['data'] : null);
      if (raw is! List) {
        return (
          overlays: <AiModel>[],
          result: const AiRefreshSourceResult(
            source: 'artificial-analysis',
            ok: false,
            error: 'Unexpected response shape (no "data" array).',
          ),
        );
      }

      final byName = <String, AiModel>{};
      for (final m in known) {
        byName.putIfAbsent(_normalizeName(m.name), () => m);
        byName.putIfAbsent(_normalizeName(m.slug), () => m);
      }

      final overlays = <String, AiModel>{};
      final efforts = <String, List<AiEffortProfile>>{};
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final entry in raw) {
        if (entry is! Map<String, dynamic>) continue;
        final name = entry['name'] as String?;
        if (name == null) continue;
        // "Claude Sonnet 5 (Non-reasoning, High Effort)" is a completely
        // different mode (thinking disabled), not a rung on the reasoning-
        // effort ladder — but its parenthetical contains "High" as a whole
        // word, so splitEffortSuffix would otherwise fold its score in as
        // if it were the `high` tier. Drop it rather than mislabelling it;
        // it isn't the model's default config either, so it can't stand in
        // for the base overlay when there's no effort suffix to strip.
        if (name.toLowerCase().contains('non-reasoning')) continue;
        final (base, effort) = splitEffortSuffix(name);
        final match = byName[_normalizeName(base)];
        if (match == null) continue;

        final evals = _map(entry['evaluations']);
        final intelligence =
            _num(evals['artificial_analysis_intelligence_index']);

        if (effort != null) {
          // An effort-tier row: it measures a variant, not the model, so it
          // only contributes a point to the effort graph.
          (efforts[match.id] ??= []).add(AiEffortProfile(
            effort: effort,
            intelligenceIndex: intelligence,
            medianOutputTokens: _num(entry['median_output_tokens'])?.round(),
          ));
          continue;
        }

        overlays[match.id] = AiModel(
          id: match.id,
          slug: match.slug,
          name: match.name,
          vendor: match.vendor,
          vendorName: match.vendorName,
          updatedAtMs: now,
          llmStatsIndex: intelligence,
          // AA publishes no single "reasoning index"; GPQA Diamond is the
          // reasoning benchmark it scores every model on, rescaled here from
          // a 0–1 fraction to the 0–100 the other columns use so the four
          // sort against each other sensibly.
          reasoningIndex: _num(evals['artificial_analysis_reasoning_index']) ??
              _asIndex(_num(evals['gpqa'])),
          codingIndex: _num(evals['artificial_analysis_coding_index']),
          agentIndex: _num(evals['artificial_analysis_agentic_index']),
          mathIndex: _num(evals['artificial_analysis_math_index']),
          speedTokensPerSec: _num(entry['median_output_tokens_per_second']),
          latencyMs: _secondsToMs(
              _num(entry['median_time_to_first_token_seconds'])),
          sources: const ['artificial-analysis'],
        );
      }

      // Fold the effort rows into whichever overlay (or bare model) they
      // belong to, cheapest tier first so the graph reads left to right.
      final merged = <AiModel>[];
      for (final id in {...overlays.keys, ...efforts.keys}) {
        final profiles = efforts[id] ?? const <AiEffortProfile>[];
        final sorted = [...profiles]
          ..sort((a, b) =>
              _effortRank(a.effort).compareTo(_effortRank(b.effort)));
        final base = overlays[id];
        if (base != null) {
          merged.add(_withEfforts(base, sorted));
        } else {
          final model = known.firstWhere((m) => m.id == id);
          merged.add(_withEfforts(
            AiModel(
              id: model.id,
              slug: model.slug,
              name: model.name,
              vendor: model.vendor,
              vendorName: model.vendorName,
              updatedAtMs: now,
              sources: const ['artificial-analysis'],
            ),
            sorted,
          ));
        }
      }

      return (
        overlays: merged,
        result: AiRefreshSourceResult(
          source: 'artificial-analysis',
          ok: true,
          fetched: raw.length,
          applied: merged.length,
        ),
      );
    } catch (e) {
      return (
        overlays: <AiModel>[],
        result: AiRefreshSourceResult(
          source: 'artificial-analysis',
          ok: false,
          error: '$e',
        ),
      );
    }
  }

  // ---- Hugging Face -------------------------------------------------------

  /// Resolves the licence and parameter count for open-weight models.
  ///
  /// Carrying a `hugging_face_id` is what makes a model open-weight in the
  /// first place — a closed model has no repo — so this is also what decides
  /// whether the leaderboard's lock icon is open. Only models still missing a
  /// licence are looked up, capped at [kHuggingFaceLookupsPerRefresh] per
  /// run, so this converges over a few refreshes instead of hammering an
  /// unauthenticated endpoint on every one.
  Future<({List<AiModel> overlays, AiRefreshSourceResult result})>
      fetchHuggingFace(List<AiModel> known) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final recheckBefore = now - kHuggingFaceRecheck.inMilliseconds;
    final pending = [
      for (final m in known)
        if (m.huggingFaceId != null &&
            m.huggingFaceId!.isNotEmpty &&
            m.licenseId == null &&
            (m.licenseCheckedAtMs ?? 0) < recheckBefore)
          m,
    ].take(kHuggingFaceLookupsPerRefresh).toList();

    if (pending.isEmpty) {
      return (
        overlays: <AiModel>[],
        result: const AiRefreshSourceResult(
            source: 'hugging-face', ok: true, fetched: 0, applied: 0),
      );
    }

    final overlays = <AiModel>[];
    var resolved = 0;

    for (var i = 0; i < pending.length; i += kHuggingFaceConcurrency) {
      final batch = pending.skip(i).take(kHuggingFaceConcurrency);
      final results = await Future.wait([
        for (final model in batch) _huggingFaceOne(model, now),
      ]);
      for (final r in results) {
        overlays.add(r);
        if (r.openWeights) resolved++;
      }
    }

    final missed = overlays.length - resolved;
    return (
      overlays: overlays,
      result: AiRefreshSourceResult(
        source: 'hugging-face',
        ok: true,
        fetched: pending.length,
        applied: resolved,
        error: missed == 0
            ? null
            : '$missed repo(s) gated or missing; rechecked in '
                '${kHuggingFaceRecheck.inDays} days',
      ),
    );
  }

  /// Always returns an overlay, even when the lookup fails: the failure still
  /// stamps [AiModel.licenseCheckedAtMs] so this model stops consuming the
  /// per-refresh budget until it is due for a recheck.
  Future<AiModel> _huggingFaceOne(AiModel model, int now) async {
    final blank = AiModel(
      id: model.id,
      slug: model.slug,
      name: model.name,
      vendor: model.vendor,
      vendorName: model.vendorName,
      updatedAtMs: now,
      licenseCheckedAtMs: now,
      sources: const ['hugging-face'],
    );
    try {
      final decoded = await _getJson(
          Uri.parse('$kHuggingFaceModelUrl${model.huggingFaceId}'));
      // Upstream JSON is data, not a contract: every branch below checks the
      // shape rather than casting, so one oddly-shaped repo can't take the
      // whole batch down with it.
      if (decoded is! Map<String, dynamic>) return blank;
      final card = decoded['cardData'];
      final safetensors = decoded['safetensors'];
      final license = card is Map ? _firstLicense(card['license']) : null;
      final total = safetensors is Map ? _num(safetensors['total']) : null;
      return AiModel(
        id: model.id,
        slug: model.slug,
        name: model.name,
        vendor: model.vendor,
        vendorName: model.vendorName,
        updatedAtMs: now,
        // The repo resolved, so the weights are downloadable — that is the
        // fact the open padlock stands for, licence text or not.
        openWeights: true,
        licenseId: license,
        licenseName: license == null ? null : licenseDisplayName(license),
        parametersB: total == null ? null : total / 1e9,
        licenseCheckedAtMs: now,
        sources: const ['hugging-face'],
      );
    } catch (_) {
      return blank;
    }
  }

  // ---- News ---------------------------------------------------------------

  /// Polls every feed in [kAiNewsFeeds] concurrently. One dead feed costs its
  /// own entry in the log and nothing else.
  Future<({List<AiNewsItem> items, List<AiRefreshSourceResult> results})>
      fetchNews() async {
    final outcomes = await Future.wait([
      for (final feed in kAiNewsFeeds) _fetchFeed(feed),
    ]);
    return (
      items: [for (final o in outcomes) ...o.items],
      results: [for (final o in outcomes) o.result],
    );
  }

  Future<({List<AiNewsItem> items, AiRefreshSourceResult result})> _fetchFeed(
      AiNewsFeed feed) async {
    try {
      final body = await _getString(Uri.parse(feed.url));
      final parsed = parseFeed(body, feed.source)
        ..sort((a, b) => b.publishedAtMs.compareTo(a.publishedAtMs));
      final items = parsed.take(kAiNewsPerFeed).toList();
      return (
        items: items,
        result: AiRefreshSourceResult(
          source: 'news:${feed.source}',
          // A feed that answers 200 with something that isn't a feed — a docs
          // site's HTML 404 page, say — parses to nothing. That is a broken
          // feed URL, not an empty week, so it is reported as a failure
          // instead of quietly contributing zero items forever.
          ok: parsed.isNotEmpty,
          fetched: parsed.length,
          applied: items.length,
          error: parsed.isEmpty ? 'No feed entries found in response.' : null,
        ),
      );
    } catch (e) {
      return (
        items: <AiNewsItem>[],
        result: AiRefreshSourceResult(
          source: 'news:${feed.source}',
          ok: false,
          error: '$e',
        ),
      );
    }
  }

  // ---- HTTP ---------------------------------------------------------------

  Future<Object?> _getJson(Uri url, {Map<String, String>? headers}) async =>
      jsonDecode(await _getString(url, headers: headers));

  Future<String> _getString(Uri url, {Map<String, String>? headers}) async {
    final request = await _client.getUrl(url).timeout(_timeout);
    request.headers.set('Accept', 'application/json, application/xml, */*');
    headers?.forEach(request.headers.set);
    final response = await request.close().timeout(_timeout);
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode} from ${url.host}');
    }
    return body;
  }
}

// ---- Parsing helpers -------------------------------------------------------

/// Turns one entry of OpenRouter's `/models` payload into an [AiModel], or
/// null if it isn't a model the leaderboard should carry a row for.
///
/// Top-level so the mapping can be tested directly against captured upstream
/// JSON — it is where the catalogue's field semantics actually live, and
/// where an upstream shape change would first show up.
AiModel? parseOpenRouterModel(Map<String, dynamic> j, {required int nowMs}) {
  final id = j['id'];
  // `~vendor/model-latest` aliases point at whichever model is newest rather
  // than being models themselves, and `:free` / `:batch` / `:thinking` are
  // routing variants of a model already listed. Both would appear as
  // duplicate rows; a $0 free-tier row would also sit at the origin of the
  // price-vs-performance chart and drag the frontier down to it.
  if (id is! String || id.startsWith('~') || id.contains(':')) return null;
  final slash = id.indexOf('/');
  if (slash <= 0) return null;
  final vendor = id.substring(0, slash);
  final slug = id.substring(slash + 1);

  final pricing = _map(j['pricing']);
  final architecture = _map(j['architecture']);
  final topProvider = _map(j['top_provider']);
  final benchmarks = _map(j['benchmarks']);
  final aa = _map(benchmarks['artificial_analysis']);
  final reasoning = _map(j['reasoning']);
  final arena = _codeArena(benchmarks['design_arena']);
  final created = _num(j['created']);

  return AiModel(
    id: id,
    slug: slug,
    // OpenRouter prefixes the display name with the vendor ("Anthropic:
    // Claude Opus 5"); the vendor already has its own column.
    name: _stripVendorPrefix(j['name'] as String? ?? slug),
    vendor: vendor,
    vendorName: vendorDisplayName(vendor),
    updatedAtMs: nowMs,
    description: _trimDescription(j['description'] as String?),
    releasedAtMs: created == null ? null : created.round() * 1000,
    contextTokens: _num(j['context_length'])?.round() ??
        _num(topProvider['context_length'])?.round(),
    maxOutputTokens: _num(topProvider['max_completion_tokens'])?.round(),
    inputPricePerM: _perMillion(pricing['prompt']),
    outputPricePerM: _perMillion(pricing['completion']),
    cacheReadPerM: _perMillion(pricing['input_cache_read']),
    cacheWritePerM: _perMillion(pricing['input_cache_write']),
    llmStatsIndex: _num(aa['intelligence_index']),
    codingIndex: _num(aa['coding_index']),
    agentIndex: _num(aa['agentic_index']),
    codeArena: arena?.elo,
    codeArenaRank: arena?.rank,
    // Closed models carry `""` here rather than null. Left as-is that empty
    // string reads as "has a repo", and the lookup URL collapses to Hugging
    // Face's *list* endpoint — which answers 200 with a JSON array of every
    // model on the hub. Normalise it to null at the door.
    huggingFaceId: _nonEmpty(j['hugging_face_id']),
    inputModalities: _stringList(architecture['input_modalities']),
    outputModalities: _stringList(architecture['output_modalities']),
    knowledgeCutoff: j['knowledge_cutoff'] as String?,
    supportedEfforts: _stringList(reasoning['supported_efforts'])
        .where((e) => e != 'none')
        .toList(),
    defaultEffort: reasoning['default_effort'] as String?,
    sources: const ['openrouter'],
  );
}

/// Collapses OpenRouter's per-category `design_arena` list into the single
/// "Code Arena" column the leaderboard shows.
///
/// The list holds one entry per arena/category pair (`website`, `gamedev`,
/// `dataviz`, …). The `codecategories` entry under the `models` arena is the
/// code-specific one and wins when present; otherwise the mean Elo across
/// every `models` entry stands in, which is a broader but still code-weighted
/// read. Agent-arena entries are ignored — they measure a different thing and
/// would not be comparable down the column.
({double elo, int? rank})? _codeArena(Object? raw) {
  if (raw is! List || raw.isEmpty) return null;
  final entries = [
    for (final e in raw)
      if (e is Map<String, dynamic> && e['arena'] == 'models') e,
  ];
  if (entries.isEmpty) return null;
  for (final e in entries) {
    if (e['category'] == 'codecategories') {
      final elo = _num(e['elo']);
      if (elo != null) return (elo: elo, rank: _num(e['rank'])?.round());
    }
  }
  final elos = [
    for (final e in entries)
      if (_num(e['elo']) != null) _num(e['elo'])!,
  ];
  if (elos.isEmpty) return null;
  return (elo: elos.reduce((a, b) => a + b) / elos.length, rank: null);
}

/// Minimal RSS 2.0 / Atom reader.
///
/// Hand-rolled rather than pulled in as a dependency: the server has no XML
/// package and a news rail needs exactly four fields per entry. Anything it
/// can't make sense of is skipped rather than throwing, since a single
/// malformed entry must not cost the whole feed. Exposed for testing.
List<AiNewsItem> parseFeed(String xml, String source) {
  final items = <AiNewsItem>[];
  final blocks = RegExp(r'<(item|entry)[\s>][\s\S]*?</\1>', caseSensitive: false)
      .allMatches(xml);
  for (final block in blocks) {
    final chunk = block.group(0)!;
    final title = _tagText(chunk, 'title');
    final link = _feedLink(chunk);
    if (title == null || link == null) continue;
    final published = _feedDate(chunk);
    items.add(AiNewsItem(
      id: _hashId(link),
      title: title,
      url: link,
      source: source,
      publishedAtMs: published,
      summary: _clampSummary(
          _tagText(chunk, 'description') ?? _tagText(chunk, 'summary')),
      imageUrl: _feedImage(chunk),
    ));
  }
  return items;
}

String? _tagText(String chunk, String tag) {
  final match = RegExp('<$tag(?:\\s[^>]*)?>([\\s\\S]*?)</$tag>',
          caseSensitive: false)
      .firstMatch(chunk);
  if (match == null) return null;
  return _cleanText(match.group(1) ?? '');
}

/// RSS puts the URL in `<link>`'s body; Atom puts it in a `href` attribute.
String? _feedLink(String chunk) {
  final href = RegExp(r'<link[^>]*\shref="([^"]+)"', caseSensitive: false)
      .firstMatch(chunk);
  if (href != null) return href.group(1);
  final body = _tagText(chunk, 'link');
  if (body != null && body.isNotEmpty) return body;
  return _tagText(chunk, 'guid');
}

int _feedDate(String chunk) {
  for (final tag in ['pubDate', 'published', 'updated', 'dc:date']) {
    final raw = _tagText(chunk, tag);
    if (raw == null || raw.isEmpty) continue;
    final parsed = DateTime.tryParse(raw) ?? _parseRfc822(raw);
    if (parsed != null) return parsed.millisecondsSinceEpoch;
  }
  return 0;
}

const List<String> _rfc822Months = [
  'jan', 'feb', 'mar', 'apr', 'may', 'jun',
  'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
];

/// Parses the `Tue, 12 Aug 2026 10:00:00 GMT` form RSS still uses, which
/// [DateTime.parse] rejects. Timezone offsets other than UTC are read but
/// named zones (EST, PDT) are treated as UTC — a few hours' drift on a
/// "7d ago" label is not worth a timezone table.
DateTime? _parseRfc822(String raw) {
  final match = RegExp(
          r'(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4})?')
      .firstMatch(raw);
  if (match == null) return null;
  final month = _rfc822Months.indexOf(match.group(2)!.toLowerCase()) + 1;
  if (month == 0) return null;
  var value = DateTime.utc(
    int.parse(match.group(3)!),
    month,
    int.parse(match.group(1)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6) ?? '0'),
  );
  final offset = match.group(7);
  if (offset != null) {
    final sign = offset[0] == '-' ? 1 : -1;
    value = value.add(Duration(
      hours: sign * int.parse(offset.substring(1, 3)),
      minutes: sign * int.parse(offset.substring(3, 5)),
    ));
  }
  return value;
}

/// Unwraps CDATA, strips inline markup and decodes the handful of entities a
/// feed actually uses.
String _cleanText(String raw) {
  var text = raw.trim();
  final cdata = RegExp(r'^<!\[CDATA\[([\s\S]*?)\]\]>$').firstMatch(text);
  if (cdata != null) text = cdata.group(1)!.trim();

  // Decode, strip, decode. An RSS `<description>` carries *escaped* HTML, so
  // one decode pass only gets as far as the markup — `&lt;p&gt;A &amp;amp; B`
  // becomes `<p>A &amp; B`. The tags come off next, and the second pass
  // resolves the entities that markup was itself carrying.
  text = _decodeEntities(text);
  text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
  text = _decodeEntities(text);

  // Some feeds ship Markdown-escaped titles ("Q4\_0"). The rail renders as
  // plain text, so the backslashes are noise.
  text = text.replaceAllMapped(
      RegExp(r'\\([_*`\[\]()#+\-.!])'), (m) => m.group(1)!);
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// The handful of entities feeds actually use. `&amp;` is resolved last so a
/// double-encoded `&amp;lt;` doesn't turn into a tag on the way through.
String _decodeEntities(String raw) {
  return raw
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&');
}

/// A representative image for the entry, or null if the feed carries none —
/// most of the feeds here never do (see the class doc on [kAiNewsFeeds]), so
/// the news rail always has to have a real placeholder design, not just an
/// occasional one.
///
/// Tries the RSS Media extension first (`media:thumbnail` / `media:content`,
/// what Google's blogs actually publish), then a plain `<enclosure>`, then
/// falls back to the first `<img>` sitting inside the description's own HTML
/// — some feeds embed a lead image there instead of a dedicated image tag.
String? _feedImage(String chunk) {
  final media = RegExp(r'<media:(?:thumbnail|content)\b[^>]*\burl="([^"]+)"',
          caseSensitive: false)
      .firstMatch(chunk);
  if (media != null) return media.group(1);

  final enclosure = RegExp(
              r'<enclosure\b[^>]*\burl="([^"]+)"[^>]*\btype="image',
              caseSensitive: false)
          .firstMatch(chunk) ??
      RegExp(r'<enclosure\b[^>]*\btype="image[^>]*\burl="([^"]+)"',
              caseSensitive: false)
          .firstMatch(chunk);
  if (enclosure != null) return enclosure.group(1);

  final rawDescription = RegExp(
          r'<description(?:\s[^>]*)?>([\s\S]*?)</description>',
          caseSensitive: false)
      .firstMatch(chunk)
      ?.group(1);
  if (rawDescription == null) return null;
  var html = rawDescription.trim();
  final cdata = RegExp(r'^<!\[CDATA\[([\s\S]*?)\]\]>$').firstMatch(html);
  if (cdata != null) html = cdata.group(1)!;
  html = _decodeEntities(html);
  return RegExp(r'<img\b[^>]*\bsrc="([^"]+)"', caseSensitive: false)
      .firstMatch(html)
      ?.group(1);
}

String? _clampSummary(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return raw.length <= 280 ? raw : '${raw.substring(0, 277)}…';
}

String _hashId(String url) =>
    sha256.convert(utf8.encode(url)).toString().substring(0, 16);

/// `"Anthropic: Claude Opus 5"` → `"Claude Opus 5"`. Only strips a prefix
/// that looks like a vendor label, so a name whose own text contains a colon
/// keeps it.
String _stripVendorPrefix(String name) {
  final colon = name.indexOf(': ');
  if (colon <= 0 || colon > 24) return name;
  return name.substring(colon + 2);
}

String? _trimDescription(String? raw) {
  if (raw == null) return null;
  final text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) return null;
  return text.length <= 600 ? text : '${text.substring(0, 597)}…';
}

/// OpenRouter quotes prices per single token as strings; the leaderboard
/// works in USD per million. A `"0"` means genuinely free, `"-1"` means the
/// model isn't priced through OpenRouter at all — the latter becomes null so
/// it shows as "–" instead of a negative price.
double? _perMillion(Object? raw) {
  final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
  if (value == null || value < 0) return null;
  return value * 1e6;
}

double? _num(Object? raw) =>
    raw is num ? raw.toDouble() : (raw is String ? double.tryParse(raw) : null);

/// Reads a nested JSON object without asserting its type — upstream payloads
/// are data, and a field that is unexpectedly a list or a string should cost
/// one empty section, not the whole parse.
Map<String, dynamic> _map(Object? raw) =>
    raw is Map<String, dynamic> ? raw : const {};

/// Treats `""` as absent. Several upstreams use the empty string where they
/// mean null, and downstream code that builds URLs out of these has no way to
/// tell the difference.
String? _nonEmpty(Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// A Hugging Face card's `license` is usually a string but is sometimes a
/// list (dual-licensed repos). Either way the leaderboard shows one.
String? _firstLicense(Object? raw) {
  if (raw is String) return _nonEmpty(raw);
  if (raw is List) {
    for (final entry in raw) {
      final value = _nonEmpty(entry);
      if (value != null) return value;
    }
  }
  return null;
}

/// Rescales a 0–1 benchmark fraction onto the 0–100 the index columns use.
/// Values already above 1 are assumed to be percentages and pass through.
double? _asIndex(double? raw) =>
    raw == null ? null : (raw <= 1 ? raw * 100 : raw);

double? _secondsToMs(double? seconds) =>
    seconds == null ? null : seconds * 1000;

/// Strips punctuation and case so `"GPT-5.6 Sol"` and `"gpt 5.6 sol"` match.
String _normalizeName(String raw) =>
    raw.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

/// Splits Artificial Analysis' effort-tier suffix off a model name. Simple
/// providers use the bare tier — `"GPT-5.6 Sol (max)"` — but others describe
/// it as a longer phrase — `"Claude Opus 5 (Adaptive Reasoning, Xhigh
/// Effort)"` — so this looks for a known tier as a whole word inside the
/// parenthetical rather than requiring the whole thing to match. Returns a
/// null effort when nothing recognisable is found, so `"Claude Opus 5
/// (Preview)"` stays a model rather than becoming a bogus point on an effort
/// graph.
(String, String?) splitEffortSuffix(String name) {
  final match = RegExp(r'^(.*?)\s*\(([^()]+)\)\s*$').firstMatch(name);
  if (match == null) return (name, null);
  final descriptor = match.group(2)!.toLowerCase();
  for (final tier in kEffortTiers) {
    if (RegExp('\\b${RegExp.escape(tier)}\\b').hasMatch(descriptor)) {
      return (match.group(1)!.trim(), tier);
    }
  }
  return (name, null);
}

/// Effort tiers, cheapest first — the order the effort graph plots them in.
const List<String> kEffortTiers = [
  'minimal',
  'low',
  'medium',
  'high',
  'xhigh',
  'max',
];

int _effortRank(String effort) {
  final index = kEffortTiers.indexOf(effort.toLowerCase());
  return index < 0 ? kEffortTiers.length : index;
}

AiModel _withEfforts(AiModel model, List<AiEffortProfile> profiles) => AiModel(
      id: model.id,
      slug: model.slug,
      name: model.name,
      vendor: model.vendor,
      vendorName: model.vendorName,
      updatedAtMs: model.updatedAtMs,
      llmStatsIndex: model.llmStatsIndex,
      reasoningIndex: model.reasoningIndex,
      codingIndex: model.codingIndex,
      agentIndex: model.agentIndex,
      mathIndex: model.mathIndex,
      speedTokensPerSec: model.speedTokensPerSec,
      latencyMs: model.latencyMs,
      effortProfiles: profiles,
      sources: model.sources,
    );

List<String> _stringList(Object? raw) => [
      for (final v in (raw as List? ?? const []))
        if (v is String) v,
    ];

/// Display name for a vendor key, falling back to a title-cased form so an
/// unlisted vendor still reads as a name rather than a slug.
String vendorDisplayName(String vendor) =>
    kAiVendorNames[vendor] ??
    vendor
        .split(RegExp('[-_]'))
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .join(' ');

/// Human form of a Hugging Face licence id (`apache-2.0` → `Apache 2.0`).
String licenseDisplayName(String id) => switch (id.toLowerCase()) {
      'apache-2.0' => 'Apache 2.0',
      'mit' => 'MIT',
      'bsd-3-clause' => 'BSD 3-Clause',
      'cc-by-4.0' => 'CC BY 4.0',
      'cc-by-nc-4.0' => 'CC BY-NC 4.0',
      'cc-by-sa-4.0' => 'CC BY-SA 4.0',
      'gemma' => 'Gemma Terms',
      'llama3' || 'llama3.1' || 'llama3.2' || 'llama3.3' => 'Llama Community',
      'llama4' => 'Llama 4 Community',
      'other' => 'Custom licence',
      _ => id
          .split(RegExp('[-_]'))
          .where((p) => p.isNotEmpty)
          .map((p) => p[0].toUpperCase() + p.substring(1))
          .join(' '),
    };
