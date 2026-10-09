import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../block_colors.dart';
import '../schematic_model.dart';

/// A bounded isometric preview made from luma's own block colours.
/// Samples top surfaces instead of building geometry for millions of blocks.
Uint8List axiomThumbnail(Schematic schematic) {
  final step = math.max(
    1,
    math.sqrt(schematic.width * schematic.length / 16000).ceil(),
  );
  final surfaces = <({int x, int y, int z, int color})>[];
  for (var z = 0; z < schematic.length; z += step) {
    for (var x = 0; x < schematic.width; x += step) {
      for (var y = schematic.height - 1; y >= 0; y--) {
        final state = schematic.blockAt(x, y, z);
        if (state.isAir) continue;
        surfaces.add((
          x: x,
          y: y,
          z: z,
          color: BlockColors.of(state).toARGB32(),
        ));
        break;
      }
    }
  }
  // A thin build can fall entirely between sampled columns.
  if (surfaces.isEmpty && schematic.blockCount > 0) {
    for (var i = 0; i < schematic.blocks.length; i++) {
      final state = schematic.palette[schematic.blocks[i]];
      if (state.isAir) continue;
      surfaces.add((
        x: i % schematic.width,
        y: i ~/ (schematic.width * schematic.length),
        z: (i ~/ schematic.width) % schematic.length,
        color: BlockColors.of(state).toARGB32(),
      ));
      break;
    }
  }
  final image = img.Image(width: 128, height: 128, numChannels: 4);
  if (surfaces.isEmpty) return img.encodePng(image);
  surfaces.sort((a, b) => (a.x + a.z).compareTo(b.x + b.z));
  final size = step.toDouble();
  (double, double) project(double x, double y, double z) =>
      ((x - z) * 0.8, (x + z) * 0.4 - y);
  final faces = <({List<(double, double)> points, int color, double shade})>[];
  for (final surface in surfaces) {
    final x = surface.x.toDouble(),
        y = surface.y.toDouble(),
        z = surface.z.toDouble();
    final x1 = math.min(x + size, schematic.width.toDouble());
    final z1 = math.min(z + size, schematic.length.toDouble());
    final top = y + 1;
    final bottom = top - math.min(size, top);
    faces.add((
      points: [
        project(x1, bottom, z),
        project(x1, bottom, z1),
        project(x1, top, z1),
        project(x1, top, z),
      ],
      color: surface.color,
      shade: 0.65,
    ));
    faces.add((
      points: [
        project(x, bottom, z1),
        project(x1, bottom, z1),
        project(x1, top, z1),
        project(x, top, z1),
      ],
      color: surface.color,
      shade: 0.8,
    ));
    faces.add((
      points: [
        project(x, top, z),
        project(x1, top, z),
        project(x1, top, z1),
        project(x, top, z1),
      ],
      color: surface.color,
      shade: 1,
    ));
  }
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (final face in faces) {
    for (final point in face.points) {
      minX = math.min(minX, point.$1);
      maxX = math.max(maxX, point.$1);
      minY = math.min(minY, point.$2);
      maxY = math.max(maxY, point.$2);
    }
  }
  final scale = math.min(
    112 / math.max(1, maxX - minX),
    112 / math.max(1, maxY - minY),
  );
  final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
  for (final face in faces) {
    int channel(int shift) =>
        (((face.color >> shift) & 255) * face.shade).round();
    img.fillPolygon(
      image,
      vertices: [
        for (final point in face.points)
          img.Point(
            ((point.$1 - cx) * scale + 64).round(),
            ((point.$2 - cy) * scale + 64).round(),
          ),
      ],
      color: img.ColorRgba8(channel(16), channel(8), channel(0), 255),
    );
  }
  return img.encodePng(image);
}
