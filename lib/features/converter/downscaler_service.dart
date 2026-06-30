import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// The optimization knobs the downscaler exposes. Every field is a primitive so
/// the whole object can be shipped to a background isolate via [compute].
@immutable
class DownscaleParams {
  const DownscaleParams({
    this.resize = false,
    this.scalePercent = 100,
    this.reduceColors = false,
    this.colors = 256,
    this.dither = true,
    this.reduceBitDepth = false,
    this.bitsPerChannel = 4,
    this.stripMetadata = false,
    this.removeAlpha = false,
    this.trim = false,
    this.pngRecompress = false,
    this.toWebp = false,
  });

  /// Scale pixel dimensions down to [scalePercent] of the original (10–100).
  final bool resize;
  final int scalePercent;

  /// Quantize to a [colors]-entry palette (2–256). [dither] keeps gradients
  /// smooth at low color counts.
  final bool reduceColors;
  final int colors;
  final bool dither;

  /// Crush each channel to [bitsPerChannel] significant bits (8 = none).
  final bool reduceBitDepth;
  final int bitsPerChannel;

  /// Drop ICC profile / EXIF / text chunks.
  final bool stripMetadata;

  /// Drop the alpha channel (only safe when the image is fully opaque).
  final bool removeAlpha;

  /// Crop fully-transparent borders.
  final bool trim;

  /// Re-encode PNG at maximum compression.
  final bool pngRecompress;

  /// Encode the result as WebP instead of PNG (handled outside the isolate).
  final bool toWebp;

  DownscaleParams copyWith({
    bool? resize,
    int? scalePercent,
    bool? reduceColors,
    int? colors,
    bool? dither,
    bool? reduceBitDepth,
    int? bitsPerChannel,
    bool? stripMetadata,
    bool? removeAlpha,
    bool? trim,
    bool? pngRecompress,
    bool? toWebp,
  }) {
    return DownscaleParams(
      resize: resize ?? this.resize,
      scalePercent: scalePercent ?? this.scalePercent,
      reduceColors: reduceColors ?? this.reduceColors,
      colors: colors ?? this.colors,
      dither: dither ?? this.dither,
      reduceBitDepth: reduceBitDepth ?? this.reduceBitDepth,
      bitsPerChannel: bitsPerChannel ?? this.bitsPerChannel,
      stripMetadata: stripMetadata ?? this.stripMetadata,
      removeAlpha: removeAlpha ?? this.removeAlpha,
      trim: trim ?? this.trim,
      pngRecompress: pngRecompress ?? this.pngRecompress,
      toWebp: toWebp ?? this.toWebp,
    );
  }
}

/// What we learn about the source image up front, used to enable/disable
/// options and pre-fill slider bounds.
@immutable
class ImageProbe {
  const ImageProbe({
    required this.width,
    required this.height,
    required this.hasAlpha,
    required this.fullyOpaque,
    required this.transparentBorder,
    required this.decodable,
  });

  final int width;
  final int height;
  final bool hasAlpha;
  final bool fullyOpaque;
  final bool transparentBorder;
  final bool decodable;

  static const undecodable = ImageProbe(
    width: 0,
    height: 0,
    hasAlpha: false,
    fullyOpaque: false,
    transparentBorder: false,
    decodable: false,
  );
}

/// Bundles bytes + params so they cross the isolate boundary as one argument.
@immutable
class _RenderRequest {
  const _RenderRequest(this.bytes, this.params);
  final Uint8List bytes;
  final DownscaleParams params;
}

/// Image-optimization logic for the downscaler. The transform pipeline runs in
/// a background isolate so the UI stays responsive while estimates compute.
class DownscalerService {
  const DownscalerService._();

  /// Powers-of-two palette sizes offered by the "reduce colors" slider.
  static const colorStops = [2, 4, 8, 16, 32, 64, 128, 256];

  /// Per-channel bit options for "reduce bit depth", labelled by total RGBA
  /// bit width in the UI (32 = 8bpc, 16 = 4bpc, 8 = 2bpc).
  static const bitStops = [8, 4, 2];

  static Future<ImageProbe> probe(Uint8List bytes) => compute(_probe, bytes);

  /// Runs the pipeline and returns PNG bytes (the lossless intermediate). WebP
  /// output is produced by the caller by re-encoding these bytes with ffmpeg.
  static Future<Uint8List> renderPng(Uint8List bytes, DownscaleParams params) =>
      compute(_render, _RenderRequest(bytes, params));
}

ImageProbe _probe(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return ImageProbe.undecodable;

  final hasAlpha = image.hasAlpha;
  var fullyOpaque = true;
  if (hasAlpha) {
    for (final p in image) {
      if (p.a < p.maxChannelValue) {
        fullyOpaque = false;
        break;
      }
    }
  }

  var transparentBorder = false;
  if (hasAlpha && !fullyOpaque) {
    transparentBorder = _hasTransparentBorder(image);
  }

  return ImageProbe(
    width: image.width,
    height: image.height,
    hasAlpha: hasAlpha,
    fullyOpaque: fullyOpaque,
    transparentBorder: transparentBorder,
    decodable: true,
  );
}

bool _hasTransparentBorder(img.Image image) {
  final w = image.width;
  final h = image.height;
  final maxA = image.maxChannelValue;
  bool clear(int x, int y) => image.getPixel(x, y).a < maxA;
  for (var x = 0; x < w; x++) {
    if (clear(x, 0) || clear(x, h - 1)) return true;
  }
  for (var y = 0; y < h; y++) {
    if (clear(0, y) || clear(w - 1, y)) return true;
  }
  return false;
}

Uint8List _render(_RenderRequest req) {
  final p = req.params;
  var image = img.decodeImage(req.bytes);
  if (image == null) {
    throw const FormatException('Could not read this image.');
  }

  // 1. Trim transparent borders (at full resolution for accuracy).
  if (p.trim && image.hasAlpha) {
    image = img.trim(image, mode: img.TrimMode.transparent);
  }

  // 2. Resize.
  if (p.resize && p.scalePercent < 100) {
    final w = (image.width * p.scalePercent / 100).round().clamp(1, image.width);
    final h =
        (image.height * p.scalePercent / 100).round().clamp(1, image.height);
    image = img.copyResize(
      image,
      width: w,
      height: h,
      interpolation: img.Interpolation.average,
    );
  }

  // 3. Remove alpha (drop to 3 channels).
  if (p.removeAlpha && image.hasAlpha) {
    image = image.convert(numChannels: 3);
  }

  // 4. Bit-depth crush.
  if (p.reduceBitDepth && p.bitsPerChannel < 8) {
    final shift = 8 - p.bitsPerChannel;
    for (final frame in image.frames) {
      for (final px in frame) {
        px
          ..r = (px.r.toInt() >> shift) << shift
          ..g = (px.g.toInt() >> shift) << shift
          ..b = (px.b.toInt() >> shift) << shift;
      }
    }
  }

  // 5. Color quantization (last, so it can build an optimal palette).
  if (p.reduceColors && p.colors < 256) {
    image = img.quantize(
      image,
      numberOfColors: p.colors,
      dither: p.dither ? img.DitherKernel.floydSteinberg : img.DitherKernel.none,
    );
  }

  // 6. Strip metadata.
  if (p.stripMetadata) {
    image.iccProfile = null;
    image.textData = null;
    image.exif = img.ExifData();
  }

  return img.encodePng(image, level: p.pngRecompress ? 9 : 6);
}
