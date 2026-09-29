import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/text_library/minecraft/player_skin.dart';

/// Just enough of a PNG for the header check: signature and IHDR size.
Uint8List png(int width, int height) {
  final bytes = BytesBuilder()
    ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    ..add([0, 0, 0, 13])
    ..add(ascii.encode('IHDR'));
  final size = ByteData(8)
    ..setUint32(0, width)
    ..setUint32(4, height);
  bytes
    ..add(size.buffer.asUint8List())
    ..add(List.filled(17, 0));
  return bytes.toBytes();
}

void main() {
  group('skinFromPng', () {
    test('takes the modern, legacy and HD layouts', () {
      expect(skinFromPng(png(64, 64)), isNotNull);
      expect(skinFromPng(png(64, 32)), isNotNull);
      expect(skinFromPng(png(128, 128)), isNotNull);
    });

    test('turns away anything else', () {
      expect(skinFromPng(png(32, 32)), isNull);
      expect(skinFromPng(png(64, 48)), isNull);
      expect(skinFromPng(png(96, 96)), isNull);
      expect(skinFromPng(png(1024, 1024)), isNull);
      expect(
        skinFromPng(
          Uint8List.fromList(utf8.encode('not a png at all, really')),
        ),
        isNull,
      );
    });
  });

  group('fetchSkinByName', () {
    String textures(String url, {bool slim = false}) => base64Encode(
      utf8.encode(
        jsonEncode({
          'textures': {
            'SKIN': {
              'url': url,
              if (slim) 'metadata': {'model': 'slim'},
            },
          },
        }),
      ),
    );

    MockClient mojang({
      String skinUrl = 'http://textures.minecraft.net/texture/abc',
      bool slim = false,
    }) => MockClient((request) async {
      switch (request.url.host) {
        case 'api.mojang.com':
          return request.url.path.endsWith('/Notch')
              ? http.Response(
                  jsonEncode({'id': '069a79f4', 'name': 'Notch'}),
                  200,
                )
              : http.Response('', 404);
        case 'sessionserver.mojang.com':
          return http.Response(
            jsonEncode({
              'properties': [
                {'name': 'textures', 'value': textures(skinUrl, slim: slim)},
              ],
            }),
            200,
          );
        case 'textures.minecraft.net':
          expect(request.url.scheme, 'https');
          return http.Response.bytes(png(64, 64), 200);
      }
      return http.Response('', 404);
    });

    test('follows the profile to the skin, over https', () async {
      final skin = await fetchSkinByName('Notch', client: mojang(slim: true));
      expect(skin.label, 'Notch');
      expect(skin.model, 'slim');
      expect(skin.toMessage()['type'], 'skin');
    });

    test('reports a player that does not exist', () async {
      expect(
        fetchSkinByName('NobodyAtAll', client: mojang()),
        throwsA(isA<SkinLookupException>()),
      );
    });

    test('never asks Mojang about something that is not a username', () async {
      var asked = false;
      final client = MockClient((_) async {
        asked = true;
        return http.Response('', 404);
      });
      await expectLater(
        fetchSkinByName('../../etc', client: client),
        throwsA(isA<SkinLookupException>()),
      );
      expect(asked, isFalse);
    });

    test('only downloads skins from Mojang\'s texture host', () async {
      expect(
        fetchSkinByName(
          'Notch',
          client: mojang(skinUrl: 'https://example.com/skin.png'),
        ),
        throwsA(isA<SkinLookupException>()),
      );
    });
  });
}
