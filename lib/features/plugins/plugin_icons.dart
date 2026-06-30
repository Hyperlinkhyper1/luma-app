import 'package:flutter/material.dart';

/// Maps a plugin manifest's `icon` string to a Material icon. Plugins are
/// data fetched at runtime, so icons are looked up by name rather than
/// shipped as assets — unknown names fall back to a generic plug icon.
IconData pluginIconFor(String? name) {
  switch (name) {
    case 'qr_code_2':
      return Icons.qr_code_2_rounded;
    default:
      return Icons.extension_rounded;
  }
}
