import 'dart:typed_data';

import '../../../../l10n/current_l.dart';
import '../binary_utils.dart';
import '../repair_report.dart';

/// Repairs a RIFF container — WAV, AVI and WebP all use it.
///
/// The classic broken WAV is a recording that stopped before the writer went
/// back to fill in the size fields, leaving a header that claims a length the
/// file does not have. Correcting those two numbers is usually the whole fix.
Uint8List repairRiff(Uint8List bytes, RepairLog log) {
  if (bytes.length < 12) {
    log.failed(currentL.repairRiffTooShort);
    return bytes;
  }

  final data = Uint8List.fromList(bytes);

  if (!matchesAt(data, 0, asciiBytes('RIFF'))) {
    data.setRange(0, 4, asciiBytes('RIFF'));
    log.fixed(currentL.repairRiffMagicRewritten);
  }

  var form = String.fromCharCodes(data, 8, 12);
  if (form != 'WAVE' && form != 'AVI ' && form != 'WEBP') {
    // The chunk names further in say what this was meant to be.
    if (indexOfBytes(data, asciiBytes('fmt '), 12, 4096) >= 0) {
      form = 'WAVE';
    } else if (indexOfBytes(data, asciiBytes('hdrl'), 12, 4096) >= 0) {
      form = 'AVI ';
    } else if (indexOfBytes(data, asciiBytes('VP8'), 12, 4096) >= 0) {
      form = 'WEBP';
    } else {
      log.failed(currentL.repairRiffUnreadableForm);
      return data;
    }
    data.setRange(8, 12, asciiBytes(form));
    log.fixed(currentL.repairRiffFormRestored(form));
  }

  final declaredRiffSize = readU32le(data, 4);
  final actualRiffSize = data.length - 8;
  if (declaredRiffSize != actualRiffSize) {
    writeU32le(data, 4, actualRiffSize);
    log.fixed(
      currentL.repairRiffLengthCorrected(declaredRiffSize, actualRiffSize),
    );
  }

  var offset = 12;
  var sawFmt = false;
  var lastChunkStart = -1;

  while (offset + 8 <= data.length) {
    final id = String.fromCharCodes(data, offset, offset + 4);
    if (!_isChunkId(id)) {
      log.warning(currentL.repairRiffUnreadableChunk(formatOffset(offset)));
      break;
    }
    final size = readU32le(data, offset + 4);
    if (id == 'fmt ') sawFmt = true;

    if (offset + 8 + size > data.length) {
      // The last chunk is the one a cut-short recording leaves dangling.
      final available = data.length - offset - 8;
      writeU32le(data, offset + 4, available);
      log.fixed(
        currentL.repairRiffChunkClamped(
          id,
          formatSize(size),
          formatSize(available),
        ),
      );
      lastChunkStart = offset;
      // The clamped chunk now runs to the end of the file, so there is no
      // trailing junk left to trim.
      offset = data.length;
      break;
    }
    lastChunkStart = offset;
    // Chunks are padded to an even length.
    offset += 8 + size + (size.isOdd ? 1 : 0);
  }

  if (form == 'WAVE' && !sawFmt) {
    log.failed(currentL.repairRiffNoFmt);
  }

  if (lastChunkStart >= 0 && offset < data.length && offset > 12) {
    final trailing = data.length - offset;
    if (trailing > 0 && trailing < data.length) {
      log.fixed(currentL.repairRiffTrailingTrimmed(formatSize(trailing)));
      final trimmed = data.sublist(0, offset);
      writeU32le(trimmed, 4, trimmed.length - 8);
      return trimmed;
    }
  }

  return data;
}

bool _isChunkId(String id) {
  if (id.length != 4) return false;
  for (final unit in id.codeUnits) {
    if (unit < 0x20 || unit > 0x7E) return false;
  }
  return true;
}
