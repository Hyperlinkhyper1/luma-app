import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:luma_sync_server/ai_benchmark_store.dart';
import 'package:luma_sync_server/ai_model_catalog.dart';
import 'package:luma_sync_server/ai_usage_store.dart';
import 'package:luma_sync_server/api.dart';
import 'package:luma_sync_server/chat_store.dart';
import 'package:luma_sync_server/family_store.dart';
import 'package:luma_sync_server/mail.dart';
import 'package:luma_sync_server/recipe_store.dart';
import 'package:luma_sync_server/store.dart';
import 'package:luma_sync_server/subway_store.dart';

Future<void> main() async {
  final config = ServerConfig.fromEnvironment(Platform.environment);
  final mailConfig = MailConfig.fromEnvironment(Platform.environment);

  if (!config.registrationEnabled) {
    stdout.writeln('[luma] NOTE: registration is CLOSED '
        '(LUMA_ALLOW_REGISTRATION=false). Existing accounts still work; no '
        'new accounts can be created. Remove that setting to reopen.');
  }
  if (config.requireEmailVerification && !mailConfig.enabled) {
    stdout.writeln('[luma] NOTE: email verification is required but no '
        'LUMA_SMTP_HOST is set; verification links will be logged to '
        'stderr instead of emailed. Set the LUMA_SMTP_* variables to send '
        'real email, or set LUMA_REQUIRE_EMAIL_VERIFICATION=false.');
  }

  final store = await Store.open(config.dataDir);
  final familyStore = await FamilyStore.open(config.dataDir);
  final chatStore = await ChatStore.open(config.dataDir);
  final aiUsage = await AiUsageStore.open(config.dataDir);
  final subwayStore = await SubwayStore.open(config.dataDir);
  final recipeStore = await RecipeStore.open(config.dataDir);
  final aiCatalog = await AiModelCatalogStore.open(config.dataDir);
  final aiBenchmarks = await AiBenchmarkStore.open(
    config.dataDir,
    seedDir: await _benchmarkSeedDir(),
  );
  final api = Api(store, config, Mailer(mailConfig), familyStore, chatStore,
      aiUsage, subwayStore, recipeStore, aiCatalog, aiBenchmarks);

  final server = await shelf_io.serve(
    api.handler,
    InternetAddress.anyIPv4,
    config.port,
  );
  // The reverse proxy (Caddy) terminates TLS; never expose this port directly.
  server.autoCompress = true;

  stdout.writeln('[luma] sync server listening on port ${server.port}');
  stdout.writeln('[luma] data directory: ${Directory(config.dataDir).absolute.path}');
  stdout.writeln(
      '[luma] registration: ${config.allowRegistration ? 'open' : 'closed'}');
  stdout.writeln('[luma] plan quotas: core 5 MB · orbit 15 MB · nova 30 MB');
  stdout.writeln('[luma] accounts: ${store.usersById.length}');
  stdout.writeln('[luma] ai leaderboard: ${aiCatalog.modelCount} models'
      '${config.artificialAnalysisConfigured ? "" : " (no LUMA_AA_API_KEY: "
          "reasoning/speed/effort columns stay empty)"}');
  stdout.writeln(
      '[luma] ai benchmarks: ${(await aiBenchmarks.list()).length} scenes');
  stdout.writeln('[luma] admin deploy button: '
      '${config.repoPathConfigured ? "configured" : "disabled (no LUMA_REPO_PATH)"}');

  // Graceful shutdown so in-flight writes complete.
  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('[luma] shutting down...');
    await server.close();
    exit(0);
  });
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) async {
      await server.close();
      exit(0);
    });
  }
}

/// Where the benchmark scenes checked into the repo live, so a fresh data
/// directory still serves every scene.
///
/// When running from source (`dart run bin/luma_server.dart` inside server/)
/// that is `benchmarks/` next to the checkout; in Docker the same files are
/// baked into the image at `/seed/benchmarks` (see the Dockerfile) because
/// the image contains no source checkout. A data-directory file always wins
/// over the seed (see [AiBenchmarkStore]), so operators override per file.
Future<String?> _benchmarkSeedDir() async {
  for (final candidate in ['benchmarks', '/seed/benchmarks']) {
    if (await Directory(candidate).exists()) return candidate;
  }
  return null;
}
