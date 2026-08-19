import 'dart:io';

import 'ai_model_catalog.dart';
import 'ai_model_sources.dart';

/// Rebuilds the AI model catalogue from every configured upstream, in the one
/// order the merge depends on:
///
/// 1. **OpenRouter** first, because it is the only source that enumerates
///    models — the other two can only refine rows that already exist.
/// 2. **Artificial Analysis**, matched by name onto what step 1 found.
/// 3. **Hugging Face**, which needs the `hugging_face_id` step 1 supplied.
/// 4. **News feeds**, independent of the model data but part of the same
///    "refresh everything" click.
///
/// Nothing here throws. Each upstream reports itself into
/// [AiRefreshStatus.results], and a failure at any step leaves the catalogue
/// at its last good state rather than emptying it — a leaderboard that is a
/// week stale still beats a blank one. Only an unexpected failure of the
/// orchestration itself lands in [AiRefreshStatus.error].
///
/// [artificialAnalysisKey] is optional: without it the reasoning column, the
/// speed figures and the per-effort measurements stay empty and every other
/// column is unaffected.
Future<AiRefreshStatus> refreshAiCatalog(
  AiModelCatalogStore store, {
  String? artificialAnalysisKey,
  AiCatalogFetcher? fetcher,
}) async {
  final client = fetcher ?? AiCatalogFetcher();
  final startedAtMs = DateTime.now().millisecondsSinceEpoch;
  final modelsBefore = store.modelCount;
  final results = <AiRefreshSourceResult>[];
  final added = <String>[];

  store.setStatus(AiRefreshStatus(
    running: true,
    startedAtMs: startedAtMs,
    modelsBefore: modelsBefore,
  ));

  String? fatal;
  var newsCount = 0;

  try {
    final openRouter = await client.fetchOpenRouter();
    results.add(openRouter.result);
    if (openRouter.models.isNotEmpty) {
      added.addAll(await store.upsertModels(openRouter.models));
    }

    // Fetching already only keeps the allowed vendors, but that alone can't
    // remove anything a catalogue built before the allowlist existed is
    // still carrying — so every refresh also actively prunes down to it.
    final removedVendors = await store.pruneVendorsNotIn(kAllowedVendors);
    if (removedVendors.isNotEmpty) {
      results.add(AiRefreshSourceResult(
        source: 'vendor-filter',
        ok: true,
        applied: removedVendors.length,
      ));
    }

    if (artificialAnalysisKey != null && artificialAnalysisKey.isNotEmpty) {
      final aa = await client.fetchArtificialAnalysis(
          artificialAnalysisKey, store.models);
      results.add(aa.result);
      if (aa.overlays.isNotEmpty) {
        await store.upsertModels(aa.overlays);
      }
    }

    final hf = await client.fetchHuggingFace(store.models);
    results.add(hf.result);
    if (hf.overlays.isNotEmpty) {
      await store.upsertModels(hf.overlays);
    }

    final news = await client.fetchNews();
    results.addAll(news.results);
    if (news.items.isNotEmpty) {
      await store.upsertNews(news.items);
    }
    newsCount = store.news.length;
  } catch (e, st) {
    fatal = '$e';
    stderr.writeln('[luma] ai catalogue refresh failed: $e\n$st');
  } finally {
    if (fetcher == null) client.close();
  }

  final status = AiRefreshStatus(
    running: false,
    startedAtMs: startedAtMs,
    finishedAtMs: DateTime.now().millisecondsSinceEpoch,
    modelsBefore: modelsBefore,
    modelsAfter: store.modelCount,
    modelsAdded: added,
    newsCount: newsCount,
    results: results,
    error: fatal,
  );
  store.setStatus(status);
  return status;
}
