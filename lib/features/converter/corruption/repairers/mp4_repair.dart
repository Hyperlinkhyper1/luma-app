import 'dart:typed_data';

import '../../../../l10n/current_l.dart';
import '../binary_utils.dart';
import '../repair_report.dart';

/// Repairs an ISO base-media file — MP4, MOV, M4A, 3GP, HEIC and AVIF.
///
/// The file is a tree of boxes, each starting with its own length. Damage to a
/// length makes every reader walk off the end and give up, so clamping the box
/// sizes back to what is actually there recovers a surprising number of files.
/// What cannot be recovered is a missing `moov` box: that holds the sample
/// index for the whole video, and nothing else in the file repeats it.
Uint8List repairMp4(Uint8List bytes, RepairLog log) {
  if (bytes.length < 8) {
    log.failed(currentL.repairMp4TooShort);
    return bytes;
  }

  var data = Uint8List.fromList(bytes);

  if (!matchesAt(data, 4, asciiBytes('ftyp'))) {
    final ftypAt = indexOfBytes(data, asciiBytes('ftyp'), 0, 1 << 16);
    if (ftypAt >= 4) {
      log.fixed(currentL.repairMp4JunkDropped(formatSize(ftypAt - 4)));
      data = data.sublist(ftypAt - 4);
    } else {
      log.warning(currentL.repairMp4NoFtyp);
    }
  }

  var offset = 0;
  var sawMoov = false;
  var sawMdat = false;
  var boxes = 0;
  var clamped = 0;
  var stopped = -1;

  while (offset + 8 <= data.length) {
    var size = readU32be(data, offset);
    final type = String.fromCharCodes(data, offset + 4, offset + 8);
    if (!_isBoxType(type)) {
      log.warning(currentL.repairMp4UnreadableBox(formatOffset(offset)));
      stopped = offset;
      break;
    }

    var headerSize = 8;
    if (size == 1) {
      if (offset + 16 > data.length) {
        stopped = offset;
        break;
      }
      // A 64-bit size. Anything above 2^32 here is already nonsense for a file
      // we are holding in memory.
      final high = readU32be(data, offset + 8);
      final low = readU32be(data, offset + 12);
      size = high != 0 ? data.length - offset : low;
      headerSize = 16;
    } else if (size == 0) {
      // Zero means "to the end of the file", which is legal for the last box.
      size = data.length - offset;
    }

    if (size < headerSize || offset + size > data.length) {
      final available = data.length - offset;
      writeU32be(data, offset, available);
      log.fixed(
        currentL.repairMp4BoxClamped(
          type,
          formatOffset(offset),
          formatSize(size),
          formatSize(available),
        ),
      );
      size = available;
      clamped++;
    }

    if (type == 'moov') sawMoov = true;
    if (type == 'mdat') sawMdat = true;
    boxes++;
    offset += size;
  }

  log.info(currentL.repairMp4BoxesParsed(boxes));

  if (!sawMoov) {
    final moovAt = indexOfBytes(data, asciiBytes('moov'));
    if (moovAt >= 4) {
      log.warning(currentL.repairMp4MoovMisplaced(formatOffset(moovAt - 4)));
    } else {
      log.failed(currentL.repairMp4NoMoov);
    }
  }
  if (!sawMdat) {
    log.warning(currentL.repairMp4NoMdat);
  }
  if (clamped > 0) {
    log.info(currentL.repairMp4ClampExplain);
  }

  if (stopped >= 0 && stopped > 0) {
    log.fixed(currentL.repairMp4TailTrimmed(formatSize(data.length - stopped)));
    return data.sublist(0, stopped);
  }
  if (stopped < 0 && offset < data.length && offset > 0) {
    log.fixed(
      currentL.repairMp4TrailingTrimmed(formatSize(data.length - offset)),
    );
    return data.sublist(0, offset);
  }

  return data;
}

bool _isBoxType(String type) {
  if (type.length != 4) return false;
  for (final unit in type.codeUnits) {
    // Box names are printable ASCII; a few legacy QuickTime ones start with a
    // copyright sign, which is why 0xA9 is allowed through.
    if (unit == 0xA9) continue;
    if (unit < 0x20 || unit > 0x7E) return false;
  }
  return true;
}
