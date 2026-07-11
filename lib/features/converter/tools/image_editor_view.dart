import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../theme/luma_theme.dart';
import '../converter_widgets.dart';
import '../file_saver.dart';
import '../image_convert.dart';

/// Color filters the editor can apply on top of the adjustments.
enum _EditorFilter { none, grayscale, sepia, invert }

/// The full set of edits applied to the source image, in pipeline order:
/// transform -> adjustments -> filter -> background removal.
class _EditOps {
  const _EditOps({
    this.rotation = 0,
    this.flipH = false,
    this.flipV = false,
    this.brightness = 1.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.filter = _EditorFilter.none,
    this.removeWhiteBg = false,
    this.tolerance = 0.0,
  });

  /// Clockwise rotation in degrees (0, 90, 180, 270).
  final int rotation;
  final bool flipH;
  final bool flipV;

  /// Multipliers where 1.0 = unchanged.
  final double brightness;
  final double contrast;
  final double saturation;

  final _EditorFilter filter;

  final bool removeWhiteBg;

  /// 0.0 = only pure white, 0.3 = anything within 30% of white.
  final double tolerance;

  bool get isIdentity =>
      rotation == 0 &&
      !flipH &&
      !flipV &&
      brightness == 1.0 &&
      contrast == 1.0 &&
      saturation == 1.0 &&
      filter == _EditorFilter.none &&
      !removeWhiteBg;

  _EditOps copyWith({
    int? rotation,
    bool? flipH,
    bool? flipV,
    double? brightness,
    double? contrast,
    double? saturation,
    _EditorFilter? filter,
    bool? removeWhiteBg,
    double? tolerance,
  }) {
    return _EditOps(
      rotation: rotation ?? this.rotation,
      flipH: flipH ?? this.flipH,
      flipV: flipV ?? this.flipV,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      filter: filter ?? this.filter,
      removeWhiteBg: removeWhiteBg ?? this.removeWhiteBg,
      tolerance: tolerance ?? this.tolerance,
    );
  }
}

/// Arguments handed to the processing isolate. Kept as a plain class of
/// sendable fields so [compute] can ship it across.
class _ProcessArgs {
  const _ProcessArgs(this.bytes, this.ops, this.maxDimension);
  final Uint8List bytes;
  final _EditOps ops;

  /// When set, the image is downscaled to fit before processing (fast
  /// previews); null means full resolution (final save).
  final int? maxDimension;
}

/// Image editor: rotate/flip, brightness/contrast/saturation, color filters,
/// and white-background removal with an adjustable tolerance. Edits preview
/// live (debounced, downscaled) and are applied at full resolution on save.
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

  _EditOps _ops = const _EditOps();

  Uint8List? _previewBytes;
  bool _previewing = false;
  bool _saving = false;
  String? _error;
  SaveResult? _result;

  Timer? _debounce;
  int _previewRequest = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

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
    _debounce?.cancel();
    setState(() {
      _bytes = bytes;
      _name = file.name;
      _size = file.size;
      _ops = const _EditOps();
      _previewBytes = null;
      _error = null;
      _result = null;
    });
    _schedulePreview(immediate: true);
  }

  /// Applies an edit and queues a debounced preview refresh, so dragging a
  /// slider doesn't spawn an isolate per tick.
  void _updateOps(_EditOps ops, {bool immediate = false}) {
    setState(() {
      _ops = ops;
      _result = null;
    });
    _schedulePreview(immediate: immediate);
  }

  void _schedulePreview({bool immediate = false}) {
    _debounce?.cancel();
    if (immediate) {
      _generatePreview();
    } else {
      _debounce = Timer(const Duration(milliseconds: 350), _generatePreview);
    }
  }

  Future<void> _generatePreview() async {
    final bytes = _bytes;
    if (bytes == null) return;

    final request = ++_previewRequest;
    setState(() {
      _previewing = true;
      _error = null;
    });

    try {
      final processed =
          await compute(_processImage, _ProcessArgs(bytes, _ops, 1400));
      if (!mounted || request != _previewRequest) return;
      setState(() {
        _previewing = false;
        _previewBytes = processed;
      });
    } on FormatException catch (e) {
      if (!mounted || request != _previewRequest) return;
      setState(() {
        _previewing = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted || request != _previewRequest) return;
      setState(() {
        _previewing = false;
        _error = 'Something went wrong: $e';
      });
    }
  }

  static Uint8List _processImage(_ProcessArgs args) {
    var image = img.decodeImage(args.bytes);
    if (image == null) {
      throw const FormatException('Could not read this image.');
    }
    final ops = args.ops;

    final maxDim = args.maxDimension;
    if (maxDim != null && (image.width > maxDim || image.height > maxDim)) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxDim)
          : img.copyResize(image, height: maxDim);
    }

    if (ops.rotation != 0) {
      image = img.copyRotate(image, angle: ops.rotation);
    }
    if (ops.flipH) image = img.flipHorizontal(image);
    if (ops.flipV) image = img.flipVertical(image);

    if (ops.brightness != 1.0 ||
        ops.contrast != 1.0 ||
        ops.saturation != 1.0) {
      image = img.adjustColor(
        image,
        brightness: ops.brightness,
        contrast: ops.contrast,
        saturation: ops.saturation,
      );
    }

    switch (ops.filter) {
      case _EditorFilter.grayscale:
        image = img.grayscale(image);
      case _EditorFilter.sepia:
        image = img.sepia(image);
      case _EditorFilter.invert:
        image = img.invert(image);
      case _EditorFilter.none:
        break;
    }

    if (ops.removeWhiteBg) {
      // JPEG and friends decode without an alpha channel; add one so setting
      // px.a actually produces transparency.
      if (image.numChannels < 4) {
        image = image.convert(numChannels: 4);
      }
      final max = image.maxChannelValue;
      final threshold = max * (1 - ops.tolerance);
      for (final frame in image.frames) {
        for (final px in frame) {
          if (px.r >= threshold && px.g >= threshold && px.b >= threshold) {
            px.a = 0;
          }
        }
      }
    }

    return img.encodePng(image);
  }

  Future<void> _save() async {
    final bytes = _bytes;
    final name = _name;
    if (bytes == null || name == null) return;

    setState(() {
      _saving = true;
      _error = null;
      _result = null;
    });

    try {
      final processed =
          await compute(_processImage, _ProcessArgs(bytes, _ops, null));
      final save = await saveConvertedFile(
        bytes: processed,
        suggestedName: '${ImageConvert.stripExtension(name)}_edited.png',
        mimeType: 'image/png',
        extensions: ['png'],
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _result = save;
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save: $e';
      });
    }
  }

  void _reset() {
    _debounce?.cancel();
    setState(() {
      _bytes = null;
      _name = null;
      _size = 0;
      _ops = const _EditOps();
      _previewBytes = null;
      _error = null;
      _result = null;
      _previewing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ToolScaffold(
      icon: Icons.photo_filter_outlined,
      title: 'Image editor',
      subtitle: 'Rotate, adjust, filter, and remove backgrounds',
      onBack: widget.onBack,
      children: [
        if (_bytes == null)
          ConverterDropZone(
            onTap: _pickFile,
            icon: Icons.add_photo_alternate_outlined,
            title: 'Click to choose an image',
            subtitle: 'PNG · JPG · BMP · TIFF',
          )
        else ...[
          ConverterFileCard(
            name: _name!,
            thumbnail: _bytes,
            icon: Icons.image_outlined,
            meta: formatBytes(_size),
            onChange: _pickFile,
          ),
          const SizedBox(height: 16),
          _PreviewCard(
            bytes: _previewBytes ?? _bytes!,
            busy: _previewing,
          ),
          const SizedBox(height: 16),
          _TransformSection(ops: _ops, onChanged: _updateOps),
          const SizedBox(height: 16),
          _AdjustmentsSection(ops: _ops, onChanged: _updateOps),
          const SizedBox(height: 16),
          _FilterSection(ops: _ops, onChanged: _updateOps),
          const SizedBox(height: 16),
          _BackgroundSection(ops: _ops, onChanged: _updateOps),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ConverterPrimaryButton(
                  label: kIsWeb ? 'Download PNG' : 'Save PNG',
                  icon: Icons.download_rounded,
                  loading: _saving,
                  onTap: _ops.isIdentity ? null : _save,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ConverterPrimaryButton(
                  label: 'Reset edits',
                  icon: Icons.restart_alt_rounded,
                  loading: false,
                  onTap: _ops.isIdentity
                      ? null
                      : () =>
                          _updateOps(const _EditOps(), immediate: true),
                ),
              ),
            ],
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

/// Live preview on a checkerboard (so transparency shows), with a subtle
/// progress veil while the isolate is re-rendering.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.bytes, required this.busy});
  final Uint8List bytes;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: luma.surfaceHover,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: luma.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _CheckerboardPainter()),
            Center(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: busy ? 1 : 0,
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.25),
                  child: Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        valueColor: AlwaysStoppedAnimation(luma.accent),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card with a bold section title, optional subtitle, and its controls.
class _EditorSection extends StatelessWidget {
  const _EditorSection({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ConverterCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(color: luma.textMuted, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _TransformSection extends StatelessWidget {
  const _TransformSection({required this.ops, required this.onChanged});
  final _EditOps ops;
  final void Function(_EditOps ops, {bool immediate}) onChanged;

  @override
  Widget build(BuildContext context) {
    return _EditorSection(
      title: 'Transform',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _ToolChip(
            icon: Icons.rotate_90_degrees_ccw_rounded,
            label: 'Rotate left',
            onTap: () => onChanged(
              ops.copyWith(rotation: (ops.rotation + 270) % 360),
              immediate: true,
            ),
          ),
          _ToolChip(
            icon: Icons.rotate_90_degrees_cw_rounded,
            label: 'Rotate right',
            onTap: () => onChanged(
              ops.copyWith(rotation: (ops.rotation + 90) % 360),
              immediate: true,
            ),
          ),
          _ToolChip(
            icon: Icons.swap_horiz_rounded,
            label: 'Flip horizontal',
            active: ops.flipH,
            onTap: () =>
                onChanged(ops.copyWith(flipH: !ops.flipH), immediate: true),
          ),
          _ToolChip(
            icon: Icons.swap_vert_rounded,
            label: 'Flip vertical',
            active: ops.flipV,
            onTap: () =>
                onChanged(ops.copyWith(flipV: !ops.flipV), immediate: true),
          ),
        ],
      ),
    );
  }
}

class _AdjustmentsSection extends StatelessWidget {
  const _AdjustmentsSection({required this.ops, required this.onChanged});
  final _EditOps ops;
  final void Function(_EditOps ops, {bool immediate}) onChanged;

  @override
  Widget build(BuildContext context) {
    return _EditorSection(
      title: 'Adjustments',
      child: Column(
        children: [
          _EditorSlider(
            label: 'Brightness',
            value: ops.brightness,
            min: 0.5,
            max: 1.5,
            onChanged: (v) => onChanged(ops.copyWith(brightness: v)),
          ),
          const SizedBox(height: 8),
          _EditorSlider(
            label: 'Contrast',
            value: ops.contrast,
            min: 0.5,
            max: 1.5,
            onChanged: (v) => onChanged(ops.copyWith(contrast: v)),
          ),
          const SizedBox(height: 8),
          _EditorSlider(
            label: 'Saturation',
            value: ops.saturation,
            min: 0.0,
            max: 2.0,
            onChanged: (v) => onChanged(ops.copyWith(saturation: v)),
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.ops, required this.onChanged});
  final _EditOps ops;
  final void Function(_EditOps ops, {bool immediate}) onChanged;

  static const _labels = {
    _EditorFilter.none: 'None',
    _EditorFilter.grayscale: 'Grayscale',
    _EditorFilter.sepia: 'Sepia',
    _EditorFilter.invert: 'Invert',
  };

  @override
  Widget build(BuildContext context) {
    return _EditorSection(
      title: 'Filters',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final filter in _EditorFilter.values)
            _ToolChip(
              icon: switch (filter) {
                _EditorFilter.none => Icons.filter_none_rounded,
                _EditorFilter.grayscale => Icons.filter_b_and_w_rounded,
                _EditorFilter.sepia => Icons.filter_vintage_rounded,
                _EditorFilter.invert => Icons.invert_colors_rounded,
              },
              label: _labels[filter]!,
              active: ops.filter == filter,
              onTap: () =>
                  onChanged(ops.copyWith(filter: filter), immediate: true),
            ),
        ],
      ),
    );
  }
}

class _BackgroundSection extends StatelessWidget {
  const _BackgroundSection({required this.ops, required this.onChanged});
  final _EditOps ops;
  final void Function(_EditOps ops, {bool immediate}) onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return _EditorSection(
      title: 'Background removal',
      subtitle: 'Make white pixels transparent. Raise the tolerance to also '
          'catch off-white pixels.',
      trailing: Switch(
        value: ops.removeWhiteBg,
        activeThumbColor: luma.accent,
        onChanged: (v) =>
            onChanged(ops.copyWith(removeWhiteBg: v), immediate: true),
      ),
      child: _EditorSlider(
        label: 'Tolerance',
        value: ops.tolerance,
        min: 0.0,
        max: 0.3,
        enabled: ops.removeWhiteBg,
        display: (v) => '${(v * 100).round()}%',
        onChanged: (v) => onChanged(ops.copyWith(tolerance: v)),
      ),
    );
  }
}

/// Labeled slider row with a live value readout, themed to luma's accent.
class _EditorSlider extends StatelessWidget {
  const _EditorSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.enabled = true,
    this.display,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final bool enabled;
  final String Function(double value)? display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final text = display?.call(value) ?? '${(value * 100).round()}%';
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? luma.textSecondary : luma.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: luma.accent,
              inactiveTrackColor: luma.surfaceHover,
              thumbColor: luma.accent,
              overlayColor: luma.accent.withValues(alpha: 0.12),
              trackHeight: 4,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            text,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: enabled ? luma.textPrimary : luma.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// Icon + label pill button used for transforms and filters. Highlights with
/// the accent color while its option is active.
class _ToolChip extends StatefulWidget {
  const _ToolChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_ToolChip> createState() => _ToolChipState();
}

class _ToolChipState extends State<_ToolChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final active = widget.active;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active
                ? luma.accentSubtle
                : (_hovering ? luma.surfaceHover : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? luma.accent : luma.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: active ? luma.accent : luma.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: active ? luma.accent : luma.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
