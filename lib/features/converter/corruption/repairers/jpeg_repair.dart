import 'dart:typed_data';

import '../binary_utils.dart';
import '../repair_report.dart';

const List<int> _soi = [0xFF, 0xD8];
const List<int> _eoi = [0xFF, 0xD9];

/// Puts a JPEG's marker chain back together.
///
/// JPEG has no per-segment checksum, so a repair here is about structure: the
/// start marker, the segment chain up to the scan, and the end marker. Damage
/// inside the entropy-coded scan itself shows up as smearing rather than as a
/// file that will not open, and there is nothing to reconstruct it from.
Uint8List repairJpeg(Uint8List bytes, RepairLog log) {
  var data = bytes;

  if (!matchesAt(data, 0, _soi)) {
    final soiAt = indexOfBytes(data, _soi, 0, 1 << 16);
    if (soiAt > 0) {
      log.fixed('Dropped ${formatSize(soiAt)} of junk in front of the image.');
      data = data.sublist(soiAt);
    } else {
      final out = Uint8List.fromList(data);
      if (out.length < 4) {
        log.failed('The file is too short to be a JPEG.');
        return data;
      }
      out.setRange(0, 2, _soi);
      // A wiped header usually takes the APP0 marker with it; without it most
      // decoders still cope, so only the SOI is restored.
      data = out;
      log.fixed('Rewrote the missing FFD8 start-of-image marker.');
    }
  }

  var offset = 2;
  var scanStart = -1;
  var segments = 0;

  while (offset + 4 <= data.length) {
    if (data[offset] != 0xFF) {
      log.warning(
        'Expected a marker at ${formatOffset(offset)} and found '
        '0x${data[offset].toRadixString(16).toUpperCase()} instead.',
      );
      break;
    }
    final marker = data[offset + 1];
    if (marker == 0xD8 ||
        (marker >= 0xD0 && marker <= 0xD7) ||
        marker == 0x01) {
      offset += 2;
      continue;
    }
    if (marker == 0xD9) break;

    final length = readU16be(data, offset + 2);
    if (length < 2 || offset + 2 + length > data.length) {
      log.warning(
        'The segment at ${formatOffset(offset)} runs past the end of the file.',
      );
      break;
    }
    segments++;
    if (marker == 0xDA) {
      scanStart = offset + 2 + length;
      break;
    }
    offset += 2 + length;
  }

  if (segments == 0) {
    log.failed(
      'No readable JPEG segments survived — the quantisation and Huffman '
      'tables are gone, and those cannot be guessed.',
    );
  } else if (scanStart < 0) {
    log.warning(
      'The file never reaches its image scan (SOS), so there is header but no '
      'picture to decode.',
    );
  }

  final eoiAt = lastIndexOfBytes(data, _eoi);
  if (eoiAt < 0) {
    log.fixed('Appended the missing FFD9 end-of-image marker.');
    return concatBytes([data, _eoi]);
  }
  if (eoiAt + 2 < data.length) {
    log.fixed(
      'Trimmed ${formatSize(data.length - eoiAt - 2)} of trailing junk after '
      'the end marker.',
    );
    return data.sublist(0, eoiAt + 2);
  }
  return data;
}
