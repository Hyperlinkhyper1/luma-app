# Minecraft world conversion worker

Luma runs this separate GPL-3.0 worker locally. It uses
[je2be-core](https://github.com/kbinani/je2be-core) at
`8dfc4de1ba5c7f72e804abea8663380c0dbd5680`, with the reproducible
`enable_java_versions.cmake` patch exposing its existing Java schema encoders
and retrying transient entity-database I/O failures. The terrain/version engine
is MIT-licensed [Chunker](https://github.com/HiveGamesOSS/Chunker) at
`50aaf6d82e8b68929279161b790d95fdddfe0a40`. No game assets are included.
The corresponding worker source is `tool/world_converter` in Luma's source
repository; CMake downloads all pinned engine dependencies from their original
source repositories. Preserve this file and the engine license when distributing
the worker. The worker code in this directory is also licensed under GPL-3.0.

Build with CMake 3.24+, a C++20 compiler, Git, Dart and a JDK 21 (`JAVA_HOME`):

```
cmake -S tool/world_converter -B build/world_converter -DCMAKE_BUILD_TYPE=Release
cmake --build build/world_converter --config Release --target luma-world-converter --parallel 2
dart run tool/world_converter/build_version_engine.dart build/world_converter
dart run tool/world_converter/verify_round_trip.dart <worker executable> --versions
cmake --install build/world_converter --config Release --component WorldConverter --prefix <luma bundle>
```

The service supports 66 Java release schemas (1.8.8 through 26.3) and 58
Bedrock release schemas (1.12 through 1.26.60), with newest targets first.
The generated `world_versions.dart` catalog is checked against the pinned
engine's actual registry during packaging. A small Java runtime is bundled;
the user does not need to install Java. `--matrix` checks every catalog entry
as a source and target, using generated terrain fixtures. These fixtures are
format/record checks, not a Minecraft in-game test.
It is currently packaged for Windows and Linux. Mobile/web are explicitly
unsupported, rather than offering a conversion button which cannot work.

Terrain goes directly from the original format to the chosen format. Entity
records take a separate verified path and are overlaid without replacing
terrain, so a newer block never has to pass through the entity engine's older
block table. Entity-region version markers allow Minecraft to upgrade native
entity schemas independently of the newer terrain format. Java 26.1's
namespaced vanilla dimensions, separate player file, single-player UUID and
players/stats paths are supported. Custom dimensions,
versions beyond the pinned registry, pre-Anvil regions and modded entities are
refused. The catalog covers release formats, not every historical snapshot.
Targets older than Java 1.13 or Bedrock 1.18.30 currently require excluding
entities and players;
selected records which the destination cannot represent cause an error, never
a published world with missing mobs. Downgrades can replace unavailable blocks
according to the terrain engine's mappings.

Commands: `scan <world folder>` and
`convert <source folder> <output folder> <java|bedrock> <entities 0|1> <players 0|1> [Java DataVersion]`.
Internal commands also strip excluded records, preserve player identity and
overlay version-adapted records. Their inputs must be disposable staging copies.
The source passed to `convert` MUST be a disposable copy: unchecked options remove
records from that copy before invoking the engine. Output is a JSON census. Luma
matches every source entity to a saved output entity by kind, dimension and
position, including passengers, hive occupants, legacy entity storage and modern actor indexes.
Missing/corrupt records are errors. Counts alone do not establish success.
Generic records without a registered target-edition entity schema are also
refused, even if their NBT can be written. Custom/modded entities are unsupported.

Only the local player can be moved without an explicit UUID/XUID account mapping.
Additional player records cause an error when player conversion is selected.
Java statistics are archived alongside a Bedrock result, and restored when that
result is converted back to Java; Bedrock account statistics are not world files.
The local player's original Java UUID is retained in the Bedrock result for the
return trip, so restored statistics and pet ownership keep the same identity.
