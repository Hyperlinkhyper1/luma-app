import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/usage/data/usage_database.dart';
import 'package:luma/features/plugins/installed/usage/usage_repository.dart';
import 'package:luma/features/plugins/installed/usage/usage_tracker_base.dart';
import 'package:luma/storage/storage_guard.dart';

void main() {
  // UsageRepository consults the app-wide storage cap before every write;
  // outside of main.dart's real startup this static is never set.
  setUpAll(() => StorageGuardService.instance = StorageGuardService());

  late UsageDatabase db;
  late UsageRepository repo;

  setUp(() {
    db = UsageDatabase(NativeDatabase.memory());
    repo = UsageRepository(db);
  });
  tearDown(() => db.close());

  const chrome = UsageAppInfo(appName: 'Chrome', processName: 'chrome.exe');
  const chromeOtherTab =
      UsageAppInfo(appName: 'Chrome', processName: 'chrome.exe', windowTitle: 'New tab');
  const spotify = UsageAppInfo(appName: 'Spotify', processName: 'spotify.exe');

  test('first poll of an app opens exactly one session row', () async {
    await repo.handlePoll(chrome);

    final rows = await db.select(db.usageSessions).get();
    expect(rows, hasLength(1));
    expect(rows.single.processName, 'chrome.exe');
    expect(rows.single.appName, 'Chrome');
    expect(repo.currentApp?.processName, 'chrome.exe');
  });

  test('repeated polls of the same process extend the same row', () async {
    await repo.handlePoll(chrome);
    final firstId = (await db.select(db.usageSessions).get()).single.id;

    await repo.handlePoll(chrome);
    await repo.handlePoll(chrome);

    final rows = await db.select(db.usageSessions).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, firstId);
  });

  test('a different window title on the same process does not start a new session', () async {
    await repo.handlePoll(chrome);
    await repo.handlePoll(chromeOtherTab);

    final rows = await db.select(db.usageSessions).get();
    expect(rows, hasLength(1),
        reason: 'window title changes should not be a session boundary');
  });

  test('switching to a different process finalizes the old row and opens a new one', () async {
    await repo.handlePoll(chrome);
    await repo.handlePoll(spotify);

    final rows = await db.select(db.usageSessions).get()
      ..sort((a, b) => a.id.compareTo(b.id));
    expect(rows, hasLength(2));
    expect(rows[0].processName, 'chrome.exe');
    expect(rows[1].processName, 'spotify.exe');
    expect(repo.currentApp?.processName, 'spotify.exe');
  });

  test('a null poll (nothing focused) finalizes the open session and clears currentApp', () async {
    await repo.handlePoll(chrome);
    await repo.handlePoll(null);

    expect(repo.currentApp, isNull);
    final rows = await db.select(db.usageSessions).get();
    expect(rows, hasLength(1));
  });

  test('clearHistory finalizes and deletes every row', () async {
    await repo.handlePoll(chrome);
    await repo.handlePoll(spotify);

    await repo.clearHistory();

    final rows = await db.select(db.usageSessions).get();
    expect(rows, isEmpty);
    expect(repo.currentApp, isNull);
  });

  test('setIntervalSeconds clamps to the supported bounds', () {
    // Pause first so this doesn't start a real polling Timer — nothing in
    // this test drives ticks, and a stray Timer would outlive the test.
    repo.setPaused(true);

    repo.setIntervalSeconds(0);
    expect(repo.intervalSeconds, kUsageMinIntervalSeconds);

    repo.setIntervalSeconds(999);
    expect(repo.intervalSeconds, kUsageMaxIntervalSeconds);
  });
}
