import 'dart:typed_data';

import '../binary_utils.dart';
import '../repair_report.dart';

const List<int> _pngMagic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// Rebuilds a PNG from whatever chunks are still intact.
///
/// PNG is unusually kind to a repairer: every chunk carries its own length and
/// CRC, so a damaged file can be walked chunk by chunk and cut at the first
/// place the structure stops making sense.
Uint8List repairPng(Uint8List bytes, RepairLog log) {
  var data = bytes;

  if (!matchesAt(data, 0, _pngMagic)) {
    final out = Uint8List.fromList(data);
    if (out.length < 8) {
      log.failed('The file is too short to be a PNG at all.');
      return data;
    }
    out.setRange(0, 8, _pngMagic);
    data = out;
    log.fixed('Rewrote the 8-byte PNG signature.');
  }

  final chunks = <_PngChunk>[];
  var offset = 8;
  var sawIhdr = false;
  var sawIend = false;
  var truncatedAt = -1;

  while (offset + 8 <= data.length) {
    final length = readU32be(data, offset);
    final type = String.fromCharCodes(data, offset + 4, offset + 8);

    if (!_isChunkType(type)) {
      log.warning(
        'Unreadable chunk name at ${formatOffset(offset)} — stopping the walk there.',
      );
      truncatedAt = offset;
      break;
    }
    if (length < 0 || offset + 12 + length > data.length) {
      log.warning(
        'The "$type" chunk at ${formatOffset(offset)} claims $length bytes but the '
        'file ends first.',
      );
      truncatedAt = offset;
      break;
    }

    final crcOffset = offset + 8 + length;
    final storedCrc = readU32be(data, crcOffset);
    final actualCrc = Crc32.compute(data, offset + 4, crcOffset);
    chunks.add(
      _PngChunk(
        type: type,
        start: offset,
        length: length,
        crcOk: storedCrc == actualCrc,
        actualCrc: actualCrc,
      ),
    );

    if (type == 'IHDR') sawIhdr = true;
    if (type == 'IEND') {
      sawIend = true;
      offset = crcOffset + 4;
      break;
    }
    offset = crcOffset + 4;
  }

  if (!sawIhdr) {
    log.failed(
      'No IHDR header chunk survived, so the image size and colour type are '
      'gone. Nothing can rebuild those.',
    );
  }

  final out = Uint8List.fromList(data);
  var repairedCrcs = 0;
  for (final chunk in chunks) {
    if (chunk.crcOk) continue;
    writeU32be(out, chunk.start + 8 + chunk.length, chunk.actualCrc);
    repairedCrcs++;
  }
  if (repairedCrcs > 0) {
    log.fixed(
      'Recomputed $repairedCrcs bad chunk checksum'
      '${repairedCrcs == 1 ? '' : 's'} — the pixel data behind them may still '
      'be wrong, but readers will stop rejecting the file outright.',
    );
  }

  final keep = truncatedAt >= 0 ? truncatedAt : offset;

  if (truncatedAt >= 0) {
    final lost = data.length - truncatedAt;
    log.fixed(
      'Cut the file at the last chunk that parsed and dropped '
      '${formatSize(lost)} of unusable tail.',
    );
  } else if (sawIend && offset < data.length) {
    log.fixed(
      'Trimmed ${formatSize(data.length - offset)} of junk sitting after IEND.',
    );
  }

  final body = out.sublist(0, keep);
  if (sawIend && truncatedAt < 0) {
    if (chunks.isEmpty) log.warning('The file has no chunks left.');
    return body;
  }

  log.fixed('Appended the missing IEND end-of-image chunk.');
  return concatBytes([body, _iendChunk()]);
}

Uint8List _iendChunk() {
  final chunk = Uint8List(12);
  writeU32be(chunk, 0, 0);
  chunk.setRange(4, 8, asciiBytes('IEND'));
  writeU32be(chunk, 8, Crc32.compute(chunk, 4, 8));
  return chunk;
}

bool _isChunkType(String type) {
  if (type.length != 4) return false;
  for (final unit in type.codeUnits) {
    final upper = unit >= 0x41 && unit <= 0x5A;
    final lower = unit >= 0x61 && unit <= 0x7A;
    if (!upper && !lower) return false;
  }
  return true;
}

class _PngChunk {
  const _PngChunk({
    required this.type,
    required this.start,
    required this.length,
    required this.crcOk,
    required this.actualCrc,
  });

  final String type;
  final int start;
  final int length;
  final bool crcOk;
  final int actualCrc;
}
