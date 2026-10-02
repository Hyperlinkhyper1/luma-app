import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/text_library/data/text_library_database.dart';
import 'package:luma/features/plugins/installed/text_library/text_library_models.dart';
import 'package:luma/features/plugins/installed/text_library/text_library_repository.dart';
import 'package:luma/storage/storage_guard.dart';
import 'package:luma/sync/sync_collections.dart';
import 'package:luma/sync/sync_crypto.dart';

DriftSyncCollection _collection(TextLibraryDatabase db) => DriftSyncCollection(
  id: 'text_library',
  label: 'Text library',
  icon: Icons.menu_book_rounded,
  db: db,
);

void main() {
  setUpAll(() => StorageGuardService.instance = StorageGuardService());

  late TextLibraryDatabase source;
  late TextLibraryDatabase target;

  setUp(() {
    source = TextLibraryDatabase(NativeDatabase.memory());
    target = TextLibraryDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  test('a library survives an encrypted round trip to another device', () async {
    final repo = TextLibraryRepository(source);
    final subject = await repo.createSubject('History', color: DyeColor.blue);
    final textId = await repo.saveText(
      subjectId: subject,
      title: 'Secret diary',
      spine: 'Vol 1',
      body: RichDoc([
        const RichSpan('Top secret ', RichStyle(bold: true)),
        const RichSpan('entry'),
      ]),
      cover: DyeColor.red,
    );

    final key = SyncCrypto.randomBytes(32);
    final snapshot = await _collection(source).export();
    final sealed = await SyncCrypto.sealPayload(snapshot!, key);

    final onTheWire = latin1.decode(sealed);
    expect(onTheWire, isNot(contains('Secret diary')));
    expect(onTheWire, isNot(contains('Top secret')));
    expect(onTheWire, isNot(contains('History')));

    final opened = await SyncCrypto.openPayload(sealed, key);
    await _collection(target).import(opened);

    final copy = await TextLibraryRepository(target).loadLibrary();
    expect(copy.subjects.single.name, 'History');
    expect(copy.subjects.single.color, DyeColor.blue);
    final text = copy.texts.single;
    expect(text.id, textId);
    expect(text.title, 'Secret diary');
    expect(text.spine, 'Vol 1');
    expect(text.cover, DyeColor.red);
    expect(text.body.plainText, 'Top secret entry');
  });

  test('a snapshot sealed under another key cannot be opened', () async {
    await TextLibraryRepository(source).createSubject('Maths');
    final snapshot = await _collection(source).export();
    final sealed = await SyncCrypto.sealPayload(
      snapshot!,
      SyncCrypto.randomBytes(32),
    );
    expect(
      () => SyncCrypto.openPayload(sealed, SyncCrypto.randomBytes(32)),
      throwsA(isA<SyncCryptoException>()),
    );
  });
}
