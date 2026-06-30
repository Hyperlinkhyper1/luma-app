import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../theme/luma_theme.dart';
import '../converter_widgets.dart';
import '../file_saver.dart';
import '../image_convert.dart';

/// Convert images between PNG, JPG, BMP and TIFF (and rasterize SVG sources).
class PictureConverterView extends StatefulWidget {
  const PictureConverterView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<PictureConverterView> createState() => _PictureConverterViewState();
}

class _PictureConverterViewState extends State<PictureConverterView> {
  Uint8List? _bytes;
  String? _name;
  int _size = 0;
  PictureFormat? _source;

  PictureFormat _target = PictureFormat.png;
  double _quality = 90;
  bool _converting = false;
  String? _error;
  SaveResult? _result;

  bool get _isSvg => _source == PictureFormat.svg;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'bmp', 'tif', 'tiff', 'svg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'Could not read the selected file.');
      return;
    }
    final source = ImageConvert.detect(bytes, file.name);
    setState(() {
      _bytes = bytes;
      _name = file.name;
      _size = file.size;
      _source = source;
      _result = null;
      _error = source == null
          ? 'That file is not a supported image (PNG, JPG, BMP, TIFF or SVG).'
          : null;
      // Default the target to something different from the source.
      _target =
          source == PictureFormat.png ? PictureFormat.jpg : PictureFormat.png;
    });
  }

  Future<void> _convert() async {
    final bytes = _bytes;
    final name = _name;
    final source = _source;
    if (bytes == null || name == null || source == null) return;

    setState(() {
      _converting = true;
      _error = null;
      _result = null;
    });

    try {
      // SVG is rasterized to PNG bytes first, then re-encoded to the target.
      final rasterBytes = _isSvg ? await _rasterizeSvg(bytes) : bytes;
      final out = ImageConvert.convertRaster(
        bytes: rasterBytes,
        target: _target,
        jpgQuality: _quality.round(),
      );
      final save = await saveConvertedFile(
        bytes: out,
        suggestedName: '${ImageConvert.stripExtension(name)}.${_target.extension}',
        mimeType: _target.mimeType,
        extensions: [_target.extension],
      );
      if (!mounted) return;
      setState(() {
        _converting = false;
        _result = save;
      });
    } on FormatException catch (e) {
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

  /// Rasterizes an SVG to PNG bytes, scaling so the longest side is at least
  /// 512px (and at most 4096px) for crisp output.
  Future<Uint8List> _rasterizeSvg(Uint8List svgBytes) async {
    final info = await vg.loadPicture(SvgBytesLoader(svgBytes), null);
    try {
      final size = info.size;
      final longest = math.max(size.width, size.height);
      final scale = longest <= 0 ? 1.0 : longest.clamp(512.0, 4096.0) / longest;
      final w = (size.width * scale).round().clamp(1, 8192);
      final h = (size.height * scale).round().clamp(1, 8192);

      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder)
        ..scale(scale)
        ..drawPicture(info.picture);
      final raster = recorder.endRecording();
      try {
        final image = await raster.toImage(w, h);
        try {
          final data =
              await image.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) {
            throw const FormatException('Could not rasterize the SVG.');
          }
          return data.buffer.asUint8List();
        } finally {
          image.dispose();
        }
      } finally {
        raster.dispose();
      }
    } finally {
      info.picture.dispose();
    }
  }

  void _reset() {
    setState(() {
      _bytes = null;
      _name = null;
      _size = 0;
      _source = null;
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ToolScaffold(
      icon: Icons.image_outlined,
      title: 'Picture converter',
      subtitle: 'Convert between PNG, JPG, BMP, TIFF and SVG',
      onBack: widget.onBack,
      children: [
        if (_bytes == null)
          ConverterDropZone(
            onTap: _pickFile,
            icon: Icons.add_photo_alternate_outlined,
            title: 'Click to choose an image',
            subtitle: 'PNG · JPG · BMP · TIFF · SVG',
          )
        else
          ConverterFileCard(
            name: _name!,
            // SVG can't be shown by Image.memory — fall back to an icon.
            thumbnail: _isSvg ? null : _bytes,
            icon: Icons.image_outlined,
            meta: formatBytes(_size),
            badge: _source == null ? null : FormatChip(label: _source!.label),
            onChange: _pickFile,
          ),
        if (_bytes != null && _source != null) ...[
          const SizedBox(height: 16),
          ConverterCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FormatTransition(
                  source: _source!.label,
                  target: _target.label,
                ),
                const SizedBox(height: 20),
                Text('Convert to',
                    style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                _FormatPicker(
                  formats: ImageConvert.targets,
                  selected: _target,
                  onSelect: _converting
                      ? null
                      : (f) => setState(() => _target = f),
                ),
                if (_target == PictureFormat.jpg) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text('Quality',
                          style: TextStyle(
                              color: luma.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text('${_quality.round()}',
                          style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Slider(
                    value: _quality,
                    min: 10,
                    max: 100,
                    divisions: 90,
                    onChanged: _converting
                        ? null
                        : (v) => setState(() => _quality = v),
                  ),
                ],
                if (_isSvg) ...[
                  const SizedBox(height: 12),
                  Text(
                    'SVG is vector — it will be rasterized at a crisp size '
                    'before converting.',
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 16),
                ConverterPrimaryButton(
                  label: kIsWeb ? 'Convert & download' : 'Convert & save',
                  icon: Icons.bolt_rounded,
                  loading: _converting,
                  onTap: _convert,
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

class _FormatPicker extends StatelessWidget {
  const _FormatPicker({
    required this.formats,
    required this.selected,
    required this.onSelect,
  });
  final List<PictureFormat> formats;
  final PictureFormat selected;
  final ValueChanged<PictureFormat>? onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final f in formats)
          _FormatPill(
            label: f.label,
            selected: f == selected,
            onTap: onSelect == null ? null : () => onSelect!(f),
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
