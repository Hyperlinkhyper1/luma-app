import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import '../../../../converter/file_saver.dart';
import '../engine/compositor.dart';
import '../engine/sketch_document.dart';
import 'ora_writer.dart';
import 'psd_writer.dart';

enum SketchExportFormat {
  png('PNG', 'png', 'image/png', 'Flattened, keeps transparency'),
  jpeg('JPEG', 'jpg', 'image/jpeg', 'Flattened, smallest file'),
  psd('Photoshop', 'psd', 'image/vnd.adobe.photoshop', 'Every layer, blend mode and mask'),
  ora('OpenRaster', 'ora', 'image/openraster', 'Layers for Krita, GIMP and MyPaint');

  const SketchExportFormat(this.label, this.extension, this.mimeType, this.note);

  final String label;
  final String extension;
  final String mimeType;
  final String note;

  bool get layered => this == psd || this == ora;
}

/// Encodes a document into an exchange format.
///
/// Every image is cloned up front: encoding reads pixels back asynchronously,
/// and an undo in the meantime would otherwise dispose a layer out from
/// under it.
class SketchExporter {
  const SketchExporter._();

  static Future<Uint8List> encode(
    SketchSnapshot state,
    int width,
    int height,
    SketchExportFormat format,
  ) async {
    final clones = <ui.Image>[];
    final layers = [
      for (final layer in state.layers)
        layer.image == null
            ? layer
            : layer.copyWith(image: (clones..add(layer.image!.clone())).last),
    ];
    final frozen = state.copyWith(layers: layers);
    try {
      return switch (format) {
        SketchExportFormat.png => await _png(frozen, width, height),
        SketchExportFormat.jpeg => await _jpeg(frozen, width, height),
        SketchExportFormat.psd => await _psd(frozen, width, height),
        SketchExportFormat.ora => await _ora(frozen, width, height),
      };
    } finally {
      for (final image in clones) {
        image.dispose();
      }
    }
  }

  static Future<Uint8List> _png(SketchSnapshot state, int width, int height) async {
    final flat = SketchCompositor.flatten(state, width, height);
    try {
      return await pngOf(flat);
    } finally {
      flat.dispose();
    }
  }

  static Future<Uint8List> _jpeg(SketchSnapshot state, int width, int height) async {
    final opaque = state.showBackground
        ? state
        : state.copyWith(showBackground: true, background: const ui.Color(0xFFFFFFFF));
    final flat = SketchCompositor.flatten(opaque, width, height);
    try {
      final rgba = await rgbaOf(flat);
      return Isolate.run(() {
        final image = img.Image.fromBytes(
          width: width,
          height: height,
          bytes: rgba.buffer,
          numChannels: 4,
        );
        return img.encodeJpg(image.convert(numChannels: 3), quality: 92);
      });
    } finally {
      flat.dispose();
    }
  }

  static Future<Uint8List> _psd(SketchSnapshot state, int width, int height) async {
    final layers = <PsdLayerData>[];
    if (state.showBackground) {
      final bg = state.background;
      final fill = Uint8List(width * height * 4);
      final r = (bg.r * 255).round();
      final g = (bg.g * 255).round();
      final b = (bg.b * 255).round();
      for (var i = 0; i < fill.length; i += 4) {
        fill[i] = r;
        fill[i + 1] = g;
        fill[i + 2] = b;
        fill[i + 3] = 255;
      }
      layers.add(PsdLayerData(name: 'Background', rgba: fill));
    }
    for (final layer in state.layers) {
      final image = layer.image;
      layers.add(PsdLayerData(
        name: layer.name,
        rgba: image == null ? Uint8List(width * height * 4) : await rgbaOf(image),
        opacity: layer.opacity,
        blendKey: layer.blend.psdKey,
        visible: layer.visible,
        clipped: layer.clipped,
        alphaLocked: layer.alphaLocked,
      ));
    }
    final flat = SketchCompositor.flatten(state, width, height);
    try {
      final composite = await rgbaOf(flat);
      // Trimming and PackBits over every channel of every layer is seconds
      // of work on a large canvas.
      return Isolate.run(
        () => encodePsd(width: width, height: height, layers: layers, composite: composite),
      );
    } finally {
      flat.dispose();
    }
  }

  static Future<Uint8List> _ora(SketchSnapshot state, int width, int height) async {
    final layers = <OraLayerData>[];
    if (state.showBackground) {
      final bg = _solid(width, height, state.background);
      try {
        layers.add(OraLayerData(name: 'Background', png: await pngOf(bg)));
      } finally {
        bg.dispose();
      }
    }
    final blank = _solid(width, height, const ui.Color(0x00000000));
    try {
      for (final layer in state.layers) {
        layers.add(OraLayerData(
          name: layer.name,
          png: await pngOf(layer.image ?? blank),
          opacity: layer.opacity,
          compositeOp: layer.blend.oraOp,
          visible: layer.visible,
        ));
      }
    } finally {
      blank.dispose();
    }
    final flat = SketchCompositor.flatten(state, width, height);
    final thumb = await SketchCompositor.thumbnail(state, width, height, maxSide: 256);
    try {
      return encodeOra(
        width: width,
        height: height,
        layers: layers,
        mergedPng: await pngOf(flat),
        thumbnailPng: await pngOf(thumb),
      );
    } finally {
      flat.dispose();
      thumb.dispose();
    }
  }

  static ui.Image _solid(int width, int height, ui.Color color) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = color,
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    return image;
  }

  static Future<Uint8List> pngOf(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('The image could not be encoded.');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  static Future<Uint8List> rgbaOf(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    if (data == null) throw StateError('The image pixels could not be read.');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  /// Encodes and opens the platform save dialog. Returns a line for the
  /// user, or null if they cancelled.
  static Future<String?> saveAs({
    required SketchSnapshot state,
    required int width,
    required int height,
    required String title,
    required SketchExportFormat format,
  }) async {
    final bytes = await encode(state, width, height, format);
    final result = await saveConvertedFile(
      bytes: bytes,
      suggestedName: '${fileNameFor(title)}.${format.extension}',
      mimeType: format.mimeType,
      extensions: [format.extension],
      dialogTitle: 'Export ${format.label}',
    );
    return result.saved ? result.summary : null;
  }

  static String fileNameFor(String title) {
    final cleaned = title
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .toLowerCase();
    return cleaned.isEmpty ? 'sketch' : cleaned;
  }
}
