# Minecraft world conversion worker

Luma runs this separate GPL-3.0 worker locally. It uses unmodified
[je2be-core](https://github.com/kbinani/je2be-core) at
`8dfc4de1ba5c7f72e804abea8663380c0dbd5680`. No game assets are included.
The corresponding worker source is `tool/world_converter` in Luma's source
repository; CMake downloads all pinned engine dependencies from their original
source repositories. Preserve this file and the engine license when distributing
the worker. The worker code in this directory is also licensed under GPL-3.0.

Build with CMake 3.24+, a C++20 compiler and Git:

```
cmake -S tool/world_converter -B build/world_converter -DCMAKE_BUILD_TYPE=Release
cmake --build build/world_converter --config Release --target luma-world-converter --parallel 2
cmake --install build/world_converter --config Release --component WorldConverter --prefix <luma bundle>
```

The worker produces Java 1.21.10 or Bedrock 1.21.120. Newer sources are refused.
It is currently packaged for Windows and Linux. Mobile/web are explicitly
unsupported, rather than offering a conversion button which cannot work.

Commands: `scan <world folder>` and
`convert <source folder> <output folder> <java|bedrock> <entities 0|1> <players 0|1>`.
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
