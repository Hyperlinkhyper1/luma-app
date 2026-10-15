import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/home/dashboard_tiles.dart';
import 'package:luma/features/home/home_layout.dart';
import 'package:luma/features/home/home_page.dart';
import 'package:luma/features/home/home_repository.dart';
import 'package:luma/features/home/home_scope.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_market_repository.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_market_scope.dart';
import 'package:luma/features/plugins/installed/steam_tools/data/steam_database.dart';
import 'package:luma/features/plugins/installed/steam_tools/steam_repository.dart';
import 'package:luma/features/plugins/installed/steam_tools/steam_scope.dart';
import 'package:luma/features/plugins/plugin_repository.dart';
import 'package:luma/features/plugins/plugin_scope.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';

class _SteamRepository extends ChangeNotifier implements SteamRepository {
  _SteamRepository(this.games);

  final List<SteamGame> games;

  @override
  Stream<List<SteamGame>> watchTrackedGames() => Stream.value(games);

  @override
  String? get error => null;

  @override
  bool get refreshingPrices => false;

  @override
  bool isFetchingDetails(int appId) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cs2Repository extends ChangeNotifier implements Cs2MarketRepository {
  _Cs2Repository(this.items, this.entries);

  final List<Cs2MarketItem> items;
  final List<Cs2MarketEntry> entries;

  @override
  Stream<List<Cs2MarketItem>> watchTrackedItems() => Stream.value(items);

  @override
  Stream<List<Cs2MarketEntry>> watchAllEntries() => Stream.value(entries);

  @override
  Stream<List<Cs2MarketPricePoint>> watchAllPriceHistory() => Stream.value([]);

  @override
  String? get error => null;

  @override
  bool get refreshingPrices => false;

  @override
  bool isFetchingPrice(String marketHashName) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Plugins implements PluginRepository {
  _Plugins(this.installed);

  final bool installed;

  @override
  Stream<List<InstalledPluginRecord>> watchInstalled() => Stream.value([
    if (installed)
      InstalledPluginRecord(
        pluginId: 'game-tools',
        name: 'Steam Tools',
        icon: 'sports_esports',
        version: '1.0.0',
        installedAt: DateTime(2026, 10, 16),
        downloadCount: 1,
      ),
  ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyHome extends ChangeNotifier implements HomeRepository {
  @override
  final HomeLayout layout = HomeLayout(columns: 12, tiles: []);

  @override
  String get family => 'desktop';

  @override
  String? get loadError => null;

  @override
  Future<void> get ready => Future.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _game = SteamGame(
  appId: 620,
  name: 'Portal 2',
  playtimeMinutes: 0,
  owned: false,
  isFree: false,
  onWindows: true,
  onMac: true,
  onLinux: true,
  itadUnknown: false,
);

const _regular = 'AK-47 | Redline (Field-Tested)';
const _statTrak = 'StatTrak™ AK-47 | Redline (Field-Tested)';

Cs2MarketItem _skin(String hash) => Cs2MarketItem(
  marketHashName: hash,
  skinId: 'redline',
  displayName: 'AK-47 | Redline',
  weaponName: 'AK-47',
  rarityName: 'Classified',
  rarityColor: '#d32ce6',
  imageUrl: '',
  wear: 'Field-Tested',
  statTrak: hash == _statTrak,
  currency: 'USD',
  trackedAt: DateTime(2026, 10, 16),
);

Cs2MarketEntry _entry(int id, String hash) => Cs2MarketEntry(
  id: id,
  marketHashName: hash,
  trackedAt: DateTime(2026, 10, 16),
);

HomeTile _tile(String kind, {Map<String, dynamic> config = const {}}) =>
    HomeTile(
      id: 'steam-tile',
      kind: kind,
      x: 0,
      y: 0,
      w: 6,
      h: kind == 'cs2_tracked_graph' ? 7 : 5,
      config: config,
    );

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: L.localizationsDelegates,
  supportedLocales: L.supportedLocales,
  theme: LumaTheme.light,
  home: Scaffold(body: child),
);

Future<HomeTile?> _configure(
  WidgetTester tester,
  HomeTile tile, {
  List<SteamGame> games = const [],
  List<Cs2MarketItem> items = const [],
  List<Cs2MarketEntry> entries = const [],
  required Future<void> Function() choose,
}) async {
  final steam = _SteamRepository(games);
  final cs2 = _Cs2Repository(items, entries);
  addTearDown(steam.dispose);
  addTearDown(cs2.dispose);
  final result = Completer<HomeTile?>();
  await tester.pumpWidget(
    SteamScope(
      repository: steam,
      child: Cs2MarketScope(
        repository: cs2,
        child: _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result.complete(await configureDashboardTile(context, tile));
              },
              child: const Text('Configure widget'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Configure widget'));
  await tester.pumpAndSettle();
  await choose();
  await tester.pumpAndSettle();
  expect(result.isCompleted, isTrue);
  return result.future;
}

void main() {
  testWidgets('Steam widget definitions have localized titles and sizes', (
    tester,
  ) async {
    final titles = <String, String>{};
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            for (final definition in dashboardTileDefinitions) {
              titles[definition.kind] = definition.localizedTitle(context);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    for (final entry in {
      'steam_game_price': 'Steam game price',
      'cs2_skin_price': 'CS2 skin price',
      'cs2_tracked_graph': 'Tracked CS2 skins graph',
    }.entries) {
      expect(titles[entry.key], entry.value);
      final definition = dashboardTileDefinitions.singleWhere(
        (definition) => definition.kind == entry.key,
      );
      expect(definition.defaultWidth, 6);
      expect(
        definition.defaultHeight,
        entry.key == 'cs2_tracked_graph' ? 7 : 5,
      );
    }
  });

  testWidgets('game picker stores the selected Steam app identity', (
    tester,
  ) async {
    final tile = await _configure(
      tester,
      _tile('steam_game_price', config: {'appId': 570, 'custom': 'preserved'}),
      games: [
        _game.copyWith(appId: 570, name: 'Dota 2'),
        _game,
      ],
      choose: () async {
        expect(find.text('Choose a Steam game'), findsOneWidget);
        await tester.tap(find.text('Portal 2'));
      },
    );
    expect(tile!.config, {'appId': 620, 'custom': 'preserved'});
    expect(tile.id, 'steam-tile');
  });

  testWidgets('all tracked games removes a previous single game selection', (
    tester,
  ) async {
    final tile = await _configure(
      tester,
      _tile('steam_game_price', config: {'appId': 620}),
      games: [_game],
      choose: () async => tester.tap(find.text('All tracked games')),
    );
    expect(tile!.config, isNot(contains('appId')));
  });

  for (final kind in ['cs2_skin_price', 'cs2_tracked_graph']) {
    testWidgets('$kind picker preserves exact CS2 market variant identity', (
      tester,
    ) async {
      final tile = await _configure(
        tester,
        _tile(kind),
        items: [_skin(_regular), _skin(_statTrak)],
        entries: [_entry(1, _regular), _entry(2, _statTrak)],
        choose: () async {
          expect(find.text('Choose a CS2 skin'), findsOneWidget);
          expect(find.text(_regular), findsOneWidget);
          await tester.tap(find.text(_statTrak));
        },
      );
      expect(tile!.config['marketHashName'], _statTrak);
    });

    testWidgets('$kind all tracked skins clears a previous selection', (
      tester,
    ) async {
      final tile = await _configure(
        tester,
        _tile(kind, config: {'marketHashName': _regular}),
        items: [_skin(_regular)],
        entries: [_entry(1, _regular)],
        choose: () async => tester.tap(find.text('All tracked CS2 skins')),
      );
      expect(tile!.config, isNot(contains('marketHashName')));
    });
  }

  testWidgets('CS2 picker excludes listings with no tracked copies', (
    tester,
  ) async {
    final tile = await _configure(
      tester,
      _tile('cs2_skin_price'),
      items: [_skin(_regular), _skin(_statTrak)],
      entries: [_entry(1, _regular)],
      choose: () async {
        expect(find.text(_statTrak), findsNothing);
        await tester.tap(find.text(_regular));
      },
    );
    expect(tile!.config['marketHashName'], _regular);
  });

  for (final kind in [
    'steam_game_price',
    'cs2_skin_price',
    'cs2_tracked_graph',
  ]) {
    testWidgets('$kind cannot be added from an empty tracker', (tester) async {
      final tile = await _configure(
        tester,
        _tile(kind),
        choose: () async {
          expect(find.byType(SimpleDialogOption), findsNothing);
          await tester.tapAt(const Offset(4, 4));
        },
      );
      expect(tile, isNull);
    });
  }

  testWidgets('dismissing a populated picker cancels the widget change', (
    tester,
  ) async {
    final tile = await _configure(
      tester,
      _tile('steam_game_price'),
      games: [_game],
      choose: () async => tester.tapAt(const Offset(4, 4)),
    );
    expect(tile, isNull);
  });

  test('home layout JSON retains Steam app and exact CS2 identities', () {
    final original = HomeLayout(
      columns: 12,
      tiles: [
        _tile('steam_game_price', config: {'appId': 620}),
        _tile(
          'cs2_skin_price',
          config: {'marketHashName': _statTrak},
        ).copyWith(id: 'skin-price', x: 6),
        _tile(
          'cs2_tracked_graph',
          config: {'marketHashName': _regular},
        ).copyWith(id: 'skin-graph', y: 5),
        _tile('cs2_tracked_graph').copyWith(id: 'all-skins', x: 6, y: 5),
      ],
    );
    final restored = HomeLayout.fromJson(
      jsonDecode(jsonEncode(original.toJson())),
      columns: 12,
    );
    expect(restored.toJson(), original.toJson());
  });

  testWidgets(
    'Steam widgets use the installed Game Tools plugin and navigation',
    (tester) async {
      final steam = _SteamRepository([]);
      final cs2 = _Cs2Repository([], []);
      addTearDown(steam.dispose);
      addTearDown(cs2.dispose);
      for (final kind in [
        'steam_game_price',
        'cs2_skin_price',
        'cs2_tracked_graph',
      ]) {
        for (final installed in [false, true]) {
          String? openedPlugin;
          await tester.pumpWidget(
            SteamScope(
              repository: steam,
              child: Cs2MarketScope(
                repository: cs2,
                child: PluginScope(
                  repository: _Plugins(installed),
                  child: _app(
                    DashboardTileContent(
                      key: ValueKey('$kind-$installed'),
                      tile: _tile(kind),
                      onNavigate: (_) {},
                      onPlugin: (id) => openedPlugin = id,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (installed) {
            expect(find.textContaining('Install '), findsNothing);
            await tester.tap(find.text('Open Steam Tools'));
            expect(openedPlugin, 'game-tools');
          } else {
            expect(find.textContaining('Install '), findsOneWidget);
            expect(find.text('Open Steam Tools'), findsNothing);
          }
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets('home editor offers all three Steam widgets in Add tile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1040, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _EmptyHome();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      _app(
        HomeScope(
          repository: repository,
          child: HomePage(onNavigate: (_) {}, startEditing: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add tile').first);
    await tester.pumpAndSettle();
    final list = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Scrollable),
    );
    for (final title in [
      'Steam game price',
      'CS2 skin price',
      'Tracked CS2 skins graph',
    ]) {
      await tester.scrollUntilVisible(find.text(title), 180, scrollable: list);
      expect(find.text(title), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
