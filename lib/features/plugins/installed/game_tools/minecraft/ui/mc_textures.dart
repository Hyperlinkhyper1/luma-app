import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../../../l10n/app_localizations.dart';
import '../../../../../../theme/luma_theme.dart';
import '../../../../../converter/schematic/block_colors.dart';
import '../../../../../converter/schematic/schematic_model.dart';
import '../../../../../converter/schematic/textures/block_atlas.dart';
import '../../../../../converter/schematic/textures/block_model_resolver.dart';
import '../../../../../converter/schematic/textures/texture_downloader.dart';
import '../../../../../converter/schematic/textures/texture_pack_source.dart';

/// Shares the schematic preview's local assets and explicit source actions.
/// Loading never holds up the tool, and downloads only start on a button tap.
class McTextureBuilder extends StatefulWidget {
  const McTextureBuilder({super.key, required this.builder});

  final Widget Function(BuildContext, BlockAtlas?, Widget status) builder;

  @override
  State<McTextureBuilder> createState() => _McTextureBuilderState();
}

class _McTextureBuilderState extends State<McTextureBuilder> {
  BlockAtlas? _atlas = BlockAtlas.current;
  bool _loading = false;
  TextureDownloadProgress? _progress;

  @override
  void initState() {
    super.initState();
    _load(BlockAtlas.load);
  }

  Future<void> _load(Future<BlockAtlas?> Function() load) async {
    if (_loading) return;
    setState(() => _loading = true);
    final atlas = await load();
    if (!mounted) return;
    setState(() {
      _atlas = atlas;
      _loading = false;
      _progress = null;
    });
  }

  Future<void> _pick() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jar', 'zip'],
    );
    final path = picked?.files.firstOrNull?.path;
    if (!mounted || path == null) return;
    await _load(() => BlockAtlas.loadFrom(path));
  }

  Future<void> _download() => _load(
    () => BlockAtlas.downloadAndLoad(
      onProgress: (progress) {
        if (!mounted) return;
        if (progress.stage == _progress?.stage &&
            ((progress.fraction ?? 0) * 100).floor() ==
                ((_progress?.fraction ?? 0) * 100).floor()) {
          return;
        }
        setState(() => _progress = progress);
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final atlas = _atlas;
    final failure = BlockAtlas.failure;
    final message = _loading
        ? _progress?.stage ?? t.textureStageReading
        : failure != null
        ? t.schemViewerFailureFallback(failure)
        : atlas != null
        ? t.schemViewerTexturesFrom(atlas.label, atlas.textureCount)
        : t.schemViewerFlatColours(
            '${(kApproximateClientJarBytes / (1024 * 1024)).round()} MB',
          );
    final status = Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (_loading)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: _progress?.fraction,
            ),
          ),
        Text(
          message,
          style: TextStyle(color: context.luma.textMuted, fontSize: 11),
        ),
        TextButton.icon(
          onPressed: _loading ? null : _pick,
          icon: const Icon(Icons.folder_open_rounded, size: 15),
          label: Text(
            atlas == null ? t.schemViewerUseInstall : t.converterChange,
          ),
        ),
        if (atlas == null)
          TextButton.icon(
            onPressed: _loading ? null : _download,
            icon: const Icon(Icons.download_rounded, size: 15),
            label: Text(t.schemViewerDownloadTextures),
          ),
      ],
    );
    return widget.builder(context, atlas, status);
  }
}

/// Draws one atlas sprite without smoothing its pixels. Returns false when
/// the chosen pack has no sprite, so callers can keep their colour fallback.
bool mcPaintSprite(
  Canvas canvas,
  BlockAtlas? atlas,
  String name,
  Rect destination, {
  Color tint = Colors.white,
}) {
  final uv = atlas?.uvFor(name);
  if (atlas == null || uv == null) return false;
  canvas.drawImageRect(
    atlas.image,
    Rect.fromLTRB(uv.left, uv.top, uv.right, uv.bottom),
    destination,
    Paint()
      ..filterQuality = FilterQuality.none
      ..colorFilter = ColorFilter.mode(tint, BlendMode.modulate),
  );
  return true;
}

/// Tiles a vertical block face in square world units, including partial
/// tiles at the edges. The model resolver chooses sides instead of tops.
void mcPaintBlockFace(
  Canvas canvas,
  BlockAtlas? atlas,
  BlockState block,
  Rect rect, {
  required double tileSize,
}) {
  if (rect.isEmpty || block.isAir) return;
  final face = atlas?.resolver.facesFor(block);
  final index = CubeFace.south.index;
  final name = face?.textures[index];
  if (atlas == null || name == null || atlas.uvFor(name) == null) {
    canvas.drawRect(rect, Paint()..color = BlockColors.of(block));
    return;
  }
  // Very deep worlds compress hundreds of blocks into the panel. A minimum
  // visible tile size keeps their actual texture legible without stretching.
  final unit = math.max(8.0, tileSize);
  final grassOverlay =
      block.shortName == 'grass_block' &&
      name == 'block/grass_block_side' &&
      atlas.uvFor('block/grass_block_side_overlay') != null;
  canvas.save();
  canvas.clipRect(rect);
  for (var y = rect.top; y < rect.bottom; y += unit) {
    for (var x = rect.left; x < rect.right; x += unit) {
      mcPaintSprite(
        canvas,
        atlas,
        name,
        Rect.fromLTWH(x, y, unit, unit),
        tint: Color(face!.tints[index]),
      );
      if (grassOverlay) {
        mcPaintSprite(
          canvas,
          atlas,
          'block/grass_block_side_overlay',
          Rect.fromLTWH(x, y, unit, unit),
          tint: Color(face.tints[CubeFace.up.index]),
        );
      }
    }
  }
  canvas.restore();
}

class McBlockFace extends StatelessWidget {
  const McBlockFace({super.key, required this.block, required this.atlas});

  final BlockState block;
  final BlockAtlas? atlas;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _BlockFacePainter(block, atlas),
    size: const Size.square(30),
  );
}

class _BlockFacePainter extends CustomPainter {
  _BlockFacePainter(this.block, this.atlas);

  final BlockState block;
  final BlockAtlas? atlas;

  @override
  void paint(Canvas canvas, Size size) => mcPaintBlockFace(
    canvas,
    atlas,
    block,
    Offset.zero & size,
    tileSize: size.shortestSide,
  );

  @override
  bool shouldRepaint(_BlockFacePainter old) =>
      old.block != block || old.atlas != atlas;
}
