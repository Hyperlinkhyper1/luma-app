import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

/// What we managed to pull off a scanned tag: the value to store on the card
/// plus a short label for where it came from (a memory dump, an NDEF record,
/// or the tag UID).
class NfcScanResult {
  const NfcScanResult({required this.payload, required this.source});

  final String payload;
  final String source;
}

/// Thrown when a scan can't start, can't complete, or is refused for safety
/// (payment cards). [message] is already user-friendly and safe to show.
class NfcScanException implements Exception {
  const NfcScanException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads a physical NFC tag and turns its contents into a string we can store
/// on a wallet card, so a tap-only card — a hotel keycard, an OV-chipkaart, an
/// MSC wristband — can be captured by holding it to the phone.
///
/// For plain memory cards (MIFARE Classic, MIFARE Ultralight / NTAG) it dumps
/// the readable blocks/pages as hex. For NDEF tags it decodes the records.
/// Bank / credit cards are deliberately refused: luma detects the contactless
/// payment application and never reads a payment card's data.
///
/// Real scanning only runs on Android and iOS; everywhere else [isSupported]
/// is false and the editor falls back to manual entry.
class CardWalletNfc {
  const CardWalletNfc._();

  /// Whether this build can reach NFC hardware at all. Desktop and web can't.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// True when [isSupported] and the device actually has NFC available/on.
  static Future<bool> isAvailable() async {
    if (!isSupported) return false;
    try {
      return await NfcManager.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Waits for a single tag and returns its contents. Throws
  /// [NfcScanException] if NFC is off, the tag is a payment card, the read
  /// fails, or [detectTimeout] elapses before a tag is presented. The reader
  /// session is always stopped before returning.
  static Future<NfcScanResult> scan({
    Duration detectTimeout = const Duration(seconds: 30),
  }) async {
    if (!isSupported) {
      throw const NfcScanException(
        "NFC scanning isn't available on this device.",
      );
    }
    if (!await isAvailable()) {
      throw const NfcScanException(
        'NFC is off or unsupported here. Turn it on in your device settings '
        'and try again.',
      );
    }

    final completer = Completer<NfcScanResult>();
    Timer? timer;

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          // A tag is in hand — stop the "no tag" countdown; the read itself
          // (a 4K card can hold a lot) is allowed to take as long as it needs.
          timer?.cancel();
          try {
            final result = await _readTag(tag);
            if (!completer.isCompleted) completer.complete(result);
          } on NfcScanException catch (e) {
            if (!completer.isCompleted) completer.completeError(e);
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(
                const NfcScanException(
                  "Couldn't read that tag — it looks empty or unsupported.",
                ),
              );
            }
          } finally {
            await stop();
          }
        },
      );
    } catch (e) {
      timer?.cancel();
      await stop();
      throw NfcScanException('Could not start the NFC reader. ($e)');
    }

    timer = Timer(detectTimeout, () async {
      if (!completer.isCompleted) {
        completer.completeError(
          const NfcScanException(
            'No tag detected. Hold the card flat against the back of your '
            'phone and try again.',
          ),
        );
        await stop();
      }
    });

    return completer.future;
  }

  /// Ends any active reader session. Safe to call when none is running.
  static Future<void> stop() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // No active session, or the platform doesn't support NFC — nothing to do.
    }
  }

  /// Reads whatever a discovered tag will safely give up, refusing payment
  /// cards outright. Prefers a full memory dump (Classic / Ultralight), then
  /// NDEF records, and always includes the tech type and UID as a header.
  static Future<NfcScanResult> _readTag(NfcTag tag) async {
    // Security boundary: never read the application data of a contactless
    // bank / credit card. The user asked for this explicitly, and it keeps a
    // PAN from ever landing in the wallet.
    if (await _isPaymentCard(tag)) {
      throw const NfcScanException(
        "That looks like a bank or credit card — luma won't copy payment "
        'cards for your security. Add a loyalty, hotel, transit or event '
        'card instead.',
      );
    }

    final sections = <String>[];
    var source = 'tag UID';

    // Header: friendly tech name + UID.
    final header = StringBuffer();
    final tech = _techLabel(tag);
    final uid = _extractUid(tag);
    if (tech != null) header.writeln(tech);
    if (uid != null) header.writeln('UID: $uid');
    if (header.isNotEmpty) sections.add(header.toString().trimRight());

    // MIFARE Classic — hotel keycards, NS OV-chipkaart, many access cards.
    final classic = await _dumpMifareClassic(tag);
    if (classic != null) {
      sections.add(classic);
      source = 'MIFARE Classic';
    } else {
      // MIFARE Ultralight / NTAG — wristbands (MSC), event and hotel tags.
      final ultralight = await _dumpMifareUltralight(tag);
      if (ultralight != null) {
        sections.add(ultralight);
        source = 'MIFARE Ultralight';
      }
    }

    // NDEF text / URI records, if the tag carries any.
    final ndef = Ndef.from(tag);
    if (ndef != null) {
      final message = ndef.cachedMessage ?? await _tryReadNdef(ndef);
      if (message != null && message.records.isNotEmpty) {
        final decoded = _decodeNdef(message.records);
        if (decoded != null && decoded.trim().isNotEmpty) {
          sections.add('NDEF:\n${decoded.trim()}');
          if (source == 'tag UID') source = 'NDEF record';
        }
      }
    }

    final payload =
        sections.where((s) => s.trim().isNotEmpty).join('\n\n').trim();
    if (payload.isEmpty) {
      throw const NfcScanException(
        "Couldn't read anything off that tag — it may be empty or locked.",
      );
    }
    return NfcScanResult(payload: payload, source: source);
  }

  // ---- Payment-card guard ---------------------------------------------------

  /// True when the tag responds to the contactless payment directory
  /// (`2PAY.SYS.DDF01`). Only the directory is selected — no account records
  /// are ever read — purely so luma can recognise and refuse a bank card.
  static Future<bool> _isPaymentCard(NfcTag tag) async {
    final iso = IsoDep.from(tag);
    if (iso == null) return false;
    // SELECT PPSE — the entry point every contactless EMV card exposes.
    final selectPpse = Uint8List.fromList([
      0x00, 0xA4, 0x04, 0x00, 0x0e, // CLA INS P1 P2 Lc
      0x32, 0x50, 0x41, 0x59, 0x2e, 0x53, 0x59, 0x53, // "2PAY.SYS"
      0x2e, 0x44, 0x44, 0x46, 0x30, 0x31, // ".DDF01"
      0x00, // Le
    ]);
    try {
      final resp = await iso.transceive(data: selectPpse);
      if (resp.length < 2) return false;
      final sw1 = resp[resp.length - 2];
      final sw2 = resp[resp.length - 1];
      // 0x9000 = OK, 0x61xx = OK with more data available.
      return (sw1 == 0x90 && sw2 == 0x00) || sw1 == 0x61;
    } catch (_) {
      return false;
    }
  }

  // ---- Memory dumps ---------------------------------------------------------

  /// Reads every MIFARE Classic block we can unlock with a well-known key.
  /// Sectors protected by non-default keys (e.g. most OV-chipkaart data) are
  /// skipped, so we return whatever is readable rather than failing. Returns
  /// null when the tag isn't a Classic card (including on iOS, which can't
  /// read Classic).
  static Future<String?> _dumpMifareClassic(NfcTag tag) async {
    final mc = MifareClassic.from(tag);
    if (mc == null) return null;

    final sectorCount = mc.sectorCount;
    final buffer = StringBuffer();
    var readAny = false;

    for (var sector = 0; sector < sectorCount; sector++) {
      final unlocked = await _authenticateSector(mc, sector);
      if (!unlocked) continue;

      final first = _firstBlockOfSector(sector);
      final count = _blocksInSector(sector);
      for (var i = 0; i < count; i++) {
        final blockIndex = first + i;
        try {
          final data = await mc.readBlock(blockIndex: blockIndex);
          buffer.writeln('Block ${_pad(blockIndex, 3)}: ${_hex(data)}');
          readAny = true;
        } catch (_) {
          // Trailer/permission-locked block — skip it.
        }
      }
    }

    return readAny ? buffer.toString().trimRight() : null;
  }

  /// Tries the common default keys (A then B) against a sector.
  static Future<bool> _authenticateSector(
    MifareClassic mc,
    int sector,
  ) async {
    for (final key in _classicDefaultKeys) {
      try {
        if (await mc.authenticateSectorWithKeyA(sectorIndex: sector, key: key)) {
          return true;
        }
      } catch (_) {
        // Wrong key / transient error — try the next one.
      }
    }
    for (final key in _classicDefaultKeys) {
      try {
        if (await mc.authenticateSectorWithKeyB(sectorIndex: sector, key: key)) {
          return true;
        }
      } catch (_) {
        // Wrong key / transient error — try the next one.
      }
    }
    return false;
  }

  /// Reads MIFARE Ultralight / NTAG pages until the memory runs out (the read
  /// throws or wraps back to page 0). Returns null when the tag isn't an
  /// Ultralight-family tag.
  static Future<String?> _dumpMifareUltralight(NfcTag tag) async {
    final mu = MifareUltralight.from(tag);
    if (mu == null) return null;

    final buffer = StringBuffer();
    Uint8List? firstChunk;
    var readAny = false;

    // READ returns 4 pages (16 bytes) at a time; cap well past the largest
    // NTAG216 (231 pages) so a misbehaving tag can't loop forever.
    for (var page = 0; page < 240; page += 4) {
      Uint8List chunk;
      try {
        chunk = await mu.readPages(pageOffset: page);
      } catch (_) {
        break; // Past the end of memory — done.
      }
      if (chunk.isEmpty) break;
      // Ultralight READ wraps around at the end of memory; a repeat of page 0
      // means we've looped, so stop.
      if (page > 0 && firstChunk != null && _bytesEqual(chunk, firstChunk)) {
        break;
      }
      firstChunk ??= chunk;

      for (var i = 0; i < chunk.length; i += 4) {
        final end = (i + 4 <= chunk.length) ? i + 4 : chunk.length;
        buffer.writeln(
          'Page ${_pad(page + i ~/ 4, 3)}: ${_hex(chunk.sublist(i, end))}',
        );
      }
      readAny = true;
    }

    return readAny ? buffer.toString().trimRight() : null;
  }

  // ---- NDEF decoding --------------------------------------------------------

  static Future<NdefMessage?> _tryReadNdef(Ndef ndef) async {
    try {
      return await ndef.read();
    } catch (_) {
      return null;
    }
  }

  /// Joins every readable NDEF record into a single string.
  static String? _decodeNdef(List<NdefRecord> records) {
    final parts = <String>[];
    for (final record in records) {
      final text = _decodeRecord(record);
      if (text != null && text.trim().isNotEmpty) parts.add(text.trim());
    }
    return parts.isEmpty ? null : parts.join('\n');
  }

  /// Decodes a single NDEF record. Handles NFC-Forum Well-Known Text ('T') and
  /// URI ('U') records precisely, and falls back to a best-effort UTF-8 read of
  /// the raw payload for anything else.
  static String? _decodeRecord(NdefRecord record) {
    final payload = record.payload;
    final type = record.type;
    final wellKnown =
        record.typeNameFormat == NdefTypeNameFormat.nfcWellknown;

    if (wellKnown && type.length == 1 && payload.isNotEmpty) {
      // Text record: first byte is a status byte (bit 7 = UTF-16, low 6 bits =
      // IANA language-code length), then the language code, then the text.
      if (type.first == 0x54) {
        final status = payload.first;
        final langLen = status & 0x3f;
        final isUtf16 = (status & 0x80) != 0;
        if (payload.length > 1 + langLen) {
          final textBytes = payload.sublist(1 + langLen);
          return isUtf16
              ? _decodeUtf16(textBytes)
              : utf8.decode(textBytes, allowMalformed: true);
        }
        return '';
      }
      // URI record: first byte is an abbreviation prefix, rest is the URI.
      if (type.first == 0x55) {
        final prefix = _uriPrefixes[payload.first] ?? '';
        final rest = utf8.decode(payload.sublist(1), allowMalformed: true);
        return '$prefix$rest';
      }
    }

    // Unknown record type: keep only the printable characters, if any.
    final raw = utf8.decode(payload, allowMalformed: true);
    final printable =
        raw.replaceAll(RegExp(r'[\x00-\x08\x0e-\x1f\x7f]'), '').trim();
    return printable.isEmpty ? null : printable;
  }

  // ---- Low-level helpers ----------------------------------------------------

  /// Formats a tag's hardware identifier as colon-separated uppercase hex,
  /// e.g. `04:A2:2C:19`. Digs through the platform-specific [NfcTag.data] map,
  /// which nests the `identifier` bytes under a technology-specific key.
  static String? _extractUid(NfcTag tag) {
    final identifier = _findIdentifier(tag.data);
    if (identifier == null || identifier.isEmpty) return null;
    return identifier
        .map((b) => (b & 0xff).toRadixString(16).padLeft(2, '0'))
        .join(':')
        .toUpperCase();
  }

  static List<int>? _findIdentifier(Object? node) {
    if (node is Map) {
      final id = node['identifier'];
      if (id is List && id.isNotEmpty && id.every((e) => e is int)) {
        return id.cast<int>();
      }
      for (final value in node.values) {
        final found = _findIdentifier(value);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// A human-friendly name for the tag technology, derived from the keys
  /// present in [NfcTag.data] (Android uses lowercase tech names; iOS uses
  /// its own). Returns null when nothing is recognised.
  static String? _techLabel(NfcTag tag) {
    final data = tag.data;
    if (data is! Map) return null;
    const names = <String, String>{
      'mifareclassic': 'MIFARE Classic',
      'mifareultralight': 'MIFARE Ultralight / NTAG',
      'mifare': 'MIFARE',
      'isodep': 'ISO-DEP smartcard',
      'iso7816': 'ISO-7816 smartcard',
      'iso15693': 'NFC-V (ISO 15693)',
      'nfcv': 'NFC-V (ISO 15693)',
      'felica': 'FeliCa',
      'nfcf': 'FeliCa (NFC-F)',
      'nfca': 'NFC-A (ISO 14443-A)',
      'nfcb': 'NFC-B (ISO 14443-B)',
    };
    for (final entry in names.entries) {
      if (data.containsKey(entry.key)) return entry.value;
    }
    return null;
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String _hex(List<int> bytes) => bytes
      .map((b) => (b & 0xff).toRadixString(16).padLeft(2, '0'))
      .join(' ')
      .toUpperCase();

  static String _pad(int value, int width) =>
      value.toString().padLeft(width, '0');

  static String _decodeUtf16(List<int> bytes) {
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

  /// Standard MIFARE Classic layout: sectors 0-31 hold 4 blocks, sectors 32+
  /// (4K only) hold 16. Works for 1K (all sectors < 32) and 4K alike.
  static int _blocksInSector(int sector) => sector < 32 ? 4 : 16;

  static int _firstBlockOfSector(int sector) =>
      sector < 32 ? sector * 4 : 128 + (sector - 32) * 16;

  /// Factory / widely-published MIFARE Classic keys, tried in turn. These
  /// unlock the readable sectors on hotel and event cards that were never
  /// re-keyed; properly secured cards (OV transit data) simply stay locked.
  static final List<Uint8List> _classicDefaultKeys = [
    Uint8List.fromList([0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
    Uint8List.fromList([0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5]),
    Uint8List.fromList([0xd3, 0xf7, 0xd3, 0xf7, 0xd3, 0xf7]),
    Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
    Uint8List.fromList([0xb0, 0xb1, 0xb2, 0xb3, 0xb4, 0xb5]),
    Uint8List.fromList([0x4d, 0x3a, 0x99, 0xc3, 0x51, 0xdd]),
    Uint8List.fromList([0x1a, 0x98, 0x2c, 0x7e, 0x45, 0x9a]),
    Uint8List.fromList([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]),
  ];

  /// NFC-Forum URI record prefix abbreviations (first payload byte → prefix).
  static const Map<int, String> _uriPrefixes = {
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
}
