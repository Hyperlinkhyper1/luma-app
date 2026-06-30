import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../theme/luma_theme.dart';
import '../converter_widgets.dart';
import '../file_saver.dart';
import '../media/ffmpeg_service.dart';
import '../media/ffmpeg_setup.dart';

/// A selectable output format with its ffmpeg recipe.
///
/// [qualityArgs] holds one args list per quality level. A single entry means
/// the format has no quality choice (lossless / fixed); three entries map to
/// the Smaller / Balanced / High presets.
class MediaFormat {
  const MediaFormat({
    required this.label,
    required this.extension,
    required this.mimeType,
    required this.qualityArgs,
  });

  final String label;
  final String extension;
  final String mimeType;
  final List<List<String>> qualityArgs;

  bool get hasQuality => qualityArgs.length > 1;
}

/// Static configuration that turns the generic converter into the audio or
/// video format converter.
class MediaToolConfig {
  const MediaToolConfig({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.fileIcon,
    required this.inputExtensions,
    required this.targets,
    required this.qualityLabels,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final IconData fileIcon;
  final List<String> inputExtensions;
  final List<MediaFormat> targets;
  final List<String> qualityLabels;
}

/// Audio format converter: MP3 · OGG · FLAC · M4A · WAV · AAC.
class AudioConverterView extends StatelessWidget {
  const AudioConverterView({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => MediaConverterView(
        onBack: onBack,
        config: const MediaToolConfig(
          icon: Icons.graphic_eq_rounded,
          title: 'Audio converter',
          subtitle: 'Convert between MP3, OGG, FLAC, M4A, WAV and AAC',
          fileIcon: Icons.music_note_rounded,
          inputExtensions: [
            'mp3', 'ogg', 'flac', 'm4a', 'wav', 'aac', 'opus', 'wma', 'aiff',
          ],
          qualityLabels: ['Smaller', 'Balanced', 'High'],
          targets: [
            MediaFormat(
              label: 'MP3',
              extension: 'mp3',
              mimeType: 'audio/mpeg',
              qualityArgs: [
                ['-c:a', 'libmp3lame', '-q:a', '5'],
                ['-c:a', 'libmp3lame', '-q:a', '2'],
                ['-c:a', 'libmp3lame', '-q:a', '0'],
              ],
            ),
            MediaFormat(
              label: 'OGG',
              extension: 'ogg',
              mimeType: 'audio/ogg',
              qualityArgs: [
                ['-c:a', 'libvorbis', '-q:a', '3'],
                ['-c:a', 'libvorbis', '-q:a', '5'],
                ['-c:a', 'libvorbis', '-q:a', '7'],
              ],
            ),
            MediaFormat(
              label: 'M4A',
              extension: 'm4a',
              mimeType: 'audio/mp4',
              qualityArgs: [
                ['-c:a', 'aac', '-b:a', '128k'],
                ['-c:a', 'aac', '-b:a', '192k'],
                ['-c:a', 'aac', '-b:a', '256k'],
              ],
            ),
            MediaFormat(
              label: 'AAC',
              extension: 'aac',
              mimeType: 'audio/aac',
              qualityArgs: [
                ['-c:a', 'aac', '-b:a', '128k'],
                ['-c:a', 'aac', '-b:a', '192k'],
                ['-c:a', 'aac', '-b:a', '256k'],
              ],
            ),
            MediaFormat(
              label: 'FLAC',
              extension: 'flac',
              mimeType: 'audio/flac',
              qualityArgs: [
                ['-c:a', 'flac'],
              ],
            ),
            MediaFormat(
              label: 'WAV',
              extension: 'wav',
              mimeType: 'audio/wav',
              qualityArgs: [
                ['-c:a', 'pcm_s16le'],
              ],
            ),
          ],
        ),
      );
}

/// Video format converter: MP4 · MOV · WEBM · OGV · MPG · MPEG · M4V, plus M4A
/// audio extraction.
class VideoConverterView extends StatelessWidget {
  const VideoConverterView({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => MediaConverterView(
        onBack: onBack,
        config: const MediaToolConfig(
          icon: Icons.movie_outlined,
          title: 'Video converter',
          subtitle: 'Convert between MP4, MOV, WEBM, OGV, MPG, M4V (or to M4A)',
          fileIcon: Icons.videocam_rounded,
          inputExtensions: [
            'mp4', 'mov', 'mkv', 'webm', 'ogv', 'mpg', 'mpeg', 'm4v', 'avi',
            'flv', 'wmv',
          ],
          qualityLabels: ['Smaller', 'Balanced', 'High'],
          targets: [
            MediaFormat(
              label: 'MP4',
              extension: 'mp4',
              mimeType: 'video/mp4',
              qualityArgs: [
                [..._h264, '-movflags', '+faststart'],
              ],
            ),
            MediaFormat(
              label: 'MOV',
              extension: 'mov',
              mimeType: 'video/quicktime',
              qualityArgs: [_h264],
            ),
            MediaFormat(
              label: 'M4V',
              extension: 'm4v',
              mimeType: 'video/x-m4v',
              qualityArgs: [_h264],
            ),
            MediaFormat(
              label: 'WEBM',
              extension: 'webm',
              mimeType: 'video/webm',
              qualityArgs: [
                [
                  '-c:v', 'libvpx-vp9', '-b:v', '0', '-crf', '32',
                  '-row-mt', '1', '-deadline', 'good',
                  '-c:a', 'libopus', '-b:a', '128k',
                ],
              ],
            ),
            MediaFormat(
              label: 'OGV',
              extension: 'ogv',
              mimeType: 'video/ogg',
              qualityArgs: [
                ['-c:v', 'libtheora', '-q:v', '7', '-c:a', 'libvorbis', '-q:a', '5'],
              ],
            ),
            MediaFormat(
              label: 'MPG',
              extension: 'mpg',
              mimeType: 'video/mpeg',
              qualityArgs: [_mpeg2],
            ),
            MediaFormat(
              label: 'MPEG',
              extension: 'mpeg',
              mimeType: 'video/mpeg',
              qualityArgs: [_mpeg2],
            ),
            MediaFormat(
              label: 'M4A',
              extension: 'm4a',
              mimeType: 'audio/mp4',
              qualityArgs: [
                ['-vn', '-c:a', 'aac', '-b:a', '192k'],
              ],
            ),
          ],
        ),
      );
}

const _h264 = [
  '-c:v', 'libx264', '-crf', '23', '-preset', 'medium', '-pix_fmt', 'yuv420p',
  '-c:a', 'aac', '-b:a', '192k',
];

const _mpeg2 = [
  '-c:v', 'mpeg2video', '-q:v', '5', '-c:a', 'mp2', '-b:a', '192k',
];

/// Generic ffmpeg-backed format converter shared by audio and video.
class MediaConverterView extends StatefulWidget {
  const MediaConverterView({
    super.key,
    required this.onBack,
    required this.config,
  });

  final VoidCallback onBack;
  final MediaToolConfig config;

  @override
  State<MediaConverterView> createState() => _MediaConverterViewState();
}

class _MediaConverterViewState extends State<MediaConverterView> {
  bool? _ffmpegReady;

  String? _path;
  String? _name;
  int _size = 0;
  String _sourceExt = '';

  int _target = 0;
  int _quality = 1;
  bool _converting = false;
  String? _error;
  SaveResult? _result;

  MediaFormat get _format => widget.config.targets[_target];

  @override
  void initState() {
    super.initState();
    _checkFfmpeg();
  }

  Future<void> _checkFfmpeg() async {
    final ready = await Ffmpeg.available();
    if (!mounted) return;
    setState(() => _ffmpegReady = ready);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: widget.config.inputExtensions,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final path = file.path;
    if (path == null) {
      setState(() => _error =
          'Could not read the file path — conversion needs the desktop app.');
      return;
    }
    setState(() {
      _path = path;
      _name = file.name;
      _size = file.size;
      _sourceExt = _extensionOf(file.name);
      _result = null;
      _error = null;
      // Default target to the first format that differs from the source.
      final idx = widget.config.targets
          .indexWhere((f) => f.extension != _sourceExt);
      _target = idx < 0 ? 0 : idx;
      _quality = 1;
    });
  }

  Future<void> _convert() async {
    final path = _path;
    final name = _name;
    if (path == null || name == null) return;

    setState(() {
      _converting = true;
      _error = null;
      _result = null;
    });

    final format = _format;
    final level = format.hasQuality ? _quality.clamp(0, 2) : 0;
    try {
      final out = await Ffmpeg.transcodePath(
        inputPath: path,
        args: format.qualityArgs[level],
        outputExtension: format.extension,
      );
      final save = await saveConvertedFile(
        bytes: out,
        suggestedName: '${_stripExtension(name)}.${format.extension}',
        mimeType: format.mimeType,
        extensions: [format.extension],
      );
      if (!mounted) return;
      setState(() {
        _converting = false;
        _result = save;
      });
    } on FfmpegException catch (e) {
      if (!mounted) return;
      setState(() {
        _converting = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _converting = false;
        _error = 'Something went wrong while converting: $e';
      });
    }
  }

  void _reset() {
    setState(() {
      _path = null;
      _name = null;
      _size = 0;
      _sourceExt = '';
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final config = widget.config;
    final ready = _ffmpegReady ?? false;

    return ToolScaffold(
      icon: config.icon,
      title: config.title,
      subtitle: config.subtitle,
      onBack: widget.onBack,
      children: [
        if (_ffmpegReady == false) ...[
          FfmpegSetup(
            onReady: () => setState(() => _ffmpegReady = true),
          ),
          const SizedBox(height: 16),
        ],
        if (_path == null)
          ConverterDropZone(
            onTap: _pickFile,
            icon: Icons.upload_file_rounded,
            title: 'Click to choose a file',
            subtitle: config.inputExtensions
                .take(6)
                .map((e) => e.toUpperCase())
                .join(' · '),
          )
        else
          ConverterFileCard(
            name: _name!,
            icon: config.fileIcon,
            meta: formatBytes(_size),
            badge: _sourceExt.isEmpty
                ? null
                : FormatChip(label: _sourceExt.toUpperCase()),
            onChange: _pickFile,
          ),
        if (_path != null) ...[
          const SizedBox(height: 16),
          ConverterCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FormatTransition(
                  source: _sourceExt.toUpperCase(),
                  target: _format.label,
                ),
                const SizedBox(height: 20),
                Text('Convert to',
                    style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                _TargetPicker(
                  targets: config.targets,
                  selected: _target,
                  onSelect: _converting
                      ? null
                      : (i) => setState(() {
                            _target = i;
                            _quality = 1;
                          }),
                ),
                if (_format.hasQuality) ...[
                  const SizedBox(height: 18),
                  Text('Quality',
                      style: TextStyle(
                          color: luma.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),
                  _SegmentSelector(
                    labels: config.qualityLabels,
                    selected: _quality,
                    onSelect: _converting
                        ? null
                        : (i) => setState(() => _quality = i),
                  ),
                ],
                const SizedBox(height: 18),
                ConverterPrimaryButton(
                  label: 'Convert & save',
                  icon: Icons.bolt_rounded,
                  loading: _converting,
                  onTap: ready ? _convert : null,
                ),
              ],
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          ConverterBanner(
            icon: Icons.error_outline_rounded,
            color: luma.danger,
            message: _error!,
          ),
        ],
        if (_result != null && _result!.saved) ...[
          const SizedBox(height: 16),
          ConverterBanner(
            icon: Icons.check_circle_outline_rounded,
            color: luma.success,
            message: _result!.summary,
            trailing:
                ConverterTextButton(label: 'Convert another', onTap: _reset),
          ),
        ],
      ],
    );
  }
}

class _TargetPicker extends StatelessWidget {
  const _TargetPicker({
    required this.targets,
    required this.selected,
    required this.onSelect,
  });
  final List<MediaFormat> targets;
  final int selected;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < targets.length; i++)
          _FormatPill(
            label: targets[i].label,
            selected: i == selected,
            onTap: onSelect == null ? null : () => onSelect!(i),
          ),
      ],
    );
  }
}

class _FormatPill extends StatelessWidget {
  const _FormatPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? luma.accentSubtle : luma.surfaceHover,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? luma.accent : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? luma.accent : luma.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentSelector extends StatelessWidget {
  const _SegmentSelector({
    required this.labels,
    required this.selected,
    required this.onSelect,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: MouseRegion(
              cursor: onSelect == null
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onSelect == null ? null : () => onSelect!(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected
                        ? luma.accentSubtle
                        : luma.surfaceHover,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: i == selected ? luma.accent : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: i == selected ? luma.accent : luma.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String _extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

String _stripExtension(String name) {
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
}
