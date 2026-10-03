enum WorldEdition {
  java('Java Edition'),
  bedrock('Bedrock Edition');

  const WorldEdition(this.label);
  final String label;
}

class WorldTarget {
  const WorldTarget(this.edition, this.version);
  final WorldEdition edition;
  final String version;

  static const supported = [
    WorldTarget(WorldEdition.java, '1.21.10'),
    WorldTarget(WorldEdition.bedrock, '1.21.120'),
  ];

  String get label => '${edition.label} $version';
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
    final name = type.replaceFirst('minecraft:', '');
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
      'leash_knot' => 'leash_knot',
      _ => name,
    };
  }
}

class WorldCensus {
  const WorldCensus({
    required this.edition,
    required this.entities,
    required this.localPlayer,
    required this.remotePlayers,
    required this.version,
  });
  final WorldEdition edition;
  final List<WorldEntityRecord> entities;
  final bool localPlayer;
  final int remotePlayers;
  final Object version;

  factory WorldCensus.fromJson(Map<String, dynamic> json) => WorldCensus(
    edition: WorldEdition.values.byName(json['edition'] as String),
    entities: (json['entities'] as List)
        .map((e) => WorldEntityRecord.fromJson(e as Map<String, dynamic>))
        .toList(),
    localPlayer: json['localPlayer'] as bool,
    remotePlayers: json['remotePlayers'] as int,
    version: json['version'] as Object,
  );
}

/// Check saved records, including multiplicity, rather than trusting an exit code.
void verifyWorldConversion(
  WorldCensus source,
  WorldCensus output,
  WorldConversionOptions options,
) {
  if (output.edition != options.target.edition ||
      (output.edition == WorldEdition.java && output.version != 4556) ||
      (output.edition == WorldEdition.bedrock &&
          output.version.toString() != '[1, 21, 120]')) {
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
  String bucket(WorldEntityRecord e, int x, int y, int z) =>
      '${e.canonicalType}:${e.dimension}:$x:$y:$z';
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
