import 'dart:typed_data';

import '../../../../l10n/current_l.dart';
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
      log.failed(currentL.repairPngTooShort);
      return data;
    }
    out.setRange(0, 8, _pngMagic);
    data = out;
    log.fixed(currentL.repairPngSignatureRewritten);
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
      log.warning(currentL.repairPngUnreadableChunk(formatOffset(offset)));
      truncatedAt = offset;
      break;
    }
    if (length < 0 || offset + 12 + length > data.length) {
      log.warning(
        currentL.repairPngChunkPastEnd(type, formatOffset(offset), length),
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
    log.failed(currentL.repairPngNoIhdr);
  }

  final out = Uint8List.fromList(data);
  var repairedCrcs = 0;
  for (final chunk in chunks) {
    if (chunk.crcOk) continue;
    writeU32be(out, chunk.start + 8 + chunk.length, chunk.actualCrc);
    repairedCrcs++;
  }
  if (repairedCrcs > 0) {
    log.fixed(currentL.repairPngCrcRecomputed(repairedCrcs));
  }

  final keep = truncatedAt >= 0 ? truncatedAt : offset;

  if (truncatedAt >= 0) {
    final lost = data.length - truncatedAt;
    log.fixed(currentL.repairPngCutAtLastChunk(formatSize(lost)));
  } else if (sawIend && offset < data.length) {
    log.fixed(
      currentL.repairPngJunkAfterIend(formatSize(data.length - offset)),
    );
  }

  final body = out.sublist(0, keep);
  if (sawIend && truncatedAt < 0) {
    if (chunks.isEmpty) log.warning(currentL.repairPngNoChunks);
    return body;
  }

  log.fixed(currentL.repairPngIendAppended);
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
