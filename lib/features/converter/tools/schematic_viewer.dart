import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../../theme/luma_theme.dart';
import '../converter_widgets.dart';
import '../schematic/block_colors.dart';
import '../schematic/textures/block_atlas.dart';
import '../schematic/textures/texture_downloader.dart';
import '../schematic/textures/texture_pack_types.dart';
import '../schematic/schematic_model.dart';

/// An interactive 3D preview of a block build, in the spirit of the litematic
/// viewers on the schematic sites: drag to orbit, scroll to zoom, and slide
/// the layer range to cut the build open.
///
/// Everything is drawn as flat-shaded cube faces through a single
/// [Canvas.drawVertices] call per frame. That is what makes it fast enough to
/// orbit smoothly: the alternative, a draw call per face, is tens of thousands
/// of calls a frame.
class SchematicViewer extends StatefulWidget {
  const SchematicViewer({super.key, required this.schematic});

  final Schematic schematic;

  @override
  State<SchematicViewer> createState() => _SchematicViewerState();
}

class _SchematicViewerState extends State<SchematicViewer> {
  static const double _minPitch = -1.45;
  static const double _maxPitch = 1.45;

  late _VoxelGeometry _geometry;

  /// Block textures, once they have been read out of the local Minecraft
  /// installation. Null until then, and the preview draws flat colours.
  BlockAtlas? _atlas;
  bool _loadingTextures = false;

  /// Set while the vanilla assets are being fetched from Mojang, so the status
  /// line can show how far along a download of tens of megabytes is rather
  /// than sitting on a spinner.
  TextureDownloadProgress? _download;

  double _yaw = -0.7;
  double _pitch = 0.5;
  double _zoom = 1;
  late RangeValues _layers;

  double _gestureStartYaw = 0;
  double _gestureStartPitch = 0;
  double _gestureStartZoom = 1;
  Offset _gestureStartFocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    _atlas = BlockAtlas.current;
    _rebuild();
    if (_atlas == null) _loadTextures();
  }

  @override
  void didUpdateWidget(SchematicViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.schematic, widget.schematic)) {
      _rebuild();
    }
  }

  void _rebuild() {
    _geometry = _VoxelGeometry.build(widget.schematic, _atlas);
    _layers = RangeValues(0, _geometry.height.toDouble());
  }

  /// Reads the block textures out of the local Minecraft installation. The
  /// preview is usable on flat colours in the meantime, so this never blocks.
  Future<void> _loadTextures({String? fromPath}) => _withAtlas(
        () => fromPath == null
            ? BlockAtlas.load()
            : BlockAtlas.loadFrom(fromPath),
      );

  /// Fetches the vanilla assets from Mojang, for the machine that has never
  /// had Minecraft on it and so has nothing to borrow textures from.
  Future<void> _downloadTextures() {
    var lastPercent = -1;
    return _withAtlas(
      () => BlockAtlas.downloadAndLoad(
        onProgress: (progress) {
          if (!mounted) return;
          // A rebuild per chunk would be thousands of frames of work for a
          // progress bar that only moves a hundred times.
          final percent = ((progress.fraction ?? 0) * 100).round();
          if (percent == lastPercent && progress.stage == _download?.stage) {
            return;
          }
          lastPercent = percent;
          setState(() => _download = progress);
        },
      ),
    );
  }

  Future<void> _withAtlas(Future<BlockAtlas?> Function() produce) async {
    if (_loadingTextures) return;
    setState(() => _loadingTextures = true);
    final atlas = await produce();
    if (!mounted) return;
    setState(() {
      _loadingTextures = false;
      _download = null;
      if (atlas != null) {
        _atlas = atlas;
        // The geometry caches per-face texture lookups, so it has to be
        // rebuilt — but keep the camera and layer range where the user left
        // them.
        final layers = _layers;
        _geometry = _VoxelGeometry.build(widget.schematic, atlas);
        _layers = RangeValues(
          layers.start.clamp(0, _geometry.height.toDouble()),
          layers.end.clamp(0, _geometry.height.toDouble()),
        );
      }
    });
  }

  Future<void> _pickTextureSource() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jar', 'zip'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.first.path;
    if (path == null) return;
    await _loadTextures(fromPath: path);
  }

  void _resetView() {
    setState(() {
      _yaw = -0.7;
      _pitch = 0.5;
      _zoom = 1;
      _layers = RangeValues(0, _geometry.height.toDouble());
    });
  }

  void _nudgeYaw(double delta) =>
      setState(() => _yaw = (_yaw + delta) % (math.pi * 2));

  void _nudgeZoom(double factor) =>
      setState(() => _zoom = (_zoom * factor).clamp(0.25, 8.0));

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final schematic = widget.schematic;

    if (_geometry.isEmpty) {
      return _ViewerShell(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.deblur_rounded, color: luma.textMuted, size: 32),
              const SizedBox(height: 12),
              Text(
                'Nothing to show — this build is all air.',
                style: TextStyle(color: luma.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ViewerShell(
          child: Listener(
            onPointerSignal: (event) {
              if (event is! PointerScrollEvent) return;
              _nudgeZoom(event.scrollDelta.dy > 0 ? 0.9 : 1.1);
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (details) {
                _gestureStartYaw = _yaw;
                _gestureStartPitch = _pitch;
                _gestureStartZoom = _zoom;
                _gestureStartFocal = details.localFocalPoint;
              },
              onScaleUpdate: (details) {
                final drag = details.localFocalPoint - _gestureStartFocal;
                setState(() {
                  _yaw = _gestureStartYaw + drag.dx * 0.011;
                  _pitch = (_gestureStartPitch + drag.dy * 0.011)
                      .clamp(_minPitch, _maxPitch);
                  if (details.scale != 1) {
                    _zoom =
                        (_gestureStartZoom * details.scale).clamp(0.25, 8.0);
                  }
                });
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Semantics(
                  label:
                      '3D preview of the build, ${schematic.width} by '
                      '${schematic.height} by ${schematic.length} blocks. '
                      'Drag to rotate, or use the rotate and zoom buttons '
                      'below.',
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _VoxelPainter(
                        geometry: _geometry,
                        atlas: _atlas,
                        yaw: _yaw,
                        pitch: _pitch,
                        zoom: _zoom,
                        minLayer: _layers.start.round(),
                        maxLayer: _layers.end.round(),
                      ),
                      isComplex: true,
                      willChange: true,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ViewerControls(
          layers: _layers,
          maxLayer: _geometry.height,
          sourceHeight: schematic.height,
          onLayersChanged: (v) => setState(() => _layers = v),
          onRotateLeft: () => _nudgeYaw(-0.4),
          onRotateRight: () => _nudgeYaw(0.4),
          onZoomIn: () => _nudgeZoom(1.25),
          onZoomOut: () => _nudgeZoom(0.8),
          onReset: _resetView,
        ),
        const SizedBox(height: 10),
        _TextureStatus(
          atlas: _atlas,
          loading: _loadingTextures,
          download: _download,
          failure: BlockAtlas.failure,
          onPick: _pickTextureSource,
          onDownload: _downloadTextures,
        ),
        if (_geometry.stride > 1) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 15, color: luma.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This build is too large to draw block-for-block, so the '
                  'preview is simplified ${_geometry.stride}× — the converted '
                  'file keeps every block.',
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Says where the block textures came from, or why the preview is falling back
/// to flat colours and what to do about it.
///
/// luma cannot ship Minecraft's textures, so being explicit about borrowing
/// them from the local installation is part of the feature rather than an
/// apology for it.
class _TextureStatus extends StatelessWidget {
  const _TextureStatus({
    required this.atlas,
    required this.loading,
    required this.download,
    required this.failure,
    required this.onPick,
    required this.onDownload,
  });

  final BlockAtlas? atlas;
  final bool loading;
  final TextureDownloadProgress? download;
  final String? failure;
  final VoidCallback onPick;
  final VoidCallback onDownload;

  static String _megabytes(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final loaded = atlas;
    final progress = download;

    final Widget leading;
    final String message;
    if (loading) {
      leading = SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: progress?.fraction,
          valueColor: AlwaysStoppedAnimation(luma.accent),
        ),
      );
      if (progress == null) {
        message = 'Reading block textures…';
      } else if (progress.total > 0) {
        message = '${progress.stage} '
            '${_megabytes(progress.received)} of '
            '${_megabytes(progress.total)}';
      } else {
        message = progress.stage;
      }
    } else if (loaded != null) {
      leading = Icon(Icons.check_circle_outline_rounded,
          size: 15, color: luma.success);
      message = 'Textures from ${loaded.label} '
          '(${loaded.textureCount} blocks)';
    } else {
      leading =
          Icon(Icons.palette_outlined, size: 15, color: luma.textMuted);
      // Naming the source and the size up front: this is the one place in the
      // feature that reaches out to the network, and it should be the user's
      // decision rather than something that quietly happens to them.
      message = failure == null
          ? 'Flat colours — no Minecraft found. Download the textures from '
              'Mojang (~${_megabytes(kApproximateClientJarBytes)}) or use '
              'your own copy.'
          : '$failure Showing flat block colours.';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        leading,
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
        ),
        if (!loading) ...[
          if (loaded == null) ...[
            ConverterTextButton(
              label: 'Download textures',
              onTap: onDownload,
            ),
            const SizedBox(width: 4),
          ],
          ConverterTextButton(
            label: loaded == null ? 'Use my install' : 'Change',
            onTap: onPick,
          ),
        ],
      ],
    );
  }
}

/// The recessed panel the preview is drawn into.
class _ViewerShell extends StatelessWidget {
  const _ViewerShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 320,
        decoration: BoxDecoration(
          color: luma.surfaceHover,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: luma.border),
        ),
        child: child,
      ),
    );
  }
}

class _ViewerControls extends StatelessWidget {
  const _ViewerControls({
    required this.layers,
    required this.maxLayer,
    required this.sourceHeight,
    required this.onLayersChanged,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  final RangeValues layers;
  final int maxLayer;
  final int sourceHeight;
  final ValueChanged<RangeValues> onLayersChanged;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    // The slider works in preview layers, which are coarser than the build's
    // own layers when the preview is simplified — label with real ones.
    final scale = maxLayer == 0 ? 1.0 : sourceHeight / maxLayer;
    final from = (layers.start * scale).round();
    final to = (layers.end * scale).round().clamp(from, sourceHeight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Layers',
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Y $from–$to',
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            _ViewerIconButton(
              icon: Icons.rotate_left_rounded,
              tooltip: 'Rotate left',
              onTap: onRotateLeft,
            ),
            _ViewerIconButton(
              icon: Icons.rotate_right_rounded,
              tooltip: 'Rotate right',
              onTap: onRotateRight,
            ),
            _ViewerIconButton(
              icon: Icons.zoom_out_rounded,
              tooltip: 'Zoom out',
              onTap: onZoomOut,
            ),
            _ViewerIconButton(
              icon: Icons.zoom_in_rounded,
              tooltip: 'Zoom in',
              onTap: onZoomIn,
            ),
            _ViewerIconButton(
              icon: Icons.restart_alt_rounded,
              tooltip: 'Reset the view',
              onTap: onReset,
            ),
          ],
        ),
        RangeSlider(
          values: layers,
          min: 0,
          max: maxLayer.toDouble(),
          divisions: maxLayer > 0 ? maxLayer : null,
          labels: RangeLabels('$from', '$to'),
          onChanged: onLayersChanged,
        ),
      ],
    );
  }
}

class _ViewerIconButton extends StatelessWidget {
  const _ViewerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        color: luma.textSecondary,
        hoverColor: luma.surfaceHover,
        // Keeps the tap target at the 44pt minimum even though the glyph is
        // smaller.
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: EdgeInsets.zero,
        tooltip: null,
      ),
    );
  }
}

/// Every non-air voxel of a build, flattened into typed arrays and grouped so
/// the painter can walk them in any of the eight back-to-front orders without
/// sorting.
///
/// Voxels are laid out Y-major, then Z, then X, and [_layerStart] / [_rowStart]
/// record where each layer and row begins. Because those runs are contiguous,
/// iterating a layer, row or run backwards is all that "draw the far side
/// first" needs.
class _VoxelGeometry {
  _VoxelGeometry({
    required this.width,
    required this.height,
    required this.length,
    required this.stride,
    required this.xs,
    required this.ys,
    required this.zs,
    required this.faces,
    required this.colors,
    required this.layerStart,
    required this.rowStart,
    required this.faceUv,
    required this.faceColors,
    required this.paletteIndex,
  });

  /// Preview grid size, which is the build's size divided by [stride].
  final int width;
  final int height;
  final int length;

  /// How many real blocks each preview voxel stands for along each axis.
  final int stride;

  final Int32List xs;
  final Int32List ys;
  final Int32List zs;

  /// Bit per face: 1 = +X, 2 = -X, 4 = +Y, 8 = -Y, 16 = +Z, 32 = -Z. A bit is
  /// set when that side is not buried behind another solid block.
  final Uint8List faces;

  /// ARGB per voxel. Used on its own when there are no textures, and as the
  /// multiplier on the texture when there are.
  final Int32List colors;

  final Int32List layerStart;
  final Int32List rowStart;

  /// Palette entry per voxel, the key into [faceUv] and [faceColors].
  final Uint16List paletteIndex;

  /// Atlas rectangle per palette entry per face, four floats each
  /// (left, top, right, bottom), indexed `(palette * 6 + face) * 4`.
  /// Empty when the preview is running without textures.
  final Float32List faceUv;

  /// Already-shaded ARGB per palette entry per face, indexed
  /// `palette * 6 + face`. Folding the block colour, its biome tint and the
  /// face's shading together here keeps the per-frame inner loop to a copy.
  final Int32List faceColors;

  bool get isTextured => faceUv.isNotEmpty;

  /// Reusable vertex buffers, kept here so they survive the painter being
  /// rebuilt every frame of a drag.
  Float32List scratchPositions = Float32List(0);
  Float32List scratchTexCoords = Float32List(0);
  Int32List scratchColors = Int32List(0);

  Paint? _texturePaint;

  /// The paint that samples the block atlas, built once and kept.
  ///
  /// A shader made inside `paint()` and thrown away there would already be
  /// disposed by the time the recorded frame is rasterised, and the build
  /// would come out blank.
  Paint paintFor(ui.Image atlasImage) => _texturePaint ??= (Paint()
    ..filterQuality = FilterQuality.none
    ..shader = ui.ImageShader(
      atlasImage,
      TileMode.clamp,
      TileMode.clamp,
      Matrix4.identity().storage,
      filterQuality: FilterQuality.none,
    ));

  bool get isEmpty => xs.isEmpty;

  static const int faceXPlus = 1;
  static const int faceXMinus = 2;
  static const int faceYPlus = 4;
  static const int faceYMinus = 8;
  static const int faceZPlus = 16;
  static const int faceZMinus = 32;

  /// Preview grids larger than this are simplified. Past roughly this many
  /// voxels a frame stops fitting in the 16ms budget.
  static const int maxVoxels = 120000;

  static _VoxelGeometry build(Schematic schematic, BlockAtlas? atlas) {
    final stride = _strideFor(schematic);
    final w = (schematic.width + stride - 1) ~/ stride;
    final h = (schematic.height + stride - 1) ~/ stride;
    final l = (schematic.length + stride - 1) ~/ stride;

    final paletteLength = schematic.palette.length;
    // Palette colours are looked up once rather than per voxel.
    final paletteColors = Int32List(paletteLength);
    final paletteSolid = Uint8List(paletteLength);
    final textured = atlas != null && atlas.isUsable;
    final faceUv = Float32List(textured ? paletteLength * 6 * 4 : 0);
    final faceColors = Int32List(textured ? paletteLength * 6 : 0);

    for (var i = 0; i < paletteLength; i++) {
      final state = schematic.palette[i];
      final color = BlockColors.of(state);
      paletteColors[i] = _argb(color);
      // A translucent block should not hide the faces behind it.
      var solid = state.isAir ? 0 : ((color.a >= 0.99) ? 1 : 2);

      if (textured) {
        final faces = atlas.texturesFor(state);
        // Leaves and glass have see-through pixels, so their neighbours have
        // to keep drawing even though the flat colour looks opaque.
        if (faces.hasTransparency && solid == 1) solid = 2;

        for (var face = 0; face < 6; face++) {
          final rect = faces.rects[face] ?? atlas.solidUv;
          final base = (i * 6 + face) * 4;
          faceUv[base] = rect.left;
          faceUv[base + 1] = rect.top;
          faceUv[base + 2] = rect.right;
          faceUv[base + 3] = rect.bottom;

          // With a texture the vertex colour is the multiplier: the biome
          // tint, dimmed by this face's shading. Without one it also has to
          // carry the block's flat colour.
          final tint = faces.rects[face] == null
              ? paletteColors[i]
              : faces.tints[face];
          faceColors[i * 6 + face] = _shade(tint, _faceShades[face]);
        }
      }
      paletteSolid[i] = solid;
    }

    final grid = Uint16List(w * h * l);
    for (var y = 0; y < h; y++) {
      for (var z = 0; z < l; z++) {
        for (var x = 0; x < w; x++) {
          grid[x + z * w + y * w * l] =
              _sample(schematic, paletteSolid, x, y, z, stride);
        }
      }
    }

    // Count first so the flat arrays can be allocated exactly once.
    var count = 0;
    for (var i = 0; i < grid.length; i++) {
      if (grid[i] != 0) count++;
    }
    if (count == 0) {
      return _VoxelGeometry(
        width: w,
        height: h,
        length: l,
        stride: stride,
        xs: Int32List(0),
        ys: Int32List(0),
        zs: Int32List(0),
        faces: Uint8List(0),
        colors: Int32List(0),
        layerStart: Int32List(h + 1),
        rowStart: Int32List(h * l + 1),
        faceUv: faceUv,
        faceColors: faceColors,
        paletteIndex: Uint16List(0),
      );
    }

    final xs = Int32List(count);
    final ys = Int32List(count);
    final zs = Int32List(count);
    final faces = Uint8List(count);
    final colors = Int32List(count);
    final paletteIndex = Uint16List(count);
    final layerStart = Int32List(h + 1);
    final rowStart = Int32List(h * l + 1);

    var cursor = 0;
    for (var y = 0; y < h; y++) {
      layerStart[y] = cursor;
      for (var z = 0; z < l; z++) {
        rowStart[y * l + z] = cursor;
        for (var x = 0; x < w; x++) {
          final index = grid[x + z * w + y * w * l];
          if (index == 0) continue;

          var mask = 0;
          // A face is drawn unless the neighbour on that side is at least as
          // opaque, which is what hides the inside of a solid build.
          bool covered(int nx, int ny, int nz) {
            if (nx < 0 || ny < 0 || nz < 0 || nx >= w || ny >= h || nz >= l) {
              return false;
            }
            final neighbour = grid[nx + nz * w + ny * w * l];
            if (neighbour == 0) return false;
            return paletteSolid[neighbour] == 1;
          }

          if (!covered(x + 1, y, z)) mask |= faceXPlus;
          if (!covered(x - 1, y, z)) mask |= faceXMinus;
          if (!covered(x, y + 1, z)) mask |= faceYPlus;
          if (!covered(x, y - 1, z)) mask |= faceYMinus;
          if (!covered(x, y, z + 1)) mask |= faceZPlus;
          if (!covered(x, y, z - 1)) mask |= faceZMinus;

          xs[cursor] = x;
          ys[cursor] = y;
          zs[cursor] = z;
          faces[cursor] = mask;
          colors[cursor] = paletteColors[index];
          paletteIndex[cursor] = index;
          cursor++;
        }
      }
      rowStart[y * l + l] = cursor;
    }
    layerStart[h] = cursor;
    rowStart[h * l] = cursor;

    return _VoxelGeometry(
      width: w,
      height: h,
      length: l,
      stride: stride,
      xs: xs,
      ys: ys,
      zs: zs,
      faces: faces,
      colors: colors,
      layerStart: layerStart,
      rowStart: rowStart,
      faceUv: faceUv,
      faceColors: faceColors,
      paletteIndex: paletteIndex,
    );
  }

  /// How much each face direction is darkened, so the shape reads without any
  /// lighting model: the top is lit, the sides step down, the base is darkest.
  /// Ordered +X, -X, +Y, -Y, +Z, -Z.
  static const List<double> _faceShades = [0.82, 0.82, 1.0, 0.5, 0.65, 0.65];

  static int _shade(int argb, double factor) {
    final a = (argb >> 24) & 0xFF;
    final r = (((argb >> 16) & 0xFF) * factor).round().clamp(0, 255);
    final g = (((argb >> 8) & 0xFF) * factor).round().clamp(0, 255);
    final b = ((argb & 0xFF) * factor).round().clamp(0, 255);
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  /// Picks the coarsest preview that still fits under [maxVoxels].
  static int _strideFor(Schematic s) {
    var stride = 1;
    while (stride < 64) {
      final w = (s.width + stride - 1) ~/ stride;
      final h = (s.height + stride - 1) ~/ stride;
      final l = (s.length + stride - 1) ~/ stride;
      if (w * h * l <= maxVoxels) return stride;
      stride++;
    }
    return stride;
  }

  /// Picks a representative block for one preview cell.
  ///
  /// Taking the corner block alone would drop one-block-thick walls at higher
  /// strides, so an empty corner falls back to scanning the cell for anything
  /// solid.
  static int _sample(
    Schematic s,
    Uint8List paletteSolid,
    int x,
    int y,
    int z,
    int stride,
  ) {
    final bx = x * stride;
    final by = y * stride;
    final bz = z * stride;
    if (stride == 1) {
      if (bx >= s.width || by >= s.height || bz >= s.length) return 0;
      final index = s.blocks[bx + bz * s.width + by * s.width * s.length];
      return paletteSolid[index] == 0 ? 0 : index;
    }

    var fallback = 0;
    for (var dy = 0; dy < stride; dy++) {
      final sy = by + dy;
      if (sy >= s.height) break;
      for (var dz = 0; dz < stride; dz++) {
        final sz = bz + dz;
        if (sz >= s.length) break;
        for (var dx = 0; dx < stride; dx++) {
          final sx = bx + dx;
          if (sx >= s.width) break;
          final index =
              s.blocks[sx + sz * s.width + sy * s.width * s.length];
          if (paletteSolid[index] == 0) continue;
          if (dx == 0 && dy == 0 && dz == 0) return index;
          fallback = index;
        }
      }
    }
    return fallback;
  }

  static int _argb(Color color) =>
      ((color.a * 255).round() << 24) |
      ((color.r * 255).round() << 16) |
      ((color.g * 255).round() << 8) |
      (color.b * 255).round();
}

class _VoxelPainter extends CustomPainter {
  _VoxelPainter({
    required this.geometry,
    required this.atlas,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.minLayer,
    required this.maxLayer,
  });

  final _VoxelGeometry geometry;

  /// The block textures, when a Minecraft installation was found to read them
  /// from. Null falls back to flat per-block colours.
  final BlockAtlas? atlas;
  final double yaw;
  final double pitch;
  final double zoom;
  final int minLayer;
  final int maxLayer;

  /// How much each face direction is darkened, so the shape reads without any
  /// lighting model: the top is lit, the sides step down, the base is darkest.
  static const double _shadeTop = 1.0;
  static const double _shadeBottom = 0.5;
  static const double _shadeX = 0.82;
  static const double _shadeZ = 0.65;

  /// Corner indices, as `cx | cy << 1 | cz << 2`, for each of the six faces
  /// wound as two triangles.
  static const List<List<int>> _faceCorners = [
    [1, 3, 7, 5],
    [0, 4, 6, 2],
    [2, 6, 7, 3],
    [0, 1, 5, 4],
    [4, 5, 7, 6],
    [0, 2, 3, 1],
  ];

  /// Which corner of the texture tile each quad corner takes, as a two-bit
  /// code: bit 0 picks right over left, bit 1 picks bottom over top. Worked
  /// out per face so textures land upright rather than rotated or mirrored.
  static const List<List<int>> _faceUvCorners = [
    [2, 0, 1, 3],
    [2, 3, 1, 0],
    [0, 2, 3, 1],
    [0, 1, 3, 2],
    [2, 3, 1, 0],
    [2, 0, 1, 3],
  ];

  /// The two triangles a quad is split into, as indices into its four corners.
  static const List<int> _quadVertexOrder = [0, 1, 2, 0, 2, 3];

  static final Paint _neutral = Paint()..color = const Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    if (geometry.isEmpty || size.isEmpty) return;

    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final cosP = math.cos(pitch);
    // Negated so that a positive pitch lifts the camera above the build and
    // shows its top. Without this the whole thing is drawn from underneath:
    // tilting the model's top away from the viewer turns the top face away
    // too, leaving only the dimly shaded undersides on screen.
    final sinP = -math.sin(pitch);

    final span = math.max(
      geometry.width,
      math.max(geometry.height, geometry.length),
    );
    final cell =
        (math.min(size.width, size.height) / (span * 1.7)).clamp(0.4, 64.0) *
            zoom;

    // Screen position is linear in (x, y, z), so the whole projection is six
    // coefficients and the cube corners become fixed per-frame offsets.
    final ax = cell * cosY;
    final az = cell * sinY;
    final bx = -cell * sinY * sinP;
    final by = -cell * cosP;
    final bz = cell * cosY * sinP;

    final cx = geometry.width / 2;
    final cy = geometry.height / 2;
    final cz = geometry.length / 2;
    final originX = size.width / 2 - (ax * cx + az * cz);
    final originY = size.height / 2 - (bx * cx + by * cy + bz * cz);

    final cornerX = Float32List(8);
    final cornerY = Float32List(8);
    for (var c = 0; c < 8; c++) {
      final ux = c & 1;
      final uy = (c >> 1) & 1;
      final uz = (c >> 2) & 1;
      cornerX[c] = ax * ux + az * uz;
      cornerY[c] = bx * ux + by * uy + bz * uz;
    }

    // Depth grows away from the camera, so a face is visible when its normal
    // has negative depth.
    double depthOf(double dx, double dy, double dz) =>
        -dx * sinY * cosP + dy * sinP + dz * cosY * cosP;

    final visible = <int>[
      if (depthOf(1, 0, 0) < 0) 0,
      if (depthOf(-1, 0, 0) < 0) 1,
      if (depthOf(0, 1, 0) < 0) 2,
      if (depthOf(0, -1, 0) < 0) 3,
      if (depthOf(0, 0, 1) < 0) 4,
      if (depthOf(0, 0, -1) < 0) 5,
    ];
    if (visible.isEmpty) return;

    final shades = <double>[
      _shadeX,
      _shadeX,
      _shadeTop,
      _shadeBottom,
      _shadeZ,
      _shadeZ,
    ];

    // Draw each axis from far to near. Higher coordinates are nearer when the
    // axis has positive "nearness", which is just the negated depth.
    final xNearHigh = depthOf(1, 0, 0) < 0;
    final yNearHigh = depthOf(0, 1, 0) < 0;
    final zNearHigh = depthOf(0, 0, 1) < 0;

    final lowLayer = minLayer.clamp(0, geometry.height);
    final highLayer = maxLayer.clamp(lowLayer, geometry.height);

    // Worst case every kept voxel shows three faces. The buffers live on the
    // geometry rather than the painter because a new painter is built on every
    // frame of a drag, and reallocating megabytes each time would dominate.
    final atlasImage = atlas;
    final textured = geometry.isTextured && atlasImage != null;
    final capacity = geometry.xs.length * 3 * 6 * 2;
    if (geometry.scratchPositions.length < capacity) {
      geometry.scratchPositions = Float32List(capacity);
      geometry.scratchColors = Int32List(capacity ~/ 2);
    }
    if (textured && geometry.scratchTexCoords.length < capacity) {
      geometry.scratchTexCoords = Float32List(capacity);
    }
    final positions = geometry.scratchPositions;
    final colors = geometry.scratchColors;
    final texCoords = geometry.scratchTexCoords;
    final faceUv = geometry.faceUv;
    final faceColors = geometry.faceColors;

    var p = 0;
    var q = 0;
    var t = 0;

    void emitVoxel(int i, bool forceTop) {
      var mask = geometry.faces[i];
      if (forceTop) mask |= _VoxelGeometry.faceYPlus;
      if (mask == 0) return;

      final baseX = ax * geometry.xs[i] + az * geometry.zs[i] + originX;
      final baseY = bx * geometry.xs[i] +
          by * geometry.ys[i] +
          bz * geometry.zs[i] +
          originY;
      final argb = geometry.colors[i];
      final alpha = (argb >> 24) & 0xFF;
      final red = (argb >> 16) & 0xFF;
      final green = (argb >> 8) & 0xFF;
      final blue = argb & 0xFF;
      final palette = textured ? geometry.paletteIndex[i] : 0;

      for (final face in visible) {
        if ((mask & (1 << face)) == 0) continue;

        final int shaded;
        if (textured) {
          shaded = faceColors[palette * 6 + face];
        } else {
          final shade = shades[face];
          shaded = (alpha << 24) |
              ((red * shade).round() << 16) |
              ((green * shade).round() << 8) |
              (blue * shade).round();
        }

        final corners = _faceCorners[face];
        final x0 = baseX + cornerX[corners[0]];
        final y0 = baseY + cornerY[corners[0]];
        final x1 = baseX + cornerX[corners[1]];
        final y1 = baseY + cornerY[corners[1]];
        final x2 = baseX + cornerX[corners[2]];
        final y2 = baseY + cornerY[corners[2]];
        final x3 = baseX + cornerX[corners[3]];
        final y3 = baseY + cornerY[corners[3]];

        positions[p++] = x0;
        positions[p++] = y0;
        positions[p++] = x1;
        positions[p++] = y1;
        positions[p++] = x2;
        positions[p++] = y2;
        positions[p++] = x0;
        positions[p++] = y0;
        positions[p++] = x2;
        positions[p++] = y2;
        positions[p++] = x3;
        positions[p++] = y3;
        for (var v = 0; v < 6; v++) {
          colors[q++] = shaded;
        }

        if (!textured) continue;
        // Each quad corner takes one of the tile's four corners, chosen so the
        // texture sits upright and unmirrored on that face.
        final uvBase = (palette * 6 + face) * 4;
        final left = faceUv[uvBase];
        final top = faceUv[uvBase + 1];
        final right = faceUv[uvBase + 2];
        final bottom = faceUv[uvBase + 3];
        final picks = _faceUvCorners[face];
        for (final vertex in _quadVertexOrder) {
          final pick = picks[vertex];
          texCoords[t++] = (pick & 1) == 0 ? left : right;
          texCoords[t++] = (pick & 2) == 0 ? top : bottom;
        }
      }
    }

    for (var yi = 0; yi < geometry.height; yi++) {
      final y = yNearHigh ? geometry.height - 1 - yi : yi;
      if (y < lowLayer || y >= highLayer) continue;
      // The cut face of a sliced build would otherwise be missing, because a
      // buried voxel has no top face of its own.
      final forceTop = y == highLayer - 1 && highLayer < geometry.height;

      for (var zi = 0; zi < geometry.length; zi++) {
        final z = zNearHigh ? geometry.length - 1 - zi : zi;
        final start = geometry.rowStart[y * geometry.length + z];
        final end = geometry.rowStart[y * geometry.length + z + 1];
        if (xNearHigh) {
          for (var i = end - 1; i >= start; i--) {
            emitVoxel(i, forceTop);
          }
        } else {
          for (var i = start; i < end; i++) {
            emitVoxel(i, forceTop);
          }
        }
      }
    }

    if (p == 0) return;

    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List.sublistView(positions, 0, p),
      textureCoordinates:
          textured ? Float32List.sublistView(texCoords, 0, t) : null,
      colors: Int32List.sublistView(colors, 0, q),
    );

    if (textured) {
      // Modulate multiplies the block texture by the vertex colour, which is
      // where the face shading and the biome tint come from. Nearest sampling
      // keeps the pixels crisp instead of smearing them at close zoom.
      //
      // The paint is cached on the geometry rather than built here: the
      // shader has to outlive this method, because the canvas only records
      // the draw now and rasterises it later.
      canvas.drawVertices(
        vertices,
        BlendMode.modulate,
        geometry.paintFor(atlasImage.image),
      );
      return;
    }

    // Modulating against opaque white passes the vertex colours through
    // untouched, whichever operand the engine treats as the source.
    canvas.drawVertices(vertices, BlendMode.modulate, _neutral);
  }

  @override
  bool shouldRepaint(_VoxelPainter old) =>
      old.geometry != geometry ||
      old.atlas != atlas ||
      old.yaw != yaw ||
      old.pitch != pitch ||
      old.zoom != zoom ||
      old.minLayer != minLayer ||
      old.maxLayer != maxLayer;
}
