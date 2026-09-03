import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// What a picture's header is worth to the gallery: where it was taken, when
/// the shutter fired, and how big the frame is.
///
/// All of it comes out of the first few kilobytes of the file. Nothing here
/// decodes pixels — a 12 MP photo would be ~50 MB of them, and the scan
/// touches tens of thousands of files.
class ImageDetails {
  const ImageDetails({
    this.latitude,
    this.longitude,
    this.takenAt,
    this.width,
    this.height,
  });

  final double? latitude;
  final double? longitude;
  final DateTime? takenAt;

  /// Frame size in pixels. The desktop scan has no media index to ask, so
  /// this is the only way anything shaped — a panorama — can be recognised.
  final int? width;
  final int? height;

  bool get isEmpty =>
      latitude == null && takenAt == null && width == null;
}

/// How much of the file to read. EXIF sits in an APP1 segment right behind
/// the start-of-image marker and the frame header follows the other
/// segments, so a couple of hundred kilobytes covers both with room to
/// spare.
const _headBytes = 256 * 1024;

/// Reads [file]'s header. Never throws: an unreadable file is simply a photo
/// the gallery knows less about.
Future<ImageDetails?> readImageDetails(File file) async {
  RandomAccessFile? handle;
  try {
    handle = await file.open();
    final head = await handle.read(_headBytes);
    return parseImageDetails(head);
  } on FileSystemException {
    return null;
  } finally {
    await handle?.close();
  }
}

/// The pure part of [readImageDetails], so the format parsing can be tested
/// without a file on disk. Returns null when the bytes are no format this
/// understands.
ImageDetails? parseImageDetails(Uint8List head) {
  final png = _pngSize(head);
  if (png != null) {
    return ImageDetails(width: png.$1, height: png.$2);
  }
  final gif = _gifSize(head);
  if (gif != null) {
    return ImageDetails(width: gif.$1, height: gif.$2);
  }
  return _parseJpeg(head);
}

/// PNG puts its size in the IHDR chunk, always the first one, always at the
/// same offset. Screenshots are usually PNGs, so this is worth having.
(int, int)? _pngSize(Uint8List bytes) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length < 24) return null;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return null;
  }
  if (bytes[12] != 0x49 || bytes[13] != 0x48 || bytes[14] != 0x44 ||
      bytes[15] != 0x52) {
    return null;
  }
  final view = ByteData.sublistView(bytes);
  return (view.getUint32(16), view.getUint32(20));
}

/// GIF's logical screen descriptor, little-endian, right after the magic.
(int, int)? _gifSize(Uint8List bytes) {
  if (bytes.length < 10) return null;
  if (bytes[0] != 0x47 || bytes[1] != 0x49 || bytes[2] != 0x46) return null;
  final view = ByteData.sublistView(bytes);
  return (view.getUint16(6, Endian.little), view.getUint16(8, Endian.little));
}

/// Walks a JPEG's segment markers once, picking up both the EXIF block and
/// the frame header on the way.
ImageDetails? _parseJpeg(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;

  img.ExifData? exif;
  int? width;
  int? height;

  var offset = 2;
  while (offset + 4 <= bytes.length) {
    if (bytes[offset] != 0xFF) {
      // Padding between segments is legal; anything else means we've walked
      // off into the compressed data.
      offset++;
      continue;
    }
    final marker = bytes[offset + 1];
    // Start of scan — the pixels begin here and there is no header left.
    if (marker == 0xDA || marker == 0xD9) break;
    // Standalone markers carry no length field.
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD8)) {
      offset += 2;
      continue;
    }
    final length = (bytes[offset + 2] << 8) | bytes[offset + 3];
    if (length < 2) break;
    final payload = offset + 4;
    final payloadLength = length - 2;
    if (payload + payloadLength > bytes.length) break;

    if (marker == 0xE1 && exif == null && payloadLength > 6) {
      exif = _readExif(bytes, payload, payloadLength);
    } else if (_isFrameHeader(marker) && width == null && payloadLength >= 5) {
      // SOF payload: precision, then height and width as big-endian 16s.
      height = (bytes[payload + 1] << 8) | bytes[payload + 2];
      width = (bytes[payload + 3] << 8) | bytes[payload + 4];
    }

    offset = payload + payloadLength;
  }

  if (exif == null && width == null) return null;

  double? latitude;
  double? longitude;
  DateTime? takenAt;

  if (exif != null) {
    final gps = exif.gpsIfd;
    final lat = _degrees(gps[0x0002], gps[0x0001]?.toString());
    final lon = _degrees(gps[0x0004], gps[0x0003]?.toString());
    if (lat != null && lon != null && !(lat == 0 && lon == 0)) {
      latitude = lat;
      longitude = lon;
    }
    takenAt = _parseExifDate(
      exif.exifIfd[0x9003]?.toString() ?? exif.imageIfd[0x0132]?.toString(),
    );
  }

  return ImageDetails(
    latitude: latitude,
    longitude: longitude,
    takenAt: takenAt,
    width: width,
    height: height,
  );
}

/// Start-of-frame markers: every SOF variant except the three values in that
/// range that mean something else (DHT, JPG, DAC).
bool _isFrameHeader(int marker) =>
    marker >= 0xC0 &&
    marker <= 0xCF &&
    marker != 0xC4 &&
    marker != 0xC8 &&
    marker != 0xCC;

/// Decodes the TIFF block inside an APP1 segment that starts with `Exif\0\0`.
img.ExifData? _readExif(Uint8List bytes, int payload, int payloadLength) {
  final isExif = bytes[payload] == 0x45 && // E
      bytes[payload + 1] == 0x78 && // x
      bytes[payload + 2] == 0x69 && // i
      bytes[payload + 3] == 0x66 && // f
      bytes[payload + 4] == 0x00;
  if (!isExif) return null;

  final tiff = img.InputBuffer(
    bytes,
    offset: payload + 6,
    length: payloadLength - 6,
  );
  // ExifData.read returns false even on a clean read, so whether the block
  // parsed is judged by whether anything came out of it.
  final exif = img.ExifData()..read(tiff);
  return exif.isEmpty ? null : exif;
}

/// EXIF stores coordinates as three rationals — degrees, minutes, seconds —
/// with the hemisphere in a separate tag.
double? _degrees(img.IfdValue? value, String? ref) {
  if (value == null || value.length < 3) return null;
  final degrees =
      value.toDouble(0) + value.toDouble(1) / 60 + value.toDouble(2) / 3600;
  if (degrees.isNaN || degrees.isInfinite) return null;
  final hemisphere = (ref ?? '').trim().toUpperCase();
  final negative = hemisphere.startsWith('S') || hemisphere.startsWith('W');
  return negative ? -degrees : degrees;
}

/// EXIF timestamps look like `2026:07:31 14:12:33`, in local time with no
/// zone, which is exactly how the gallery wants to show them.
DateTime? _parseExifDate(String? raw) {
  if (raw == null) return null;
  final match = RegExp(r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})')
      .firstMatch(raw.trim());
  if (match == null) return null;
  final parts = [
    for (var i = 1; i <= 6; i++) int.tryParse(match.group(i)!) ?? 0,
  ];
  if (parts[0] < 1900) return null;
  return DateTime(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
}
