import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';

import 'world_conversion.dart';

const _lenientUtf8 = Utf8Codec(allowMalformed: true);

typedef WorldWorker = Future<WorldCensus> Function(List<String> arguments);
typedef WorldVersionWorker =
    Future<void> Function(
      String source,
      String destination,
      WorldTarget target,
      bool preserveRecords,
    );

class WorldConverterService {
  WorldConverterService({
    WorldWorker? worker,
    WorldVersionWorker? versionWorker,
  }) : this._(worker, versionWorker);
  WorldConverterService._(this._worker, this._versionWorker);
  final WorldWorker? _worker;
  final WorldVersionWorker? _versionWorker;
  bool get supported => Platform.isWindows || Platform.isLinux;

  Future<File> _executable() async {
    if (!supported) {
      throw UnsupportedError('World conversion requires Windows or Linux.');
    }
    final suffix = Platform.isWindows ? '.exe' : '';
    final name = 'luma-world-converter$suffix';
    final bundled = File(
      '${File(Platform.resolvedExecutable).parent.path}/world_converter/$name',
    );
    final development = File('build/world_converter/Release/$name');
    final developmentLinux = File('build/world_converter/$name');
    final executable = await bundled.exists()
        ? bundled
        : await development.exists()
        ? development
        : developmentLinux;
    if (!await executable.exists()) {
      throw const FormatException(
        'The world conversion engine is missing from this build. '
        'Install a desktop build containing the world converter.',
      );
    }
    return executable.absolute;
  }

  Future<WorldCensus> _run(List<String> arguments) async {
    if (_worker != null) return _worker(arguments);
    final executable = await _executable();
    final result = await Process.run(
      executable.path,
      arguments,
      stdoutEncoding: _lenientUtf8,
      stderrEncoding: _lenientUtf8,
    );
    if (result.exitCode != 0) {
      final detail = result.stderr.toString().trim();
      throw FormatException(
        detail.isEmpty
            ? 'The world conversion engine stopped unexpectedly '
                  '(exit code ${result.exitCode}). The original world has not changed.'
            : detail,
      );
    }
    final lines = const LineSplitter().convert(result.stdout.toString());
    final payload = lines.lastWhere(
      (line) => line.startsWith('{'),
      orElse: () => throw const FormatException('Missing saved-world audit.'),
    );
    return WorldCensus.fromJson(jsonDecode(payload) as Map<String, dynamic>);
  }

  Future<void> _versionConvert(
    String source,
    String destination,
    WorldTarget target, {
    required bool preserveRecords,
  }) async {
    if (_versionWorker != null) {
      await _versionWorker(source, destination, target, preserveRecords);
      return;
    }
    final engine = await _executable();
    final root = engine.parent;
    final jar = File('${root.path}/chunker.jar');
    final suffix = Platform.isWindows ? '.exe' : '';
    final java = File('${root.path}/java/bin/java$suffix');
    if (!await jar.exists() || !await java.exists()) {
      throw const FormatException(
        'The Minecraft version engine is missing from this build. '
        'Install a desktop build containing both world conversion engines.',
      );
    }
    if (preserveRecords) {
      await _copyTree(Directory(source), Directory(destination));
    } else {
      await Directory(destination).create();
    }
    final result = await Process.run(
      java.path,
      [
        '-Xmx4G',
        '-Dfile.encoding=UTF-8',
        '-Dstdout.encoding=UTF-8',
        '-Dstderr.encoding=UTF-8',
        '-jar',
        jar.path,
        '-i',
        Directory(source).absolute.path,
        '-o',
        Directory(destination).absolute.path,
        '-f',
        target.format,
        if (preserveRecords) '-k',
      ],
      stdoutEncoding: _lenientUtf8,
      stderrEncoding: _lenientUtf8,
    );
    if (result.exitCode != 0 ||
        !result.stdout.toString().contains('Conversion complete!') ||
        !await File('$destination/level.dat').exists()) {
      var detail = result.stderr.toString().trim();
      if (detail.isEmpty) {
        final lines = const LineSplitter()
            .convert(result.stdout.toString())
            .where((line) => line.trim().isNotEmpty)
            .toList();
        detail = lines.skip(lines.length > 5 ? lines.length - 5 : 0).join('\n');
      }
      throw FormatException(
        'Version conversion failed: '
        '${detail.isEmpty ? 'exit code ${result.exitCode}' : detail}',
      );
    }
  }

  Future<WorldCensus> inspect(String path) async {
    path = normalizeWorldSourcePath(path);
    final snapshot = await Directory.systemTemp.createTemp(
      'luma-world-inspect-',
    );
    try {
      final copy = Directory('${snapshot.path}/world');
      await _snapshotSource(path, copy);
      final census = await _run(['scan', copy.path, 'normalize']);
      return census.withLevelName(await _bedrockLevelName(copy));
    } finally {
      await snapshot.delete(recursive: true);
    }
  }

  /// Bedrock world folders are random ids; the real name is in levelname.txt.
  Future<String?> _bedrockLevelName(Directory world) async {
    final file = File('${world.path}/levelname.txt');
    if (!await file.exists()) return null;
    try {
      final name = utf8
          .decode(await file.readAsBytes(), allowMalformed: true)
          .split('\n')
          .first
          .replaceFirst('\uFEFF', '')
          .trim();
      return name.isEmpty ? null : name;
    } on FileSystemException {
      return null;
    }
  }

  /// The first of `name`, `name (2)`, `name (3)`… that is free under [parent].
  Future<String> availableDestination(String parent, String name) async {
    final base = worldFolderName(name);
    for (var n = 1; ; n++) {
      final path = '$parent/${n == 1 ? base : '$base ($n)'}';
      if (await FileSystemEntity.type(path, followLinks: false) ==
          FileSystemEntityType.notFound) {
        return path;
      }
    }
  }

  Future<WorldConversionResult> convert({
    required String source,
    required String destination,
    required WorldConversionOptions options,
    void Function(String)? onProgress,
  }) async {
    if (!WorldTarget.supported.any(
      (t) =>
          t.edition == options.target.edition &&
          t.version == options.target.version,
    )) {
      throw const FormatException('Unsupported target version.');
    }
    source = normalizeWorldSourcePath(source);
    final input = await Directory(source).exists()
        ? await Directory(source).resolveSymbolicLinks()
        : await File(source).resolveSymbolicLinks();
    final parent = await Directory(destination).parent.resolveSymbolicLinks();
    final target = Directory(
      '$parent/${Directory(destination).uri.pathSegments.where((s) => s.isNotEmpty).last}',
    );
    final inputKey = Platform.isWindows ? input.toLowerCase() : input;
    final parentKey = Platform.isWindows ? parent.toLowerCase() : parent;
    if (parentKey == inputKey ||
        parentKey.startsWith('$inputKey${Platform.pathSeparator}')) {
      throw const FormatException(
        'Choose an output folder outside your source world.',
      );
    }
    if (await target.exists() || await File(target.path).exists()) {
      throw const FormatException(
        'The output path already exists. Choose a new name.',
      );
    }
    final staging = await Directory(parent).createTemp('.luma-world-');
    try {
      final copy = Directory('${staging.path}/source');
      onProgress?.call('Opening a temporary copy of the source world…');
      await _snapshotSource(input, copy);
      onProgress?.call('Checking entities and players…');
      final before = await _run(['scan', copy.path, 'normalize']);
      if (before.edition == options.target.edition) {
        throw const FormatException('Choose the other Minecraft edition.');
      }
      if (options.entities) verifyWorldEntityTarget(before, options.target);
      if (options.players && before.remotePlayers != 0) {
        throw const FormatException(
          'Additional players need Java UUID / Bedrock XUID mappings. '
          'Player conversion currently supports single-player worlds.',
        );
      }
      // Refuse before the terrain pass, which can take minutes on a large world.
      if (options.target.edition == WorldEdition.java &&
          (options.target.savedVersion as int) < 1519 &&
          ((options.entities && before.entities.isNotEmpty) ||
              (options.players && before.localPlayer))) {
        throw const FormatException(
          'Java targets before 1.13 cannot safely store entity/player '
          'records. Choose Java 1.13 or newer, or turn off Convert entities '
          'and Convert players. The original world has not changed.',
        );
      }
      if (options.target.edition == WorldEdition.bedrock) {
        final version = options.target.savedVersion as List<int>;
        final legacyRecords =
            version[1] < 18 || (version[1] == 18 && version[2] < 30);
        if (legacyRecords &&
            ((options.entities && before.entities.isNotEmpty) ||
                (options.players && before.localPlayer))) {
          throw const FormatException(
            'Bedrock targets before 1.18.30 require older entity/player '
            'storage that this converter cannot safely write. Choose a newer '
            'target or exclude those records. The original world has not changed.',
          );
        }
      }
      final output = Directory('${staging.path}/converted');
      onProgress?.call('Converting terrain, containers and selected records…');
      final usesJavaSchema =
          options.target.edition == WorldEdition.java &&
          (options.target.savedVersion as int) >= 1519 &&
          (options.target.savedVersion as int) <= 4556;
      final baseline = usesJavaSchema
          ? options.target
          : WorldTarget(
              options.target.edition,
              options.target.edition == WorldEdition.java
                  ? '1.21.10'
                  : '1.21.120',
            );
      final broadVersion =
          options.target.version !=
              (options.target.edition == WorldEdition.java
                  ? '1.21.10'
                  : '1.21.120') ||
          (before.edition == WorldEdition.java && before.version != 4556) ||
          (before.edition == WorldEdition.bedrock &&
              before.version.toString() != '[1, 21, 120]');
      // Terrain is converted directly from the original version, so newer blocks
      // never travel through the older entity engine's terrain representation.
      if (broadVersion) {
        onProgress?.call('Converting terrain to ${options.target.label}…');
        await _versionConvert(
          copy.path,
          output.path,
          options.target,
          preserveRecords: false,
        );
      }
      var recordsInput = copy;
      if (broadVersion &&
          (options.entities || options.players) &&
          before.edition == WorldEdition.java &&
          before.version != 4556) {
        recordsInput = Directory('${staging.path}/normalized');
        await _versionConvert(
          copy.path,
          recordsInput.path,
          const WorldTarget(WorldEdition.java, '1.21.10'),
          preserveRecords: true,
        );
        if (options.players && before.localPlayer) {
          await _run(['restore-player', copy.path, recordsInput.path]);
        }
      }
      final bridge = broadVersion
          ? Directory('${staging.path}/records')
          : output;
      // For terrain-only conversions the version engine is sufficient.
      WorldCensus after;
      if (broadVersion && !options.entities && !options.players) {
        after = await _run(['strip', output.path, '1', '1']);
      } else {
        final bridged = await _run([
          'convert',
          recordsInput.path,
          bridge.path,
          options.target.edition.name,
          options.entities ? '1' : '0',
          options.players ? '1' : '0',
          if (usesJavaSchema && options.target.version != '1.21.10')
            options.target.savedVersion.toString(),
        ]);
        if (broadVersion) {
          await Isolate.run(
            () => verifyWorldConversion(
              before,
              bridged,
              WorldConversionOptions(
                target: baseline,
                entities: options.entities,
                players: options.players,
                statistics: options.statistics,
              ),
            ),
          );
          var records = bridge;
          if (usesJavaSchema && options.target.version != '1.21.10') {
            await _run(['identity', bridge.path, baseline.version]);
          }
          if (options.target.version != baseline.version) {
            if (options.target.edition == WorldEdition.java &&
                (options.target.savedVersion as int) < 1519 &&
                ((options.entities && bridged.entities.isNotEmpty) ||
                    (options.players && bridged.localPlayer))) {
              throw const FormatException(
                'This older Java target cannot safely read the selected newer '
                'entity/player schemas. Choose a newer Java version or exclude '
                'those records. The original world has not changed.',
              );
            }
            records = Directory('${staging.path}/versioned-records');
            if (options.target.edition == WorldEdition.java) {
              await _run(['identity', bridge.path, baseline.version]);
            }
            onProgress?.call(
              'Adapting selected records to ${options.target.label}…',
            );
            await _versionConvert(
              bridge.path,
              records.path,
              options.target,
              preserveRecords: true,
            );
          }
          after = await _run([
            'overlay',
            records.path,
            output.path,
            options.entities ? '1' : '0',
            options.players ? '1' : '0',
          ]);
        } else {
          after = bridged;
        }
      }
      onProgress?.call('Verifying entities in the saved world…');
      await Isolate.run(() => verifyWorldConversion(before, after, options));
      final notes = <String>[...before.warnings];
      if (options.statistics) {
        await _statistics(copy, output, options.target, notes);
      }
      await File('${output.path}/luma-conversion-report.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'target': options.target.label,
          'entitiesRequested': options.entities,
          'sourceEntities': before.entities.length,
          'savedEntities': after.entities.length,
          'entitiesVerified': options.entities,
          'playersRequested': options.players,
          'statisticsRequested': options.statistics,
          'notes': notes,
        }),
      );
      await _publish(output, target);
      return WorldConversionResult(target.path, after.entities.length, notes);
    } finally {
      // Only delete the task-owned staging directory inside the chosen parent.
      final resolved = await staging.resolveSymbolicLinks();
      if (Directory(resolved).parent.path == parent &&
          Directory(resolved).uri.pathSegments
              .where((s) => s.isNotEmpty)
              .last
              .startsWith('.luma-world-')) {
        await staging.delete(recursive: true);
      }
    }
  }

  Future<void> _publish(Directory output, Directory target) async {
    for (var attempt = 0; ; attempt++) {
      if (await FileSystemEntity.type(target.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw const FormatException(
          'The output path already exists. Choose a new name.',
        );
      }
      try {
        await output.rename(target.path);
        return;
      } on FileSystemException catch (e) {
        final code = e.osError?.errorCode;
        if (!Platform.isWindows || (code != 5 && code != 32) || attempt == 4) {
          rethrow;
        }
        // Windows file scanners can briefly retain handles after the worker exits.
        await Future<void>.delayed(Duration(milliseconds: 100 << attempt));
      }
    }
  }

  Future<void> _copyTree(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entry in source.list(followLinks: false)) {
      final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (entry is Link) {
        throw const FormatException('Linked world files are not supported.');
      }
      if (entry is Directory) {
        await _copyTree(entry, Directory('${target.path}/$name'));
      } else if (entry is File && name != 'session.lock') {
        await entry.copy('${target.path}/$name');
      }
    }
  }

  Future<void> _snapshotSource(String path, Directory target) async {
    if (await Directory(path).exists()) {
      await _copyTree(Directory(path), target);
    } else if (await File(path).exists() &&
        RegExp(r'\.(mcworld|zip)$', caseSensitive: false).hasMatch(path)) {
      await Isolate.run(() => _extractWorldArchive(path, target.path));
    } else {
      throw const FormatException(
        'Choose a world folder or an exported .mcworld / .zip file.',
      );
    }
    if (!await File('${target.path}/level.dat').exists()) {
      throw const FormatException('The selected world is missing level.dat.');
    }
  }

  Future<void> _statistics(
    Directory source,
    Directory output,
    WorldTarget target,
    List<String> notes,
  ) async {
    final modernStats = Directory('${source.path}/players/stats');
    final stats = await modernStats.exists()
        ? modernStats
        : Directory('${source.path}/stats');
    final archive = Directory('${source.path}/luma-java-statistics');
    final existing = await stats.exists() ? stats : archive;
    if (!await existing.exists()) {
      notes.add(
        'No Java world statistics were present. Bedrock account statistics are not stored in the world.',
      );
      return;
    }
    final saved = Directory(
      '${output.path}/${target.edition == WorldEdition.java ? ((target.savedVersion as int) >= 4786 ? 'players/stats' : 'stats') : 'luma-java-statistics'}',
    );
    await _copyTree(existing, saved);
    notes.add(
      target.edition == WorldEdition.java
          ? 'Java statistics restored from the archive.'
          : 'Java statistics archived for a later conversion back to Java. Bedrock cannot display them.',
    );
  }
}

void _extractWorldArchive(String path, String destination) {
  final input = InputFileStream(path);
  try {
    final decoder = ZipDecoder();
    final archive = decoder.decodeStream(input);
    String safeName(String name) {
      final normalized = name.replaceAll('\\', '/');
      final parts = normalized
          .split('/')
          .where((p) => p.isNotEmpty && p != '.')
          .toList();
      if (normalized.startsWith('/') ||
          parts.isEmpty ||
          parts.any(
            (p) =>
                p == '..' ||
                p.contains(':') ||
                p.contains('\u0000') ||
                p.endsWith('.') ||
                p.endsWith(' '),
          )) {
        throw const FormatException(
          'The world archive contains an unsafe file path.',
        );
      }
      return parts.join('/');
    }

    final names = <String>{};
    for (final header in decoder.directory.fileHeaders) {
      final name = safeName(header.filename);
      if (!names.add(Platform.isWindows ? name.toLowerCase() : name)) {
        throw const FormatException(
          'The world archive contains duplicate file paths.',
        );
      }
    }
    for (final entry in archive) {
      if (entry.isSymbolicLink) {
        throw const FormatException(
          'Linked files in world archives are not supported.',
        );
      }
    }
    final levels = archive
        .where(
          (e) => e.isFile && safeName(e.name).split('/').last == 'level.dat',
        )
        .toList();
    if (levels.length != 1) {
      throw const FormatException(
        'The archive must contain exactly one world with level.dat.',
      );
    }
    final level = safeName(levels.single.name);
    final prefix = level.substring(0, level.length - 'level.dat'.length);
    for (final entry in archive) {
      final name = safeName(entry.name);
      if (!name.startsWith(prefix) || !entry.isFile) continue;
      final relative = name.substring(prefix.length);
      if (relative == 'session.lock') continue;
      final file = File('$destination/$relative');
      file.parent.createSync(recursive: true);
      final output = OutputFileStream(file.path);
      try {
        entry.writeContent(output);
      } finally {
        output.closeSync();
      }
      if (file.lengthSync() != entry.size) {
        throw FormatException(
          'The world archive contains a truncated file: $relative',
        );
      }
      final content = InputFileStream(file.path);
      var crc = 0;
      try {
        while (!content.isEOS) {
          crc = getCrc32(content.readBytes(65536).toUint8List(), crc);
        }
      } finally {
        content.closeSync();
      }
      if (crc != entry.crc32) {
        throw FormatException(
          'The world archive contains a damaged file: $relative',
        );
      }
    }
  } finally {
    input.closeSync();
  }
}
