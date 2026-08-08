import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// What a JPEG's EXIF header is worth to the gallery: where it was taken and
/// when the shutter actually fired.
class JpegMetadata {
  const JpegMetadata({this.latitude, this.longitude, this.takenAt});

  final double? latitude;
  final double? longitude;
  final DateTime? takenAt;

  bool get isEmpty => latitude == null && longitude == null && takenAt == null;
}

/// How much of the file to read looking for the EXIF block. It sits in an
/// APP1 segment right behind the start-of-image marker, so a couple of
/// hundred kilobytes is generous — and it means the desktop scan never pulls
/// a 12 MP photo into memory just to find out it has no GPS tag.
const _exifHeadBytes = 256 * 1024;

/// Reads [file]'s EXIF header. Returns null for anything that isn't a JPEG
/// with a readable APP1 block — a PNG screenshot, a video, a truncated
/// download. Never throws: an unreadable file is simply a photo without
/// metadata.
Future<JpegMetadata?> readJpegMetadata(File file) async {
  RandomAccessFile? handle;
  try {
    handle = await file.open();
    final head = await handle.read(_exifHeadBytes);
    return parseJpegMetadata(head);
  } on FileSystemException {
    return null;
  } finally {
    await handle?.close();
  }
}

/// The pure part of [readJpegMetadata], so the marker walk can be tested
/// without a file on disk.
JpegMetadata? parseJpegMetadata(Uint8List head) {
  final exif = _findExif(head);
  if (exif == null) return null;

  double? latitude;
  double? longitude;
  final gps = exif.gpsIfd;
  final lat = _degrees(gps[0x0002], gps[0x0001]?.toString());
  final lon = _degrees(gps[0x0004], gps[0x0003]?.toString());
  if (lat != null && lon != null && !(lat == 0 && lon == 0)) {
    latitude = lat;
    longitude = lon;
  }

  final stamp = exif.exifIfd[0x9003]?.toString() ??
      exif.imageIfd[0x0132]?.toString();
  return JpegMetadata(
    latitude: latitude,
    longitude: longitude,
    takenAt: _parseExifDate(stamp),
  );
}

/// Walks the JPEG segment markers for the APP1 block that starts with the
/// `Exif\0\0` signature, and hands its TIFF header to the decoder.
img.ExifData? _findExif(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;

  var offset = 2;
  while (offset + 4 <= bytes.length) {
    if (bytes[offset] != 0xFF) {
      // Padding between segments is legal; anything else means we've walked
      // off into the compressed data.
      offset++;
      continue;
    }
    final marker = bytes[offset + 1];
    // Start of scan — the pixels begin here and there is no metadata past it.
    if (marker == 0xDA || marker == 0xD9) return null;
    // Standalone markers carry no length field.
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD8)) {
      offset += 2;
      continue;
    }
    final length = (bytes[offset + 2] << 8) | bytes[offset + 3];
    if (length < 2) return null;
    final payload = offset + 4;
    final payloadLength = length - 2;
    if (payload + payloadLength > bytes.length) return null;

    if (marker == 0xE1 && payloadLength > 6) {
      final isExif = bytes[payload] == 0x45 && // E
          bytes[payload + 1] == 0x78 && // x
          bytes[payload + 2] == 0x69 && // i
          bytes[payload + 3] == 0x66 && // f
          bytes[payload + 4] == 0x00;
      if (isExif) {
        final tiff = img.InputBuffer(
          bytes,
          offset: payload + 6,
          length: payloadLength - 6,
        );
        // ExifData.read returns false even on a clean read, so whether the
        // block parsed is judged by whether anything came out of it.
        final exif = img.ExifData()..read(tiff);
        return exif.isEmpty ? null : exif;
      }
    }
    offset = payload + payloadLength;
  }
  return null;
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
