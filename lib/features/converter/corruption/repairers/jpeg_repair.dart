import 'dart:typed_data';

import '../../../../l10n/current_l.dart';
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
      log.fixed(currentL.repairJpegJunkDropped(formatSize(soiAt)));
      data = data.sublist(soiAt);
    } else {
      final out = Uint8List.fromList(data);
      if (out.length < 4) {
        log.failed(currentL.repairJpegTooShort);
        return data;
      }
      out.setRange(0, 2, _soi);
      // A wiped header usually takes the APP0 marker with it; without it most
      // decoders still cope, so only the SOI is restored.
      data = out;
      log.fixed(currentL.repairJpegSoiRewritten);
    }
  }

  var offset = 2;
  var scanStart = -1;
  var segments = 0;

  while (offset + 4 <= data.length) {
    if (data[offset] != 0xFF) {
      log.warning(
        currentL.repairJpegMarkerExpected(
          formatOffset(offset),
          '0x${data[offset].toRadixString(16).toUpperCase()}',
        ),
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
      log.warning(currentL.repairJpegSegmentPastEnd(formatOffset(offset)));
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
    log.failed(currentL.repairJpegNoSegments);
  } else if (scanStart < 0) {
    log.warning(currentL.repairJpegNoScan);
  }

  final eoiAt = lastIndexOfBytes(data, _eoi);
  if (eoiAt < 0) {
    log.fixed(currentL.repairJpegEoiAppended);
    return concatBytes([data, _eoi]);
  }
  if (eoiAt + 2 < data.length) {
    log.fixed(
      currentL.repairJpegTrailingTrimmed(formatSize(data.length - eoiAt - 2)),
    );
    return data.sublist(0, eoiAt + 2);
  }
  return data;
}
