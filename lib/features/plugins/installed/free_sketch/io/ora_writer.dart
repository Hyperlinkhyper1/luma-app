import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// One layer for [encodeOra], already encoded as a full-canvas PNG.
class OraLayerData {
  const OraLayerData({
    required this.name,
    required this.png,
    this.opacity = 1,
    this.compositeOp = 'svg:src-over',
    this.visible = true,
  });

  final String name;
  final Uint8List png;
  final double opacity;
  final String compositeOp;
  final bool visible;
}

/// Writes an OpenRaster (`.ora`) file — the open layered format Krita, GIMP
/// and MyPaint all read. It is a zip: an uncompressed `mimetype` entry first
/// (that is how the format is sniffed), `stack.xml` listing the layers top
/// first, one PNG per layer, and a flattened copy plus thumbnail.
Uint8List encodeOra({
  required int width,
  required int height,
  required List<OraLayerData> layers,
  required Uint8List mergedPng,
  required Uint8List thumbnailPng,
}) {
  final archive = Archive();
  final mime = utf8.encode('image/openraster');
  archive.addFile(ArchiveFile.noCompress('mimetype', mime.length, mime));

  final stack = StringBuffer()
    ..writeln("<?xml version='1.0' encoding='UTF-8'?>")
    ..writeln('<image version="0.0.3" w="$width" h="$height" xres="72" yres="72">')
    ..writeln('  <stack>');
  for (var i = layers.length - 1; i >= 0; i--) {
    final layer = layers[i];
    final src = 'data/layer$i.png';
    stack.writeln(
      '    <layer name="${_escape(layer.name)}" src="$src" x="0" y="0" '
      'opacity="${layer.opacity.clamp(0.0, 1.0).toStringAsFixed(3)}" '
      'visibility="${layer.visible ? 'visible' : 'hidden'}" '
      'composite-op="${layer.compositeOp}"/>',
    );
    archive.addFile(ArchiveFile.noCompress(src, layer.png.length, layer.png));
  }
  stack
    ..writeln('  </stack>')
    ..writeln('</image>');
  final xml = utf8.encode(stack.toString());
  archive.addFile(ArchiveFile.bytes('stack.xml', xml));
  archive.addFile(ArchiveFile.noCompress('mergedimage.png', mergedPng.length, mergedPng));
  archive.addFile(
    ArchiveFile.noCompress('Thumbnails/thumbnail.png', thumbnailPng.length, thumbnailPng),
  );
  return ZipEncoder().encodeBytes(archive);
}

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
