import 'package:flutter/material.dart';

/// The icons a dashboard button can wear. Stored by key so the JSON file
/// never holds a codepoint.
const commandIcons = <String, IconData>{
  'terminal': Icons.terminal_rounded,
  'dns': Icons.dns_rounded,
  'web': Icons.language_rounded,
  'code': Icons.code_rounded,
  'build': Icons.build_rounded,
  'play': Icons.play_circle_rounded,
  'wifi': Icons.wifi_rounded,
  'storage': Icons.storage_rounded,
  'folder': Icons.folder_rounded,
  'cloud': Icons.cloud_rounded,
  'bolt': Icons.bolt_rounded,
  'games': Icons.sports_esports_rounded,
  'cleaning': Icons.cleaning_services_rounded,
  'restart': Icons.restart_alt_rounded,
};

IconData commandIcon(String key) =>
    commandIcons[key] ?? Icons.terminal_rounded;

const monoStyle = TextStyle(
  fontFamily: 'Consolas',
  fontFamilyFallback: ['Menlo', 'monospace'],
);
