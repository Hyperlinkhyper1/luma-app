import 'dart:typed_data';

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
    log.failed('The file is too short to hold a single box.');
    return bytes;
  }

  var data = Uint8List.fromList(bytes);

  if (!matchesAt(data, 4, asciiBytes('ftyp'))) {
    final ftypAt = indexOfBytes(data, asciiBytes('ftyp'), 0, 1 << 16);
    if (ftypAt >= 4) {
      log.fixed(
        'Dropped ${formatSize(ftypAt - 4)} of junk before the ftyp box.',
      );
      data = data.sublist(ftypAt - 4);
    } else {
      log.warning(
        'There is no ftyp box, so the exact flavour of MP4 is unknown. The box '
        'tree was still checked.',
      );
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
      log.warning(
        'Unreadable box name at ${formatOffset(offset)} — stopping the walk '
        'there.',
      );
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
        'The "$type" box at ${formatOffset(offset)} claimed '
        '${formatSize(size)} but only ${formatSize(available)} follows — '
        'clamped it to fit.',
      );
      size = available;
      clamped++;
    }

    if (type == 'moov') sawMoov = true;
    if (type == 'mdat') sawMdat = true;
    boxes++;
    offset += size;
  }

  log.info('$boxes top-level boxes parsed.');

  if (!sawMoov) {
    final moovAt = indexOfBytes(data, asciiBytes('moov'));
    if (moovAt >= 4) {
      log.warning(
        'A moov box exists at ${formatOffset(moovAt - 4)} but the box chain '
        'never reaches it. Some players will still find it by scanning.',
      );
    } else {
      log.failed(
        'There is no moov box. That box is the index of every video and audio '
        'sample in the file, and without it the media data cannot be played '
        'back — recovering it needs an undamaged file recorded by the same '
        'device.',
      );
    }
  }
  if (!sawMdat) {
    log.warning('No mdat box was found, so there may be no media data left.');
  }
  if (clamped > 0) {
    log.info(
      'Clamping a box size keeps readers from walking off the end; it does not '
      'bring back what was cut off.',
    );
  }

  if (stopped >= 0 && stopped > 0) {
    log.fixed(
      'Trimmed ${formatSize(data.length - stopped)} of unreadable tail.',
    );
    return data.sublist(0, stopped);
  }
  if (stopped < 0 && offset < data.length && offset > 0) {
    log.fixed('Trimmed ${formatSize(data.length - offset)} of trailing junk.');
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
