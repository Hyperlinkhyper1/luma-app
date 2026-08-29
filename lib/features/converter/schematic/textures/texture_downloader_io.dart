import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'texture_pack_types.dart';

/// Fetches the vanilla client jar from Mojang's public CDN so the preview has
/// real block textures on a machine with no Minecraft installed.
///
/// luma still ships no Mojang assets: nothing is bundled or committed, the
/// bytes come from Mojang's own servers to the user's own disk, and only when
/// the user asks for them. This is the same public, unauthenticated endpoint
/// every third-party launcher uses, and the same one luma's Minecraft launcher
/// plugin already talks to.

const String _manifestUrl =
    'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json';

/// Where a downloaded jar is kept.
///
/// Deliberately the same `<app support>/minecraft/versions/<id>/<id>.jar`
/// layout the Minecraft launcher plugin uses, for two reasons: a version the
/// launcher already downloaded is reused instead of fetched twice, and the
/// `minecraft` directory is one `StorageGuard` excludes from the plan's
/// storage cap and from sync, which a few tens of megabytes of game files have
/// no business counting against.
Future<File> _jarFileFor(String versionId) async {
  if (versionId.isEmpty ||
      versionId.contains('/') ||
      versionId.contains(r'\') ||
      versionId.contains(':') ||
      versionId == '.' ||
      versionId == '..') {
    throw TextureDownloadException('Mojang returned an unusable version id.');
  }
  final support = await getApplicationSupportDirectory();
  final sep = Platform.pathSeparator;
  final dir = Directory(
    '${support.path}${sep}minecraft${sep}versions$sep$versionId',
  );
  if (!await dir.exists()) await dir.create(recursive: true);
  return File('${dir.path}$sep$versionId.jar');
}

Future<Map<String, dynamic>> _getJson(String url) async {
  final http.Response response;
  try {
    response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
  } catch (_) {
    throw TextureDownloadException(
      'Could not reach Mojang. Check your connection and try again.',
    );
  }
  if (response.statusCode != 200) {
    throw TextureDownloadException(
      'Mojang returned ${response.statusCode} for the version manifest.',
    );
  }
  return jsonDecode(response.body) as Map<String, dynamic>;
}

/// Downloads the latest release's client jar, or returns the path to one
/// already on disk, and reports progress along the way.
///
/// The returned path is a client jar that [readAndBuildAtlas] can read.
Future<String> downloadVanillaTextures({
  void Function(TextureDownloadProgress)? onProgress,
}) async {
  void report(String stage, [int received = 0, int total = 0]) =>
      onProgress?.call(TextureDownloadProgress(
        stage: stage,
        received: received,
        total: total,
      ));

  report('Asking Mojang which version is current…');
  final manifest = await _getJson(_manifestUrl);
  final latest = (manifest['latest'] as Map<String, dynamic>?)?['release'];
  if (latest is! String || latest.isEmpty) {
    throw TextureDownloadException(
      'Mojang\'s version manifest did not name a current release.',
    );
  }

  final versions = manifest['versions'];
  if (versions is! List) {
    throw TextureDownloadException('Mojang\'s version manifest was malformed.');
  }
  final entry = versions.cast<Map<String, dynamic>>().firstWhere(
        (v) => v['id'] == latest,
        orElse: () => throw TextureDownloadException(
          'Mojang\'s manifest has no entry for $latest.',
        ),
      );

  final target = await _jarFileFor(latest);

  final detail = await _getJson(entry['url'] as String);
  final client = (detail['downloads'] as Map<String, dynamic>?)?['client'];
  if (client is! Map<String, dynamic>) {
    throw TextureDownloadException('Version $latest has no client download.');
  }
  final url = client['url'] as String?;
  final expectedSha1 = client['sha1'] as String? ?? '';
  final expectedSize = (client['size'] as num?)?.toInt() ?? 0;
  if (url == null) {
    throw TextureDownloadException('Version $latest has no client download.');
  }

  // A jar the launcher plugin (or an earlier run of this) already fetched is
  // the same file; re-downloading tens of megabytes to arrive at it again
  // would be rude.
  if (await target.exists() &&
      (expectedSize == 0 || await target.length() == expectedSize)) {
    report('Using the copy already downloaded.');
    return target.path;
  }

  report('Downloading Minecraft $latest…', 0, expectedSize);

  final request = http.Request('GET', Uri.parse(url));
  final http.StreamedResponse response;
  try {
    response = await http.Client()
        .send(request)
        .timeout(const Duration(seconds: 30));
  } catch (_) {
    throw TextureDownloadException(
      'Could not download the textures. Check your connection and try again.',
    );
  }
  if (response.statusCode != 200) {
    throw TextureDownloadException(
      'Mojang returned ${response.statusCode} for the client download.',
    );
  }

  final total =
      response.contentLength ?? (expectedSize > 0 ? expectedSize : 0);
  final builder = BytesBuilder(copy: true);
  var received = 0;
  await for (final chunk in response.stream) {
    builder.add(chunk);
    received += chunk.length;
    report('Downloading Minecraft $latest…', received, total);
  }
  final bytes = builder.takeBytes();

  if (expectedSize > 0 && bytes.length != expectedSize) {
    throw TextureDownloadException(
      'The download ended early — got ${bytes.length} of $expectedSize bytes.',
    );
  }
  if (expectedSha1.isNotEmpty) {
    report('Verifying the download…', received, total);
    final actual = sha1.convert(bytes).toString();
    if (actual != expectedSha1) {
      throw TextureDownloadException(
        'The downloaded file did not match Mojang\'s checksum.',
      );
    }
  }

  // Written under a temporary name first: a half-written jar left behind by a
  // crash would otherwise look like a usable install to [findTextureSources]
  // ever after.
  final partial = File('${target.path}.part');
  await partial.writeAsBytes(bytes, flush: true);
  await partial.rename(target.path);

  report('Reading block textures…', received, total);
  return target.path;
}

/// The rough download size to warn the user about before they commit to it.
///
/// Only used for the prompt — the real size comes from the manifest.
const int kApproximateClientJarBytes = 27 * 1024 * 1024;
