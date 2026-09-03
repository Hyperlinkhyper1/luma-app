import 'dart:io';

import 'gallery_media.dart';

/// What the details panel is allowed to change about a file, and the checks
/// that stop it doing damage.
///
/// Renaming and re-dating touch the user's own files, in folders the gallery
/// only borrowed for the afternoon — so every edit is validated before
/// anything is written, and the write itself is a rename or a timestamp
/// touch, never a re-encode.
class GalleryFileEditor {
  const GalleryFileEditor._();

  /// Characters Windows refuses in a file name, plus the separators every
  /// platform reserves.
  static final _illegal = RegExp(r'[<>:"/\\|?*\x00-\x1F]');

  /// Names Windows reserves whatever the extension.
  static const _reservedNames = {
    'con', 'prn', 'aux', 'nul',
    'com1', 'com2', 'com3', 'com4', 'com5', 'com6', 'com7', 'com8', 'com9',
    'lpt1', 'lpt2', 'lpt3', 'lpt4', 'lpt5', 'lpt6', 'lpt7', 'lpt8', 'lpt9',
  };

  /// Why [name] can't be used, or null if it can. The message is shown under
  /// the field, so it says what is wrong *and* what to do about it.
  static String? validateName(String name, {required String originalName}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'A file needs a name.';
    if (trimmed.length > 250) return 'That name is too long — keep it under 250 characters.';
    if (_illegal.hasMatch(trimmed)) {
      return r'A file name can’t contain \ / : * ? " < > |';
    }
    if (trimmed.startsWith('.')) {
      return 'A name starting with a dot would hide the file.';
    }
    if (trimmed.endsWith('.') || trimmed.endsWith(' ')) {
      return 'Names can’t end with a dot or a space.';
    }
    final stem = trimmed.split('.').first.toLowerCase();
    if (_reservedNames.contains(stem)) {
      return '“$stem” is a name Windows reserves. Pick another.';
    }
    if (extensionOf(trimmed) != extensionOf(originalName)) {
      return 'Keep the .${extensionOf(originalName)} ending — changing it '
          'stops the file opening.';
    }
    return null;
  }

  /// Lowercase extension without the dot.
  static String extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  /// Why [taken] can't be used, or null. A date in the future is almost
  /// always a typo, and one before photography existed certainly is.
  static String? validateDate(DateTime taken, {DateTime? now}) {
    final today = now ?? DateTime.now();
    if (taken.isAfter(today.add(const Duration(days: 1)))) {
      return 'That is in the future.';
    }
    if (taken.year < 1826) return 'Photography is not that old.';
    return null;
  }

  /// Applies an edit to the file on disk and returns the updated item.
  ///
  /// Renaming is a real rename; the date is written as the file's modified
  /// time, which is exactly what the desktop scan reads it back from. The
  /// EXIF block inside the photo is deliberately left alone — rewriting it
  /// means re-encoding the picture, and losing quality to correct a date is
  /// a bad trade the user didn't ask for.
  static Future<GalleryEditResult> apply(
    GalleryItem item, {
    String? newName,
    DateTime? newTakenAt,
  }) async {
    final path = item.path ?? item.id;
    final file = File(path);
    if (!file.existsSync()) {
      return const GalleryEditResult.failure('That file is no longer there.');
    }

    var updated = item;
    var currentPath = path;

    if (newName != null && newName.trim() != item.name) {
      final trimmed = newName.trim();
      final error = validateName(trimmed, originalName: item.name);
      if (error != null) return GalleryEditResult.failure(error);

      final separator = currentPath.contains(r'\') ? r'\' : '/';
      final directory =
          currentPath.substring(0, currentPath.lastIndexOf(separator));
      final target = '$directory$separator$trimmed';

      if (File(target).existsSync()) {
        return const GalleryEditResult.failure(
          'A file with that name is already in this folder.',
        );
      }
      try {
        await file.rename(target);
      } on FileSystemException catch (error) {
        return GalleryEditResult.failure(
          'Windows would not rename it: ${error.osError?.message ?? error.message}',
        );
      }
      currentPath = target;
      updated = updated.withFile(name: trimmed, path: target);
    }

    if (newTakenAt != null && newTakenAt != item.takenAt) {
      final error = validateDate(newTakenAt);
      if (error != null) return GalleryEditResult.failure(error);
      try {
        await File(currentPath).setLastModified(newTakenAt);
        updated = updated.withFile(takenAt: newTakenAt);
      } on FileSystemException catch (error) {
        return GalleryEditResult.failure(
          'The date could not be written: '
          '${error.osError?.message ?? error.message}',
        );
      }
    }

    return GalleryEditResult.success(updated);
  }
}

/// The outcome of an edit — the new item, or why nothing changed.
class GalleryEditResult {
  const GalleryEditResult.success(this.item) : error = null;
  const GalleryEditResult.failure(this.error) : item = null;

  final GalleryItem? item;
  final String? error;

  bool get ok => item != null;
}
