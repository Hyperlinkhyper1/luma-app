import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:nfc_manager/nfc_manager.dart';

/// What we managed to pull off a scanned tag: the value to store on the card
/// plus a short label for where it came from (an NDEF record or the tag UID).
class NfcScanResult {
  const NfcScanResult({required this.payload, required this.source});

  final String payload;
  final String source;
}

/// Thrown when a scan can't start or complete. [message] is already
/// user-friendly and safe to show in the UI.
class NfcScanException implements Exception {
  const NfcScanException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads a physical NFC tag and turns it into a string we can store on a wallet
/// card, so a card with a tap-only tag can be captured by holding it to the
/// phone instead of typing the payload out by hand.
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
  /// [NfcScanException] if NFC is off, the read fails, or [timeout] elapses.
  /// The reader session is always stopped before returning.
  static Future<NfcScanResult> scan({
    Duration timeout = const Duration(seconds: 30),
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

    Future<void> finish() async {
      timer?.cancel();
      await stop();
    }

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final result = _readTag(tag);
            if (!completer.isCompleted) completer.complete(result);
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(
                const NfcScanException(
                  "Couldn't read that tag — it looks empty or unsupported.",
                ),
              );
            }
          } finally {
            await finish();
          }
        },
      );
    } catch (e) {
      await finish();
      throw NfcScanException('Could not start the NFC reader. ($e)');
    }

    timer = Timer(timeout, () async {
      if (!completer.isCompleted) {
        completer.completeError(
          const NfcScanException(
            'No tag detected. Hold the card flat against the back of your '
            'phone and try again.',
          ),
        );
      }
      await finish();
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

  /// Pulls the most useful string out of a discovered tag: a decoded NDEF
  /// record when the tag carries one, otherwise the hardware UID as hex.
  static NfcScanResult _readTag(NfcTag tag) {
    final ndef = Ndef.from(tag);
    final message = ndef?.cachedMessage;
    if (message != null && message.records.isNotEmpty) {
      final decoded = _decodeNdef(message.records);
      if (decoded != null && decoded.trim().isNotEmpty) {
        return NfcScanResult(payload: decoded.trim(), source: 'NDEF record');
      }
    }

    final uid = _extractUid(tag);
    if (uid != null && uid.isNotEmpty) {
      return NfcScanResult(payload: uid, source: 'tag UID');
    }

    throw StateError('empty tag');
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
