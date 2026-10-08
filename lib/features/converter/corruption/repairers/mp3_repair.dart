import 'dart:typed_data';

import '../../../../l10n/current_l.dart';
import '../binary_utils.dart';
import '../repair_report.dart';

// Bitrates in kbps, indexed by the 4-bit field, for MPEG-1 Layer III and
// MPEG-2/2.5 Layer III respectively.
const List<int> _bitratesV1L3 = [
  0,
  32,
  40,
  48,
  56,
  64,
  80,
  96,
  112,
  128,
  160,
  192,
  224,
  256,
  320,
  -1,
];
const List<int> _bitratesV2L3 = [
  0,
  8,
  16,
  24,
  32,
  40,
  48,
  56,
  64,
  80,
  96,
  112,
  128,
  144,
  160,
  -1,
];
const List<List<int>> _sampleRates = [
  [11025, 12000, 8000], // MPEG 2.5
  [-1, -1, -1],
  [22050, 24000, 16000], // MPEG 2
  [44100, 48000, 32000], // MPEG 1
];

/// Resynchronises an MP3.
///
/// MP3 has no container to lose — it is a bare run of self-describing frames.
/// So the repair is to find where the real frames start, throw away whatever
/// junk sits in front of them, and cut off anything at the end that no longer
/// parses as a frame.
Uint8List repairMp3(Uint8List bytes, RepairLog log) {
  var data = bytes;
  var tagBytes = 0;

  if (matchesAt(data, 0, asciiBytes('ID3')) && data.length > 10) {
    // The tag length is stored as four 7-bit bytes.
    final size =
        ((data[6] & 0x7F) << 21) |
        ((data[7] & 0x7F) << 14) |
        ((data[8] & 0x7F) << 7) |
        (data[9] & 0x7F);
    tagBytes = 10 + size;
    if (tagBytes > data.length) {
      log.fixed(currentL.repairMp3TagTooBig(formatSize(tagBytes)));
      tagBytes = 0;
      final firstFrame = _findFrameRun(data, 10);
      if (firstFrame >= 0) data = data.sublist(firstFrame);
    } else {
      log.info(currentL.repairMp3TagKept(formatSize(tagBytes)));
    }
  }

  final start = _findFrameRun(data, tagBytes);
  if (start < 0) {
    log.failed(currentL.repairMp3NoFrames);
    return data;
  }

  if (start > tagBytes) {
    log.fixed(currentL.repairMp3JunkSkipped(formatSize(start - tagBytes)));
  }

  // Walk the frames from there to find where the audio stops making sense.
  var offset = start;
  var frames = 0;
  var lastGood = start;
  while (offset + 4 <= data.length) {
    final frame = _frameAt(data, offset);
    if (frame == null) {
      final resync = _findFrameRun(data, offset + 1, limit: 1 << 16);
      if (resync < 0) break;
      log.warning(currentL.repairMp3DamagedStretch(formatOffset(offset)));
      offset = resync;
      continue;
    }
    offset += frame;
    lastGood = offset;
    frames++;
  }

  if (frames == 0) {
    log.failed(currentL.repairMp3FramesStop);
    return data;
  }
  log.info(currentL.repairMp3FramesSurvived(frames));

  final head = tagBytes > 0 && start >= tagBytes
      ? data.sublist(0, tagBytes)
      : Uint8List(0);
  final body = data.sublist(start, lastGood);

  if (lastGood < data.length) {
    log.fixed(currentL.repairMp3CutTail(formatSize(data.length - lastGood)));
  }
  if (head.isEmpty && start == 0 && lastGood == data.length) return data;
  return concatBytes([head, body]);
}

/// Finds an offset where several consecutive valid frames line up, which is
/// what tells a real frame header apart from two bytes that happen to look
/// like one.
int _findFrameRun(Uint8List bytes, int from, {int? limit}) {
  final stop = limit == null
      ? bytes.length - 4
      : (from + limit).clamp(0, bytes.length - 4);
  for (var i = from < 0 ? 0 : from; i < stop; i++) {
    if (bytes[i] != 0xFF || (bytes[i + 1] & 0xE0) != 0xE0) continue;
    var offset = i;
    var matched = 0;
    while (matched < 3) {
      final size = _frameAt(bytes, offset);
      if (size == null) break;
      offset += size;
      matched++;
      if (offset + 4 > bytes.length) {
        matched = 3;
        break;
      }
    }
    if (matched >= 3) return i;
  }
  return -1;
}

/// The length of the frame starting at [offset], or null if there is no valid
/// frame there.
int? _frameAt(Uint8List bytes, int offset) {
  if (offset + 4 > bytes.length) return null;
  if (bytes[offset] != 0xFF || (bytes[offset + 1] & 0xE0) != 0xE0) return null;

  final versionBits = (bytes[offset + 1] >> 3) & 0x03;
  final layerBits = (bytes[offset + 1] >> 1) & 0x03;
  if (versionBits == 1 || layerBits == 0) return null;

  final bitrateIndex = (bytes[offset + 2] >> 4) & 0x0F;
  final sampleIndex = (bytes[offset + 2] >> 2) & 0x03;
  if (bitrateIndex == 0 || bitrateIndex == 15 || sampleIndex == 3) return null;

  final sampleRate = _sampleRates[versionBits][sampleIndex];
  if (sampleRate <= 0) return null;

  final isVersion1 = versionBits == 3;
  final bitrate =
      (isVersion1 ? _bitratesV1L3[bitrateIndex] : _bitratesV2L3[bitrateIndex]) *
      1000;
  if (bitrate <= 0) return null;

  final padding = (bytes[offset + 2] >> 1) & 0x01;
  // Layer I counts samples differently from Layers II and III.
  final isLayer1 = layerBits == 3;
  final size = isLayer1
      ? ((12 * bitrate ~/ sampleRate) + padding) * 4
      : ((isVersion1 ? 144 : 72) * bitrate ~/ sampleRate) + padding;

  if (size < 4 || offset + size > bytes.length) return null;
  return size;
}
