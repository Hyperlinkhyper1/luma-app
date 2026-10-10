import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/data/plugin_database.dart';
import 'package:luma/features/plugins/plugin_catalog_service.dart';
import 'package:luma/features/plugins/plugin_repository.dart';
import 'package:luma/sync/sync_api.dart';

void main() {
  late PluginDatabase db;
  late PluginRepository repository;

  setUp(() {
    db = PluginDatabase(NativeDatabase.memory());
    repository = PluginRepository(db, PluginCatalogService());
  });

  tearDown(() => db.close());

  Future<void> addRow(String id) => db
      .into(db.installedPlugins)
      .insert(InstalledPluginsCompanion.insert(pluginId: id, name: id));

  test('a granted plugin joins the nav rail and leaves when revoked', () async {
    await addRow('calculator');
    final seen = <List<String>>[];
    final sub = repository.watchInstalled().listen(
      (list) => seen.add([for (final p in list) p.pluginId]),
    );
    await pumpEventQueue();
    expect(seen.last, ['calculator']);

    repository.granted.value = {'team-clipboard'};
    await pumpEventQueue();
    expect(seen.last, ['calculator', 'team-clipboard']);

    repository.granted.value = const {};
    await pumpEventQueue();
    expect(seen.last, ['calculator']);
    await sub.cancel();
  });

  test('an old marketplace install cannot keep it on screen', () async {
    await addRow('team-clipboard');
    final first = await repository.watchInstalled().first;
    expect(first, isEmpty);

    repository.granted.value = {'team-clipboard'};
    final granted = await repository.watchInstalled().first;
    expect(granted.single.pluginId, 'team-clipboard');
    expect(granted.single.icon, 'content_paste');
  });

  test('only known granted-only ids are shown', () async {
    repository.granted.value = {'calculator', 'made-up'};
    expect(await repository.watchInstalled().first, isEmpty);
  });

  test('it can be neither downloaded nor uninstalled', () async {
    await expectLater(
      repository.install(
        const PluginCatalogEntry(
          id: 'team-clipboard',
          name: 'Team Clipboard',
          description: '',
          icon: 'content_paste',
          category: 'Productivity',
          version: '1.0.0',
        ),
      ),
      throwsStateError,
    );
    expect(await db.select(db.installedPlugins).get(), isEmpty);

    repository.granted.value = {'team-clipboard'};
    await repository.uninstall('team-clipboard');
    expect(
      (await repository.watchInstalled().first).single.pluginId,
      'team-clipboard',
    );
  });

  test('the account carries what the admin granted', () {
    expect(
      RemoteAccount.fromJson({
        'email': 'a@b.com',
        'grantedPlugins': ['team-clipboard', 7],
      }).grantedPlugins,
      ['team-clipboard'],
    );
    expect(
      RemoteAccount.fromJson({'email': 'a@b.com'}).grantedPlugins,
      isEmpty,
    );
  });
}
