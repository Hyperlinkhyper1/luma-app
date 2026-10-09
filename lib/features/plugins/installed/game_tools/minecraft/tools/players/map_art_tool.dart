import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../../../../../converter/schematic/schematic_model.dart';
import '../../../../../../converter/tools/schematic_viewer.dart';
import '../../data/map_art.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_files.dart';
import '../../ui/mc_schematic_panel.dart';
import '../../ui/mc_style.dart';

enum _Fit {
  crop,
  contain,
  stretch;

  String label(L t) => switch (this) {
    crop => t.mcMapCrop,
    contain => t.mcMapContain,
    stretch => t.mcMapStretch,
  };
}

enum _Palette {
  all,
  survival,
  concrete,
  greys;

  String label(L t) => switch (this) {
    all => t.mcMapPaletteAll,
    survival => t.mcMapPaletteSurvival,
    concrete => t.mcMapPaletteConcrete,
    greys => t.mcMapPaletteGreys,
  };

  bool allows(McMapColor c) => switch (this) {
    _Palette.all => true,
    _Palette.survival => !{30, 31, 32, 33}.contains(c.id),
    _Palette.concrete => (c.id >= 15 && c.id <= 29) || c.id == 8 || (c.id >= 36 && c.id <= 51),
    _Palette.greys => {8, 22, 21, 29, 11, 6, 59, 3, 9}.contains(c.id),
  };
}

/// Builds the schematic for a converted map: one block per pixel, plus the
/// row of cobblestone north of the map that sets the first row's shade.
Schematic _buildMapSchematic(McMapArtResult art, bool staircase) {
  final w = art.width, h = art.height;
  final heights = staircase ? mcStaircaseHeights(art) : null;
  var maxY = 0;
  if (heights != null) {
    for (final v in heights) {
      if (v > maxY) maxY = v;
    }
  }
  final height = maxY + 1;
  final length = h + 1;
  final palette = PaletteBuilder();
  final blocks = Uint16List(w * height * length);
  final noob = palette.add(BlockState('minecraft:cobblestone'));
  final ids = <int, int>{};
  int at(int x, int y, int z) => x + z * w + y * w * length;
  for (var x = 0; x < w; x++) {
    final y0 = heights == null ? 0 : heights[x];
    blocks[at(x, y0, 0)] = noob;
    for (var z = 0; z < h; z++) {
      final ci = art.color[z * w + x];
      if (ci < 0) continue;
      final p = ids.putIfAbsent(ci, () {
        final c = kMcMapColors[ci];
        return palette.add(
          c.block == 'oak_leaves'
              ? BlockState('minecraft:oak_leaves', {'persistent': 'true'})
              : BlockState('minecraft:${c.block}'),
        );
      });
      final y = heights == null ? 0 : heights[(z + 1) * w + x];
      blocks[at(x, y, z + 1)] = p;
    }
  }
  return Schematic(
    width: w,
    height: height,
    length: length,
    palette: palette.build(),
    blocks: blocks,
    name: 'map_art',
    author: 'luma',
    dataVersion: 5023,
  );
}

const _notAnImage = 'not-an-image';

class _Prepared {
  const _Prepared(this.pixels, this.width, this.height);
  final Uint8List pixels;
  final int width;
  final int height;
}

_Prepared _prepare(Uint8List bytes, int mapsX, int mapsY, _Fit fit) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException(_notAnImage);
  final tw = mapsX * 128, th = mapsY * 128;
  img.Image scaled;
  switch (fit) {
    case _Fit.stretch:
      scaled = img.copyResize(decoded, width: tw, height: th, interpolation: img.Interpolation.average);
    case _Fit.crop:
      final scale = (tw / decoded.width) > (th / decoded.height) ? tw / decoded.width : th / decoded.height;
      final r = img.copyResize(
        decoded,
        width: (decoded.width * scale).ceil(),
        height: (decoded.height * scale).ceil(),
        interpolation: img.Interpolation.average,
      );
      scaled = img.copyCrop(r, x: (r.width - tw) ~/ 2, y: (r.height - th) ~/ 2, width: tw, height: th);
    case _Fit.contain:
      final scale = (tw / decoded.width) < (th / decoded.height) ? tw / decoded.width : th / decoded.height;
      final r = img.copyResize(
        decoded,
        width: (decoded.width * scale).floor().clamp(1, tw),
        height: (decoded.height * scale).floor().clamp(1, th),
        interpolation: img.Interpolation.average,
      );
      scaled = img.Image(width: tw, height: th, numChannels: 4);
      img.compositeImage(scaled, r, dstX: (tw - r.width) ~/ 2, dstY: (th - r.height) ~/ 2);
  }
  final rgba = scaled.convert(numChannels: 4, format: img.Format.uint8);
  return _Prepared(Uint8List.fromList(rgba.getBytes(order: img.ChannelOrder.rgba)), tw, th);
}

/// Turns a picture into map art: matched to the map palette, dithered,
/// flat or staircased, and exported as a schematic to build.
class MapArtTool extends StatefulWidget {
  const MapArtTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<MapArtTool> createState() => _MapArtToolState();
}

class _MapArtToolState extends State<MapArtTool> {
  Uint8List? _source;
  String _name = 'map_art';
  int _mapsX = 1;
  int _mapsY = 1;
  _Fit _fit = _Fit.crop;
  bool _staircase = false;
  McDither _dither = McDither.floydSteinberg;
  final Set<int> _enabled = {for (var i = 0; i < kMcMapColors.length; i++) i};

  bool _busy = false;
  McMapArtResult? _result;
  ui.Image? _preview;
  Schematic? _schematic;
  bool _show3d = false;
  int _token = 0;

  Future<void> _pick() async {
    final picked = await FilePicker.pickFiles(type: FileType.image, withData: true);
    final file = picked?.files.firstOrNull;
    if (file?.bytes == null) return;
    _source = file!.bytes;
    _name = file.name.contains('.') ? file.name.substring(0, file.name.lastIndexOf('.')) : file.name;
    await _run();
  }

  Future<void> _run() async {
    final source = _source;
    if (source == null) return;
    final token = ++_token;
    setState(() => _busy = true);
    try {
      final mapsX = _mapsX, mapsY = _mapsY, fit = _fit;
      final colors = _enabled.toList()..sort();
      final staircase = _staircase, dither = _dither;
      final (result, schematic) = await Isolate.run(() {
        final prepared = _prepare(source, mapsX, mapsY, fit);
        final r = mcConvertMapArt(
          McMapArtJob(
            pixels: prepared.pixels,
            width: prepared.width,
            height: prepared.height,
            colors: colors,
            staircase: staircase,
            dither: dither,
          ),
        );
        return (r, _buildMapSchematic(r, staircase));
      });
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        result.preview,
        result.width,
        result.height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      final image = await completer.future;
      if (!mounted || token != _token) return;
      setState(() {
        _result = result;
        _preview = image;
        _schematic = schematic;
        _busy = false;
      });
    } on Object catch (e) {
      if (!mounted || token != _token) return;
      setState(() => _busy = false);
      final t = L.of(context);
      mcToast(
        context,
        e is FormatException && e.message == _notAnImage
            ? t.mcMapNotImage
            : t.mcMapCouldNotConvert('$e'),
      );
    }
  }

  void _set(VoidCallback change) {
    setState(change);
    _run();
  }

  Future<void> _savePng() async {
    final r = _result;
    if (r == null) return;
    final image = img.Image.fromBytes(
      width: r.width,
      height: r.height,
      bytes: r.preview.buffer,
      numChannels: 4,
    );
    await mcSaveBytes(
      context,
      Uint8List.fromList(img.encodePng(image)),
      fileName: '${_name}_map.png',
      mimeType: 'image/png',
    );
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final result = _result;
    final schematic = _schematic;
    return widget.host.frame(
      context,
      actions: [
        McButton(
          label: _source == null ? t.mcMapChooseImage : t.mcMapChangeImage,
          icon: Icons.image_rounded,
          onTap: _pick,
        ),
      ],
      child: McSplit(
        controlsWidth: 380,
        controls: McFormColumn(
          children: [
            McPanel(
              title: t.mcMapSize,
              icon: Icons.grid_view_rounded,
              child: McFormColumn(
                gap: 8,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(t.mcMapAcross, style: TextStyle(color: luma.textSecondary, fontSize: 12.5))),
                      McStepper(value: _mapsX, min: 1, max: 6, onChanged: (v) => _set(() => _mapsX = v)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: Text(t.mcMapDown, style: TextStyle(color: luma.textSecondary, fontSize: 12.5))),
                      McStepper(value: _mapsY, min: 1, max: 6, onChanged: (v) => _set(() => _mapsY = v)),
                    ],
                  ),
                  Text(
                    t.mcMapBlocksSize(_mapsX * 128, _mapsY * 128),
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                  McChoice<_Fit>(
                    values: _Fit.values,
                    selected: _fit,
                    label: (f) => f.label(t),
                    onSelect: (f) => _set(() => _fit = f),
                  ),
                ],
              ),
            ),
            McPanel(
              title: t.mcShapeStyle,
              icon: Icons.tune_rounded,
              child: McFormColumn(
                gap: 8,
                children: [
                  McSwitch(
                    label: t.mcMapStaircase,
                    detail: t.mcMapStaircaseDetail,
                    value: _staircase,
                    onChanged: (v) => _set(() => _staircase = v),
                  ),
                  McField(
                    label: t.mcMapDithering,
                    child: McChoice<McDither>(
                      values: McDither.values,
                      selected: _dither,
                      label: (d) => d.label(t),
                      onSelect: (d) => _set(() => _dither = d),
                    ),
                  ),
                ],
              ),
            ),
            McPanel(
              title: t.mcMapBlocksToUse(_enabled.length),
              icon: Icons.palette_rounded,
              child: McFormColumn(
                gap: 10,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in _Palette.values)
                        ActionChip(
                          label: Text(p.label(t)),
                          onPressed: () => _set(() {
                            _enabled
                              ..clear()
                              ..addAll([
                                for (var i = 0; i < kMcMapColors.length; i++)
                                  if (p.allows(kMcMapColors[i])) i,
                              ]);
                          }),
                        ),
                    ],
                  ),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (var i = 0; i < kMcMapColors.length; i++)
                        Tooltip(
                          message: '${kMcMapColors[i].name} — ${mcPretty(kMcMapColors[i].block)}',
                          child: InkWell(
                            onTap: () => _set(() {
                              if (!_enabled.remove(i)) _enabled.add(i);
                            }),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Color(0xFF000000 | mcShade(kMcMapColors[i].rgb, 220)),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: _enabled.contains(i) ? luma.accent : luma.border,
                                  width: _enabled.contains(i) ? 2 : 1,
                                ),
                              ),
                              child: _enabled.contains(i)
                                  ? null
                                  : Icon(Icons.close_rounded, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        result: _source == null
            ? McPanel(
                child: McHint(
                  icon: Icons.image_rounded,
                  title: t.mcMapChooseTitle,
                  body: t.mcMapChooseBody,
                  action: McButton(label: t.mcMapChooseImage, icon: Icons.image_rounded, onTap: _pick),
                ),
              )
            : McFormColumn(
                children: [
                  if (_busy) const LinearProgressIndicator(minHeight: 2),
                  if (_preview != null)
                    McPanel(
                      title: t.mcMapPreview,
                      icon: Icons.map_rounded,
                      trailing: McIconButton(icon: Icons.download_rounded, tooltip: t.mcMapSavePng, onTap: _savePng),
                      child: AspectRatio(
                        aspectRatio: _mapsX / _mapsY,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            RawImage(image: _preview, fit: BoxFit.fill, filterQuality: FilterQuality.none),
                            CustomPaint(painter: _MapGridPainter(_mapsX, _mapsY)),
                          ],
                        ),
                      ),
                    ),
                  if (schematic != null && result != null) ...[
                    McStatRow(
                      stats: [
                        McStat(value: '${schematic.blockCount}', label: t.mcStatBlocks, hue: McHue.violet),
                        McStat(value: '${schematic.materials().length}', label: t.mcPlanBlockTypes, hue: McHue.indigo),
                        McStat(value: '${schematic.height}', label: t.mcMapTallest, hue: McHue.mint),
                      ],
                    ),
                    if (_mapsX * _mapsY <= 4)
                      McSwitch(
                        label: t.mcMapShow3d,
                        value: _show3d,
                        onChanged: (v) => setState(() => _show3d = v),
                      ),
                    if (_show3d && _mapsX * _mapsY <= 4)
                      SchematicViewer(key: ObjectKey(schematic), schematic: schematic),
                    _MapExport(schematic: schematic, name: _name),
                    McPanel(
                      title: t.mcMaterials,
                      icon: Icons.inventory_2_rounded,
                      child: Column(
                        children: [for (final m in schematic.materials()) McMaterialRow(material: m)],
                      ),
                    ),
                    Text(
                      t.mcMapBuildNote,
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _MapExport extends StatefulWidget {
  const _MapExport({required this.schematic, required this.name});

  final Schematic schematic;
  final String name;

  @override
  State<_MapExport> createState() => _MapExportState();
}

class _MapExportState extends State<_MapExport> {
  SchematicFormat _format = SchematicFormat.litematic;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return McPanel(
      title: t.mcExport,
      icon: Icons.download_rounded,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          McChoice<SchematicFormat>(
            values: const [
              SchematicFormat.litematic,
              SchematicFormat.sponge,
              SchematicFormat.structure,
              SchematicFormat.mcstructure,
            ],
            selected: _format,
            label: (f) => '.${f.extension}',
            onSelect: (f) => setState(() => _format = f),
          ),
          McButton(
            label: t.mcSaveExtension(_format.extension),
            icon: Icons.save_alt_rounded,
            onTap: () => mcSaveSchematic(context, widget.schematic, _format, widget.name),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  _MapGridPainter(this.x, this.y);
  final int x;
  final int y;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var i = 1; i < x; i++) {
      canvas.drawLine(Offset(size.width * i / x, 0), Offset(size.width * i / x, size.height), p);
    }
    for (var j = 1; j < y; j++) {
      canvas.drawLine(Offset(0, size.height * j / y), Offset(size.width, size.height * j / y), p);
    }
  }

  @override
  bool shouldRepaint(_MapGridPainter old) => old.x != x || old.y != y;
}
