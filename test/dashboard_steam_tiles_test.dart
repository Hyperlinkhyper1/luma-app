import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/home/dashboard_steam_tiles.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_market_repository.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_market_scope.dart';
import 'package:luma/features/plugins/installed/steam_tools/data/steam_database.dart';
import 'package:luma/features/plugins/installed/steam_tools/steam_repository.dart';
import 'package:luma/features/plugins/installed/steam_tools/steam_scope.dart';
import 'package:luma/features/plugins/installed/steam_tools/ui/cs2_price_chart.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';

class _GameRepository extends SteamRepository {
  _GameRepository(super.db);

  final games = StreamController<List<SteamGame>>.broadcast(sync: true);
  int watches = 0;
  int refreshes = 0;
  int? refreshedAppId;

  @override
  Stream<List<SteamGame>> watchTrackedGames() {
    watches++;
    return games.stream;
  }

  @override
  Future<void> ensureDetails(int appId, {bool force = false}) async {
    refreshes++;
    refreshedAppId = appId;
    notifyListeners();
  }

  @override
  Future<void> refreshAllPrices() async {
    refreshes++;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(games.close());
    super.dispose();
  }
}

class _SkinRepository extends ChangeNotifier implements Cs2MarketRepository {
  final items = StreamController<List<Cs2MarketItem>>.broadcast(sync: true);
  final entries = StreamController<List<Cs2MarketEntry>>.broadcast(sync: true);
  final history = StreamController<List<Cs2MarketPricePoint>>.broadcast(
    sync: true,
  );
  int itemWatches = 0;
  int entryWatches = 0;
  int historyWatches = 0;

  @override
  String? get error => null;

  @override
  bool get refreshingPrices => false;

  @override
  bool isFetchingPrice(String marketHashName) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<List<Cs2MarketItem>> watchTrackedItems() {
    itemWatches++;
    return items.stream;
  }

  @override
  Stream<List<Cs2MarketEntry>> watchAllEntries() {
    entryWatches++;
    return entries.stream;
  }

  @override
  Stream<List<Cs2MarketPricePoint>> watchAllPriceHistory() {
    historyWatches++;
    return history.stream;
  }

  @override
  void dispose() {
    unawaited(items.close());
    unawaited(entries.close());
    unawaited(history.close());
    super.dispose();
  }
}

final _checkedAt = DateTime(2026, 10, 16, 12);

SteamGame _game(int appId, String name, int cents) => SteamGame(
  appId: appId,
  name: name,
  playtimeMinutes: 0,
  owned: false,
  isFree: false,
  onWindows: true,
  onMac: false,
  onLinux: false,
  itadUnknown: false,
  currency: 'USD',
  lastPriceCents: cents,
  detailsFetchedAt: _checkedAt,
);

Cs2MarketItem _item(String hash, int? cents, {String currency = 'USD'}) =>
    Cs2MarketItem(
      marketHashName: hash,
      skinId: hash,
      displayName: hash,
      weaponName: 'AK-47',
      rarityName: 'Classified',
      rarityColor: '#d32ce6',
      imageUrl: '',
      statTrak: false,
      currency: currency,
      lastLowestCents: cents,
      priceFetchedAt: cents == null ? null : _checkedAt,
      trackedAt: DateTime(2026),
    );

Cs2MarketEntry _entry(int id, String hash) =>
    Cs2MarketEntry(id: id, marketHashName: hash, trackedAt: DateTime(2026));

Cs2MarketPricePoint _point(String hash, int cents, {String currency = 'USD'}) =>
    Cs2MarketPricePoint(
      id: cents,
      marketHashName: hash,
      observedAt: DateTime.now().subtract(const Duration(hours: 1)),
      lowestCents: cents,
      currency: currency,
    );

Widget _app(Widget child, {double width = 420, double height = 500}) =>
    MaterialApp(
      theme: LumaTheme.dark,
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  late SteamDatabase db;

  setUp(() => db = SteamDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('selected game shows saved price and only refreshes on request', (
    tester,
  ) async {
    final repository = _GameRepository(db);
    addTearDown(repository.dispose);
    var opens = 0;
    await tester.pumpWidget(
      SteamScope(
        repository: repository,
        child: _app(
          DashboardSteamGamePriceTile(appId: 2, onOpen: () => opens++),
        ),
      ),
    );
    repository.games.add([
      _game(1, 'Other game', 1234),
      _game(2, 'Selected game', 2499),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Selected game'), findsOneWidget);
    expect(find.text('Other game'), findsNothing);
    expect(find.text(r'$24.99'), findsOneWidget);
    expect(find.textContaining('Checked'), findsOneWidget);
    expect(repository.refreshes, 0);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    expect(repository.refreshes, 1);
    expect(repository.refreshedAppId, 2);
    expect(repository.watches, 1);
    expect(find.text(r'$24.99'), findsOneWidget);

    await tester.tap(find.text('Open Steam Tools'));
    expect(opens, 1);
    await _unmount(tester);
  });

  testWidgets('skin prices update when only the item stream changes', (
    tester,
  ) async {
    final repository = _SkinRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      Cs2MarketScope(
        repository: repository,
        child: _app(DashboardCs2SkinPriceTile(onOpen: () {})),
      ),
    );
    repository.items.add([_item('Redline', 1000)]);
    repository.entries.add([_entry(1, 'Redline'), _entry(2, 'Redline')]);
    await tester.pumpAndSettle();
    expect(find.text(r'$10.00'), findsOneWidget);

    repository.items.add([_item('Redline', 1250)]);
    await tester.pumpAndSettle();
    expect(find.text(r'$12.50'), findsOneWidget);
    expect(find.text(r'$10.00'), findsNothing);
    expect(repository.itemWatches, 1);
    expect(repository.entryWatches, 1);
    await _unmount(tester);
  });

  testWidgets('portfolio graph counts every copy and updates saved total', (
    tester,
  ) async {
    final repository = _SkinRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      Cs2MarketScope(
        repository: repository,
        child: _app(DashboardCs2TrackedGraphTile(onOpen: () {})),
      ),
    );
    repository.items.add([_item('Redline', 1000)]);
    repository.entries.add([_entry(1, 'Redline'), _entry(2, 'Redline')]);
    await tester.pump();
    repository.history.add([_point('Redline', 1000)]);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Cs2PriceSeriesView>(find.byType(Cs2PriceSeriesView))
          .series
          .samples
          .last
          .priceCents,
      2000,
    );

    repository.items.add([_item('Redline', 1250)]);
    await tester.pumpAndSettle();
    expect(find.text(r'$25.00'), findsOneWidget);
    expect(repository.itemWatches, 1);
    expect(repository.entryWatches, 1);
    expect(repository.historyWatches, 1);
    await _unmount(tester);
  });

  testWidgets('portfolio avoids combining mixed currencies or missing prices', (
    tester,
  ) async {
    final repository = _SkinRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      Cs2MarketScope(
        repository: repository,
        child: _app(DashboardCs2TrackedGraphTile(onOpen: () {})),
      ),
    );
    repository.items.add([
      _item('Redline', 1000),
      _item('Doppler', 2000, currency: 'EUR'),
    ]);
    repository.entries.add([_entry(1, 'Redline'), _entry(2, 'Doppler')]);
    await tester.pump();
    repository.history.add(const []);
    await tester.pumpAndSettle();
    expect(find.byType(Cs2PriceSeriesView), findsNothing);
    expect(find.textContaining('different currencies'), findsOneWidget);

    repository.items.add([_item('Redline', 1000), _item('Doppler', null)]);
    await tester.pumpAndSettle();
    expect(find.text(r'$10.00'), findsNothing);
    expect(find.text('Not checked yet'), findsWidgets);
    await _unmount(tester);
  });

  testWidgets('selected skin graph remains scrollable in a narrow short tile', (
    tester,
  ) async {
    final repository = _SkinRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      Cs2MarketScope(
        repository: repository,
        child: _app(
          DashboardCs2TrackedGraphTile(
            marketHashName: 'Redline',
            onOpen: () {},
          ),
          width: 180,
          height: 130,
        ),
      ),
    );
    repository.items.add([_item('Redline', 1000), _item('Other skin', 2000)]);
    repository.entries.add([
      _entry(1, 'Redline'),
      _entry(2, 'Redline'),
      _entry(3, 'Other skin'),
    ]);
    await tester.pump();
    repository.history.add([
      _point('Redline', 1000),
      _point('Other skin', 2000),
    ]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byType(Cs2PriceSeriesView),
      80,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    final series = tester
        .widget<Cs2PriceSeriesView>(find.byType(Cs2PriceSeriesView))
        .series;
    expect(series.samples.last.priceCents, 1000);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets(
    'a removed selected game offers Steam Tools and stream errors stay local',
    (tester) async {
      final repository = _GameRepository(db);
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        SteamScope(
          repository: repository,
          child: _app(DashboardSteamGamePriceTile(appId: 42, onOpen: () {})),
        ),
      );
      repository.games.add([_game(1, 'Other game', 500)]);
      await tester.pumpAndSettle();
      expect(find.textContaining('no longer tracked'), findsOneWidget);
      expect(find.text('Open Steam Tools'), findsOneWidget);

      repository.games.addError(StateError('stream failed'));
      await tester.pumpAndSettle();
      expect(find.text('Could not load Steam Tools data.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    },
  );
}
