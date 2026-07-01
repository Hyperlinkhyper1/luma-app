import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../theme/luma_theme.dart';
import '../converter_widgets.dart';
import '../file_saver.dart';
import '../image_convert.dart';

/// Image editor focused on background removal: every pure white pixel (#FFFFFF)
/// becomes transparent. Best for simple images with a clean white background.
class ImageEditorView extends StatefulWidget {
  const ImageEditorView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<ImageEditorView> createState() => _ImageEditorViewState();
}

class _ImageEditorViewState extends State<ImageEditorView> {
  Uint8List? _bytes;
  String? _name;
  int _size = 0;
  bool _processing = false;
  String? _error;
  SaveResult? _result;
  Uint8List? _processedBytes;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'bmp', 'tif', 'tiff'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'Could not read the selected file.');
      return;
    }
    setState(() {
      _bytes = bytes;
      _name = file.name;
      _size = file.size;
      _result = null;
      _error = null;
      _processedBytes = null;
    });
  }

  Future<void> _removeWhiteBackground() async {
    final bytes = _bytes;
    if (bytes == null) return;

    setState(() {
      _processing = true;
      _error = null;
      _result = null;
    });

    try {
      final processed = await compute(_processImage, bytes);
      if (!mounted) return;
      setState(() {
        _processing = false;
        _processedBytes = processed;
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = 'Something went wrong: \$e';
      });
    }
  }

  static Uint8List _processImage(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw const FormatException('Could not read this image.');
    }
    final max = image.maxChannelValue;
    for (final frame in image.frames) {
      for (final px in frame) {
        if (px.r == max && px.g == max && px.b == max) {
          px.a = 0;
        }
      }
    }
    return img.encodePng(image);
  }

  Future<void> _save() async {
    final bytes = _processedBytes;
    final name = _name;
    if (bytes == null || name == null) return;

    setState(() {
      _processing = true;
      _error = null;
      _result = null;
    });

    try {
      final save = await saveConvertedFile(
        bytes: bytes,
        suggestedName: '${ImageConvert.stripExtension(name)}_transparent.png',
        mimeType: 'image/png',
        extensions: ['png'],
      );
      if (!mounted) return;
      setState(() {
        _processing = false;
        _result = save;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = 'Could not save: \$e';
      });
    }
  }

  void _reset() {
    setState(() {
      _bytes = null;
      _name = null;
      _size = 0;
      _error = null;
      _result = null;
      _processedBytes = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ToolScaffold(
      icon: Icons.photo_filter_outlined,
      title: 'Image editor',
      subtitle: 'Remove white backgrounds from images',
      onBack: widget.onBack,
      children: [
        if (_bytes == null)
          ConverterDropZone(
            onTap: _pickFile,
            icon: Icons.add_photo_alternate_outlined,
            title: 'Click to choose an image',
            subtitle: 'PNG · JPG · BMP · TIFF',
          )
        else
          ConverterFileCard(
            name: _name!,
            thumbnail: _bytes,
            icon: Icons.image_outlined,
            meta: formatBytes(_size),
            onChange: _pickFile,
          ),
        if (_bytes != null) ...[
          const SizedBox(height: 16),
          ConverterCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Background Editor',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Make every pure white pixel (#FFFFFF) transparent. '
                  'This works best for simple images with a clean white background.',
                  style: TextStyle(color: luma.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (_processedBytes == null)
                  ConverterPrimaryButton(
                    label: 'Remove white background',
                    icon: Icons.auto_fix_high_rounded,
                    loading: _processing,
                    onTap: _removeWhiteBackground,
                  )
                else ...[
                  _ResultPreview(bytes: _processedBytes!),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ConverterPrimaryButton(
                          label: kIsWeb ? 'Download PNG' : 'Save PNG',
                          icon: Icons.download_rounded,
                          loading: _processing,
                          onTap: _save,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ConverterPrimaryButton(
                          label: 'Start over',
                          icon: Icons.replay_rounded,
                          loading: _processing,
                          onTap: () => setState(() => _processedBytes = null),
                        ),
                      ),
                    ],
                  ),
                ],
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
            trailing: ConverterTextButton(label: 'Edit another', onTap: _reset),
          ),
        ],
      ],
    );
  }
}

/// Preview of a processed image with a checkerboard backdrop so transparent
/// areas are visible.
class _ResultPreview extends StatelessWidget {
  const _ResultPreview({required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: luma.surfaceHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _CheckerboardPainter(),
            ),
            Center(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cellSize = 16.0;
    final paint = Paint();
    for (var y = 0.0; y < size.height; y += cellSize) {
      for (var x = 0.0; x < size.width; x += cellSize) {
        final row = (y / cellSize).floor();
        final col = (x / cellSize).floor();
        paint.color = (row + col).isEven
            ? const Color(0xFFFFFFFF)
            : const Color(0xFFE0E0E0);
        canvas.drawRect(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
