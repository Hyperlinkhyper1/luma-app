import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:luma_sync_server/api.dart';
import 'package:luma_sync_server/store.dart';

Future<void> main() async {
  final config = ServerConfig.fromEnvironment(Platform.environment);

  if (!config.registrationEnabled) {
    stdout.writeln('[luma] NOTE: registration is CLOSED '
        '(LUMA_ALLOW_REGISTRATION=false). Existing accounts still work; no '
        'new accounts can be created. Remove that setting to reopen.');
  }

  final store = await Store.open(config.dataDir);
  final api = Api(store, config);

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
  stdout.writeln('[luma] quota per account: '
      '${(config.quotaBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GiB');
  stdout.writeln('[luma] accounts: ${store.usersById.length}');

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
