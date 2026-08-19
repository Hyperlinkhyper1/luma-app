// Regenerates the AI model leaderboard snapshot that ships inside the app.
//
// The Leaderboard tab has to work on a fresh install with no account, so a
// catalogue is bundled as an asset and shown immediately; devices with an
// approved account then pull a fresher copy from the luma server. This script
// rebuilds that bundled copy using the *same* code the server runs, so the two
// can never drift into different shapes.
//
// Run it from the server/ directory, then commit the regenerated asset:
//
//   dart run tool/refresh_ai_catalog.dart
//
// It reaches OpenRouter and Hugging Face (both free and keyless) and the news
// feeds. Set LUMA_AA_API_KEY first to also fill in the reasoning column, the
// speed figures and the per-effort measurements:
//
//   $env:LUMA_AA_API_KEY = "..."; dart run tool/refresh_ai_catalog.dart
//
// Hugging Face lookups are capped per run, so the first pass leaves some
// models without a licence. Run it a second time to drain the backlog — it
// resumes rather than starting over.

import 'dart:io';

import 'package:luma_sync_server/ai_model_catalog.dart';
import 'package:luma_sync_server/ai_model_refresh.dart';

const String _assetPath = '../assets/ai_models/catalog.json';

Future<void> main() async {
  final assetFile = File(_assetPath);
  if (!await assetFile.parent.exists()) {
    stderr.writeln('Run this from the server/ directory: $_assetPath is not '
        'reachable from ${Directory.current.path}.');
    exitCode = 1;
    return;
  }

  // The store writes `ai_models.json` into a directory, so build it next to
  // the asset and move the result into place.
  final workDir = await Directory.systemTemp.createTemp('luma_ai_catalog');
  try {
    // Seed from the committed snapshot so a run resumes the Hugging Face
    // backlog instead of re-asking about every model from scratch.
    if (await assetFile.exists()) {
      await assetFile.copy('${workDir.path}${Platform.pathSeparator}'
          'ai_models.json');
    }

    final store = await AiModelCatalogStore.open(workDir.path);
    stdout.writeln('starting from ${store.modelCount} models…');

    final key = Platform.environment['LUMA_AA_API_KEY'];
    if (key == null || key.isEmpty) {
      stdout.writeln('note: LUMA_AA_API_KEY not set — reasoning, speed and '
          'effort-level data will be missing from this snapshot.');
    }

    final status = await refreshAiCatalog(store, artificialAnalysisKey: key);

    for (final result in status.results) {
      stdout.writeln('${result.ok ? "ok  " : "FAIL"} '
          '${result.source.padRight(24)} fetched=${result.fetched} '
          'applied=${result.applied} ${result.error ?? ""}');
    }
    if (status.error != null) {
      stderr.writeln('refresh failed: ${status.error}');
      exitCode = 1;
      return;
    }
    if (store.modelCount == 0) {
      stderr.writeln('refresh produced no models; leaving the existing '
          'snapshot alone.');
      exitCode = 1;
      return;
    }

    final built = File('${workDir.path}${Platform.pathSeparator}'
        'ai_models.json');
    await built.copy(assetFile.path);

    stdout.writeln('models: ${status.modelsBefore} -> ${status.modelsAfter} '
        '(+${status.modelsAdded.length}) · news ${status.newsCount} · '
        '${(await assetFile.length() / 1024).round()} KB');

    // Two different reasons a model can have no licence, and only one of them
    // is worth another run: never looked up yet (capped out of this pass) vs
    // looked up and found gated or licence-less, which is remembered.
    final unchecked = store.models
        .where((m) =>
            m.huggingFaceId != null &&
            m.licenseId == null &&
            m.licenseCheckedAtMs == null)
        .length;
    final gated = store.models
        .where((m) =>
            m.huggingFaceId != null &&
            m.licenseId == null &&
            m.licenseCheckedAtMs != null)
        .length;
    if (unchecked > 0) {
      stdout.writeln('$unchecked open-weight model(s) not looked up yet — '
          'run again to drain the backlog.');
    }
    if (gated > 0) {
      stdout.writeln('$gated repo(s) are gated or publish no licence; they '
          'stay open-weight with an unnamed licence.');
    }
  } finally {
    if (await workDir.exists()) await workDir.delete(recursive: true);
  }
}
