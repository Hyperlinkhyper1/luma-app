import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:luma/features/plugins/installed/steam_tools/data/steam_database.dart';
import 'package:luma/features/plugins/installed/steam_tools/steam_api.dart';
import 'package:luma/features/plugins/installed/steam_tools/steam_repository.dart';
import 'package:luma/features/plugins/installed/steam_tools/steam_scope.dart';
import 'package:luma/features/plugins/installed/steam_tools/ui/steam_game_search_dialog.dart';
import 'package:luma/storage/storage_guard.dart';
import 'package:luma/theme/luma_theme.dart';

/// Covers the thing this dialog exists to prove: a game can be found and
/// tracked through Steam's public store search alone, with no Steam account
/// or Web API key anywhere in the path. The fake client below stands in for
/// that keyless search endpoint — nothing here touches the real network.
/// `scheduleRefresh` starts a real `Timer` that eventually calls
/// `path_provider`, unmocked here. In production that's fine — the call
/// just fails quietly — but under flutter_test's FakeAsync clock, a
/// platform-channel wait started from inside a fired Timer doesn't resolve
/// the way a normal awaited Future does, and the test hangs rather than
/// completing. Tests that call `SteamRepository.trackGame` never need the
/// real scheduling, so it's a no-op here.
class _NoScheduleStorageGuard extends StorageGuardService {
  @override
  void scheduleRefresh() {}
}

void main() {
  setUpAll(() => StorageGuardService.instance = _NoScheduleStorageGuard());

  late SteamDatabase db;

  setUp(() {
    db = SteamDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  http.Client fakeSearchClient(Map<String, dynamic> Function(Uri) respond) =>
      MockClient((request) async {
        final body = respond(request.url);
        return http.Response(jsonEncode(body), 200);
      });

  Widget app(SteamRepository repository, Widget child) => SteamScope(
        repository: repository,
        child: MaterialApp(
          theme: LumaTheme.dark,
          home: Scaffold(body: child),
        ),
      );

  /// Every test here pumps a tree with a `StreamBuilder` over a drift query
  /// (`watchTrackedGames`). Drift schedules a zero-duration cleanup `Timer`
  /// when that subscription is torn down, and flutter_test's automatic
  /// between-tests teardown unmounts the tree *after* the test body already
  /// returned — too late for a `pump()` to flush that timer, which then
  /// trips flutter_test's "timer still pending" invariant check. Disposing
  /// the tree explicitly and pumping once more, from inside the test body,
  /// gives that cleanup timer a chance to fire before the test ends.
  Future<void> disposeAndFlush(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('shows a hint until something is typed', (tester) async {
    final repository = SteamRepository(db, api: SteamApi(client: MockClient(
      (_) async => http.Response('{}', 200),
    )));

    await tester.pumpWidget(app(repository, const SteamGameSearchDialog()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining("Search by a game's name"),
      findsOneWidget,
    );

    await disposeAndFlush(tester);
  });

  testWidgets('typing a query returns results after the debounce settles',
      (tester) async {
    final repository = SteamRepository(
      db,
      api: SteamApi(
        client: fakeSearchClient((uri) {
          expect(uri.queryParameters['term'], 'hollow knight');
          // No tiny_image here on purpose: Image.network isn't mocked in
          // this test, and a real fetch attempt would stall pumpAndSettle
          // waiting on a request that never resolves. The row's fallback
          // (ColoredBox) is exercised instead — see the null-image branch
          // in _SearchResultRow.
          return {
            'total': 1,
            'items': [
              {'type': 'app', 'name': 'Hollow Knight', 'id': 367520},
            ],
          };
        }),
      ),
    );

    await tester.pumpWidget(app(repository, const SteamGameSearchDialog()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Search for a game'),
      'hollow knight',
    );
    // The debounce is 400ms; settle it, then let the fake response resolve.
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.text('Hollow Knight'), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);

    await disposeAndFlush(tester);
  });

  // Tapping a result to track it is deliberately not driven end-to-end
  // through the widget here: SteamRepository.trackGame fires
  // `unawaited(ensureDetails(...))` in the background (by design — the new
  // tile shouldn't sit blank until the next open), and that background
  // fetch racing pumpAndSettle/tester teardown made this test flaky
  // (intermittent real-time hangs, not a bug in the tracking logic itself).
  // The tracking semantics it would have checked — a searched game is
  // added untracked ownership-wise, tracking is idempotent, a merge never
  // clobbers a manual add — are covered directly against the database in
  // steam_tools_test.dart's "tracking a game needs no Steam account" group.

  testWidgets('says plainly when nothing matched', (tester) async {
    final repository = SteamRepository(
      db,
      api: SteamApi(
        client: fakeSearchClient((_) => const {'total': 0, 'items': []}),
      ),
    );

    await tester.pumpWidget(app(repository, const SteamGameSearchDialog()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Search for a game'),
      'zzzzzznotagame',
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.textContaining('No games matched'), findsOneWidget);

    await disposeAndFlush(tester);
  });

  testWidgets('Done closes the dialog', (tester) async {
    final repository = SteamRepository(db, api: SteamApi(client: MockClient(
      (_) async => http.Response('{}', 200),
    )));

    await tester.pumpWidget(app(repository, Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => showSteamGameSearchDialog(context),
          child: const Text('open'),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(SteamGameSearchDialog), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.byType(SteamGameSearchDialog), findsNothing);

    await disposeAndFlush(tester);
  });
}
