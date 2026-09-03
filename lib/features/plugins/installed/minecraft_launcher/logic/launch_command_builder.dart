import 'dart:io';

import '../data/minecraft_launcher_database.dart';
import 'library_resolver.dart';
import 'mc_paths.dart';
import 'piston_meta_client.dart';
import 'rules_evaluator.dart';

/// Everything [buildLaunchCommand] needs beyond the version/instance rows
/// themselves — the resolved on-disk paths for this specific launch.
class LaunchContext {
  LaunchContext({
    required this.javaPath,
    required this.instanceDir,
    required this.nativesDir,
    required this.assetsRoot,
    required this.librariesDir,
    required this.clientJarPath,
    required this.libraries,
    required this.accountUsername,
    required this.accountUuid,
    required this.accountAccessToken,
    required this.accountIsMicrosoft,
  });

  final String javaPath;
  final Directory instanceDir;
  final Directory nativesDir;
  final Directory assetsRoot;
  final Directory librariesDir;
  final String clientJarPath;
  final List<ResolvedLibrary> libraries;
  final String accountUsername;
  final String accountUuid;
  final String accountAccessToken;
  final bool accountIsMicrosoft;
}

/// Builds the full `javaw.exe <jvm args> <mainClass> <game args>` argv for
/// launching [detail] as [instance], substituting the `${...}` placeholder
/// tokens Mojang's version JSON uses (both the modern structured
/// `arguments.jvm`/`arguments.game` format and the pre-1.13 flat
/// `minecraftArguments` string).
List<String> buildLaunchCommand(
  VersionDetail detail,
  McInstance instance,
  LaunchContext ctx,
) {
  final classpath = [
    for (final lib in ctx.libraries.where((l) => !l.isNative))
      '${ctx.librariesDir.path}${Platform.pathSeparator}${lib.mavenPath.replaceAll('/', Platform.pathSeparator)}',
    ctx.clientJarPath,
  ].join(';'); // ';' is the Windows classpath separator

  final tokens = <String, String>{
    'auth_player_name': ctx.accountUsername,
    'version_name': detail.id,
    'game_directory': ctx.instanceDir.path,
    'assets_root': ctx.assetsRoot.path,
    'game_assets': ctx.assetsRoot.path, // pre-1.7.10 alias
    'assets_index_name': detail.assetIndexId,
    'auth_uuid': ctx.accountUuid,
    'auth_access_token': ctx.accountAccessToken,
    'auth_session': ctx.accountAccessToken, // legacy alias
    'clientid': '',
    'auth_xuid': '',
    'user_type': ctx.accountIsMicrosoft ? 'msa' : 'legacy',
    'user_properties': '{}',
    'version_type': 'luma',
    'natives_directory': ctx.nativesDir.path,
    'launcher_name': 'luma',
    'launcher_version': '1.0.0',
    'classpath': classpath,
    'classpath_separator': ';',
    'library_directory': ctx.librariesDir.path,
    'resolution_width': '${instance.resolutionWidth}',
    'resolution_height': '${instance.resolutionHeight}',
  };

  String substitute(String value) {
    var result = value;
    for (final entry in tokens.entries) {
      result = result.replaceAll('\${${entry.key}}', entry.value);
    }
    return result;
  }

  final memoryArgs = [
    '-Xms${instance.minMemoryMb}M',
    '-Xmx${instance.maxMemoryMb}M',
  ];
  final extraJvmArgs = (instance.jvmArgs ?? '')
      .split(RegExp(r'\s+'))
      .where((a) => a.isNotEmpty)
      .toList();

  final jvmArgs = <String>[];
  final gameArgs = <String>[];

  if (detail.jvmArguments.isNotEmpty || detail.gameArguments.isNotEmpty) {
    jvmArgs.addAll(_resolveArgumentList(detail.jvmArguments, substitute));
    if (!jvmArgs.any((a) => a.startsWith('-cp'))) {
      jvmArgs.addAll(['-cp', classpath]);
    }
    gameArgs.addAll(_resolveArgumentList(detail.gameArguments, substitute));
  } else {
    // Legacy (pre-1.13): no structured `arguments` object — build the
    // classic JVM args by hand and split the flat `minecraftArguments`.
    jvmArgs.addAll([
      '-Djava.library.path=${ctx.nativesDir.path}',
      '-cp',
      classpath,
    ]);
    final legacy = detail.legacyMinecraftArguments ?? '';
    gameArgs.addAll(
      legacy.split(' ').where((a) => a.isNotEmpty).map(substitute),
    );
  }

  if (instance.fullscreen) {
    gameArgs.add('--fullscreen');
  } else if (!gameArgs.contains('--width')) {
    gameArgs.addAll(['--width', '${instance.resolutionWidth}', '--height', '${instance.resolutionHeight}']);
  }

  return [
    ...memoryArgs,
    ...extraJvmArgs,
    ...jvmArgs,
    detail.mainClass,
    ...gameArgs,
  ];
}

/// Resolves a raw `arguments.jvm`/`arguments.game` list: each entry is either
/// a plain string token, or a `{rules, value}` object whose `value` (a string
/// or list of strings) is included only if its rules pass.
List<String> _resolveArgumentList(
  List<dynamic> raw,
  String Function(String) substitute,
) {
  final result = <String>[];
  for (final entry in raw) {
    if (entry is String) {
      result.add(substitute(entry));
      continue;
    }
    if (entry is Map<String, dynamic>) {
      final rules = (entry['rules'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      if (!evaluateRules(rules)) continue;
      final value = entry['value'];
      if (value is String) {
        result.add(substitute(value));
      } else if (value is List) {
        result.addAll(value.map((v) => substitute(v as String)));
      }
    }
  }
  return result;
}

/// Resolves the client jar path for a version, matching where
/// [PistonMetaClient]/the download step places it.
Future<String> clientJarPathFor(String versionId) async {
  final dir = await McPaths.versionDir(versionId);
  return '${dir.path}${Platform.pathSeparator}$versionId.jar';
}
