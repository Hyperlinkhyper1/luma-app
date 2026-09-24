import 'dart:io';

import 'package:luma_sync_server/update_check.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// The "System updates" button promises a server restart, but the restart
/// itself happens on the host where no test can reach. What can be checked
/// is the one thing the dashboard reports: a finished update requested after
/// this process started must not be shown as "server and wiki restarted".
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('luma_update_check_test');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  UpdateCheckConsole console(DateTime startedAt) => UpdateCheckConsole(
        dataDir: dir.path,
        repoPathConfigured: true,
        startedAt: startedAt,
      );

  /// What deploy-watcher.sh leaves behind once it has run the update.
  Future<void> watcherFinishes() async {
    await File('${dir.path}/update-check.request').delete();
    await File('${dir.path}/update-check.done')
        .writeAsString(DateTime.now().toIso8601String());
  }

  test('an update whose restart never happened reports notRestarted',
      () async {
    final running = console(DateTime.now().subtract(const Duration(hours: 1)));
    await running.requestCheck(Request('POST', Uri.parse('http://x/')));
    await watcherFinishes();

    expect((await running.status()).phase, UpdateCheckPhase.notRestarted);
  });

  test('the process that came up after the request reports done', () async {
    final before =
        console(DateTime.now().subtract(const Duration(hours: 1)));
    await before.requestCheck(Request('POST', Uri.parse('http://x/')));
    await watcherFinishes();

    final restarted = console(DateTime.now().add(const Duration(seconds: 1)));
    expect((await restarted.status()).phase, UpdateCheckPhase.done);
  });

  test('a result from before the requested-at marker existed stays done',
      () async {
    await File('${dir.path}/update-check.done')
        .writeAsString(DateTime.now().toIso8601String());

    expect((await console(DateTime.now()).status()).phase,
        UpdateCheckPhase.done);
  });
}
