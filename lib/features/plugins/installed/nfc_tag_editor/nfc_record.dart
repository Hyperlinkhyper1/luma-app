import 'dart:convert';
import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';

/// What kind of NDEF record this is, and therefore which fields in
/// [EditableNdefRecord.fields] are meaningful and which dedicated editor
/// applies. [raw] is the catch-all for anything read off a tag that doesn't
/// match one of the others — its bytes are kept exactly so re-writing the
/// tag never silently drops or corrupts data the editor doesn't understand.
enum NfcRecordKind {
  text,
  uri,
  phone,
  email,
  wifi,
  contact,
  appLaunch,
  mime,
  raw,
}

int _idCounter = 0;

/// A short, unique id for a record or history/template entry. Stable across
/// list reorders since it's tied to the record's identity, not its position.
String newNfcRecordId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

/// One NDEF record, in a form the editor UI can read and write without every
/// caller needing to know the NDEF byte format. [fields] holds named,
/// kind-specific values (e.g. `wifi` uses `ssid`/`password`/`security`); the
/// three `raw*` fields are only populated for [NfcRecordKind.raw], and
/// round-trip the original bytes exactly.
class EditableNdefRecord {
  EditableNdefRecord({
    required this.id,
    required this.kind,
    Map<String, String>? fields,
    this.rawTnf,
    this.rawTypeHex,
    this.rawPayloadHex,
  }) : fields = fields ?? <String, String>{};

  final String id;
  final NfcRecordKind kind;
  final Map<String, String> fields;

  /// Only set for [NfcRecordKind.raw]: the original [NdefTypeNameFormat]
  /// index, and the type/payload bytes as hex, preserved byte-for-byte.
  final int? rawTnf;
  final String? rawTypeHex;
  final String? rawPayloadHex;

  EditableNdefRecord copyWith({String? id}) => EditableNdefRecord(
        id: id ?? newNfcRecordId(),
        kind: kind,
        fields: Map.of(fields),
        rawTnf: rawTnf,
        rawTypeHex: rawTypeHex,
        rawPayloadHex: rawPayloadHex,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'fields': fields,
        if (rawTnf != null) 'rawTnf': rawTnf,
        if (rawTypeHex != null) 'rawTypeHex': rawTypeHex,
        if (rawPayloadHex != null) 'rawPayloadHex': rawPayloadHex,
      };

  factory EditableNdefRecord.fromJson(Map<String, dynamic> json) {
    final kind = NfcRecordKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => NfcRecordKind.raw,
    );
    final rawFields = json['fields'];
    return EditableNdefRecord(
      id: json['id']?.toString() ?? newNfcRecordId(),
      kind: kind,
      fields: rawFields is Map
          ? rawFields.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))
          : <String, String>{},
      rawTnf: (json['rawTnf'] as num?)?.toInt(),
      rawTypeHex: json['rawTypeHex']?.toString(),
      rawPayloadHex: json['rawPayloadHex']?.toString(),
    );
  }

  /// Builds the real NDEF record this represents, ready to write to a tag.
  NdefRecord toNdefRecord() {
    switch (kind) {
      case NfcRecordKind.text:
        final lang = fields['lang'];
        return NdefRecord.createText(
          fields['text'] ?? '',
          languageCode: (lang == null || lang.isEmpty) ? 'en' : lang,
        );
      case NfcRecordKind.uri:
        return NdefRecord.createUri(Uri.parse(fields['uri'] ?? ''));
      case NfcRecordKind.phone:
        return NdefRecord.createUri(Uri.parse('tel:${fields['number'] ?? ''}'));
      case NfcRecordKind.email:
        final query = <String, String>{};
        final subject = fields['subject'] ?? '';
        final body = fields['body'] ?? '';
        if (subject.isNotEmpty) query['subject'] = subject;
        if (body.isNotEmpty) query['body'] = body;
        return NdefRecord.createUri(Uri(
          scheme: 'mailto',
          path: fields['address'] ?? '',
          queryParameters: query.isEmpty ? null : query,
        ));
      case NfcRecordKind.wifi:
        final security = fields['security'] ?? 'WPA';
        final password = fields['password'] ?? '';
        final buffer = StringBuffer('WIFI:S:${_escapeWifi(fields['ssid'] ?? '')};')
          ..write('T:${_escapeWifi(security)};');
        if (security != 'nopass' && password.isNotEmpty) {
          buffer.write('P:${_escapeWifi(password)};');
        }
        buffer.write('H:false;;');
        return NdefRecord.createText(buffer.toString());
      case NfcRecordKind.contact:
        return NdefRecord.createMime(
          'text/vcard',
          Uint8List.fromList(utf8.encode(_buildVCard(fields))),
        );
      case NfcRecordKind.appLaunch:
        return NdefRecord.createExternal(
          'android.com',
          'pkg',
          Uint8List.fromList(utf8.encode(fields['package'] ?? '')),
        );
      case NfcRecordKind.mime:
        return NdefRecord.createMime(
          (fields['mimeType']?.isEmpty ?? true) ? 'text/plain' : fields['mimeType']!,
          Uint8List.fromList(utf8.encode(fields['text'] ?? '')),
        );
      case NfcRecordKind.raw:
        return NdefRecord(
          typeNameFormat: NdefTypeNameFormat
              .values[rawTnf ?? NdefTypeNameFormat.unknown.index],
          type: _hexToBytes(rawTypeHex ?? ''),
          identifier: Uint8List(0),
          payload: _hexToBytes(rawPayloadHex ?? ''),
        );
    }
  }

  /// Decodes a record read off a physical tag into editor-friendly form.
  /// Anything not recognised falls back to [NfcRecordKind.raw] so a
  /// subsequent write can't silently drop or mangle it.
  factory EditableNdefRecord.fromNdefRecord(NdefRecord record) {
    final id = newNfcRecordId();
    final tnf = record.typeNameFormat;
    final type = record.type;
    final payload = record.payload;

    if (tnf == NdefTypeNameFormat.nfcWellknown &&
        type.length == 1 &&
        type.first == 0x54 &&
        payload.isNotEmpty) {
      final status = payload.first;
      final langLen = status & 0x3f;
      final isUtf16 = (status & 0x80) != 0;
      if (payload.length >= 1 + langLen) {
        final lang = ascii.decode(payload.sublist(1, 1 + langLen), allowInvalid: true);
        final textBytes = payload.sublist(1 + langLen);
        final text = isUtf16
            ? _decodeUtf16(textBytes)
            : utf8.decode(textBytes, allowMalformed: true);
        final wifi = _parseWifiText(text);
        if (wifi != null) {
          return EditableNdefRecord(id: id, kind: NfcRecordKind.wifi, fields: wifi);
        }
        return EditableNdefRecord(
          id: id,
          kind: NfcRecordKind.text,
          fields: {'text': text, 'lang': lang.isEmpty ? 'en' : lang},
        );
      }
    }

    if (tnf == NdefTypeNameFormat.nfcWellknown &&
        type.length == 1 &&
        type.first == 0x55) {
      final prefix = _uriPrefixes[payload.isNotEmpty ? payload.first : 0] ?? '';
      final rest =
          payload.isNotEmpty ? utf8.decode(payload.sublist(1), allowMalformed: true) : '';
      final uri = '$prefix$rest';
      if (uri.startsWith('tel:')) {
        return EditableNdefRecord(
          id: id,
          kind: NfcRecordKind.phone,
          fields: {'number': uri.substring(4)},
        );
      }
      if (uri.startsWith('mailto:')) {
        final parsed = Uri.tryParse(uri);
        return EditableNdefRecord(
          id: id,
          kind: NfcRecordKind.email,
          fields: {
            'address': parsed?.path ?? uri.substring(7),
            'subject': parsed?.queryParameters['subject'] ?? '',
            'body': parsed?.queryParameters['body'] ?? '',
          },
        );
      }
      return EditableNdefRecord(id: id, kind: NfcRecordKind.uri, fields: {'uri': uri});
    }

    if (tnf == NdefTypeNameFormat.media) {
      final mimeType = ascii.decode(type, allowInvalid: true);
      if (mimeType.toLowerCase() == 'text/vcard' ||
          mimeType.toLowerCase() == 'text/x-vcard') {
        final vcard = utf8.decode(payload, allowMalformed: true);
        return EditableNdefRecord(
          id: id,
          kind: NfcRecordKind.contact,
          fields: _parseVCard(vcard),
        );
      }
      return EditableNdefRecord(
        id: id,
        kind: NfcRecordKind.mime,
        fields: {
          'mimeType': mimeType,
          'text': utf8.decode(payload, allowMalformed: true),
        },
      );
    }

    if (tnf == NdefTypeNameFormat.nfcExternal) {
      final typeStr = ascii.decode(type, allowInvalid: true);
      if (typeStr == 'android.com:pkg') {
        return EditableNdefRecord(
          id: id,
          kind: NfcRecordKind.appLaunch,
          fields: {'package': utf8.decode(payload, allowMalformed: true)},
        );
      }
    }

    return EditableNdefRecord(
      id: id,
      kind: NfcRecordKind.raw,
      rawTnf: tnf.index,
      rawTypeHex: _bytesToHex(type),
      rawPayloadHex: _bytesToHex(payload),
    );
  }
}

// ---- vCard --------------------------------------------------------------

String _buildVCard(Map<String, String> fields) {
  final buffer = StringBuffer()
    ..writeln('BEGIN:VCARD')
    ..writeln('VERSION:3.0');
  if ((fields['name'] ?? '').isNotEmpty) buffer.writeln('FN:${fields['name']}');
  if ((fields['phone'] ?? '').isNotEmpty) buffer.writeln('TEL:${fields['phone']}');
  if ((fields['email'] ?? '').isNotEmpty) buffer.writeln('EMAIL:${fields['email']}');
  if ((fields['org'] ?? '').isNotEmpty) buffer.writeln('ORG:${fields['org']}');
  buffer.writeln('END:VCARD');
  return buffer.toString();
}

Map<String, String> _parseVCard(String text) {
  final fields = <String, String>{'name': '', 'phone': '', 'email': '', 'org': ''};
  for (final rawLine in text.split(RegExp(r'\r\n|\n|\r'))) {
    final line = rawLine.trim();
    final colon = line.indexOf(':');
    if (colon < 0) continue;
    final key = line.substring(0, colon).split(';').first.toUpperCase();
    final value = line.substring(colon + 1);
    switch (key) {
      case 'FN':
        fields['name'] = value;
        break;
      case 'TEL':
        if (fields['phone']!.isEmpty) fields['phone'] = value;
        break;
      case 'EMAIL':
        if (fields['email']!.isEmpty) fields['email'] = value;
        break;
      case 'ORG':
        fields['org'] = value;
        break;
    }
  }
  return fields;
}

// ---- Wi-Fi text encoding (same `WIFI:S:...;;` syntax as Wi-Fi QR codes) --

String _escapeWifi(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll(':', '\\:');

Map<String, String>? _parseWifiText(String text) {
  if (!text.startsWith('WIFI:')) return null;
  final body = text.substring(5);
  final parsed = <String, String>{};
  final buffer = StringBuffer();
  String? key;
  var i = 0;
  while (i < body.length) {
    final c = body[i];
    if (c == '\\' && i + 1 < body.length) {
      buffer.write(body[i + 1]);
      i += 2;
      continue;
    }
    if (c == ':' && key == null) {
      key = buffer.toString();
      buffer.clear();
      i++;
      continue;
    }
    if (c == ';') {
      if (key != null) parsed[key] = buffer.toString();
      key = null;
      buffer.clear();
      i++;
      continue;
    }
    buffer.write(c);
    i++;
  }
  final ssid = parsed['S'];
  if (ssid == null || ssid.isEmpty) return null;
  return {
    'ssid': ssid,
    'security': parsed['T'] ?? 'WPA',
    'password': parsed['P'] ?? '',
  };
}

// ---- Low-level byte helpers -----------------------------------------------

String _decodeUtf16(List<int> bytes) {
  if (bytes.length < 2) return '';
  var start = 0;
  var bigEndian = true;
  if (bytes[0] == 0xfe && bytes[1] == 0xff) {
    start = 2;
  } else if (bytes[0] == 0xff && bytes[1] == 0xfe) {
    start = 2;
    bigEndian = false;
  }
  final codeUnits = <int>[];
  for (var i = start; i + 1 < bytes.length; i += 2) {
    codeUnits.add(bigEndian
        ? (bytes[i] << 8) | bytes[i + 1]
        : (bytes[i + 1] << 8) | bytes[i]);
  }
  return String.fromCharCodes(codeUnits);
}

String _bytesToHex(List<int> bytes) =>
    bytes.map((b) => (b & 0xff).toRadixString(16).padLeft(2, '0')).join();

Uint8List _hexToBytes(String hex) {
  final clean = hex.length.isOdd ? hex.substring(0, hex.length - 1) : hex;
  final bytes = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

/// NFC-Forum URI record prefix abbreviations (first payload byte → prefix).
const Map<int, String> _uriPrefixes = {
  0x00: '',
  0x01: 'http://www.',
  0x02: 'https://www.',
  0x03: 'http://',
  0x04: 'https://',
  0x05: 'tel:',
  0x06: 'mailto:',
  0x07: 'ftp://anonymous:anonymous@',
  0x08: 'ftp://ftp.',
  0x09: 'ftps://',
  0x0a: 'sftp://',
  0x0b: 'smb://',
  0x0c: 'nfs://',
  0x0d: 'ftp://',
  0x0e: 'dav://',
  0x0f: 'news:',
  0x10: 'telnet://',
  0x11: 'imap:',
  0x12: 'rtsp://',
  0x13: 'urn:',
  0x14: 'pop:',
  0x15: 'sip:',
  0x16: 'sips:',
  0x17: 'tftp:',
  0x18: 'btspp://',
  0x19: 'btl2cap://',
  0x1a: 'btgoep://',
  0x1b: 'tcpobex://',
  0x1c: 'irdaobex://',
  0x1d: 'file://',
  0x1e: 'urn:epc:id:',
  0x1f: 'urn:epc:tag:',
  0x20: 'urn:epc:pat:',
  0x21: 'urn:epc:raw:',
  0x22: 'urn:epc:',
  0x23: 'urn:nfc:',
};
