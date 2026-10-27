import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/family/family_cache_store.dart';
import 'package:luma/features/plugins/installed/secure_chat/data/chat_cache_store.dart';
import 'package:luma/security/authenticated_cipher.dart';
import 'package:luma/security/secure_secret_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final chat in [true, false]) {
    final label = chat ? 'Secure Chat' : 'Family';
    final fileName = chat ? 'luma_chat_cache.json' : 'luma_family_cache.json';
    final keyName = chat ? 'secure-chat-cache' : 'family-cache';

    group('$label encrypted cache', () {
      late Directory dir;
      late File file;
      late SecureSecretStore secrets;

      setUp(() async {
        FlutterSecureStorage.setMockInitialValues({});
        dir = await Directory.systemTemp.createTemp('luma_encrypted_cache_');
        file = File('${dir.path}${Platform.pathSeparator}$fileName');
        secrets = SecureSecretStore(storageDir: dir);
      });

      tearDown(() async {
        await dir.delete(recursive: true);
      });

      Future<_Cache> load({SecureSecretStore? secretStore}) async {
        final store = secretStore ?? secrets;
        if (chat) {
          return _ChatCache(
            await ChatCacheStore.load(storageDir: dir, secretStore: store),
          );
        }
        return _FamilyCache(
          await FamilyCacheStore.load(storageDir: dir, secretStore: store),
        );
      }

      test(
        'round trips the complete payload without writing plaintext',
        () async {
          final cache = await load();
          cache.populate();
          final expected = cache.payload;
          await cache.save();

          final bytes = await file.readAsBytes();
          expect(bytes.take(3), [0x4c, 0x41, 0x01]);
          expect(latin1.decode(bytes), isNot(contains('private-message')));
          expect(await File('${file.path}.tmp').exists(), isFalse);
          final reloaded = await load(
            secretStore: SecureSecretStore(storageDir: dir),
          );
          expect(reloaded.payload, expected);
        },
      );

      test(
        'discards legacy plaintext and interrupted temporary writes',
        () async {
          final original = await load();
          original.populate();
          await file.writeAsString(jsonEncode(original.payload));
          final tmp = File('${file.path}.tmp');
          await tmp.writeAsString(jsonEncode(original.payload));

          final migrated = await load();
          expect(migrated.isEmpty, isTrue);
          expect(await file.exists(), isFalse);
          expect(await tmp.exists(), isFalse);

          migrated.populate();
          await migrated.save();
          expect((await load()).payload, migrated.payload);
          expect((await file.readAsBytes()).take(3), [0x4c, 0x41, 0x01]);
        },
      );

      test('temporary writes stay encrypted when replacement fails', () async {
        final cache = await load();
        cache.populate();
        final destination = Directory(file.path);
        await destination.create();
        await cache.save();

        final tmp = File('${file.path}.tmp');
        final bytes = await tmp.readAsBytes();
        final key = await secrets.loadKey(keyName);
        final decrypted = jsonDecode(
          utf8.decode(AuthenticatedCipher.open(bytes, key, 'luma.$keyName')),
        );
        expect(decrypted, cache.payload);
        expect(latin1.decode(bytes), isNot(contains('private-message')));

        await destination.delete();
        expect((await load()).isEmpty, isTrue);
        expect(await tmp.exists(), isFalse);
      });

      test(
        'discards truncated plaintext without waiting for a refresh',
        () async {
          await file.writeAsString('{"messages": ["private-message');
          final tmp = File('${file.path}.tmp');
          await tmp.writeAsString('{"messages": ["private-message');

          final migrated = await load();
          expect(migrated.isEmpty, isTrue);
          expect(await file.exists(), isFalse);
          expect(await tmp.exists(), isFalse);
        },
      );

      test(
        'lost keys yield an empty cache and allow the next refresh',
        () async {
          final cache = await load();
          cache.populate();
          await cache.save();

          FlutterSecureStorage.setMockInitialValues({});
          final replacementSecrets = SecureSecretStore(storageDir: dir);
          final reopened = await load(secretStore: replacementSecrets);
          expect(reopened.isEmpty, isTrue);
          expect(replacementSecrets.lostKeys, contains(keyName));

          reopened.populate();
          await reopened.save();
          final refreshed = await load(secretStore: replacementSecrets);
          expect(refreshed.payload, reopened.payload);
        },
      );

      test('tampered ciphertext is discarded until the next refresh', () async {
        final cache = await load();
        cache.populate();
        await cache.save();
        final bytes = await file.readAsBytes();
        bytes[20] ^= 1;
        await file.writeAsBytes(bytes);

        final reopened = await load();
        expect(reopened.isEmpty, isTrue);
        reopened.populate();
        await reopened.save();
        expect((await load()).payload, reopened.payload);
      });
    });
  }
}

abstract class _Cache {
  Map<String, dynamic> get payload;
  bool get isEmpty;
  void populate();
  Future<void> save();
}

class _ChatCache implements _Cache {
  _ChatCache(this.store);

  final ChatCacheStore store;

  @override
  Map<String, dynamic> get payload => {
    'conversations': store.conversationsJson,
    'invites': store.invitesJson,
    'messages': store.messagesByConversation,
    'pinnedKeys': store.pinnedKeys,
  };

  @override
  bool get isEmpty =>
      store.conversationsJson.isEmpty &&
      store.invitesJson.isEmpty &&
      store.messagesByConversation.isEmpty;

  @override
  void populate() {
    store.conversationsJson = [
      {'id': 'conversation', 'title': 'private-conversation'},
    ];
    store.invitesJson = [
      {'id': 'invite', 'from': 'private-invite'},
    ];
    store.messagesByConversation = {
      'conversation': [
        {'id': 'message', 'text': 'private-message'},
      ],
    };
  }

  @override
  Future<void> save() => store.save();
}

class _FamilyCache implements _Cache {
  _FamilyCache(this.store);

  final FamilyCacheStore store;

  @override
  Map<String, dynamic> get payload => {
    'family': store.familyJson,
    'invites': store.invitesJson,
    'events': store.eventsJson,
    'messages': store.messagesJson,
  };

  @override
  bool get isEmpty =>
      store.familyJson == null &&
      store.invitesJson.isEmpty &&
      store.eventsJson.isEmpty &&
      store.messagesJson.isEmpty;

  @override
  void populate() {
    store.familyJson = {'id': 'family', 'name': 'private-family'};
    store.invitesJson = [
      {'id': 'invite', 'from': 'private-invite'},
    ];
    store.eventsJson = [
      {'id': 'event', 'title': 'private-event'},
    ];
    store.messagesJson = [
      {'id': 'message', 'text': 'private-message'},
    ];
  }

  @override
  Future<void> save() => store.save();
}
