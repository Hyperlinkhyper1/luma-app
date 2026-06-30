import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Image formats the picture converter understands. SVG is decode-only (it is
/// rasterized to a raster target); it is never an encode target.
enum PictureFormat {
  png('PNG', 'png', 'image/png'),
  jpg('JPG', 'jpg', 'image/jpeg'),
  bmp('BMP', 'bmp', 'image/bmp'),
  tiff('TIFF', 'tiff', 'image/tiff'),
  svg('SVG', 'svg', 'image/svg+xml');

  const PictureFormat(this.label, this.extension, this.mimeType);

  final String label;
  final String extension;
  final String mimeType;
}

/// Raster image conversion (pure Dart via the `image` package). SVG sources are
/// rasterized to PNG bytes by the caller before reaching [convertRaster].
class ImageConvert {
  const ImageConvert._();

  /// Selectable output formats (SVG excluded — can't vectorize).
  static const targets = [
    PictureFormat.png,
    PictureFormat.jpg,
    PictureFormat.bmp,
    PictureFormat.tiff,
  ];

  /// Detects the source format from magic bytes, falling back to the file
  /// extension. Returns null for anything unsupported.
  static PictureFormat? detect(Uint8List b, String name) {
    if (b.length >= 4 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47) {
      return PictureFormat.png;
    }
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return PictureFormat.jpg;
    }
    if (b.length >= 2 && b[0] == 0x42 && b[1] == 0x4D) {
      return PictureFormat.bmp;
    }
    if (b.length >= 4 &&
        ((b[0] == 0x49 && b[1] == 0x49 && b[2] == 0x2A && b[3] == 0x00) ||
            (b[0] == 0x4D && b[1] == 0x4D && b[2] == 0x00 && b[3] == 0x2A))) {
      return PictureFormat.tiff;
    }
    if (_looksLikeSvg(b)) return PictureFormat.svg;

    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return PictureFormat.png;
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return PictureFormat.jpg;
    }
    if (lower.endsWith('.bmp')) return PictureFormat.bmp;
    if (lower.endsWith('.tif') || lower.endsWith('.tiff')) {
      return PictureFormat.tiff;
    }
    if (lower.endsWith('.svg')) return PictureFormat.svg;
    return null;
  }

  static bool _looksLikeSvg(Uint8List b) {
    // Scan the first chunk for an "<svg" token (allowing an XML prolog / BOM).
    final n = b.length < 1024 ? b.length : 1024;
    final sb = StringBuffer();
    for (var i = 0; i < n; i++) {
      sb.writeCharCode(b[i]);
    }
    return sb.toString().toLowerCase().contains('<svg');
  }

  /// Decodes raster [bytes] and re-encodes them as [target].
  static Uint8List convertRaster({
    required Uint8List bytes,
    required PictureFormat target,
    int jpgQuality = 90,
  }) {
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw const FormatException(
        'Could not read this image — it may be corrupt or unsupported.',
      );
    }
    return encode(image, target, jpgQuality: jpgQuality);
  }

  /// Encodes a decoded [image] to [target].
  static Uint8List encode(
    img.Image image,
    PictureFormat target, {
    int jpgQuality = 90,
  }) {
    switch (target) {
      case PictureFormat.png:
        return img.encodePng(image);
      case PictureFormat.jpg:
        var working = image;
        // JPEG has no alpha; flatten transparency onto white.
        if (working.hasAlpha) {
          final flat = img.Image(
            width: working.width,
            height: working.height,
            numChannels: 3,
          );
          img.fill(flat, color: img.ColorRgb8(255, 255, 255));
          img.compositeImage(flat, working);
          working = flat;
        }
        return img.encodeJpg(working, quality: jpgQuality);
      case PictureFormat.bmp:
        return img.encodeBmp(image);
      case PictureFormat.tiff:
        return img.encodeTiff(image);
      case PictureFormat.svg:
        throw StateError('SVG is not an encodable target.');
    }
  }

  static String stripExtension(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }
}
