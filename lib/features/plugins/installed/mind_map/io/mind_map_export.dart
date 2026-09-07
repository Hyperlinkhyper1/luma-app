import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../converter/file_saver.dart';
import '../data/mind_map_database.dart';
import '../mind_map_repository.dart';
import 'mind_map_outline.dart';

enum MindMapExportFormat { png, markdown, opml }

class MindMapExport {
  const MindMapExport._();

  /// Writes the map out and returns a line to show the user, or null when
  /// they cancelled the save dialog.
  static Future<String?> run({
    required MindMapExportFormat format,
    required MindMapRepository repository,
    required MindMap map,
    required GlobalKey boundaryKey,
  }) async {
    final name = _fileNameFor(map.title);
    return switch (format) {
      MindMapExportFormat.png => _savePng(boundaryKey, name),
      MindMapExportFormat.markdown => _saveOutline(
          repository: repository,
          map: map,
          name: '$name.md',
          mimeType: 'text/markdown',
          extension: 'md',
          render: (roots, _) => MindMapOutline.toMarkdown(roots),
        ),
      MindMapExportFormat.opml => _saveOutline(
          repository: repository,
          map: map,
          name: '$name.opml',
          mimeType: 'text/x-opml',
          extension: 'opml',
          render: (roots, title) => MindMapOutline.toOpml(roots, title: title),
        ),
    };
  }

  /// Captures the whole map, not just what is on screen.
  ///
  /// The repaint boundary wraps the full-size canvas inside the viewer, so
  /// `toImage` renders the entire layer regardless of where the user happens
  /// to be panned or zoomed to.
  static Future<String?> _savePng(GlobalKey boundaryKey, String name) async {
    final object = boundaryKey.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) {
      throw StateError('The canvas is not ready to be captured.');
    }
    final image = await object.toImage(pixelRatio: 2);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('The image could not be encoded.');
      final result = await saveConvertedFile(
        bytes: data.buffer.asUint8List(),
        suggestedName: '$name.png',
        mimeType: 'image/png',
        extensions: const ['png'],
        dialogTitle: 'Save mind map image',
      );
      return result.saved ? result.summary : null;
    } finally {
      image.dispose();
    }
  }

  static Future<String?> _saveOutline({
    required MindMapRepository repository,
    required MindMap map,
    required String name,
    required String mimeType,
    required String extension,
    required String Function(List<OutlineNode> roots, String title) render,
  }) async {
    final roots = await repository.toOutline(map.id);
    final text = render(roots, map.title);
    final result = await saveConvertedFile(
      bytes: utf8.encode(text),
      suggestedName: name,
      mimeType: mimeType,
      extensions: [extension],
      dialogTitle: 'Save mind map outline',
    );
    return result.saved ? result.summary : null;
  }

  static String _fileNameFor(String title) {
    final cleaned = title
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .toLowerCase();
    return cleaned.isEmpty ? 'mind-map' : cleaned;
  }
}
