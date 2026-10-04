import 'world_versions.dart';

enum WorldEdition {
  java('Java Edition'),
  bedrock('Bedrock Edition');

  const WorldEdition(this.label);
  final String label;
}

String normalizeWorldSourcePath(String path) {
  final trimmed = path.trim();
  if (trimmed.length >= 2 &&
      ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
          (trimmed.startsWith("'") && trimmed.endsWith("'")))) {
    return trimmed.substring(1, trimmed.length - 1);
  }
  return trimmed;
}

String worldSourceName(String path) => normalizeWorldSourcePath(path)
    .replaceAll('\\', '/')
    .split('/')
    .where((part) => part.isNotEmpty)
    .last
    .replaceFirst(RegExp(r'\.(mcworld|zip)$', caseSensitive: false), '');

/// A world name made safe to use as a folder name on Windows and Linux.
String worldFolderName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .replaceAll(RegExp(r'[. ]+$'), '')
      .trim();
  final reserved = RegExp(
    r'^(con|prn|aux|nul|com[0-9]|lpt[0-9])(\..*)?$',
    caseSensitive: false,
  );
  if (cleaned.isEmpty) return 'world';
  return reserved.hasMatch(cleaned) ? '_$cleaned' : cleaned;
}

class WorldTarget {
  const WorldTarget(this.edition, this.version);
  final WorldEdition edition;
  final String version;

  static final supported = List<WorldTarget>.unmodifiable([
    for (final version in javaWorldVersions.keys.toList().reversed)
      WorldTarget(WorldEdition.java, version),
    for (final version in bedrockWorldVersions.reversed)
      WorldTarget(WorldEdition.bedrock, version),
  ]);

  static WorldTarget latest(WorldEdition edition) =>
      supported.firstWhere((t) => t.edition == edition);

  Object get savedVersion => edition == WorldEdition.java
      ? javaWorldVersions[version] ?? -1
      : version.split('.').map(int.parse).toList();

  String get format =>
      '${edition.name.toUpperCase()}_${version.replaceAll('.', '_')}';

  String get displayVersion =>
      edition == WorldEdition.java && version.endsWith('.0')
      ? version.substring(0, version.length - 2)
      : version;
  String get label => '${edition.label} $displayVersion';
}

class WorldConversionOptions {
  const WorldConversionOptions({
    required this.target,
    this.entities = true,
    this.players = true,
    this.statistics = true,
  });
  final WorldTarget target;
  final bool entities;
  final bool players;
  final bool statistics;
}

class WorldEntityRecord {
  const WorldEntityRecord(this.type, this.dimension, this.position);
  final String type;
  final int dimension;
  final List<double> position;

  factory WorldEntityRecord.fromJson(Map<String, dynamic> json) {
    final position = (json['position'] as List)
        .map((n) => (n as num).toDouble())
        .toList();
    if (position.length != 3 || position.any((n) => !n.isFinite)) {
      throw const FormatException('Invalid entity position in world audit.');
    }
    return WorldEntityRecord(
      json['type'] as String,
      json['dimension'] as int,
      position,
    );
  }

  String get canonicalType {
    final name = type
        .replaceFirst('minecraft:', '')
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]}_${m[2]}',
        )
        .toLowerCase();
    if (name.endsWith('_chest_boat') ||
        name == 'chest_boat' ||
        name == 'bamboo_chest_raft') {
      return 'chest_boat';
    }
    if (name.endsWith('_boat') || name == 'boat' || name == 'bamboo_raft') {
      return 'boat';
    }
    return switch (name) {
      'villager_v2' => 'villager',
      'zombie_villager_v2' => 'zombie_villager',
      'evocation_illager' => 'evoker',
      'vindication_illager' => 'vindicator',
      'snowgolem' => 'snow_golem',
      'xp_orb' => 'experience_orb',
      'xp_bottle' => 'experience_bottle',
      'tropicalfish' => 'tropical_fish',
      'zombie_pigman' => 'zombified_piglin',
      'thrown_trident' => 'trident',
      'pig_zombie' => 'zombified_piglin',
      'lava_slime' => 'magma_cube',
      'mushroom_cow' => 'mooshroom',
      'ozelot' => 'ocelot',
      'villager_golem' => 'iron_golem',
      'snow_man' => 'snow_golem',
      'entity_horse' => 'horse',
      'leash_knot' => 'leash_knot',
      _ => name,
    };
  }

  /// The kind used to pair source and saved records. A Bedrock llama that
  /// arrived with a wandering trader is saved by Java as a trader llama.
  String get matchType => switch (canonicalType) {
    'trader_llama' => 'llama',
    final kind => kind,
  };
}

class WorldCensus {
  const WorldCensus({
    required this.edition,
    required this.entities,
    required this.localPlayer,
    required this.remotePlayers,
    required this.version,
    this.warnings = const [],
    this.levelName,
  });
  final WorldEdition edition;
  final List<WorldEntityRecord> entities;
  final bool localPlayer;
  final int remotePlayers;
  final Object version;
  final List<String> warnings;

  /// The in-game name, when the save records one apart from its folder name.
  final String? levelName;

  WorldCensus withLevelName(String? name) => WorldCensus(
    edition: edition,
    entities: entities,
    localPlayer: localPlayer,
    remotePlayers: remotePlayers,
    version: version,
    warnings: warnings,
    levelName: name,
  );

  factory WorldCensus.fromJson(Map<String, dynamic> json) => WorldCensus(
    edition: WorldEdition.values.byName(json['edition'] as String),
    entities: (json['entities'] as List)
        .map((e) => WorldEntityRecord.fromJson(e as Map<String, dynamic>))
        .toList(),
    localPlayer: json['localPlayer'] as bool,
    remotePlayers: json['remotePlayers'] as int,
    version: json['version'] as Object,
    warnings: (json['warnings'] as List?)?.cast<String>() ?? const [],
  );
}

/// Reject entities absent from the destination's release schema.
void verifyWorldEntityTarget(WorldCensus source, WorldTarget target) {
  final targetParts = target.version.split('.').map(int.parse).toList();
  for (final entity in source.entities) {
    final type = entity.canonicalType.replaceFirst('@hive', '');
    final minimum = target.edition == WorldEdition.java
        ? switch (type) {
            'cat' ||
            'fox' ||
            'panda' ||
            'pillager' ||
            'ravager' ||
            'trader_llama' ||
            'wandering_trader' => '1.14.0',
            'bee' => '1.15.0',
            'hoglin' || 'piglin' || 'zoglin' || 'strider' => '1.16.0',
            'piglin_brute' => '1.16.2',
            'axolotl' ||
            'goat' ||
            'glow_squid' ||
            'glow_item_frame' ||
            'marker' => '1.17.0',
            'allay' ||
            'frog' ||
            'tadpole' ||
            'warden' ||
            'chest_boat' => '1.19.0',
            'interaction' ||
            'item_display' ||
            'block_display' ||
            'text_display' => '1.19.4',
            'camel' || 'sniffer' => '1.20.0',
            'armadillo' => '1.20.5',
            'breeze' ||
            'bogged' ||
            'wind_charge' ||
            'breeze_wind_charge' ||
            'ominous_item_spawner' => '1.21.0',
            'creaking' => '1.21.2',
            'happy_ghast' => '1.21.6',
            'copper_golem' || 'mannequin' => '1.21.9',
            'camel_husk' ||
            'nautilus' ||
            'zombie_nautilus' ||
            'parched' => '1.21.11',
            'sulfur_cube' => '26.2.0',
            'cushion' => '26.3.0',
            _ => null,
          }
        : switch (type) {
            'allay' ||
            'frog' ||
            'tadpole' ||
            'warden' ||
            'chest_boat' => '1.19.0',
            'trader_llama' => '1.19.10',
            'camel' || 'sniffer' => '1.20.0',
            'armadillo' => '1.20.80',
            'breeze' ||
            'bogged' ||
            'wind_charge_projectile' ||
            'breeze_wind_charge_projectile' ||
            'ominous_item_spawner' => '1.21.0',
            'creaking' => '1.21.50',
            'happy_ghast' => '1.21.80',
            'copper_golem' => '1.21.100',
            'camel_husk' ||
            'nautilus' ||
            'zombie_nautilus' ||
            'parched' => '1.21.130',
            'sulfur_cube' => '1.26.20',
            'cushion' => '1.26.40',
            'frostbite' => '1.26.60',
            _ => null,
          };
    if (minimum == null) continue;
    final parts = minimum.split('.').map(int.parse).toList();
    for (var i = 0; i < 3; i++) {
      if (targetParts[i] > parts[i]) break;
      if (targetParts[i] < parts[i]) {
        throw FormatException(
          '${target.label} cannot represent ${entity.type}. '
          'Choose $minimum or newer, or exclude entities.',
        );
      }
    }
  }
}

/// Check saved records, including multiplicity, rather than trusting an exit code.
void verifyWorldConversion(
  WorldCensus source,
  WorldCensus output,
  WorldConversionOptions options,
) {
  if (output.edition != options.target.edition ||
      output.version.toString() != options.target.savedVersion.toString()) {
    throw const FormatException(
      'The saved world has the wrong target version.',
    );
  }
  if (options.players && source.remotePlayers != 0) {
    throw const FormatException(
      'Additional players need Java UUID / Bedrock XUID mappings. '
      'Player conversion currently supports single-player worlds.',
    );
  }
  if (options.players && source.localPlayer && !output.localPlayer) {
    throw const FormatException('The local player was not transferred.');
  }
  if (!options.players && (output.localPlayer || output.remotePlayers != 0)) {
    throw const FormatException(
      'Excluded player records remain in the output.',
    );
  }
  if (!options.entities) {
    if (output.entities.isNotEmpty) {
      throw const FormatException('Excluded entities remain in the output.');
    }
    return;
  }
  verifyWorldEntityTarget(output, options.target);
  String bucket(WorldEntityRecord e, int x, int y, int z) =>
      '${e.matchType}:${e.dimension}:$x:$y:$z';
  final remaining = <String, List<WorldEntityRecord>>{};
  for (final entity in output.entities) {
    final key = bucket(
      entity,
      entity.position[0].floor(),
      entity.position[1].floor(),
      entity.position[2].floor(),
    );
    remaining.putIfAbsent(key, () => []).add(entity);
  }
  final missing = <String, int>{};
  for (final entity in source.entities) {
    List<WorldEntityRecord>? matchedBucket;
    var matchedIndex = -1;
    var nearest = 2.25;
    // Hanging entities and riding positions have edition-specific offsets.
    for (var x = -2; x <= 2; x++) {
      for (var y = -2; y <= 2; y++) {
        for (var z = -2; z <= 2; z++) {
          final candidates =
              remaining[bucket(
                entity,
                entity.position[0].floor() + x,
                entity.position[1].floor() + y,
                entity.position[2].floor() + z,
              )];
          if (candidates == null) continue;
          for (var index = 0; index < candidates.length; index++) {
            final candidate = candidates[index];
            var distanceSquared = 0.0;
            for (var axis = 0; axis < 3; axis++) {
              final delta = candidate.position[axis] - entity.position[axis];
              distanceSquared += delta * delta;
            }
            if (distanceSquared <= nearest) {
              nearest = distanceSquared;
              matchedBucket = candidates;
              matchedIndex = index;
            }
          }
        }
      }
    }
    if (matchedBucket == null) {
      missing.update(entity.type, (n) => n + 1, ifAbsent: () => 1);
    } else {
      matchedBucket.removeAt(matchedIndex);
    }
  }
  if (missing.isNotEmpty) {
    final detail = missing.entries
        .map((e) => '${e.value} × ${e.key}')
        .join(', ');
    throw FormatException(
      'Entity transfer failed verification: $detail. '
      'The converted world was not saved. Your source is unchanged.',
    );
  }
}

class WorldConversionResult {
  const WorldConversionResult(this.path, this.entityCount, this.notes);
  final String path;
  final int entityCount;
  final List<String> notes;
}
