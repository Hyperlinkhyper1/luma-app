import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:luma/features/plugins/installed/free_sketch/engine/adjustments.dart';
import 'package:luma/features/plugins/installed/free_sketch/engine/brush_textures.dart';
import 'package:luma/features/plugins/installed/free_sketch/engine/compositor.dart';
import 'package:luma/features/plugins/installed/free_sketch/engine/dab_renderer.dart';
import 'package:luma/features/plugins/installed/free_sketch/engine/flood_fill.dart';
import 'package:luma/features/plugins/installed/free_sketch/engine/sketch_document.dart';
import 'package:luma/features/plugins/installed/free_sketch/engine/stroke_engine.dart';
import 'package:luma/features/plugins/installed/free_sketch/engine/stroke_session.dart';
import 'package:luma/features/plugins/installed/free_sketch/engine/symmetry.dart';
import 'package:luma/features/plugins/installed/free_sketch/free_sketch_repository.dart';
import 'package:luma/features/plugins/installed/free_sketch/io/ora_writer.dart';
import 'package:luma/features/plugins/installed/free_sketch/io/psd_writer.dart';
import 'package:luma/features/plugins/installed/free_sketch/io/sketch_export.dart';
import 'package:luma/features/plugins/installed/free_sketch/model/brush.dart';
import 'package:luma/features/plugins/installed/free_sketch/model/sketch_blend.dart';
import 'package:luma/features/plugins/installed/free_sketch/model/sketch_meta.dart';
import 'package:luma/storage/storage_guard.dart';

/// A brush with every source of randomness and lag switched off, so dab
/// positions can be asserted exactly.
BrushPreset _plain({
  double size = 10,
  double spacing = 0.25,
  double sizePressure = 0,
  double taperStart = 0,
  double taperEnd = 0,
  double streamline = 0,
}) =>
    BrushPreset(
      id: 'test',
      name: 'Test',
      category: BrushCategory.painting,
      size: size,
      spacing: spacing,
      hardness: 1,
      sizePressure: sizePressure,
      flowPressure: 0,
      taperStart: taperStart,
      taperEnd: taperEnd,
      streamline: streamline,
    );

List<Dab> _stroke(StrokeEngine engine, List<StrokeInput> inputs) => [
      for (final input in inputs) ...engine.add(input),
      ...engine.finish(),
    ];

List<StrokeInput> _line(Offset from, Offset to, {int steps = 50, double pressure = 1}) => [
      for (var i = 0; i <= steps; i++) StrokeInput(Offset.lerp(from, to, i / steps)!, pressure: pressure),
    ];

ui.Image _solid(int w, int h, Color color, {Rect? rect}) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(rect ?? Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = color);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(w, h);
  picture.dispose();
  return image;
}

Future<List<int>> _pixel(ui.Image image, int x, int y) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  final o = (y * image.width + x) * 4;
  return [for (var i = 0; i < 4; i++) data!.getUint8(o + i)];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('brush library', () {
    test('ids are unique and every category has brushes', () {
      final ids = BrushLibrary.all.map((b) => b.id).toSet();
      expect(ids, hasLength(BrushLibrary.all.length));
      for (final category in BrushCategory.values) {
        expect(BrushLibrary.inCategory(category), isNotEmpty, reason: category.label);
      }
      expect(BrushLibrary.contains(BrushLibrary.defaultBrush), isTrue);
      expect(BrushLibrary.contains(BrushLibrary.defaultEraser), isTrue);
      expect(BrushLibrary.contains(BrushLibrary.defaultSmudge), isTrue);
    });

    test('defaults sit inside their own slider ranges', () {
      for (final brush in BrushLibrary.all) {
        for (final param in brush.adjustable) {
          final max = param == BrushParam.size ? brush.maxSize : param.max;
          expect(brush.get(param), inInclusiveRange(param.min, max), reason: '${brush.id}.${param.name}');
        }
      }
    });

    test('overrides apply, clamp, and ignore keys they do not know', () {
      final base = BrushLibrary.byId('pencil_hb');
      final tuned = base.withOverrides({'size': 20, 'opacity': 7, 'fromTheFuture': 3});
      expect(tuned.size, 20);
      expect(tuned.opacity, 1, reason: 'clamped to the parameter maximum');
      expect(tuned.flow, base.flow);
      expect(BrushLibrary.byId('no-such-brush').id, BrushLibrary.all.first.id);
    });
  });

  group('stroke engine', () {
    test('dabs are spaced by spacing × diameter along a straight line', () {
      final engine = StrokeEngine(brush: _plain(), color: Colors.black, seed: 1);
      final dabs = _stroke(engine, _line(Offset.zero, const Offset(100, 0)));
      final xs = dabs.map((d) => d.center.dx).toList();
      expect(xs.first, 0);
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i] - xs[i - 1], closeTo(2.5, 1e-6));
      }
      expect(xs.last, closeTo(100, 2.5));
      expect(dabs.every((d) => d.center.dy == 0), isTrue);
    });

    test('light pressure shrinks the dab by sizePressure', () {
      final engine = StrokeEngine(brush: _plain(sizePressure: 0.8), color: Colors.black, seed: 1);
      final dabs = _stroke(engine, _line(Offset.zero, const Offset(40, 0), pressure: 0.25));
      expect(dabs.first.size, closeTo(10 * (1 - 0.8 * 0.75), 1e-6));
    });

    test('the pressure curve bends pressure before it reaches the brush', () {
      final soft = StrokeEngine(brush: _plain(sizePressure: 1), color: Colors.black, pressureGamma: 0.5, seed: 1);
      final firm = StrokeEngine(brush: _plain(sizePressure: 1), color: Colors.black, pressureGamma: 2, seed: 1);
      final a = soft.add(const StrokeInput(Offset.zero, pressure: 0.25)).single;
      final b = firm.add(const StrokeInput(Offset.zero, pressure: 0.25)).single;
      expect(a.size, closeTo(5, 1e-6));
      expect(b.size, closeTo(0.625, 1e-6));
    });

    test('end taper thins the last dabs and leaves the middle alone', () {
      final engine = StrokeEngine(brush: _plain(taperEnd: 1), color: Colors.black, seed: 1);
      final dabs = _stroke(engine, _line(Offset.zero, const Offset(200, 0), steps: 100));
      final middle = dabs[dabs.length ~/ 2];
      expect(middle.size, 10);
      expect(dabs.last.size, lessThan(middle.size * 0.5));
    });

    test('while drawing, the tail waiting for the taper is provisional', () {
      final engine = StrokeEngine(brush: _plain(taperEnd: 1), color: Colors.black, seed: 1);
      final released = <Dab>[];
      for (final input in _line(Offset.zero, const Offset(200, 0), steps: 100)) {
        released.addAll(engine.add(input));
      }
      expect(engine.provisional, isNotEmpty);
      final cut = engine.length - 25;
      expect(released.every((d) => d.distance < cut), isTrue);
      expect(engine.provisional.every((d) => d.distance >= cut), isTrue);
    });

    test('a tap is a full-size dot even on a tapered brush', () {
      final engine = StrokeEngine(brush: _plain(taperStart: 1, taperEnd: 1), color: Colors.black, seed: 1);
      final dabs = _stroke(engine, const [StrokeInput(Offset(5, 5))]);
      expect(dabs.last.size, 10);
      expect(dabs.last.center, const Offset(5, 5));
    });

    test('StreamLine lags the pen but catches up to where it lifted', () {
      final engine = StrokeEngine(brush: _plain(streamline: 0.9), color: Colors.black, seed: 1);
      final dabs = _stroke(engine, [
        ..._line(Offset.zero, const Offset(100, 0), steps: 20),
        ..._line(const Offset(100, 0), const Offset(100, 100), steps: 20),
      ]);
      expect((dabs.last.center - const Offset(100, 100)).distance, lessThan(3));
      // The corner is cut: no dab reaches the sharp (100, 0) turn.
      final nearest = dabs.map((d) => (d.center - const Offset(100, 0)).distance).reduce((a, b) => a < b ? a : b);
      expect(nearest, greaterThan(5));
    });

    test('airbrush builds up only on airbrush brushes', () {
      final air = StrokeEngine(brush: BrushLibrary.byId('airbrush'), color: Colors.black, seed: 1)
        ..add(const StrokeInput(Offset(10, 10)));
      final pen = StrokeEngine(brush: BrushLibrary.byId('studio_pen'), color: Colors.black, seed: 1)
        ..add(const StrokeInput(Offset(10, 10)));
      expect(air.dwell(0.1), isNotEmpty);
      expect(pen.dwell(0.1), isEmpty);
    });
  });

  group('symmetry', () {
    const canvas = Size(200, 100);
    const dab = Dab(center: Offset(30, 20), size: 4, alpha: 1, angle: 0.3, color: Colors.black);

    test('vertical mirrors across the centre line', () {
      final out = const SymmetrySettings(mode: SymmetryMode.vertical).expand([dab], canvas);
      expect(out.map((d) => d.center), [const Offset(30, 20), const Offset(170, 20)]);
    });

    test('quadrant makes four copies', () {
      final out = const SymmetrySettings(mode: SymmetryMode.quadrant).expand([dab], canvas);
      expect(out.map((d) => d.center).toSet(), {
        const Offset(30, 20),
        const Offset(170, 20),
        const Offset(30, 80),
        const Offset(170, 80),
      });
    });

    test('radial repeats around the centre', () {
      final out = const SymmetrySettings(mode: SymmetryMode.radial, segments: 6).expand([dab], canvas);
      expect(out, hasLength(6));
      for (final d in out) {
        expect((d.center - const Offset(100, 50)).distance, closeTo((dab.center - const Offset(100, 50)).distance, 1e-9));
      }
      final mirrored = const SymmetrySettings(mode: SymmetryMode.radial, segments: 6, mirrorRadial: true)
          .expand([dab], canvas);
      expect(mirrored, hasLength(12));
    });

    test('settings survive a JSON round trip', () {
      const s = SymmetrySettings(mode: SymmetryMode.radial, segments: 8, mirrorRadial: true);
      final back = SymmetrySettings.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect(back.mode, SymmetryMode.radial);
      expect(back.segments, 8);
      expect(back.mirrorRadial, isTrue);
      expect(SymmetrySettings.fromJson('garbage').mode, SymmetryMode.off);
    });
  });

  group('flood fill', () {
    /// 10×10 transparent canvas with an opaque vertical wall at x = 5.
    Uint8List walled() {
      final rgba = Uint8List(10 * 10 * 4);
      for (var y = 0; y < 10; y++) {
        final o = (y * 10 + 5) * 4;
        rgba[o] = 0;
        rgba[o + 3] = 255;
      }
      return rgba;
    }

    test('fills the connected region and stops at the wall', () {
      final mask = floodFillMask(walled(), 10, 10, 1, 1, grow: 0);
      expect(mask.where((v) => v == 255).length, 50);
      expect(mask[2 * 10 + 4], 255);
      expect(mask[2 * 10 + 5], 0);
      expect(mask[2 * 10 + 6], 0);
    });

    test('grow creeps one pixel under the line', () {
      final mask = floodFillMask(walled(), 10, 10, 1, 1, grow: 1);
      expect(mask[2 * 10 + 5], 255);
      expect(mask[2 * 10 + 6], 0);
    });

    test('tolerance decides whether a near colour counts as the same', () {
      final rgba = Uint8List(4 * 4);
      for (var i = 0; i < 4; i++) {
        rgba[i * 4] = i == 3 ? 40 : 10;
        rgba[i * 4 + 3] = 255;
      }
      expect(floodFillMask(rgba, 4, 1, 0, 0, tolerance: 0.05, grow: 0).where((v) => v != 0).length, 3);
      expect(floodFillMask(rgba, 4, 1, 0, 0, tolerance: 0.2, grow: 0).where((v) => v != 0).length, 4);
    });

    test('opaque bounds finds the drawn pixels', () {
      final rgba = Uint8List(8 * 8 * 4);
      rgba[(3 * 8 + 2) * 4 + 3] = 255;
      rgba[(5 * 8 + 6) * 4 + 3] = 10;
      final b = opaqueBounds(rgba, 8, 8)!;
      expect((b.left, b.top, b.right, b.bottom), (2, 3, 7, 6));
      expect(opaqueBounds(Uint8List(16), 2, 2), isNull);
    });
  });

  group('file formats', () {
    test('PackBits round-trips runs, literals and the 128-byte limits', () {
      final input = Uint8List.fromList([
        ...List.filled(300, 7),
        1, 2, 3, 4, 5,
        ...List.generate(200, (i) => i % 251),
        9, 9,
        0,
      ]);
      final packed = packBits(input);
      expect(packed.length, lessThan(input.length));
      expect(unpackBits(packed, input.length), input);
    });

    test('PSD layers read back with names, blend modes, visibility and pixels', () {
      const w = 6;
      const h = 4;
      Uint8List layer(int x, int y, List<int> rgba) {
        final out = Uint8List(w * h * 4);
        out.setRange((y * w + x) * 4, (y * w + x) * 4 + 4, rgba);
        return out;
      }

      final bytes = encodePsd(
        width: w,
        height: h,
        layers: [
          PsdLayerData(name: 'Ink', rgba: layer(1, 1, [255, 0, 0, 255])),
          PsdLayerData(
            name: 'Shade',
            rgba: layer(4, 2, [0, 0, 255, 128]),
            opacity: 0.5,
            blendKey: SketchBlend.multiply.psdKey,
            visible: false,
            clipped: true,
          ),
          PsdLayerData(name: 'Empty', rgba: Uint8List(w * h * 4)),
        ],
        composite: Uint8List(w * h * 4),
      );
      final psd = img.PsdDecoder().decodePsd(bytes);
      expect(psd, isNotNull);
      expect(psd!.width, w);
      expect(psd.height, h);
      expect(psd.layers.map((l) => l.name), ['Ink', 'Shade', 'Empty']);

      final ink = psd.layers[0];
      expect((ink.left, ink.top, ink.width, ink.height), (1, 1, 1, 1));
      final p = ink.layerImage!.getPixel(0, 0);
      expect([p.r, p.g, p.b, p.a], [255, 0, 0, 255]);

      final shade = psd.layers[1];
      int key(String s) => s.codeUnits.fold(0, (acc, c) => (acc << 8) | c);
      expect(shade.blendMode, key('mul '));
      expect(shade.opacity, 128);
      expect(shade.isVisible(), isFalse);
      expect(shade.clipping, 1);
      expect(ink.isVisible(), isTrue);
    });

    test('OpenRaster puts an uncompressed mimetype first and lists layers top first', () {
      final png = Uint8List.fromList([137, 80, 78, 71]);
      final bytes = encodeOra(
        width: 10,
        height: 8,
        layers: [
          OraLayerData(name: 'Bottom', png: png),
          OraLayerData(name: 'Top & "quoted"', png: png, compositeOp: SketchBlend.screen.oraOp, visible: false),
        ],
        mergedPng: png,
        thumbnailPng: png,
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.files.first.name, 'mimetype');
      expect(utf8.decode(archive.files.first.content as List<int>), 'image/openraster');
      final stack = utf8.decode(archive.findFile('stack.xml')!.content as List<int>);
      expect(stack.indexOf('Top &amp; &quot;quoted&quot;'), lessThan(stack.indexOf('Bottom')));
      expect(stack, contains('composite-op="svg:screen"'));
      expect(stack, contains('visibility="hidden"'));
      expect(archive.findFile('mergedimage.png'), isNotNull);
      expect(archive.findFile('Thumbnails/thumbnail.png'), isNotNull);
    });

    test('document metadata survives JSON and tolerates unknown blend modes', () {
      final meta = SketchMeta(
        id: 's1',
        title: 'Harbour',
        width: 640,
        height: 480,
        created: DateTime.utc(2026, 9, 1),
        updated: DateTime.utc(2026, 9, 2),
        background: 0xFFF6F1E7,
        showBackground: false,
        activeLayerId: 2,
        layers: const [
          SketchLayerMeta(id: 1, name: 'Sketch', file: 'layer_1_1.png', opacity: 0.4, blend: SketchBlend.multiply),
          SketchLayerMeta(id: 2, name: 'Colour', alphaLocked: true, clipped: true, visible: false, locked: true),
        ],
      );
      final json = jsonDecode(jsonEncode(meta.toJson())) as Map<String, Object?>;
      final back = SketchMeta.fromJson('s1', json);
      expect(back.title, 'Harbour');
      expect((back.width, back.height), (640, 480));
      expect(back.showBackground, isFalse);
      expect(back.background, 0xFFF6F1E7);
      expect(back.activeLayerId, 2);
      expect(back.layers[0].blend, SketchBlend.multiply);
      expect(back.layers[0].opacity, 0.4);
      expect(back.layers[1].file, isNull);
      expect(back.layers[1].clipped && back.layers[1].alphaLocked && back.layers[1].locked, isTrue);
      expect(back.layers[1].visible, isFalse);

      (json['layers'] as List).first['blend'] = 'hologram';
      expect(SketchMeta.fromJson('s1', json).layers.first.blend, SketchBlend.normal);
      expect(() => SketchMeta.fromJson('s1', {'width': 0}), throwsFormatException);
    });
  });

  group('history', () {
    test('undo and redo walk snapshots and dispose what nothing can reach', () {
      final doc = SketchDocument.blank(width: 8, height: 8);
      final first = _solid(8, 8, Colors.red);
      final second = _solid(8, 8, Colors.blue);
      final third = _solid(8, 8, Colors.green);
      final layer = doc.state.active;

      doc.commit(doc.state.replaceLayer(layer.copyWith(image: first)), 'one');
      doc.commit(doc.state.replaceLayer(layer.copyWith(image: second)), 'two');
      expect(doc.undoLabel, 'two');
      expect(doc.undo(), isTrue);
      expect(doc.state.active.image, same(first));
      expect(doc.redoLabel, 'two');

      // A new step after an undo drops the redo branch — and its image.
      doc.commit(doc.state.replaceLayer(layer.copyWith(image: third)), 'three');
      expect(doc.canRedo, isFalse);
      expect(second.debugDisposed, isTrue);
      expect(first.debugDisposed, isFalse);

      expect(doc.undo(), isTrue);
      expect(doc.undo(), isTrue);
      expect(doc.state.active.image, isNull);
      expect(doc.redo(), isTrue);
      expect(doc.state.active.image, same(first));
      doc.dispose();
      expect(first.debugDisposed && third.debugDisposed, isTrue);
    });

    test('old steps are dropped once history outgrows its memory budget', () {
      final doc = SketchDocument(
        width: 4,
        height: 4,
        memoryBudget: 4 * 4 * 4 * 3,
        initial: const SketchSnapshot(
          layers: [SketchLayer(id: 1, name: 'L')],
          activeLayerId: 1,
          background: Colors.white,
        ),
      );
      final images = <ui.Image>[];
      for (var i = 0; i < 8; i++) {
        final image = _solid(4, 4, Color(0xFF000000 + i));
        images.add(image);
        doc.commit(doc.state.replaceLayer(doc.state.active.copyWith(image: image)), 'step $i');
      }
      expect(doc.undoDepth, lessThanOrEqualTo(4));
      expect(images.first.debugDisposed, isTrue);
      expect(images.last.debugDisposed, isFalse);
      doc.dispose();
    });

    test('a run of previews collapses into one undo step', () {
      final doc = SketchDocument.blank(width: 4, height: 4);
      final before = doc.state;
      for (final opacity in [0.9, 0.6, 0.3]) {
        doc.preview(doc.state.replaceLayer(doc.state.active.copyWith(opacity: opacity)));
      }
      doc.commitFrom(before, 'Layer opacity');
      expect(doc.undoDepth, 1);
      doc.undo();
      expect(doc.state.active.opacity, 1);
      doc.dispose();
    });
  });

  group('painting', () {
    late BrushTextures textures;
    setUpAll(() async => textures = await BrushTextures.load());

    StrokeSession session(
      SketchLayer layer,
      StrokeMode mode, {
      BrushPreset? brush,
      Path? selection,
      Color color = Colors.black,
    }) =>
        StrokeSession(
          layer: layer,
          width: 40,
          height: 20,
          brush: brush ?? _plain(size: 8),
          mode: mode,
          color: color,
          renderer: DabRenderer(textures),
          selection: selection,
          seed: 1,
        );

    ui.Image run(StrokeSession s, Offset from, Offset to) {
      for (final input in _line(from, to, steps: 30)) {
        s.add(input);
      }
      s.finish();
      final image = s.commit()!;
      s.dispose();
      return image;
    }

    test('paint lands on the layer; the eraser takes it back off', () async {
      const layer = SketchLayer(id: 1, name: 'L');
      final painted = run(session(layer, StrokeMode.paint), const Offset(4, 10), const Offset(36, 10));
      expect((await _pixel(painted, 20, 10))[3], 255);
      expect((await _pixel(painted, 20, 1))[3], 0);

      final erased = run(
        session(layer.copyWith(image: painted), StrokeMode.erase),
        const Offset(4, 10),
        const Offset(36, 10),
      );
      expect((await _pixel(erased, 20, 10))[3], 0);
    });

    test('alpha lock only recolours pixels that were already there', () async {
      final base = _solid(40, 20, Colors.red, rect: const Rect.fromLTWH(0, 0, 20, 20));
      final layer = SketchLayer(id: 1, name: 'L', image: base, alphaLocked: true);
      final out = run(session(layer, StrokeMode.paint, color: const Color(0xFF0000FF)), const Offset(4, 10), const Offset(36, 10));
      expect(await _pixel(out, 10, 10), [0, 0, 255, 255]);
      expect((await _pixel(out, 30, 10))[3], 0);
    });

    test('a selection keeps the stroke inside it', () async {
      final selection = Path()..addRect(const Rect.fromLTWH(0, 0, 20, 20));
      const layer = SketchLayer(id: 1, name: 'L');
      final out = run(session(layer, StrokeMode.paint, selection: selection), const Offset(4, 10), const Offset(36, 10));
      expect((await _pixel(out, 10, 10))[3], 255);
      expect((await _pixel(out, 30, 10))[3], 0);
    });

    test('smudge drags colour and never erases on its own', () async {
      final r = ui.PictureRecorder();
      final c = Canvas(r);
      c.drawRect(const Rect.fromLTWH(0, 0, 20, 20), Paint()..color = Colors.red);
      c.drawRect(const Rect.fromLTWH(20, 0, 20, 20), Paint()..color = Colors.blue);
      final base = r.endRecording().toImageSync(40, 20);
      final layer = SketchLayer(id: 1, name: 'L', image: base);
      final smudger = BrushLibrary.byId('smudge').copyWithParam(BrushParam.size, 10).copyWithParam(BrushParam.streamline, 0);
      final out = run(session(layer, StrokeMode.smudge, brush: smudger), const Offset(6, 10), const Offset(34, 10));
      final dragged = await _pixel(out, 26, 10);
      expect(dragged[0], greaterThan(60), reason: 'red carried into the blue');
      expect(dragged[3], 255);
    });

    test('a clipping mask shows only through the layer below', () async {
      final base = _solid(40, 20, Colors.white, rect: const Rect.fromLTWH(0, 0, 20, 20));
      final top = _solid(40, 20, const Color(0xFF0000FF));
      final state = SketchSnapshot(
        layers: [
          SketchLayer(id: 1, name: 'Base', image: base),
          SketchLayer(id: 2, name: 'Clipped', image: top, clipped: true),
        ],
        activeLayerId: 2,
        background: Colors.black,
        showBackground: false,
      );
      final flat = SketchCompositor.flatten(state, 40, 20);
      expect(await _pixel(flat, 10, 10), [0, 0, 255, 255]);
      expect((await _pixel(flat, 30, 10))[3], 0);
    });

    test('blend modes and opacity composite like Photoshop', () async {
      final state = SketchSnapshot(
        layers: [
          SketchLayer(id: 1, name: 'Grey', image: _solid(4, 4, const Color(0xFF808080))),
          SketchLayer(id: 2, name: 'Multiply', image: _solid(4, 4, const Color(0xFF808080)), blend: SketchBlend.multiply),
        ],
        activeLayerId: 2,
        background: Colors.white,
      );
      final multiplied = await _pixel(SketchCompositor.flatten(state, 4, 4), 1, 1);
      expect(multiplied[0], closeTo(64, 2));

      final faded = state.replaceLayer(state.layers[1].copyWith(blend: SketchBlend.normal, opacity: 0));
      expect((await _pixel(SketchCompositor.flatten(faded, 4, 4), 1, 1))[0], closeTo(128, 1));

      final hidden = state.replaceLayer(state.layers[0].copyWith(visible: false));
      final onlyTop = await _pixel(SketchCompositor.flatten(hidden, 4, 4), 1, 1);
      expect(onlyTop[0], closeTo(128, 1), reason: 'multiply over white background');
    });

    test('the eyedropper reads the composite at a canvas point', () async {
      final state = SketchSnapshot(
        layers: [SketchLayer(id: 1, name: 'L', image: _solid(10, 10, Colors.red, rect: const Rect.fromLTWH(0, 0, 5, 10)))],
        activeLayerId: 1,
        background: const Color(0xFF00FF00),
      );
      expect(await SketchCompositor.sample(state, const Offset(2, 2)), const Color(0xFFF44336));
      expect(await SketchCompositor.sample(state, const Offset(8, 2)), const Color(0xFF00FF00));
      expect(await SketchCompositor.sample(state, const Offset(8, 2), layerId: 1), isNull);
    });

    test('invert adjustment flips a colour', () async {
      final r = ui.PictureRecorder();
      final c = Canvas(r);
      c.saveLayer(null, AdjustmentKind.invert.paint(const {}));
      c.drawRect(const Rect.fromLTWH(0, 0, 2, 2), Paint()..color = const Color(0xFF204060));
      c.restore();
      final image = r.endRecording().toImageSync(2, 2);
      expect(await _pixel(image, 0, 0), [0xDF, 0xBF, 0x9F, 255]);
    });

    test('exports decode back: PNG size and a PSD with every layer', () async {
      final state = SketchSnapshot(
        layers: [
          SketchLayer(id: 1, name: 'Line art', image: _solid(12, 8, Colors.black, rect: const Rect.fromLTWH(2, 2, 3, 3))),
          const SketchLayer(id: 2, name: 'Empty'),
        ],
        activeLayerId: 1,
        background: Colors.white,
      );
      final png = img.decodePng(await SketchExporter.encode(state, 12, 8, SketchExportFormat.png))!;
      expect((png.width, png.height), (12, 8));
      final jpg = img.decodeJpg(await SketchExporter.encode(state, 12, 8, SketchExportFormat.jpeg))!;
      expect(jpg.width, 12);
      final psd = img.PsdDecoder().decodePsd(await SketchExporter.encode(state, 12, 8, SketchExportFormat.psd))!;
      expect(psd.layers.map((l) => l.name), ['Background', 'Line art', 'Empty']);
      final ora = ZipDecoder().decodeBytes(await SketchExporter.encode(state, 12, 8, SketchExportFormat.ora));
      expect(ora.files.where((f) => f.name.startsWith('data/')), hasLength(3));
      expect(SketchExporter.fileNameFor(' My  Art: v2? '), 'my-art-v2');
    });
  });

  group('repository', () {
    late Directory root;
    late FreeSketchRepository repository;

    setUpAll(() => StorageGuardService.instance = StorageGuardService());
    setUp(() async {
      root = await Directory.systemTemp.createTemp('free_sketch_test');
      repository = FreeSketchRepository(root: () async => root);
    });
    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('create, save changed layers, load, and sweep replaced files', () async {
      final meta = await repository.create(title: 'Study', width: 32, height: 16);
      expect((await repository.list()).single.meta.title, 'Study');

      final first = await repository.save(
        meta.copyWith(layers: [
          ...meta.layers,
          const SketchLayerMeta(id: 2, name: 'Colour', blend: SketchBlend.overlay),
        ]),
        changed: {1: Uint8List.fromList([1, 2, 3]), 2: Uint8List.fromList([4, 5])},
        thumbnail: Uint8List.fromList([9]),
      );
      final file1 = first.layers[0].file!;
      final loaded = await repository.load(meta.id);
      expect(loaded.layers[1], [1, 2, 3]);
      expect(loaded.layers[2], [4, 5]);
      expect(loaded.meta.layers[1].blend, SketchBlend.overlay);

      // Only layer 2 changes, then is cleared: layer 1 keeps its file, the
      // old layer 2 file is swept.
      final second = await repository.save(first, changed: {2: null});
      expect(second.layers[0].file, file1);
      expect(second.layers[1].file, isNull);
      final docDir = Directory('${root.path}${Platform.pathSeparator}docs${Platform.pathSeparator}${meta.id}');
      final pngs = docDir.listSync().map((e) => e.path.split(Platform.pathSeparator).last).where((n) => n.endsWith('.png'));
      expect(pngs.toSet(), {file1, 'thumb.png'});
      expect((await repository.list()).single.thumbnail, isNotNull);
    });

    test('rename, duplicate and delete', () async {
      final meta = await repository.create(title: 'One', width: 16, height: 16, firstLayerPng: Uint8List.fromList([7]));
      await repository.rename(meta.id, 'Renamed');
      final copy = await repository.duplicate(meta.id);
      final titles = (await repository.list()).map((s) => s.meta.title).toSet();
      expect(titles, {'Renamed', 'Renamed copy'});
      expect((await repository.load(copy.id)).layers[1], [7]);
      await repository.delete(meta.id);
      expect((await repository.list()).single.meta.id, copy.id);
      expect(() => repository.load('../escape'), throwsArgumentError);
    });

    test('a broken document folder is skipped rather than breaking the list', () async {
      await repository.create(title: 'Good', width: 16, height: 16);
      final broken = Directory('${root.path}${Platform.pathSeparator}docs${Platform.pathSeparator}sBroken');
      await broken.create(recursive: true);
      await File('${broken.path}${Platform.pathSeparator}document.json').writeAsString('{not json');
      expect((await repository.list()).map((s) => s.meta.title), ['Good']);
    });

    test('preferences round-trip and survive corruption', () async {
      await repository.savePrefs({'color': 42, 'overrides': {'pencil_hb': {'size': 3.0}}});
      expect((await repository.loadPrefs())['color'], 42);
      await File('${root.path}${Platform.pathSeparator}prefs.json').writeAsString('][');
      expect(await repository.loadPrefs(), isEmpty);
    });
  });
}
