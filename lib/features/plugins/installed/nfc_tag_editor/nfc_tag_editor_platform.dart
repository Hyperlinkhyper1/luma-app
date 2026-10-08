import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import '../../../../l10n/app_localizations.dart';

/// Where the NFC Tag Editor can actually scan and write tags. Only Android
/// exposes the reader/writer NDEF APIs this plugin needs, so Windows, macOS,
/// Linux and iOS all see an explanatory empty state instead of the editor.
class NfcTagEditorPlatform {
  const NfcTagEditorPlatform._();

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static String unsupportedNotice(L t) => t.nfcUnsupportedNotice;
}
