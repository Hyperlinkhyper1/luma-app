import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'minecraft_launcher_database.g.dart';

/// A saved login usable to launch Minecraft: either a local "offline" profile
/// (no ownership check, works everywhere) or a linked Microsoft account.
class McAccounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()(); // 'offline' | 'microsoft'
  TextColumn get username => text()();
  TextColumn get uuid => text()();
  TextColumn get accessToken => text().nullable()();
  TextColumn get refreshToken => text().nullable()();
  DateTimeColumn get accessTokenExpiresAt => dateTime().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A configured Minecraft install: a version + loader pinned to its own
/// folder under `minecraft/instances/<id>/` with independent mods/saves/etc.
class McInstances extends Table {
  TextColumn get id => text()(); // uuid, also the instances/<id> dirname
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get versionId => text()(); // e.g. "1.20.4"
  TextColumn get loader =>
      text().withDefault(const Constant('vanilla'))(); // vanilla|fabric|forge|neoforge|quilt
  TextColumn get loaderVersion => text().nullable()();
  TextColumn get iconPath => text().nullable()();
  IntColumn get minMemoryMb => integer().withDefault(const Constant(1024))();
  IntColumn get maxMemoryMb => integer().withDefault(const Constant(4096))();
  TextColumn get jvmArgs => text().nullable()();
  TextColumn get javaPath => text().nullable()(); // null = auto-resolve
  IntColumn get resolutionWidth => integer().withDefault(const Constant(854))();
  IntColumn get resolutionHeight =>
      integer().withDefault(const Constant(480))();
  BoolColumn get fullscreen => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();
  IntColumn get totalPlayTimeSeconds =>
      integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One completed or in-progress launch of an instance, for playtime and a
/// per-launch link back to the saved log file.
class McLaunchHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get instanceId => text().references(McInstances, #id)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get exitCode => integer().nullable()();
  TextColumn get logFilePath => text().nullable()();
}

/// A mod/resource pack/shader pack/datapack installed into one instance's
/// content folder. Search results themselves are never cached here — only
/// what's actually been installed, so a re-launch or update check can tell
/// what's already present and where it came from.
class McInstalledMods extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get instanceId => text().references(McInstances, #id)();
  TextColumn get projectId => text().nullable()(); // Modrinth project id, null if added manually
  TextColumn get versionId => text().nullable()(); // Modrinth version id
  TextColumn get projectName => text().nullable()();
  TextColumn get projectIconUrl => text().nullable()();
  TextColumn get fileName => text()();
  TextColumn get sha1 => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get kind =>
      text().withDefault(const Constant('mod'))(); // mod|resourcepack|shaderpack|datapack
  DateTimeColumn get installedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [McAccounts, McInstances, McLaunchHistory, McInstalledMods])
class MinecraftLauncherDatabase extends _$MinecraftLauncherDatabase {
  MinecraftLauncherDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'luma_minecraft_launcher',
              native: DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(mcInstalledMods);
          }
        },
      );
}
