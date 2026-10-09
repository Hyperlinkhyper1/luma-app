import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/widgets.dart';

import '../../../../../../l10n/app_localizations.dart';
import '../../../../../converter/file_saver.dart';
import 'mc_style.dart';

/// Saves [bytes] through the platform save dialog and reports the outcome.
Future<void> mcSaveBytes(
  BuildContext context,
  Uint8List bytes, {
  required String fileName,
  required String mimeType,
}) async {
  final dot = fileName.lastIndexOf('.');
  final ext = dot < 0 ? 'bin' : fileName.substring(dot + 1);
  try {
    final result = await saveConvertedFile(
      bytes: bytes,
      suggestedName: fileName,
      mimeType: mimeType,
      extensions: [ext],
    );
    if (!context.mounted || !result.saved) return;
    mcToast(context, result.summary);
  } on Object catch (e) {
    if (context.mounted) mcToast(context, L.of(context).mcCouldNotSave('$e'));
  }
}

Future<void> mcSaveText(
  BuildContext context,
  String text, {
  required String fileName,
  String mimeType = 'application/json',
}) => mcSaveBytes(
  context,
  Uint8List.fromList(utf8.encode(text)),
  fileName: fileName,
  mimeType: mimeType,
);

/// The `pack.mcmeta` for a datapack that loads on 26.1 through 26.3.
String mcPackMeta(String description) =>
    const JsonEncoder.withIndent('  ').convert({
      'pack': {
        'description': description,
        'min_format': [101, 1],
        'max_format': 121,
      },
    });

/// Zips a datapack: `pack.mcmeta` plus [files], keyed by their path inside
/// the pack (`data/<namespace>/...`).
Uint8List mcDatapackZip(String description, Map<String, String> files) {
  final archive = Archive();
  void add(String path, String text) {
    final bytes = utf8.encode(text);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  add('pack.mcmeta', mcPackMeta(description));
  files.forEach(add);
  return ZipEncoder().encodeBytes(archive);
}

/// A namespaced-id-safe version of [text]: lowercase, `[a-z0-9_.-/]` only.
String mcSlug(String text, {String fallback = 'custom'}) {
  final slug = text
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_.\-/]'), '');
  return slug.isEmpty ? fallback : slug;
}
