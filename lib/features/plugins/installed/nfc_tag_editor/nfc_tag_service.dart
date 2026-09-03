import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

import 'nfc_record.dart';

/// Thrown when a scan/write can't start, can't complete, or is refused.
/// [message] is already user-friendly and safe to show directly.
class NfcTagEditorException implements Exception {
  const NfcTagEditorException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A snapshot of what holding a physical tag to the phone found: its
/// technology, UID, NDEF capacity, and the records already on it. A tag that
/// supports NDEF but has never been formatted comes back with [isNdef] false
/// and an empty record list — writing to it formats it in the same tap.
class ScannedNfcTag {
  const ScannedNfcTag({
    required this.techLabel,
    required this.uid,
    required this.isNdef,
    required this.isWritable,
    required this.isLocked,
    required this.maxSize,
    required this.records,
  });

  final String? techLabel;
  final String? uid;
  final bool isNdef;
  final bool isWritable;
  final bool isLocked;
  final int maxSize;
  final List<EditableNdefRecord> records;
}

/// Reads and writes NDEF content on a physical NFC tag. Scanning only runs on
/// Android — the desktop and iOS builds have no in-app tag writer, so the
/// plugin page hides its editing UI everywhere [isSupported] is false.
class NfcTagService {
  const NfcTagService._();

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// True when [isSupported] and the device actually has NFC available/on.
  static Future<bool> isAvailable() async {
    if (!isSupported) return false;
    try {
      return await NfcManager.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Ends any active reader session. Safe to call when none is running.
  static Future<void> stop() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // No active session, or the platform doesn't support NFC.
    }
  }

  /// Waits for a tag and reads whatever NDEF content it carries. Throws
  /// [NfcTagEditorException] for anything that isn't NDEF-capable at all.
  static Future<ScannedNfcTag> scan({
    Duration timeout = const Duration(seconds: 30),
  }) {
    return _runSession<ScannedNfcTag>(
      timeout: timeout,
      onTag: (tag) async {
        final ndef = Ndef.from(tag);
        if (ndef == null) {
          if (NdefFormatable.from(tag) == null) {
            throw const NfcTagEditorException(
              "This tag doesn't support NDEF, so luma can't edit it. Most "
              'blank NFC stickers and cards do — try another tag.',
            );
          }
          return ScannedNfcTag(
            techLabel: _techLabel(tag),
            uid: _extractUid(tag),
            isNdef: false,
            isWritable: true,
            isLocked: false,
            maxSize: 0,
            records: const [],
          );
        }
        final message = ndef.cachedMessage ?? await _tryRead(ndef);
        final records = (message?.records ?? const <NdefRecord>[])
            .map(EditableNdefRecord.fromNdefRecord)
            .toList();
        return ScannedNfcTag(
          techLabel: _techLabel(tag),
          uid: _extractUid(tag),
          isNdef: true,
          isWritable: ndef.isWritable,
          isLocked: !ndef.isWritable,
          maxSize: ndef.maxSize,
          records: records,
        );
      },
    );
  }

  /// Waits for a tag and writes [records] to it, formatting a blank tag if
  /// needed. When [lock] is true the tag is made permanently read-only in the
  /// same tap — this cannot be undone, so callers must confirm with the user
  /// first.
  static Future<void> write(
    List<EditableNdefRecord> records, {
    bool lock = false,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return _runSession<void>(
      timeout: timeout,
      onTag: (tag) async {
        final message = NdefMessage(records.map((r) => r.toNdefRecord()).toList());
        final ndef = Ndef.from(tag);
        if (ndef != null) {
          if (!ndef.isWritable) {
            throw const NfcTagEditorException(
              'This tag is locked read-only and can no longer be written to.',
            );
          }
          if (ndef.maxSize > 0 && message.byteLength > ndef.maxSize) {
            throw NfcTagEditorException(
              "That's ${message.byteLength} bytes, but this tag only holds "
              '${ndef.maxSize}. Remove a record and try again.',
            );
          }
          await ndef.write(message);
          if (lock) await ndef.writeLock();
          return;
        }
        final formatable = NdefFormatable.from(tag);
        if (formatable == null) {
          throw const NfcTagEditorException(
            "This tag can't be written to — it doesn't support NDEF.",
          );
        }
        if (lock) {
          await formatable.formatReadOnly(message);
        } else {
          await formatable.format(message);
        }
      },
    );
  }

  /// Locks whatever is currently on the tag as read-only, without changing
  /// its content. Irreversible — callers must confirm with the user first.
  static Future<void> lock({Duration timeout = const Duration(seconds: 30)}) {
    return _runSession<void>(
      timeout: timeout,
      onTag: (tag) async {
        final ndef = Ndef.from(tag);
        if (ndef == null) {
          throw const NfcTagEditorException(
            "This tag isn't NDEF-formatted, so there's nothing to lock.",
          );
        }
        if (!ndef.isWritable) return; // Already locked.
        await ndef.writeLock();
      },
    );
  }

  static Future<NdefMessage?> _tryRead(Ndef ndef) async {
    try {
      return await ndef.read();
    } catch (_) {
      return null;
    }
  }

  /// Runs one scan-for-a-tag session: starts the reader, waits for either a
  /// tag (handed to [onTag]) or [timeout], and always stops the session
  /// before returning.
  static Future<T> _runSession<T>({
    required Duration timeout,
    required Future<T> Function(NfcTag tag) onTag,
  }) async {
    if (!isSupported) {
      throw const NfcTagEditorException(
        "NFC editing isn't available on this device.",
      );
    }
    if (!await isAvailable()) {
      throw const NfcTagEditorException(
        'NFC is off or unsupported here. Turn it on in your device settings '
        'and try again.',
      );
    }

    final completer = Completer<T>();
    Timer? timer;

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (tag) async {
          timer?.cancel();
          try {
            final result = await onTag(tag);
            if (!completer.isCompleted) completer.complete(result);
          } on NfcTagEditorException catch (e) {
            if (!completer.isCompleted) completer.completeError(e);
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(
                NfcTagEditorException("Couldn't reach that tag. ($e)"),
              );
            }
          } finally {
            await stop();
          }
        },
      );
    } catch (e) {
      // The countdown below hasn't started yet, so there's nothing to cancel.
      await stop();
      throw NfcTagEditorException('Could not start the NFC reader. ($e)');
    }

    timer = Timer(timeout, () async {
      if (!completer.isCompleted) {
        completer.completeError(
          const NfcTagEditorException(
            'No tag detected. Hold it flat against the back of your phone '
            'and try again.',
          ),
        );
        await stop();
      }
    });

    return completer.future;
  }

  /// Formats a tag's hardware identifier as colon-separated uppercase hex.
  /// Digs through the platform-specific [NfcTag.data] map, which nests the
  /// `identifier` bytes under a technology-specific key.
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
  /// present in [NfcTag.data] (Android uses lowercase tech names).
  static String? _techLabel(NfcTag tag) {
    final data = tag.data;
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
}
