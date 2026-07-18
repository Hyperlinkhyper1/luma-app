import 'package:flutter/material.dart';

import '../../theme/luma_theme.dart';
import 'tools/audio_editor_view.dart';
import 'tools/collage_maker_view.dart';
import 'tools/downscaler_view.dart';
import 'tools/image_editor_view.dart';
import 'tools/media_converter_view.dart';
import 'tools/picture_converter_view.dart';
import 'tools/video_downscaler_view.dart';

/// The converter tools, surfaced as tiles on the hub.
enum ConverterTool {
  audio,
  picture,
  video,
  downscaler,
  videoDownscaler,
  imageEditor,
  audioEditor,
  collageMaker,
}

/// File Converter section: a hub of four tools, each opening its own screen.
class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key});

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  ConverterTool? _active;

  void _open(ConverterTool tool) => setState(() => _active = tool);
  void _back() => setState(() => _active = null);

  @override
  Widget build(BuildContext context) {
    switch (_active) {
      case ConverterTool.picture:
        return PictureConverterView(onBack: _back);
      case ConverterTool.audio:
        return AudioConverterView(onBack: _back);
      case ConverterTool.video:
        return VideoConverterView(onBack: _back);
      case ConverterTool.downscaler:
        return DownscalerView(onBack: _back);
      case ConverterTool.videoDownscaler:
        return VideoDownscalerView(onBack: _back);
      case ConverterTool.imageEditor:
        return ImageEditorView(onBack: _back);
      case ConverterTool.audioEditor:
        return AudioEditorView(onBack: _back);
      case ConverterTool.collageMaker:
        return CollageMakerView(onBack: _back);
      case null:
        return _ConverterHub(onOpen: _open);
    }
  }
}

class _ConverterHub extends StatelessWidget {
  const _ConverterHub({required this.onOpen});
  final ValueChanged<ConverterTool> onOpen;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pick a tool to get started.',
                style: TextStyle(color: luma.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoCols = constraints.maxWidth >= 520;
                  final tiles = _tiles(onOpen);
                  if (!twoCols) {
                    return Column(
                      children: [
                        for (var i = 0; i < tiles.length; i++) ...[
                          if (i > 0) const SizedBox(height: 16),
                          tiles[i],
                        ],
                      ],
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < tiles.length; i += 2) ...[
                        if (i > 0) const SizedBox(height: 16),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: tiles[i]),
                              const SizedBox(width: 16),
                              Expanded(
                                child: i + 1 < tiles.length
                                    ? tiles[i + 1]
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _tiles(ValueChanged<ConverterTool> onOpen) => [
        _ToolTile(
          icon: Icons.graphic_eq_rounded,
          title: 'Audio converter',
          subtitle: 'MP3 · OGG · FLAC · M4A · WAV · AAC',
          badge: 'AUDIO',
          onTap: () => onOpen(ConverterTool.audio),
        ),
        _ToolTile(
          icon: Icons.image_outlined,
          title: 'Picture converter',
          subtitle: 'PNG · JPG · BMP · TIFF · SVG',
          badge: 'IMAGE',
          onTap: () => onOpen(ConverterTool.picture),
        ),
        _ToolTile(
          icon: Icons.movie_outlined,
          title: 'Video converter',
          subtitle: 'MP4 · MOV · WEBM · OGV · MPG · M4V',
          badge: 'VIDEO',
          onTap: () => onOpen(ConverterTool.video),
        ),
        _ToolTile(
          icon: Icons.compress_rounded,
          title: 'Image downscaler',
          subtitle: 'Shrink images with smart options',
          badge: 'OPTIMIZE',
          onTap: () => onOpen(ConverterTool.downscaler),
        ),
        _ToolTile(
          icon: Icons.movie_filter_outlined,
          title: 'Video downscaler',
          subtitle: 'Compress & shrink video files',
          badge: 'OPTIMIZE',
          onTap: () => onOpen(ConverterTool.videoDownscaler),
        ),
        _ToolTile(
          icon: Icons.photo_filter_outlined,
          title: 'Image editor',
          subtitle: 'Remove white backgrounds from images',
          badge: 'EDIT',
          onTap: () => onOpen(ConverterTool.imageEditor),
        ),
        _ToolTile(
          icon: Icons.equalizer_rounded,
          title: 'Audio editor',
          subtitle: 'Cut, equalize & preview audio',
          badge: 'EDIT',
          onTap: () => onOpen(ConverterTool.audioEditor),
        ),
        _ToolTile(
          icon: Icons.grid_view_rounded,
          title: 'Collage maker',
          subtitle: 'Create photo collages with templates',
          badge: 'CREATE',
          onTap: () => onOpen(ConverterTool.collageMaker),
        ),
      ];
}

class _ToolTile extends StatefulWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  @override
  State<_ToolTile> createState() => _ToolTileState();
}

class _ToolTileState extends State<_ToolTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _hovering ? luma.surfaceHover : luma.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _hovering ? luma.accent : luma.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: luma.accentSubtle,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: luma.accent, size: 24),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: luma.surfaceHover,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      widget.badge,
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.subtitle,
                style: TextStyle(color: luma.textMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
