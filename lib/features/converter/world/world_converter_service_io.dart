import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'world_conversion.dart';

typedef WorldWorker = Future<WorldCensus> Function(List<String> arguments);

class WorldConverterService {
  WorldConverterService({WorldWorker? worker}) : this._(worker);
  WorldConverterService._(this._worker);
  final WorldWorker? _worker;
  bool get supported => Platform.isWindows || Platform.isLinux;

  Future<WorldCensus> _run(List<String> arguments) async {
    if (_worker != null) return _worker(arguments);
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
    final result = await Process.run(executable.absolute.path, arguments);
    if (result.exitCode != 0) {
      throw FormatException(result.stderr.toString().trim());
    }
    final lines = const LineSplitter().convert(result.stdout.toString());
    final payload = lines.lastWhere(
      (line) => line.startsWith('{'),
      orElse: () => throw const FormatException('Missing saved-world audit.'),
    );
    return WorldCensus.fromJson(jsonDecode(payload) as Map<String, dynamic>);
  }

  Future<WorldCensus> inspect(String path) async {
    if (!await File('$path/level.dat').exists()) {
      throw const FormatException(
        'Select a world folder containing level.dat.',
      );
    }
    final snapshot = await Directory.systemTemp.createTemp(
      'luma-world-inspect-',
    );
    try {
      final copy = Directory('${snapshot.path}/world');
      await _copyTree(Directory(path), copy);
      return await _run(['scan', copy.path]);
    } finally {
      await snapshot.delete(recursive: true);
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
    final input = await Directory(source).resolveSymbolicLinks();
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
      onProgress?.call('Copying the source world…');
      await _copyTree(Directory(input), copy);
      onProgress?.call('Checking entities and players…');
      final before = await _run(['scan', copy.path]);
      if (before.edition == options.target.edition) {
        throw const FormatException('Choose the other Minecraft edition.');
      }
      if (options.players && before.remotePlayers != 0) {
        throw const FormatException(
          'Additional players need Java UUID / Bedrock XUID mappings. '
          'Player conversion currently supports single-player worlds.',
        );
      }
      final output = Directory('${staging.path}/converted');
      onProgress?.call('Converting terrain, containers and selected records…');
      final after = await _run([
        'convert',
        copy.path,
        output.path,
        options.target.edition.name,
        options.entities ? '1' : '0',
        options.players ? '1' : '0',
      ]);
      onProgress?.call('Verifying entities in the saved world…');
      await Isolate.run(() => verifyWorldConversion(before, after, options));
      final notes = <String>[];
      if (options.statistics) {
        await _statistics(copy, output, options.target.edition, notes);
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

  Future<void> _statistics(
    Directory source,
    Directory output,
    WorldEdition target,
    List<String> notes,
  ) async {
    final stats = Directory('${source.path}/stats');
    final archive = Directory('${source.path}/luma-java-statistics');
    final existing = await stats.exists() ? stats : archive;
    if (!await existing.exists()) {
      notes.add(
        'No Java world statistics were present. Bedrock account statistics are not stored in the world.',
      );
      return;
    }
    final saved = Directory(
      '${output.path}/${target == WorldEdition.java ? 'stats' : 'luma-java-statistics'}',
    );
    await _copyTree(existing, saved);
    notes.add(
      target == WorldEdition.java
          ? 'Java statistics restored from the archive.'
          : 'Java statistics archived for a later conversion back to Java. Bedrock cannot display them.',
    );
  }
}
