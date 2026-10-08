import 'dart:typed_data';

import '../../../../l10n/current_l.dart';
import '../binary_utils.dart';
import '../repair_report.dart';

/// Repairs a Windows bitmap.
///
/// BMP stores the same facts twice — the file header's size and pixel offset
/// are both derivable from the DIB header — which makes it one of the few
/// formats where a wiped header can be genuinely rebuilt rather than guessed.
Uint8List repairBmp(Uint8List bytes, RepairLog log) {
  if (bytes.length < 30) {
    log.failed(currentL.repairBmpTooShort);
    return bytes;
  }

  final data = Uint8List.fromList(bytes);

  if (!matchesAt(data, 0, asciiBytes('BM'))) {
    data.setRange(0, 2, asciiBytes('BM'));
    log.fixed(currentL.repairBmpMagicRewritten);
  }

  final declaredSize = readU32le(data, 2);
  if (declaredSize != data.length) {
    writeU32le(data, 2, data.length);
    log.fixed(currentL.repairBmpSizeCorrected(declaredSize, data.length));
  }

  final dibSize = readU32le(data, 14);
  if (!const [12, 40, 52, 56, 64, 108, 124].contains(dibSize)) {
    log.failed(currentL.repairBmpDibUnknown(dibSize));
    return data;
  }

  int width;
  int height;
  int bitsPerPixel;
  int paletteEntries = 0;
  if (dibSize == 12) {
    width = readU16le(data, 18);
    height = readU16le(data, 20);
    bitsPerPixel = readU16le(data, 24);
  } else {
    width = readU32le(data, 18);
    height = readU32le(data, 22);
    bitsPerPixel = readU16le(data, 28);
    if (dibSize >= 40 && 14 + 36 <= data.length) {
      paletteEntries = readU32le(data, 46);
    }
  }
  // Height is signed: a negative value means the rows are stored top-down.
  if (height > 0x7FFFFFFF) height = 0x100000000 - height;

  if (width <= 0 || height <= 0 || bitsPerPixel == 0) {
    log.failed(
      currentL.repairBmpDimensionsImpossible(width, height, bitsPerPixel),
    );
    return data;
  }
  log.info(currentL.repairBmpImageInfo(width, height, bitsPerPixel));

  if (paletteEntries == 0 && bitsPerPixel <= 8) {
    paletteEntries = 1 << bitsPerPixel;
  }
  final paletteBytes = paletteEntries * (dibSize == 12 ? 3 : 4);
  final expectedOffset = 14 + dibSize + paletteBytes;
  final declaredOffset = readU32le(data, 10);
  if (declaredOffset != expectedOffset) {
    writeU32le(data, 10, expectedOffset);
    log.fixed(
      currentL.repairBmpOffsetRecalculated(expectedOffset, declaredOffset),
    );
  }

  // Rows are padded out to a 4-byte boundary.
  final rowBytes = (((width * bitsPerPixel) + 31) ~/ 32) * 4;
  final needed = expectedOffset + rowBytes * height;
  if (needed > data.length) {
    final missing = needed - data.length;
    log.fixed(currentL.repairBmpPadded(formatSize(missing)));
    final padded = Uint8List(needed);
    padded.setRange(0, data.length, data);
    writeU32le(padded, 2, padded.length);
    return padded;
  }
  if (needed < data.length) {
    log.fixed(currentL.repairBmpTrimmed(formatSize(data.length - needed)));
    final trimmed = data.sublist(0, needed);
    writeU32le(trimmed, 2, trimmed.length);
    return trimmed;
  }

  return data;
}
