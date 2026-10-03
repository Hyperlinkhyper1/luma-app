import 'dart:io';

import 'package:luma/features/converter/world/world_versions.dart';

const chunkerCommit = '50aaf6d82e8b68929279161b790d95fdddfe0a40';

Future<void> command(
  String executable,
  List<String> arguments, {
  String? directory,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: directory,
    runInShell: executable.endsWith('.bat'),
  );
  await Future.wait([
    stdout.addStream(process.stdout),
    stderr.addStream(process.stderr),
  ]);
  final code = await process.exitCode;
  if (code != 0) {
    throw ProcessException(executable, arguments, 'Build failed', code);
  }
}

Future<void> main(List<String> args) async {
  final build = Directory(
    args.isEmpty ? 'build/world_converter' : args[0],
  ).absolute;
  final source = Directory(
    args.length > 1 ? args[1] : '${build.path}/chunker-src',
  ).absolute;
  final javaHome = Platform.environment['JAVA_HOME'];
  if (javaHome == null) {
    throw StateError('Set JAVA_HOME to a JDK 21 installation.');
  }
  if (!await Directory('${source.path}/.git').exists()) {
    await command('git', [
      'clone',
      '--no-checkout',
      'https://github.com/HiveGamesOSS/Chunker.git',
      source.path,
    ]);
    await command('git', [
      'checkout',
      '--detach',
      chunkerCommit,
    ], directory: source.path);
  }
  final revision = await Process.run('git', [
    'rev-parse',
    'HEAD',
  ], workingDirectory: source.path);
  if (revision.exitCode != 0 ||
      revision.stdout.toString().trim() != chunkerCommit) {
    throw StateError('Chunker checkout does not match the pinned version.');
  }
  final encoding =
      '${source.path}/cli/src/main/java/com/hivemc/chunker/conversion/encoding';
  final javaText = await File(
    '$encoding/java/JavaDataVersion.java',
  ).readAsString();
  final bedrockText = await File(
    '$encoding/bedrock/BedrockDataVersion.java',
  ).readAsString();
  final javaVersions = <String, int>{
    for (final m in RegExp(
      r'register\((\d+), new Version\((\d+), (\d+), (\d+)\)\)',
    ).allMatches(javaText))
      '${m[2]}.${m[3]}.${m[4]}': int.parse(m[1]!),
  };
  final bedrockVersions = [
    for (final m in RegExp(
      r'register\([^;]+new Version\((\d+), (\d+), (\d+)\)\)',
    ).allMatches(bedrockText))
      '${m[1]}.${m[2]}.${m[3]}',
  ];
  if (javaVersions.toString() != javaWorldVersions.toString() ||
      bedrockVersions.toString() != bedrockWorldVersions.toString()) {
    throw StateError(
      'Update world_versions.dart with the engine version registry.',
    );
  }
  await command(
    Platform.isWindows
        ? '${source.path}/gradlew.bat'
        : '${source.path}/gradlew',
    [':cli:shadowJar', '--no-daemon', '--console=plain'],
    directory: source.path,
  );
  final bundle = Directory(
    Platform.isWindows ? '${build.path}/Release' : build.path,
  );
  await bundle.create(recursive: true);
  await File(
    '${source.path}/cli/build/libs/chunker-cli-1.21.0.jar',
  ).copy('${bundle.path}/chunker.jar');
  await File(
    '${source.path}/LICENSE',
  ).copy('${bundle.path}/Chunker-LICENSE.txt');
  final runtime = Directory('${bundle.path}/java');
  if (!await runtime.exists()) {
    await command('$javaHome/bin/jlink${Platform.isWindows ? '.exe' : ''}', [
      '--add-modules',
      'java.base,java.desktop,java.logging,java.management,jdk.unsupported',
      '--strip-debug',
      '--no-header-files',
      '--no-man-pages',
      '--output',
      runtime.path,
    ]);
  }
  stdout.writeln(
    'Packaged ${javaVersions.length} Java and ${bedrockVersions.length} Bedrock release formats.',
  );
}
