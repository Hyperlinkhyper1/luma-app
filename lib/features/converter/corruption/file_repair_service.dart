import 'dart:typed_data';

import 'binary_utils.dart';
import 'corruption_recipe.dart';
import 'file_signatures.dart';
import 'repair_report.dart';
import 'repairers/bmp_repair.dart';
import 'repairers/gif_repair.dart';
import 'repairers/jpeg_repair.dart';
import 'repairers/mp3_repair.dart';
import 'repairers/mp4_repair.dart';
import 'repairers/pdf_repair.dart';
import 'repairers/png_repair.dart';
import 'repairers/riff_repair.dart';
import 'repairers/zip_repair.dart';

/// Puts damaged files back together.
class FileRepairService {
  FileRepairService._();

  /// Undoes a corruption using the recipe that recorded it.
  static RepairResult restoreFromRecipe({
    required Uint8List corrupted,
    required CorruptionRecipe recipe,
    required String corruptedName,
  }) {
    final log = RepairLog();

    final actualHash = sha256Hex(corrupted);
    if (recipe.corruptedSha256.isNotEmpty &&
        actualHash != recipe.corruptedSha256) {
      log.warning(
        'This recipe was written for a different file than the one you opened. '
        'Undoing it anyway will almost certainly produce nonsense.',
      );
      if (corrupted.length != recipe.corruptedSize) {
        throw FormatException(
          'That recipe belongs to a ${formatSize(recipe.corruptedSize)} file, '
          'but the one you opened is ${formatSize(corrupted.length)}. Pick the '
          'matching pair.',
        );
      }
    }

    if (!recipe.fullyReversible) {
      final lost = recipe.ops.where((op) => !op.canUndo).length;
      throw FormatException(
        'This recipe has $lost step${lost == 1 ? '' : 's'} that destroyed bytes '
        'without recording them, so the original cannot be rebuilt from it.',
      );
    }

    final Uint8List restored;
    try {
      restored = recipe.restore(corrupted);
    } on StateError catch (e) {
      throw FormatException(e.message);
    }

    for (final op in recipe.ops.reversed) {
      log.fixed('Undid: ${op.describe()}');
    }

    final matched =
        recipe.originalSha256.isNotEmpty &&
        sha256Hex(restored) == recipe.originalSha256;
    if (matched) {
      log.info(
        'The result matches the original checksum exactly — this is the file '
        'that was corrupted, byte for byte.',
      );
    } else if (recipe.originalSha256.isNotEmpty) {
      log.warning(
        'The rebuilt file does not match the checksum recorded when it was '
        'corrupted, so something else changed it after the fact.',
      );
    }

    return RepairResult(
      bytes: restored,
      notes: log.notes,
      formatLabel: 'Restored from recipe',
      suggestedName: recipe.originalName.isEmpty
          ? _restoredName(corruptedName)
          : recipe.originalName,
      changed: true,
      restoredExactly: matched,
    );
  }

  /// Works out what a damaged file is and rebuilds what can be rebuilt.
  static RepairResult repair(Uint8List bytes, String fileName) {
    final log = RepairLog();
    if (bytes.isEmpty) {
      throw const FormatException(
        'That file is empty — there is nothing in it '
        'to repair.',
      );
    }

    final extension = FileSignatures.extensionOf(fileName);
    var data = bytes;
    var signature = FileSignatures.detectAt(data);

    // The file's own name is the best hint about what to look for, so try that
    // signature before casting around for any signature at all.
    if (signature == null) {
      final expected = FileSignatures.byExtension(extension);
      if (expected != null) {
        final at = FileSignatures.findSpecific(data, expected);
        if (at > 0) {
          log.fixed(
            'Found the ${expected.label} header ${formatSize(at)} into the '
            'file and dropped everything before it.',
          );
          data = data.sublist(at);
          signature = expected;
        }
      }
    }

    if (signature == null) {
      final found = FileSignatures.findSignature(data);
      if (found != null) {
        final (candidate, at) = found;
        if (at > 0) {
          log.fixed(
            'Found a ${candidate.label} starting ${formatSize(at)} into the '
            'file and dropped everything before it.',
          );
          data = data.sublist(at);
          signature = candidate;
        }
      }
    }

    if (signature == null) {
      final guess = FileSignatures.byExtension(extension);
      if (guess != null) {
        log.warning(
          'The header is gone, so nothing in the bytes says what this is. '
          'Going by the .$extension name and treating it as a ${guess.label}.',
        );
        signature = guess;
      }
    }

    if (signature == null) {
      log.failed(
        'This does not start with any file signature luma recognises, and the '
        'name gives nothing away either. Only the generic checks were run.',
      );
      final repaired = _repairGeneric(data, log);
      return _build(repaired, bytes, log, 'Unknown format', fileName);
    }

    if (extension.isNotEmpty &&
        !FileSignatures.extensionFits(signature, extension)) {
      log.warning(
        'The file is named .$extension but the bytes are a ${signature.label}. '
        'Saving it as .${signature.extension} will make it open again.',
      );
    }

    final Uint8List repaired;
    switch (signature.family) {
      case RepairFamily.png:
        repaired = repairPng(data, log);
      case RepairFamily.jpeg:
        repaired = repairJpeg(data, log);
      case RepairFamily.gif:
        repaired = repairGif(data, log);
      case RepairFamily.bmp:
        repaired = repairBmp(data, log);
      case RepairFamily.zip:
        repaired = repairZip(data, log, extension: extension);
      case RepairFamily.pdf:
        repaired = repairPdf(data, log);
      case RepairFamily.riff:
        repaired = repairRiff(data, log);
      case RepairFamily.mp3:
        repaired = repairMp3(data, log);
      case RepairFamily.mp4:
        repaired = repairMp4(data, log);
      case RepairFamily.generic:
        log.info(
          'luma knows this is a ${signature.label} but has no structural '
          'repairer for that format, so only the generic checks ran.',
        );
        repaired = _repairGeneric(data, log);
    }

    return _build(
      repaired,
      bytes,
      log,
      signature.label,
      fileName,
      signature: signature,
    );
  }

  /// The checks that apply whatever the file turns out to be.
  static Uint8List _repairGeneric(Uint8List bytes, RepairLog log) {
    var data = bytes;

    // A run of zeroes on the end is what a half-written copy leaves behind.
    var end = data.length;
    while (end > 0 && data[end - 1] == 0) {
      end--;
    }
    final zeroes = data.length - end;
    if (zeroes > 64 && zeroes > data.length ~/ 100) {
      log.fixed(
        'Trimmed ${formatSize(zeroes)} of zero-fill from the end, which is '
        'what an interrupted copy leaves behind.',
      );
      data = data.sublist(0, end);
    }

    if (data.isEmpty) {
      log.failed('Nothing but padding was left once the zero-fill came off.');
    }
    return data;
  }

  static RepairResult _build(
    Uint8List repaired,
    Uint8List original,
    RepairLog log,
    String label,
    String fileName, {
    FileSignature? signature,
  }) {
    final changed =
        repaired.length != original.length || !_sameBytes(repaired, original);
    if (!changed && !log.anyFailed) {
      log.info('Nothing needed changing — the structure already checks out.');
    }
    return RepairResult(
      bytes: repaired,
      notes: log.notes,
      formatLabel: label,
      suggestedName: _fixedName(fileName, signature),
      changed: changed,
      restoredExactly: false,
    );
  }

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// `photo.corrupt.png` → `photo.fixed.png`, correcting the extension when
  /// the bytes turned out to be something else.
  static String _fixedName(String original, FileSignature? signature) {
    var base = original;
    var extension = FileSignatures.extensionOf(original);
    final dot = base.lastIndexOf('.');
    if (dot > 0) base = base.substring(0, dot);
    if (base.endsWith('.corrupt')) {
      base = base.substring(0, base.length - '.corrupt'.length);
    }
    if (signature != null &&
        !FileSignatures.extensionFits(signature, extension)) {
      extension = signature.extension;
    }
    if (extension.isEmpty) extension = 'bin';
    return '$base.fixed.$extension';
  }

  static String _restoredName(String corruptedName) {
    var base = corruptedName;
    final dot = base.lastIndexOf('.');
    final extension = dot > 0 ? base.substring(dot) : '';
    if (dot > 0) base = base.substring(0, dot);
    if (base.endsWith('.corrupt')) {
      base = base.substring(0, base.length - '.corrupt'.length);
    }
    return '$base.restored$extension';
  }
}
