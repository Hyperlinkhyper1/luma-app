import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/nfc_tag_editor/nfc_record.dart';
import 'package:luma/features/plugins/installed/nfc_tag_editor/nfc_tag_store.dart';
import 'package:nfc_manager/nfc_manager.dart';

EditableNdefRecord _record(NfcRecordKind kind, Map<String, String> fields) =>
    EditableNdefRecord(id: 'r1', kind: kind, fields: fields);

/// Encodes a record to real NDEF bytes and decodes them straight back, which
/// is what a write-then-scan of the same tag does.
EditableNdefRecord _roundTrip(EditableNdefRecord record) =>
    EditableNdefRecord.fromNdefRecord(record.toNdefRecord());

void main() {
  group('EditableNdefRecord NDEF encoding', () {
    test('a text record keeps its text and language code', () {
      final restored = _roundTrip(
        _record(NfcRecordKind.text, {'text': 'Hello tag', 'lang': 'nl'}),
      );
      expect(restored.kind, NfcRecordKind.text);
      expect(restored.fields['text'], 'Hello tag');
      expect(restored.fields['lang'], 'nl');
    });

    test('a link record survives the URI prefix abbreviation', () {
      final restored = _roundTrip(
        _record(NfcRecordKind.uri, {'uri': 'https://example.com/a'}),
      );
      expect(restored.kind, NfcRecordKind.uri);
      expect(restored.fields['uri'], 'https://example.com/a');
    });

    test('a phone number comes back as a phone record, not a bare link', () {
      final restored =
          _roundTrip(_record(NfcRecordKind.phone, {'number': '+15550100'}));
      expect(restored.kind, NfcRecordKind.phone);
      expect(restored.fields['number'], '+15550100');
    });

    test('an email keeps its address, subject and body', () {
      final restored = _roundTrip(_record(NfcRecordKind.email, {
        'address': 'name@example.com',
        'subject': 'Hi there',
        'body': 'Sent from a tag',
      }));
      expect(restored.kind, NfcRecordKind.email);
      expect(restored.fields['address'], 'name@example.com');
      expect(restored.fields['subject'], 'Hi there');
      expect(restored.fields['body'], 'Sent from a tag');
    });

    test('Wi-Fi details round-trip, including a password with a semicolon', () {
      final restored = _roundTrip(_record(NfcRecordKind.wifi, {
        'ssid': 'Guest;Net',
        'password': r'p:a;s\s',
        'security': 'WPA',
      }));
      expect(restored.kind, NfcRecordKind.wifi);
      expect(restored.fields['ssid'], 'Guest;Net');
      expect(restored.fields['password'], r'p:a;s\s');
      expect(restored.fields['security'], 'WPA');
    });

    test('an open network writes no password field', () {
      final record = _record(NfcRecordKind.wifi, {
        'ssid': 'Cafe',
        'password': 'ignored',
        'security': 'nopass',
      });
      final restored = _roundTrip(record);
      expect(restored.fields['security'], 'nopass');
      expect(restored.fields['password'], '');
    });

    test('a contact card round-trips through vCard', () {
      final restored = _roundTrip(_record(NfcRecordKind.contact, {
        'name': 'Ada Lovelace',
        'phone': '+15550100',
        'email': 'ada@example.com',
        'org': 'Analytical Engines',
      }));
      expect(restored.kind, NfcRecordKind.contact);
      expect(restored.fields['name'], 'Ada Lovelace');
      expect(restored.fields['phone'], '+15550100');
      expect(restored.fields['email'], 'ada@example.com');
      expect(restored.fields['org'], 'Analytical Engines');
    });

    test('an app shortcut keeps its package name', () {
      final restored = _roundTrip(
        _record(NfcRecordKind.appLaunch, {'package': 'com.example.app'}),
      );
      expect(restored.kind, NfcRecordKind.appLaunch);
      expect(restored.fields['package'], 'com.example.app');
    });

    test('a custom MIME record keeps its type and content', () {
      final restored = _roundTrip(_record(NfcRecordKind.mime, {
        'mimeType': 'application/json',
        'text': '{"a":1}',
      }));
      expect(restored.kind, NfcRecordKind.mime);
      expect(restored.fields['mimeType'], 'application/json');
      expect(restored.fields['text'], '{"a":1}');
    });

    test('an unrecognised record is kept byte-for-byte as raw', () {
      final payload = Uint8List.fromList([0xde, 0xad, 0xbe, 0xef]);
      final original = NdefRecord(
        typeNameFormat: NdefTypeNameFormat.nfcExternal,
        type: Uint8List.fromList(ascii.encode('example.com:thing')),
        identifier: Uint8List(0),
        payload: payload,
      );

      final decoded = EditableNdefRecord.fromNdefRecord(original);
      expect(decoded.kind, NfcRecordKind.raw);

      final reencoded = decoded.toNdefRecord();
      expect(reencoded.typeNameFormat, NdefTypeNameFormat.nfcExternal);
      expect(reencoded.type, original.type);
      expect(reencoded.payload, payload);
    });
  });

  group('EditableNdefRecord JSON', () {
    test('round-trips a decoded record through the store format', () {
      final record = _record(NfcRecordKind.wifi, {
        'ssid': 'Home',
        'password': 'hunter2',
        'security': 'WPA',
      });
      final restored = EditableNdefRecord.fromJson(record.toJson());
      expect(restored.id, 'r1');
      expect(restored.kind, NfcRecordKind.wifi);
      expect(restored.fields['ssid'], 'Home');
      expect(restored.fields['password'], 'hunter2');
    });

    test('keeps the raw bytes of an unrecognised record across a save', () {
      final raw = EditableNdefRecord(
        id: 'r2',
        kind: NfcRecordKind.raw,
        rawTnf: NdefTypeNameFormat.unknown.index,
        rawTypeHex: '',
        rawPayloadHex: 'deadbeef',
      );
      final restored = EditableNdefRecord.fromJson(raw.toJson());
      expect(restored.kind, NfcRecordKind.raw);
      expect(restored.rawPayloadHex, 'deadbeef');
      expect(restored.toNdefRecord().payload, [0xde, 0xad, 0xbe, 0xef]);
    });

    test('a malformed stored record falls back to raw', () {
      final restored =
          EditableNdefRecord.fromJson(<String, dynamic>{'kind': 'nonsense'});
      expect(restored.kind, NfcRecordKind.raw);
      expect(restored.id, isNotEmpty);
    });

    test('duplicating a record gives it a fresh id but the same content', () {
      final record = _record(NfcRecordKind.text, {'text': 'Hi', 'lang': 'en'});
      final copy = record.copyWith();
      expect(copy.id, isNot('r1'));
      expect(copy.fields['text'], 'Hi');

      copy.fields['text'] = 'Changed';
      expect(record.fields['text'], 'Hi');
    });
  });

  group('Store entries', () {
    test('a history entry round-trips through JSON', () {
      final entry = NfcHistoryEntry(
        id: 'h1',
        timestamp: DateTime.parse('2026-08-11T10:30:00.000'),
        direction: NfcHistoryDirection.written,
        records: [_record(NfcRecordKind.text, {'text': 'Hi', 'lang': 'en'})],
        techLabel: 'MIFARE Ultralight / NTAG',
        uid: '04:A2:2C:19',
        locked: true,
      );
      final restored = NfcHistoryEntry.fromJson(entry.toJson());
      expect(restored.id, 'h1');
      expect(restored.timestamp, DateTime.parse('2026-08-11T10:30:00.000'));
      expect(restored.direction, NfcHistoryDirection.written);
      expect(restored.records.single.fields['text'], 'Hi');
      expect(restored.techLabel, 'MIFARE Ultralight / NTAG');
      expect(restored.uid, '04:A2:2C:19');
      expect(restored.locked, isTrue);
    });

    test('a template round-trips through JSON', () {
      final template = NfcTagTemplate(
        id: 't1',
        name: 'Guest Wi-Fi',
        createdAt: DateTime.parse('2026-08-11T10:30:00.000'),
        records: [
          _record(NfcRecordKind.wifi, {
            'ssid': 'Guest',
            'password': 'letmein',
            'security': 'WPA',
          }),
        ],
      );
      final restored = NfcTagTemplate.fromJson(template.toJson());
      expect(restored.name, 'Guest Wi-Fi');
      expect(restored.records.single.kind, NfcRecordKind.wifi);
      expect(restored.records.single.fields['ssid'], 'Guest');
    });

    test('a history entry with no records survives a malformed save', () {
      final restored = NfcHistoryEntry.fromJson(<String, dynamic>{});
      expect(restored.records, isEmpty);
      expect(restored.direction, NfcHistoryDirection.scanned);
      expect(restored.id, isNotEmpty);
    });
  });
}
