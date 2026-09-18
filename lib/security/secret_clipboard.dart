import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

/// Best-effort clipboard expiry. OS clipboard history and other processes
/// remain outside this API's control. Only a digest is retained by the timer.
class SecretClipboard {
  static Timer? _timer;
  static int _generation = 0;

  static Future<void> copy(
    String value, {
    Duration clearAfter = const Duration(seconds: 30),
  }) async {
    final generation = ++_generation;
    _timer?.cancel();
    await Clipboard.setData(ClipboardData(text: value));
    if (generation != _generation) return;
    _schedule(
      sha256.convert(utf8.encode(value)).toString(),
      generation,
      clearAfter,
    );
  }

  static void _schedule(String digest, int generation, Duration delay) {
    _timer = Timer(delay, () async {
      try {
        final current = await Clipboard.getData(Clipboard.kTextPlain);
        if (generation == _generation &&
            current?.text != null &&
            sha256.convert(utf8.encode(current!.text!)).toString() == digest) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      } catch (_) {
        // Clipboard access may be denied while the app is backgrounded.
      }
    });
  }
}
