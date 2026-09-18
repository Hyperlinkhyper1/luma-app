import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../converter/file_saver.dart';
import '../model/whiteboard_element.dart';
import '../ui/whiteboard_painter.dart';

class WhiteboardExport {
  const WhiteboardExport._();

  /// Writes the board out as a PNG and returns a line to show the user, or
  /// null when they cancelled the save dialog.
  ///
  /// The image is recorded from the elements rather than captured from the
  /// widget tree, so it holds exactly the drawn content — cropped to what was
  /// actually used, with no selection outline, no grid, and no dependence on
  /// where the user happened to be scrolled or zoomed to.
  static Future<String?> savePng({
    required List<WhiteboardElement> elements,
    required String title,
    required Color paper,
    double pixelRatio = 2,
  }) async {
    if (elements.isEmpty) {
      throw StateError('There is nothing on this board to export.');
    }
    final image = await render(
      elements: elements,
      paper: paper,
      pixelRatio: pixelRatio,
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('The image could not be encoded.');
      final result = await saveConvertedFile(
        bytes: data.buffer.asUint8List(),
        suggestedName: '${fileNameFor(title)}.png',
        mimeType: 'image/png',
        extensions: const ['png'],
        dialogTitle: 'Save whiteboard image',
      );
      return result.saved ? result.summary : null;
    } finally {
      image.dispose();
    }
  }

  /// Paints [elements] onto a [paper] background, cropped to their bounds plus
  /// a margin. Split out from [savePng] so it can be exercised without a file
  /// picker in the way.
  static Future<ui.Image> render({
    required List<WhiteboardElement> elements,
    required Color paper,
    double pixelRatio = 2,
    double margin = 32,
  }) async {
    final box = boundsOf(elements).inflate(margin);
    final width = math.max(1.0, box.width);
    final height = math.max(1.0, box.height);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // toImage rasterises at the size given, not at the canvas' own scale, so
    // the ratio has to be baked into the recording for it to mean anything.
    canvas.scale(pixelRatio);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = paper);
    canvas.translate(-box.left, -box.top);
    for (final element in elements) {
      paintWhiteboardElement(canvas, element);
    }
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(
        math.max(1, (width * pixelRatio).round()),
        math.max(1, (height * pixelRatio).round()),
      );
    } finally {
      picture.dispose();
    }
  }

  static Rect boundsOf(List<WhiteboardElement> elements) {
    if (elements.isEmpty) return Rect.zero;
    var box = elements.first.bounds;
    for (final element in elements.skip(1)) {
      box = box.expandToInclude(element.bounds);
    }
    return box;
  }

  static String fileNameFor(String title) {
    final cleaned = title
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .toLowerCase();
    return cleaned.isEmpty ? 'whiteboard' : cleaned;
  }
}
