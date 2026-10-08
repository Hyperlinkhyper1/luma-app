import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/data/plugin_database.dart';
import 'package:luma/features/plugins/plugin_catalog_service.dart';
import 'package:luma/features/plugins/plugin_repository.dart';

void main() {
  late PluginDatabase db;
  late PluginRepository repository;

  setUp(() {
    db = PluginDatabase(NativeDatabase.memory());
    repository = PluginRepository(db, PluginCatalogService());
  });

  tearDown(() => db.close());

  Future<void> install(String id, DateTime at) => db
      .into(db.installedPlugins)
      .insert(
        InstalledPluginsCompanion.insert(
          pluginId: id,
          name: id,
          icon: const Value('sports_esports'),
          installedAt: Value(at),
        ),
      );

  Future<List<InstalledPlugin>> rows() => db.select(db.installedPlugins).get();

  test('steam and roblox tools collapse into one game tools entry', () async {
    await install('roblox-tools', DateTime(2026, 5, 2));
    await install('calculator', DateTime(2026, 5, 3));
    await install('steam-tools', DateTime(2026, 5, 1));

    await repository.migrateMergedPlugins();

    final after = await rows();
    expect(
      after.map((r) => r.pluginId),
      unorderedEquals(['calculator', 'game-tools']),
    );
    final game = after.firstWhere((r) => r.pluginId == 'game-tools');
    expect(game.name, 'Game Tools');
    expect(game.installedAt, DateTime(2026, 5, 1));
  });

  test(
    'an existing game tools install is kept, legacy rows are dropped',
    () async {
      await install('game-tools', DateTime(2026, 6, 1));
      await install('steam-tools', DateTime(2026, 5, 1));

      await repository.migrateMergedPlugins();

      final after = await rows();
      expect(after, hasLength(1));
      expect(after.single.pluginId, 'game-tools');
      expect(after.single.installedAt, DateTime(2026, 6, 1));
    },
  );

  test('nothing to migrate leaves the table alone', () async {
    await install('calculator', DateTime(2026, 5, 3));
    await repository.migrateMergedPlugins();
    expect((await rows()).single.pluginId, 'calculator');
  });
}
