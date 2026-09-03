import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Where the NFC Tag Editor can actually scan and write tags. Only Android
/// exposes the reader/writer NDEF APIs this plugin needs, so Windows, macOS,
/// Linux and iOS all see an explanatory empty state instead of the editor.
class NfcTagEditorPlatform {
  const NfcTagEditorPlatform._();

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const String unsupportedNotice =
      'NFC Tag Editor needs Android\'s NFC hardware and reader APIs, so it '
      "only works on an Android phone or tablet — there's nothing to scan "
      'or write here.';
}
