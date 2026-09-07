import 'dart:typed_data';

import '../binary_utils.dart';
import '../repair_report.dart';

/// Fixes a GIF's header, logical screen descriptor and trailer.
Uint8List repairGif(Uint8List bytes, RepairLog log) {
  if (bytes.length < 13) {
    log.failed('A GIF needs at least 13 bytes of header; this has fewer.');
    return bytes;
  }

  var data = Uint8List.fromList(bytes);

  if (!matchesAt(data, 0, asciiBytes('GIF'))) {
    data.setRange(0, 3, asciiBytes('GIF'));
    log.fixed('Rewrote the "GIF" signature.');
  }

  final version = String.fromCharCodes(data, 3, 6);
  if (version != '87a' && version != '89a') {
    // 89a is the superset, so it is the safe guess when the version bytes are
    // gone.
    data.setRange(3, 6, asciiBytes('89a'));
    log.fixed('Restored the version stamp to "89a".');
  }

  final width = readU16le(data, 6);
  final height = readU16le(data, 8);
  if (width == 0 || height == 0) {
    log.failed(
      'The logical screen size reads $width×$height, which no decoder will '
      'accept. The real dimensions are not recorded anywhere else.',
    );
  } else {
    log.info('Logical screen: $width×$height.');
  }

  final packed = data[10];
  final hasGlobalTable = (packed & 0x80) != 0;
  final tableSize = hasGlobalTable ? 3 * (1 << ((packed & 0x07) + 1)) : 0;
  final afterTable = 13 + tableSize;
  if (afterTable > data.length) {
    log.warning(
      'The global colour table is declared as ${formatSize(tableSize)} but the '
      'file ends before it does.',
    );
  }

  final trailer = data.isEmpty ? 0 : data[data.length - 1];
  if (trailer != 0x3B) {
    final trailerAt = lastIndexOfBytes(data, [0x3B]);
    if (trailerAt > afterTable && trailerAt > data.length - 64) {
      log.fixed(
        'Trimmed ${formatSize(data.length - trailerAt - 1)} of junk after the '
        'GIF trailer.',
      );
      return data.sublist(0, trailerAt + 1);
    }
    log.fixed('Appended the missing 0x3B trailer byte.');
    return concatBytes([
      data,
      const [0x3B],
    ]);
  }

  return data;
}
