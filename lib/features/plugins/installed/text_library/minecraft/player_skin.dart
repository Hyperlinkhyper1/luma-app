import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// The reader's own Minecraft skin for the hall: their hand in first
/// person, and them sitting at the desk while they write.
///
/// It comes from a PNG the reader picks or from Mojang's public profile
/// lookup for a username they type — never fetched on its own — and is kept
/// on this device only, like the choice of view.
class PlayerSkin {
  const PlayerSkin({required this.png, this.model, this.label});

  final Uint8List png;

  /// 'slim' or 'classic' when known; otherwise the scene reads the arm width
  /// off the sheet.
  final String? model;

  /// What the settings show it as: the username, or the file's name.
  final String? label;

  Map<String, Object?> toMessage() => {
    'type': 'skin',
    'data': base64Encode(png),
    'model': model,
    'label': label,
  };
}

/// A skin lookup that didn't work, with a reason for the log.
class SkinLookupException implements Exception {
  const SkinLookupException(this.reason);
  final String reason;
  @override
  String toString() => 'SkinLookupException: $reason';
}

const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// [bytes] as a skin if it is one: a PNG in the game's 64×64 layout, the old
/// 64×32 one, or an HD multiple of either up to 512 wide.
PlayerSkin? skinFromPng(Uint8List bytes, {String? model, String? label}) {
  if (bytes.length < 24 || bytes.length > 2 * 1024 * 1024) return null;
  for (var i = 0; i < _pngSignature.length; i++) {
    if (bytes[i] != _pngSignature[i]) return null;
  }
  final header = ByteData.sublistView(bytes, 16, 24);
  final width = header.getUint32(0);
  final height = header.getUint32(4);
  final shape = height == width || height * 2 == width;
  if (width < 64 || width > 512 || width % 64 != 0 || !shape) return null;
  return PlayerSkin(png: bytes, model: model, label: label);
}

final _username = RegExp(r'^[A-Za-z0-9_]{3,16}$');

/// Looks [name] up with Mojang's public profile API and downloads the skin
/// it points at. Unauthenticated, and only ever run when the reader asks.
Future<PlayerSkin> fetchSkinByName(String name, {http.Client? client}) async {
  final trimmed = name.trim();
  if (!_username.hasMatch(trimmed)) {
    throw const SkinLookupException('not a Minecraft username');
  }
  final web = client ?? http.Client();
  try {
    final profile = await web
        .get(Uri.https('api.mojang.com', '/users/profiles/minecraft/$trimmed'))
        .timeout(const Duration(seconds: 15));
    if (profile.statusCode != 200) {
      throw const SkinLookupException('no such player');
    }
    final found = jsonDecode(profile.body) as Map;
    final id = found['id'] as String?;
    final shownName = found['name'] as String?;
    if (id == null) throw const SkinLookupException('no such player');

    final session = await web
        .get(
          Uri.https(
            'sessionserver.mojang.com',
            '/session/minecraft/profile/$id',
          ),
        )
        .timeout(const Duration(seconds: 15));
    if (session.statusCode != 200) {
      throw const SkinLookupException('profile unavailable');
    }
    final properties =
        (jsonDecode(session.body) as Map)['properties'] as List? ?? const [];
    final textures = properties.whereType<Map>().firstWhere(
      (p) => p['name'] == 'textures',
      orElse: () => const {},
    );
    final value = textures['value'] as String?;
    if (value == null) throw const SkinLookupException('no skin set');
    final decoded =
        jsonDecode(utf8.decode(base64Decode(value))) as Map<String, dynamic>;
    final skin =
        (decoded['textures'] as Map?)?['SKIN'] as Map<String, dynamic>?;
    final url = skin?['url'] as String?;
    if (url == null) throw const SkinLookupException('no skin set');
    final model = (skin?['metadata'] as Map?)?['model'] == 'slim'
        ? 'slim'
        : 'classic';

    // Skins are only ever served from Mojang's texture host.
    final uri = Uri.parse(url).replace(scheme: 'https');
    if (uri.host != 'textures.minecraft.net') {
      throw const SkinLookupException('unexpected skin host');
    }
    final image = await web.get(uri).timeout(const Duration(seconds: 15));
    if (image.statusCode != 200) {
      throw const SkinLookupException('skin download failed');
    }
    final result = skinFromPng(
      image.bodyBytes,
      model: model,
      label: shownName ?? trimmed,
    );
    if (result == null) throw const SkinLookupException('not a skin image');
    return result;
  } finally {
    if (client == null) web.close();
  }
}

Future<File> _png() async {
  final support = await getApplicationSupportDirectory();
  return File('${support.path}${Platform.pathSeparator}text_library_skin.png');
}

Future<File> _meta() async {
  final support = await getApplicationSupportDirectory();
  return File('${support.path}${Platform.pathSeparator}text_library_skin.json');
}

/// The skin kept on this device, if the reader imported one.
Future<PlayerSkin?> loadSavedSkin() async {
  try {
    final png = await _png();
    if (!await png.exists()) return null;
    final meta = await _meta();
    final info = await meta.exists()
        ? jsonDecode(await meta.readAsString()) as Map<String, dynamic>
        : const <String, dynamic>{};
    return skinFromPng(
      await png.readAsBytes(),
      model: info['model'] as String?,
      label: info['label'] as String?,
    );
  } catch (_) {
    return null;
  }
}

Future<void> saveSkin(PlayerSkin skin) async {
  await (await _png()).writeAsBytes(skin.png, flush: true);
  await (await _meta()).writeAsString(
    jsonEncode({'model': skin.model, 'label': skin.label}),
  );
}

Future<void> clearSavedSkin() async {
  for (final file in [await _png(), await _meta()]) {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Only the remembered skin is affected.
    }
  }
}
