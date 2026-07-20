import 'dart:io';

import 'package:archive/archive_io.dart';

import 'library_resolver.dart';
import 'mc_paths.dart';
import 'safe_path.dart';

/// Unzips each native-classifier library (LWJGL natives etc.) into the
/// instance's `natives/` folder right before launch, skipping any entry path
/// that starts with one of the library's `extract.exclude` prefixes (almost
/// always `META-INF/`, to avoid clobbering signature files across jars).
///
/// The folder is wiped and recreated on every launch since native jars can
/// change between launches (e.g. after switching Minecraft/loader version).
class NativeLibraryExtractor {
  const NativeLibraryExtractor._();

  static Future<Directory> extractAll(
    String instanceId,
    List<ResolvedLibrary> libraries,
  ) async {
    final nativesDir = await McPaths.instanceSubDir(instanceId, 'natives');
    if (await nativesDir.exists()) {
      await nativesDir.delete(recursive: true);
    }
    await nativesDir.create(recursive: true);

    final librariesDir = await McPaths.libraries();

    for (final lib in libraries.where((l) => l.isNative)) {
      final jarPath = '${librariesDir.path}${Platform.pathSeparator}'
          '${lib.mavenPath.replaceAll('/', Platform.pathSeparator)}';
      final jarFile = File(jarPath);
      if (!await jarFile.exists()) continue;

      final archive = ZipDecoder().decodeBytes(await jarFile.readAsBytes());
      for (final entry in archive) {
        if (!entry.isFile) continue;
        if (lib.extractExclude.any((prefix) => entry.name.startsWith(prefix))) {
          continue;
        }
        final resolved = safeJoin(nativesDir.path, entry.name);
        if (resolved == null) continue; // refuse to write outside natives/
        final outFile = File(resolved);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(entry.content as List<int>);
      }
    }

    return nativesDir;
  }
}
