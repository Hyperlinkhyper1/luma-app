import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/luma_theme.dart';
import 'converter_widgets.dart';
import 'tools/audio_editor_view.dart';
import 'tools/collage_maker_view.dart';
import 'tools/downscaler_view.dart';
import 'tools/image_editor_view.dart';
import 'tools/media_converter_view.dart';
import 'tools/other_tools_view.dart';
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
  other,
}

/// File Converter section: a hub of tools, each opening its own screen.
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
      case ConverterTool.other:
        return OtherToolsView(onBack: _back);
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
    final t = L.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.converterHubPickTool,
                style: TextStyle(color: luma.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ConverterToolGrid(tiles: _tiles(t, onOpen)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _tiles(L t, ValueChanged<ConverterTool> onOpen) => [
        ConverterToolTile(
          icon: Icons.graphic_eq_rounded,
          title: t.converterHubAudioTitle,
          subtitle: 'MP3 · OGG · FLAC · M4A · WAV · AAC',
          badge: t.converterBadgeAudio,
          onTap: () => onOpen(ConverterTool.audio),
        ),
        ConverterToolTile(
          icon: Icons.image_outlined,
          title: t.converterHubPictureTitle,
          subtitle: 'PNG · JPG · BMP · TIFF · SVG',
          badge: t.converterBadgeImage,
          onTap: () => onOpen(ConverterTool.picture),
        ),
        ConverterToolTile(
          icon: Icons.movie_outlined,
          title: t.converterHubVideoTitle,
          subtitle: 'MP4 · MOV · WEBM · OGV · MPG · M4V',
          badge: t.converterBadgeVideo,
          onTap: () => onOpen(ConverterTool.video),
        ),
        ConverterToolTile(
          icon: Icons.compress_rounded,
          title: t.converterHubDownscalerTitle,
          subtitle: t.converterHubDownscalerSubtitle,
          badge: t.converterBadgeOptimize,
          onTap: () => onOpen(ConverterTool.downscaler),
        ),
        ConverterToolTile(
          icon: Icons.movie_filter_outlined,
          title: t.converterHubVideoDownscalerTitle,
          subtitle: t.converterHubVideoDownscalerSubtitle,
          badge: t.converterBadgeOptimize,
          onTap: () => onOpen(ConverterTool.videoDownscaler),
        ),
        ConverterToolTile(
          icon: Icons.photo_filter_outlined,
          title: t.converterHubImageEditorTitle,
          subtitle: t.converterHubImageEditorSubtitle,
          badge: t.converterBadgeEdit,
          onTap: () => onOpen(ConverterTool.imageEditor),
        ),
        ConverterToolTile(
          icon: Icons.equalizer_rounded,
          title: t.converterHubAudioEditorTitle,
          subtitle: t.converterHubAudioEditorSubtitle,
          badge: t.converterBadgeEdit,
          onTap: () => onOpen(ConverterTool.audioEditor),
        ),
        ConverterToolTile(
          icon: Icons.grid_view_rounded,
          title: t.converterHubCollageTitle,
          subtitle: t.converterHubCollageSubtitle,
          badge: t.converterBadgeCreate,
          onTap: () => onOpen(ConverterTool.collageMaker),
        ),
        ConverterToolTile(
          icon: Icons.category_outlined,
          title: t.commonOther,
          subtitle: t.converterHubOtherSubtitle,
          badge: t.converterBadgeOther,
          onTap: () => onOpen(ConverterTool.other),
        ),
      ];
}
