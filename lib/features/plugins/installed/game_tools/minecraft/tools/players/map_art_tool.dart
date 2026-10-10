import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../../../../../../app/widgets.dart';
import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../../../../../converter/schematic/schematic_model.dart';
import '../../../../../../converter/tools/schematic_viewer.dart';
import '../../data/map_art.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_files.dart';
import '../../ui/mc_schematic_panel.dart';
import '../../ui/mc_showcase.dart';
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
  cheap,
  concrete,
  greys;

  String label(L t) => switch (this) {
    all => t.mcMapPaletteAll,
    survival => t.mcMapPaletteSurvival,
    cheap => t.mcMapPaletteCheap,
    concrete => t.mcMapPaletteConcrete,
    greys => t.mcMapPaletteGreys,
  };

  bool allows(McMapColor c) => switch (this) {
    _Palette.all => true,
    _Palette.survival => !{30, 31, 32, 33}.contains(c.id),
    // Leaves out precious blocks and the ones that need silk touch.
    _Palette.cheap => !{3, 4, 5, 6, 14, 30, 31, 32, 33, 52, 55, 60, 61}.contains(c.id),
    _Palette.concrete => (c.id >= 15 && c.id <= 29) || c.id == 8 || (c.id >= 36 && c.id <= 51),
    _Palette.greys => {8, 22, 21, 29, 11, 6, 59, 3, 9}.contains(c.id),
  };

  Set<int> get indices => {
    for (var i = 0; i < kMcMapColors.length; i++)
      if (allows(kMcMapColors[i])) i,
  };
}

enum _View { map, build, guide }

enum _SizeMode { maps, free }

/// The schematic formats a map can be saved as, most useful first.
const _formats = [
  SchematicFormat.litematic,
  SchematicFormat.sponge,
  SchematicFormat.structure,
  SchematicFormat.mcstructure,
];

const _notAnImage = 'not-an-image';

/// Biggest free size, in blocks a side.
const _maxFree = 1024;

class _Prepared {
  const _Prepared(this.pixels, this.width, this.height);
  final Uint8List pixels;
  final int width;
  final int height;
}

_Prepared _prepare(Uint8List bytes, int tw, int th, _Fit fit) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException(_notAnImage);
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

/// Everything a conversion needs, as plain data so it can cross isolates.
class _Job {
  const _Job({
    required this.width,
    required this.height,
    required this.fit,
    required this.colors,
    required this.staircase,
    required this.compact,
    required this.dither,
    required this.strength,
    required this.match,
    required this.scale,
  });

  /// In map pixels.
  final int width;
  final int height;
  final _Fit fit;
  final List<int> colors;
  final bool staircase;
  final bool compact;
  final McDither dither;
  final double strength;
  final McColorMatch match;
  final int scale;
}

/// Converts off the UI thread. A top-level function on purpose: a closure
/// built inside the State's methods shares their captured scope, which holds
/// the State itself, and Isolate.run would try to send the whole widget tree.
///
/// The bool is true when a staircase was asked for but the build would have
/// been too big, so it came out flat.
Future<(McMapArtResult, Schematic, bool)> _convertInIsolate(Uint8List source, _Job job) => Isolate.run(() {
  final prepared = _prepare(source, job.width, job.height, job.fit);
  McMapArtResult convert(bool staircase) => mcConvertMapArt(
    McMapArtJob(
      pixels: prepared.pixels,
      width: prepared.width,
      height: prepared.height,
      colors: job.colors,
      staircase: staircase,
      dither: job.dither,
      ditherStrength: job.strength,
      match: job.match,
    ),
  );
  var result = convert(job.staircase);
  final built = mcBuildMapSchematic(result, staircase: job.staircase, compact: job.compact, scale: job.scale);
  if (built != null) return (result, built, false);
  result = convert(false);
  return (result, mcBuildMapSchematic(result, staircase: false, scale: job.scale)!, job.staircase);
});

/// Turns a picture into map art: matched to the map palette, dithered,
/// flat or staircased, at any map size and zoom, and exported as a
/// schematic to build. The map, the build in 3D and a build guide share
/// one big viewer, with the settings down the side.
class MapArtTool extends StatefulWidget {
  const MapArtTool({super.key, required this.host, this.initialImage, this.initialName});

  final McToolHost host;

  /// Opens already converting this picture, for tests and the hub's
  /// screenshots.
  final Uint8List? initialImage;
  final String? initialName;

  @override
  State<MapArtTool> createState() => _MapArtToolState();
}

class _MapArtToolState extends State<MapArtTool> {
  Uint8List? _source;
  String _name = 'map_art';

  _SizeMode _sizeMode = _SizeMode.maps;
  int _mapsX = 1;
  int _mapsY = 1;

  /// Map zoom level, 0 (1:1) to 4 (1:16).
  int _scale = 0;
  int _freeW = 128;
  int _freeH = 128;
  late final TextEditingController _freeWText = TextEditingController(text: '$_freeW');
  late final TextEditingController _freeHText = TextEditingController(text: '$_freeH');

  _Fit _fit = _Fit.crop;
  bool _staircase = true;
  bool _compact = true;
  McColorMatch _match = McColorMatch.balanced;
  McDither _dither = McDither.floydSteinberg;
  double _strength = 1;
  final Set<int> _enabled = _Palette.all.indices;

  bool _advanced = false;
  _View _view = _View.map;
  SchematicFormat _format = SchematicFormat.litematic;

  bool _busy = false;
  McMapArtResult? _result;
  ui.Image? _preview;
  Schematic? _schematic;
  bool _flattened = false;
  int _token = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final image = widget.initialImage;
    if (image != null) {
      _source = image;
      _name = widget.initialName ?? _name;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _run();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _freeWText.dispose();
    _freeHText.dispose();
    super.dispose();
  }

  int get _maxMaps => math.min(8, 16 >> _scale);
  int get _pixelsWide => _sizeMode == _SizeMode.maps ? _mapsX * 128 : _freeW;
  int get _pixelsTall => _sizeMode == _SizeMode.maps ? _mapsY * 128 : _freeH;
  int get _blockScale => _sizeMode == _SizeMode.maps ? _scale : 0;
  int get _blocksWide => _pixelsWide * mcMapScaleBlocks(_blockScale);
  int get _blocksTall => _pixelsTall * mcMapScaleBlocks(_blockScale);

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
      final job = _Job(
        width: _pixelsWide,
        height: _pixelsTall,
        fit: _fit,
        colors: _enabled.toList()..sort(),
        staircase: _staircase,
        compact: _compact,
        dither: _dither,
        strength: _strength,
        match: _match,
        scale: _blockScale,
      );
      final (result, schematic, flattened) = await _convertInIsolate(source, job);
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
        _flattened = flattened;
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

  /// Applies a change and converts again once the settings stop moving, so
  /// a dragged slider doesn't start a conversion per frame.
  void _set(VoidCallback change) {
    setState(change);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 160), _run);
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

  void _download(SchematicFormat format) {
    final schematic = _schematic;
    if (schematic == null) return;
    setState(() => _format = format);
    mcSaveSchematic(context, schematic, format, _name);
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final viewer = _viewer(context);
    final panel = _panel(context);
    return widget.host.frame(
      context,
      scroll: !wide,
      actions: [
        _AdvancedToggle(
          label: t.mcMapAdvanced,
          value: _advanced,
          onChanged: (v) => setState(() => _advanced = v),
        ),
        _DownloadButton(
          format: _format,
          enabled: _schematic != null,
          onDownload: _download,
          onPng: _savePng,
        ),
      ],
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: viewer),
                const SizedBox(width: 20),
                SizedBox(
                  width: 340,
                  child: SingleChildScrollView(child: panel),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: context.isPhoneWidth ? 420 : 520, child: viewer),
                const SizedBox(height: 16),
                panel,
              ],
            ),
    );
  }

  // ---------------------------------------------------------------- viewer

  Widget _viewer(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final reduced = McMotion.reduced(context);
    final Widget content;
    if (_source == null) {
      content = _view == _View.guide
          ? _guide(context)
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
                child: McHint(
                  icon: Icons.image_rounded,
                  title: t.mcMapChooseTitle,
                  body: t.mcMapChooseBody,
                  action: McButton(label: t.mcMapChooseImage, icon: Icons.image_rounded, onTap: _pick),
                ),
              ),
            );
    } else {
      content = switch (_view) {
        _View.map => _mapView(context),
        _View.build => _schematic == null
            ? const Center(child: CircularProgressIndicator())
            : SchematicViewer(key: ObjectKey(_schematic), schematic: _schematic!, immersive: true),
        _View.guide => _guide(context),
      };
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Color.alphaBlend(luma.textPrimary.withValues(alpha: 0.035), luma.surface),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: luma.border),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: reduced ? Duration.zero : McMotion.fast,
              switchInCurve: McMotion.enter,
              child: KeyedSubtree(key: ValueKey(_view), child: content),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: _ViewTabs(
              values: _View.values,
              selected: _view,
              label: (v) => switch (v) {
                _View.map => t.mcMapTabMap,
                _View.build => t.mcMapTab3d,
                _View.guide => t.mcMapTabGuide,
              },
              onSelect: (v) => setState(() => _view = v),
            ),
          ),
          if (_busy)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }

  String _sizeSummary(L t) {
    if (_sizeMode == _SizeMode.free) return t.mcMapBlocksSize(_freeW, _freeH);
    final summary = t.mcMapSizeSummary(_blocksWide, _blocksTall, _mapsX * _mapsY);
    return _scale == 0 ? summary : '$summary · 1:${mcMapScaleBlocks(_scale)}';
  }

  Widget _mapView(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final preview = _preview;
    final aspect = _pixelsWide / _pixelsTall;
    return Stack(
      children: [
        Positioned.fill(
          child: preview == null
              ? const Center(child: CircularProgressIndicator())
              : InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 32,
                  boundaryMargin: const EdgeInsets.all(400),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(40, 72, 40, 64),
                      child: AspectRatio(
                        aspectRatio: aspect,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              RawImage(image: preview, fit: BoxFit.fill, filterQuality: FilterQuality.none),
                              if (_sizeMode == _SizeMode.maps)
                                CustomPaint(painter: _MapGridPainter(_mapsX, _mapsY)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _Pill(
                    child: Text(
                      t.mcMapPanHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Pill(
                child: Text(
                  _sizeSummary(t),
                  style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 12,
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _guide(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final schematic = _schematic;
    final blocks = 128 * mcMapScaleBlocks(_scale);
    final staircase = _staircase && !_flattened;
    final steps = [
      if (_sizeMode == _SizeMode.maps) ...[
        t.mcMapGuideMaps(_mapsX * _mapsY),
        if (_scale > 0) t.mcMapGuideZoom(_scale, blocks),
        t.mcMapGuideArea(blocks),
      ] else
        t.mcMapGuideFree,
      t.mcMapGuideNoobline,
      t.mcMapGuideBuild,
      staircase ? t.mcMapGuideStair : t.mcMapGuideFlat,
      t.mcMapGuideDone,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 72, 20, 24),
      children: [
        if (schematic != null) ...[
          McStatRow(
            stats: [
              McStat(value: '${schematic.blockCount}', label: t.mcStatBlocks, hue: McHue.violet),
              McStat(value: '${schematic.materials().length}', label: t.mcPlanBlockTypes, hue: McHue.indigo),
              McStat(value: '${schematic.height}', label: t.mcMapTallest, hue: McHue.mint),
              if (_sizeMode == _SizeMode.maps)
                McStat(value: '${_mapsX * _mapsY}', label: t.mcMapMapsStat, hue: McHue.amber),
            ],
          ),
          const SizedBox(height: 18),
        ],
        McPanel(
          title: t.mcMapGuideTitle,
          icon: Icons.checklist_rounded,
          child: Column(
            children: [
              for (final (i, step) in steps.indexed)
                Padding(
                  padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: luma.accentSubtle, shape: BoxShape.circle),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(color: luma.accent, fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            step,
                            style: TextStyle(color: luma.textPrimary, fontSize: 13.5, height: 1.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (schematic != null) ...[
          const SizedBox(height: 16),
          McPanel(
            title: t.mcMaterials,
            icon: Icons.inventory_2_rounded,
            child: Column(
              children: [for (final m in schematic.materials()) McMaterialRow(material: m)],
            ),
          ),
        ],
      ],
    );
  }

  // ----------------------------------------------------------------- panel

  Widget _panel(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final source = _source;
    final presets = {for (final p in _Palette.values) p: p.indices};
    return Container(
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: luma.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(
            title: t.mcMapSectionImage,
            child: McFormColumn(
              gap: 12,
              children: [
                Row(
                  children: [
                    if (source != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          source,
                          width: 52,
                          height: 52,
                          cacheWidth: 104,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: luma.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (source == null)
                      Expanded(
                        child: McButton(label: t.mcMapChooseImage, icon: Icons.image_rounded, onTap: _pick),
                      )
                    else
                      McButton(label: t.mcMapChangeImage, primary: false, onTap: _pick),
                  ],
                ),
                _Segmented<_Fit>(
                  values: _Fit.values,
                  selected: _fit,
                  label: (f) => f.label(t),
                  onSelect: (f) => _set(() => _fit = f),
                ),
              ],
            ),
          ),
          _Section(
            title: t.mcMapSectionSize,
            child: McFormColumn(
              gap: 12,
              children: [
                _Segmented<_SizeMode>(
                  values: _SizeMode.values,
                  selected: _sizeMode,
                  label: (m) => m == _SizeMode.maps ? t.mcMapByMaps : t.mcMapFreeSize,
                  onSelect: (m) => _set(() => _sizeMode = m),
                ),
                if (_sizeMode == _SizeMode.maps) ...[
                  Row(
                    children: [
                      Expanded(
                        child: McField(
                          label: t.mcMapAcross,
                          child: McStepper(
                            value: _mapsX,
                            min: 1,
                            max: _maxMaps,
                            onChanged: (v) => _set(() => _mapsX = v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: McField(
                          label: t.mcMapDown,
                          child: McStepper(
                            value: _mapsY,
                            min: 1,
                            max: _maxMaps,
                            onChanged: (v) => _set(() => _mapsY = v),
                          ),
                        ),
                      ),
                    ],
                  ),
                  McField(
                    label: t.mcMapScale,
                    child: _Segmented<int>(
                      values: const [0, 1, 2, 3, 4],
                      selected: _scale,
                      label: (s) => '1:${mcMapScaleBlocks(s)}',
                      onSelect: (s) => _set(() {
                        _scale = s;
                        _mapsX = math.min(_mapsX, _maxMaps);
                        _mapsY = math.min(_mapsY, _maxMaps);
                      }),
                    ),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: McField(
                          label: t.mcMapWidth,
                          child: _NumberField(
                            controller: _freeWText,
                            onChanged: (v) => _set(() => _freeW = v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: McField(
                          label: t.mcMapHeight,
                          child: _NumberField(
                            controller: _freeHText,
                            onChanged: (v) => _set(() => _freeH = v),
                          ),
                        ),
                      ),
                    ],
                  ),
                Text(_sizeSummary(t), style: TextStyle(color: luma.textMuted, fontSize: 12)),
              ],
            ),
          ),
          _Section(
            title: t.mcMapSectionStyle,
            child: McFormColumn(
              gap: 12,
              children: [
                McField(
                  label: t.mcMapBuildMode,
                  child: _Segmented<bool>(
                    values: const [false, true],
                    selected: _staircase,
                    label: (s) => s ? t.mcMapStaircase : t.mcMapFlat,
                    onSelect: (s) => _set(() => _staircase = s),
                  ),
                ),
                if (_staircase && _flattened)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 15, color: luma.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(t.mcMapFlattened, style: TextStyle(color: luma.textMuted, fontSize: 12)),
                      ),
                    ],
                  ),
                if (_staircase)
                  McField(
                    label: t.mcMapStaircaseStyle,
                    child: _Segmented<bool>(
                      values: const [true, false],
                      selected: _compact,
                      label: (c) => c ? t.mcMapCompact : t.mcMapAligned,
                      onSelect: (c) => _set(() => _compact = c),
                    ),
                  ),
                McField(
                  label: t.mcMapColourMatch,
                  child: _Segmented<McColorMatch>(
                    values: McColorMatch.values,
                    selected: _match,
                    label: (m) => m.label(t),
                    onSelect: (m) => _set(() => _match = m),
                  ),
                ),
                McField(
                  label: t.mcMapDithering,
                  child: McDropdown<McDither>(
                    values: McDither.values,
                    value: _dither,
                    label: (d) => d.label(t),
                    onChanged: (d) => _set(() => _dither = d),
                  ),
                ),
                if (_dither != McDither.none)
                  McSlider(
                    label: t.mcMapDitherStrength,
                    value: _strength * 100,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    format: (v) => '${v.round()}%',
                    onChanged: (v) => _set(() => _strength = v / 100),
                  ),
              ],
            ),
          ),
          _Section(
            title: t.mcMapSectionBlocks,
            last: true,
            child: McFormColumn(
              gap: 12,
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 3.6,
                  children: [
                    for (final p in _Palette.values)
                      _PresetButton(
                        label: p.label(t),
                        selected: presets[p]!.length == _enabled.length && presets[p]!.containsAll(_enabled),
                        onTap: () => _set(() {
                          _enabled
                            ..clear()
                            ..addAll(presets[p]!);
                        }),
                      ),
                  ],
                ),
                Text(t.mcMapBlocksToUse(_enabled.length), style: TextStyle(color: luma.textMuted, fontSize: 12)),
                if (_advanced) _swatches(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _swatches(BuildContext context) {
    final luma = context.luma;
    return Wrap(
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
              borderRadius: BorderRadius.circular(5),
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
    );
  }
}

/// The gradient fill of a selected option, as in the viewer's tabs: the
/// accent turning a little warmer and lighter, which is indigo to violet on
/// the standard theme and stays in the family on the others.
LinearGradient _selectedFill(LumaPalette luma) {
  final hsl = HSLColor.fromColor(luma.accent);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      luma.accent,
      hsl.withHue((hsl.hue + 22) % 360).withLightness((hsl.lightness + 0.06).clamp(0.0, 1.0)).toColor(),
    ],
  );
}

/// Map / 3D build / Guide, floating over the top-left of the viewer.
class _ViewTabs<T> extends StatelessWidget {
  const _ViewTabs({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelect,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final reduced = McMotion.reduced(context);
    return _Pill(
      padding: const EdgeInsets.all(4),
      radius: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final v in values)
            Semantics(
              button: true,
              selected: v == selected,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onSelect(v),
                  child: AnimatedContainer(
                    duration: reduced ? Duration.zero : McMotion.fast,
                    curve: McMotion.enter,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: v == selected ? _selectedFill(luma) : null,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: v == selected
                          ? [
                              BoxShadow(
                                color: luma.accent.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : const [],
                    ),
                    child: Text(
                      label(v),
                      style: TextStyle(
                        color: v == selected ? luma.onAccent : luma.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A full-width segmented control; the chosen option fills with the accent.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelect,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final reduced = McMotion.reduced(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        children: [
          for (final v in values)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == selected,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(v),
                    child: AnimatedContainer(
                      duration: reduced ? Duration.zero : McMotion.fast,
                      curve: McMotion.enter,
                      height: 36,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        gradient: v == selected ? _selectedFill(luma) : null,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        label(v),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: v == selected ? luma.onAccent : luma.textSecondary,
                          fontSize: 12.5,
                          fontWeight: v == selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One collapsible group of settings with a small capitalised heading.
class _Section extends StatefulWidget {
  const _Section({required this.title, required this.child, this.last = false});

  final String title;
  final Widget child;
  final bool last;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final reduced = McMotion.reduced(context);
    return Container(
      decoration: BoxDecoration(
        border: widget.last ? null : Border(bottom: BorderSide(color: luma.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            child: InkWell(
              onTap: () => setState(() => _open = !_open),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: _open ? 0.25 : 0,
                      duration: reduced ? Duration.zero : McMotion.fast,
                      child: Icon(Icons.chevron_right_rounded, size: 18, color: luma.textMuted),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.title.toUpperCase(),
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: reduced ? Duration.zero : McMotion.fast,
            curve: McMotion.enter,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(padding: const EdgeInsets.only(bottom: 16), child: widget.child)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// A block preset: a soft accent button that fills when it is the set in use.
class _PresetButton extends StatelessWidget {
  const _PresetButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? null : luma.accentSubtle,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            gradient: selected ? _selectedFill(luma) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? luma.onAccent : luma.accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A block count typed in, kept between 1 and [_maxFree].
class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return McTextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
      onChanged: (text) {
        final v = int.tryParse(text);
        if (v != null) onChanged(v.clamp(1, _maxFree));
      },
    );
  }
}

/// The Advanced switch in the header.
class _AdvancedToggle extends StatelessWidget {
  const _AdvancedToggle({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SizedBox(
      height: 44,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: 0.75,
              child: Switch(value: value, onChanged: onChanged, activeTrackColor: luma.accent),
            ),
            Text(
              label,
              style: TextStyle(color: luma.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// "Download .litematic", with the other formats and the map image behind
/// the chevron.
class _DownloadButton extends StatelessWidget {
  const _DownloadButton({
    required this.format,
    required this.enabled,
    required this.onDownload,
    required this.onPng,
  });

  final SchematicFormat format;
  final bool enabled;
  final ValueChanged<SchematicFormat> onDownload;
  final VoidCallback onPng;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final fg = luma.onAccent;
    final label = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: fg,
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
    );
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          gradient: _selectedFill(luma),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: luma.accent.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: enabled ? () => onDownload(format) : null,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.download_rounded, size: 17, color: fg),
                      const SizedBox(width: 8),
                      Text(t.mcMapDownload, style: label),
                      const SizedBox(width: 6),
                      Text(
                        '.${format.extension}',
                        style: label?.copyWith(
                          color: fg.withValues(alpha: 0.75),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(width: 1, height: 24, color: fg.withValues(alpha: 0.3)),
              PopupMenuButton<SchematicFormat?>(
                enabled: enabled,
                tooltip: t.mcMapOtherFormats,
                position: PopupMenuPosition.under,
                onSelected: (f) => f == null ? onPng() : onDownload(f),
                itemBuilder: (context) => [
                  for (final f in _formats)
                    PopupMenuItem(value: f, child: Text('.${f.extension}')),
                  const PopupMenuDivider(),
                  PopupMenuItem(value: null, child: Text(t.mcMapDownloadPng)),
                ],
                child: SizedBox(
                  width: 40,
                  height: 44,
                  child: Icon(Icons.expand_more_rounded, size: 19, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small card floating over the viewer.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    this.radius = 12,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: luma.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: luma.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
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
