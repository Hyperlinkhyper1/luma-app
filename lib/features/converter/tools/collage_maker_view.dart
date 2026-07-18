import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../theme/luma_theme.dart';
import '../converter_widgets.dart';
import '../file_saver.dart';
import '../image_convert.dart';

// ---------------------------------------------------------------------------
// Template data model
// ---------------------------------------------------------------------------

/// A single rectangular slot inside a collage template, expressed in normalized
/// 0–1 coordinates relative to the canvas.
class CollageSlot {
  const CollageSlot(this.rect);
  final Rect rect;
}

/// A named template containing a list of slots.
class CollageTemplate {
  const CollageTemplate({
    required this.name,
    required this.icon,
    required this.slots,
  });
  final String name;
  final IconData icon;
  final List<CollageSlot> slots;

  int get slotCount => slots.length;
}

/// All built-in templates. Rects use (left, top, right, bottom) in 0..1 space.
final List<CollageTemplate> kTemplates = [
  // -- 2-cell horizontal split
  CollageTemplate(
    name: '2 Horizontal',
    icon: Icons.view_column_rounded,
    slots: [
      CollageSlot(const Rect.fromLTRB(0, 0, 0.5, 1)),
      CollageSlot(const Rect.fromLTRB(0.5, 0, 1, 1)),
    ],
  ),
  // -- 2-cell vertical split
  CollageTemplate(
    name: '2 Vertical',
    icon: Icons.view_stream_rounded,
    slots: [
      CollageSlot(const Rect.fromLTRB(0, 0, 1, 0.5)),
      CollageSlot(const Rect.fromLTRB(0, 0.5, 1, 1)),
    ],
  ),
  // -- 3-column equal
  CollageTemplate(
    name: '3 Column',
    icon: Icons.view_week_rounded,
    slots: [
      CollageSlot(const Rect.fromLTRB(0, 0, 0.333, 1)),
      CollageSlot(const Rect.fromLTRB(0.333, 0, 0.666, 1)),
      CollageSlot(const Rect.fromLTRB(0.666, 0, 1, 1)),
    ],
  ),
  // -- 2x2 grid
  CollageTemplate(
    name: '2×2 Grid',
    icon: Icons.grid_view_rounded,
    slots: [
      CollageSlot(const Rect.fromLTRB(0, 0, 0.5, 0.5)),
      CollageSlot(const Rect.fromLTRB(0.5, 0, 1, 0.5)),
      CollageSlot(const Rect.fromLTRB(0, 0.5, 0.5, 1)),
      CollageSlot(const Rect.fromLTRB(0.5, 0.5, 1, 1)),
    ],
  ),
  // -- 1 big left + 2 small right (L-shape)
  CollageTemplate(
    name: 'L-Shape',
    icon: Icons.dashboard_rounded,
    slots: [
      CollageSlot(const Rect.fromLTRB(0, 0, 0.6, 1)),
      CollageSlot(const Rect.fromLTRB(0.6, 0, 1, 0.5)),
      CollageSlot(const Rect.fromLTRB(0.6, 0.5, 1, 1)),
    ],
  ),
  // -- 1 big top + 3 bottom strip
  CollageTemplate(
    name: 'Hero + Strip',
    icon: Icons.view_compact_rounded,
    slots: [
      CollageSlot(const Rect.fromLTRB(0, 0, 1, 0.6)),
      CollageSlot(const Rect.fromLTRB(0, 0.6, 0.333, 1)),
      CollageSlot(const Rect.fromLTRB(0.333, 0.6, 0.666, 1)),
      CollageSlot(const Rect.fromLTRB(0.666, 0.6, 1, 1)),
    ],
  ),
  // -- 3x3 grid
  CollageTemplate(
    name: '3×3 Grid',
    icon: Icons.apps_rounded,
    slots: [
      for (int r = 0; r < 3; r++)
        for (int c = 0; c < 3; c++)
          CollageSlot(Rect.fromLTRB(
            c / 3,
            r / 3,
            (c + 1) / 3,
            (r + 1) / 3,
          )),
    ],
  ),
  // -- Mosaic (mixed sizes)
  CollageTemplate(
    name: 'Mosaic',
    icon: Icons.auto_awesome_mosaic_rounded,
    slots: [
      CollageSlot(const Rect.fromLTRB(0, 0, 0.5, 0.6)),
      CollageSlot(const Rect.fromLTRB(0.5, 0, 1, 0.4)),
      CollageSlot(const Rect.fromLTRB(0.5, 0.4, 1, 1)),
      CollageSlot(const Rect.fromLTRB(0, 0.6, 0.3, 1)),
      CollageSlot(const Rect.fromLTRB(0.3, 0.6, 0.5, 1)),
    ],
  ),
  // -- Panorama strip (1 tall row of 4)
  CollageTemplate(
    name: 'Panorama',
    icon: Icons.panorama_rounded,
    slots: [
      CollageSlot(const Rect.fromLTRB(0, 0, 0.25, 1)),
      CollageSlot(const Rect.fromLTRB(0.25, 0, 0.5, 1)),
      CollageSlot(const Rect.fromLTRB(0.5, 0, 0.75, 1)),
      CollageSlot(const Rect.fromLTRB(0.75, 0, 1, 1)),
    ],
  ),
  // -- Cross / plus
  CollageTemplate(
    name: 'Cross',
    icon: Icons.add_rounded,
    slots: [
      CollageSlot(const Rect.fromLTRB(0.333, 0, 0.666, 0.333)),
      CollageSlot(const Rect.fromLTRB(0, 0.333, 0.333, 0.666)),
      CollageSlot(const Rect.fromLTRB(0.333, 0.333, 0.666, 0.666)),
      CollageSlot(const Rect.fromLTRB(0.666, 0.333, 1, 0.666)),
      CollageSlot(const Rect.fromLTRB(0.333, 0.666, 0.666, 1)),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Imported photo
// ---------------------------------------------------------------------------

class _ImportedPhoto {
  _ImportedPhoto({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

// ---------------------------------------------------------------------------
// Canvas aspect-ratio presets
// ---------------------------------------------------------------------------

enum _CanvasRatio {
  square('1 : 1', 1),
  landscape('4 : 3', 4 / 3),
  wide('16 : 9', 16 / 9),
  portrait('3 : 4', 3 / 4),
  tall('9 : 16', 9 / 16);

  const _CanvasRatio(this.label, this.value);
  final String label;
  final double value;
}

// ---------------------------------------------------------------------------
// Background color presets
// ---------------------------------------------------------------------------

enum _BgColor {
  white('White', Colors.white),
  black('Black', Colors.black),
  transparent('Transparent', Colors.transparent),
  dark('Dark', Color(0xFF1E1B28));

  const _BgColor(this.label, this.value);
  final String label;
  final Color value;
}

// ---------------------------------------------------------------------------
// Export isolate args
// ---------------------------------------------------------------------------

class _ExportArgs {
  const _ExportArgs({
    required this.photos,
    required this.slotAssignments,
    required this.templateSlots,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.gap,
    required this.bgColor,
    required this.borderRadius,
  });
  final List<Uint8List> photos;
  final Map<int, int> slotAssignments;
  final List<Rect> templateSlots;
  final int canvasWidth;
  final int canvasHeight;
  final int gap;
  final int bgColor;
  final int borderRadius;
}

// ---------------------------------------------------------------------------
// Main view
// ---------------------------------------------------------------------------

class CollageMakerView extends StatefulWidget {
  const CollageMakerView({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  State<CollageMakerView> createState() => _CollageMakerViewState();
}

class _CollageMakerViewState extends State<CollageMakerView> {
  final List<_ImportedPhoto> _photos = [];

  CollageTemplate _template = kTemplates[3]; // default: 2x2 grid

  /// Maps slot index → photo index.
  final Map<int, int> _slotAssignments = {};

  _CanvasRatio _ratio = _CanvasRatio.square;
  _BgColor _bgColor = _BgColor.white;
  double _gap = 6;
  double _borderRadius = 8;

  bool _exporting = false;
  String? _error;
  SaveResult? _result;

  Future<void> _importPhotos() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'png',
        'jpg',
        'jpeg',
        'bmp',
        'tif',
        'tiff',
        'webp'
      ],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      for (final f in result.files) {
        if (f.bytes != null) {
          _photos.add(_ImportedPhoto(name: f.name, bytes: f.bytes!));
        }
      }
    });
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
      // Remove assignments that pointed at this photo and shift indices.
      final updated = <int, int>{};
      for (final e in _slotAssignments.entries) {
        if (e.value == index) continue;
        updated[e.key] = e.value > index ? e.value - 1 : e.value;
      }
      _slotAssignments
        ..clear()
        ..addAll(updated);
    });
  }

  void _selectTemplate(CollageTemplate t) {
    setState(() {
      _template = t;
      _slotAssignments.clear();
    });
  }

  void _assignPhoto(int slotIndex, int photoIndex) {
    setState(() => _slotAssignments[slotIndex] = photoIndex);
  }

  void _clearSlot(int slotIndex) {
    setState(() => _slotAssignments.remove(slotIndex));
  }

  bool get _canExport =>
      _slotAssignments.isNotEmpty && _photos.isNotEmpty && !_exporting;

  Future<void> _export() async {
    setState(() {
      _exporting = true;
      _error = null;
      _result = null;
    });
    try {
      const outputW = 2400;
      final outputH = (outputW / _ratio.value).round();

      final args = _ExportArgs(
        photos: _photos.map((p) => p.bytes).toList(),
        slotAssignments: Map.of(_slotAssignments),
        templateSlots: _template.slots.map((s) => s.rect).toList(),
        canvasWidth: outputW,
        canvasHeight: outputH,
        gap: _gap.round(),
        bgColor: _bgColor.value.toARGB32(),
        borderRadius: _borderRadius.round(),
      );

      final png = await compute(_renderCollage, args);
      final save = await saveConvertedFile(
        bytes: png,
        suggestedName: 'collage.png',
        mimeType: 'image/png',
        extensions: ['png'],
      );
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _result = save;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _error = 'Export failed: $e';
      });
    }
  }

  static Uint8List _renderCollage(_ExportArgs args) {
    final w = args.canvasWidth;
    final h = args.canvasHeight;
    final gap = args.gap;

    final canvas = img.Image(width: w, height: h, numChannels: 4);

    // Fill background.
    final bg = img.ColorUint8.rgba(
      (args.bgColor >> 16) & 0xFF,
      (args.bgColor >> 8) & 0xFF,
      args.bgColor & 0xFF,
      (args.bgColor >> 24) & 0xFF,
    );
    img.fill(canvas, color: bg);

    for (final entry in args.slotAssignments.entries) {
      final slotIdx = entry.key;
      final photoIdx = entry.value;
      if (slotIdx >= args.templateSlots.length) continue;
      if (photoIdx >= args.photos.length) continue;

      final slotRect = args.templateSlots[slotIdx];
      final sx = (slotRect.left * w).round() + gap;
      final sy = (slotRect.top * h).round() + gap;
      final sw = ((slotRect.width) * w).round() - gap * 2;
      final sh = ((slotRect.height) * h).round() - gap * 2;
      if (sw <= 0 || sh <= 0) continue;

      var photo = img.decodeImage(args.photos[photoIdx]);
      if (photo == null) continue;

      // Cover-fit: scale so the photo fills the slot, then center-crop.
      final scaleX = sw / photo.width;
      final scaleY = sh / photo.height;
      final scale = scaleX > scaleY ? scaleX : scaleY;
      final scaledW = (photo.width * scale).round();
      final scaledH = (photo.height * scale).round();
      photo = img.copyResize(photo, width: scaledW, height: scaledH);

      final cropX = ((scaledW - sw) / 2).round();
      final cropY = ((scaledH - sh) / 2).round();
      photo = img.copyCrop(photo, x: cropX, y: cropY, width: sw, height: sh);

      // Ensure 4 channels for compositing.
      if (photo.numChannels < 4) {
        photo = photo.convert(numChannels: 4);
      }

      img.compositeImage(canvas, photo, dstX: sx, dstY: sy);
    }

    return img.encodePng(canvas);
  }

  void _reset() {
    setState(() {
      _photos.clear();
      _slotAssignments.clear();
      _template = kTemplates[3];
      _ratio = _CanvasRatio.square;
      _bgColor = _BgColor.white;
      _gap = 6;
      _borderRadius = 8;
      _error = null;
      _result = null;
    });
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    return ToolScaffold(
      icon: Icons.grid_view_rounded,
      title: 'Collage maker',
      subtitle: 'Create photo collages with templates',
      onBack: widget.onBack,
      children: [
        // -- Photo import zone / photo bar
        if (_photos.isEmpty)
          ConverterDropZone(
            onTap: _importPhotos,
            icon: Icons.add_photo_alternate_outlined,
            title: 'Import photos to get started',
            subtitle: 'PNG · JPG · BMP · TIFF · WEBP',
          )
        else ...[
          _PhotoBar(
            photos: _photos,
            onImportMore: _importPhotos,
            onRemove: _removePhoto,
          ),
          const SizedBox(height: 16),

          // -- Template picker
          _TemplatePicker(
            templates: kTemplates,
            selected: _template,
            onSelect: _selectTemplate,
          ),
          const SizedBox(height: 16),

          // -- Canvas
          _CollageCanvas(
            template: _template,
            photos: _photos,
            slotAssignments: _slotAssignments,
            ratio: _ratio.value,
            gap: _gap,
            borderRadius: _borderRadius,
            bgColor: _bgColor.value,
            onAssign: _assignPhoto,
            onClear: _clearSlot,
          ),
          const SizedBox(height: 16),

          // -- Settings
          _SettingsSection(
            ratio: _ratio,
            bgColor: _bgColor,
            gap: _gap,
            borderRadius: _borderRadius,
            onRatioChanged: (v) => setState(() => _ratio = v),
            onBgColorChanged: (v) => setState(() => _bgColor = v),
            onGapChanged: (v) => setState(() => _gap = v),
            onBorderRadiusChanged: (v) => setState(() => _borderRadius = v),
          ),
          const SizedBox(height: 20),

          // -- Actions
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ConverterPrimaryButton(
                  label: kIsWeb ? 'Download PNG' : 'Export PNG',
                  icon: Icons.download_rounded,
                  loading: _exporting,
                  onTap: _canExport ? _export : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ConverterPrimaryButton(
                  label: 'Reset',
                  icon: Icons.restart_alt_rounded,
                  loading: false,
                  onTap: _reset,
                ),
              ),
            ],
          ),
        ],

        // -- Error / success banners
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
            trailing: ConverterTextButton(label: 'New collage', onTap: _reset),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Photo sidebar / bar
// ---------------------------------------------------------------------------

class _PhotoBar extends StatelessWidget {
  const _PhotoBar({
    required this.photos,
    required this.onImportMore,
    required this.onRemove,
  });
  final List<_ImportedPhoto> photos;
  final VoidCallback onImportMore;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ConverterCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library_outlined,
                  color: luma.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Imported photos',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${photos.length} photo${photos.length == 1 ? '' : 's'}',
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                if (i == photos.length) {
                  return _AddMoreButton(onTap: onImportMore);
                }
                return _DraggablePhotoThumb(
                  index: i,
                  photo: photos[i],
                  onRemove: () => onRemove(i),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DraggablePhotoThumb extends StatefulWidget {
  const _DraggablePhotoThumb({
    required this.index,
    required this.photo,
    required this.onRemove,
  });
  final int index;
  final _ImportedPhoto photo;
  final VoidCallback onRemove;

  @override
  State<_DraggablePhotoThumb> createState() => _DraggablePhotoThumbState();
}

class _DraggablePhotoThumbState extends State<_DraggablePhotoThumb> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Draggable<int>(
      data: widget.index,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: luma.accent, width: 2),
            boxShadow: [
              BoxShadow(
                color: luma.accent.withValues(alpha: 0.35),
                blurRadius: 12,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(widget.photo.bytes,
                fit: BoxFit.cover, width: 72, height: 72),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _thumbBody(luma),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Stack(
          children: [
            _thumbBody(luma),
            if (_hovering)
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: widget.onRemove,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: luma.danger,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _thumbBody(LumaPalette luma) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _hovering ? luma.accent : luma.border,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.memory(widget.photo.bytes,
            fit: BoxFit.cover, width: 72, height: 72),
      ),
    );
  }
}

class _AddMoreButton extends StatefulWidget {
  const _AddMoreButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_AddMoreButton> createState() => _AddMoreButtonState();
}

class _AddMoreButtonState extends State<_AddMoreButton> {
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
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: _hovering ? luma.accentSubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovering ? luma.accent : luma.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: luma.accent, size: 22),
              const SizedBox(height: 2),
              Text(
                'Add',
                style: TextStyle(
                  color: luma.accent,
                  fontSize: 11,
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

// ---------------------------------------------------------------------------
// Template picker
// ---------------------------------------------------------------------------

class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({
    required this.templates,
    required this.selected,
    required this.onSelect,
  });
  final List<CollageTemplate> templates;
  final CollageTemplate selected;
  final ValueChanged<CollageTemplate> onSelect;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ConverterCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard_customize_outlined,
                  color: luma.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Choose a layout',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: templates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final t = templates[i];
                final active = t == selected;
                return _TemplateThumb(
                  template: t,
                  active: active,
                  onTap: () => onSelect(t),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateThumb extends StatefulWidget {
  const _TemplateThumb({
    required this.template,
    required this.active,
    required this.onTap,
  });
  final CollageTemplate template;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_TemplateThumb> createState() => _TemplateThumbState();
}

class _TemplateThumbState extends State<_TemplateThumb> {
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
          width: 90,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: active
                ? luma.accentSubtle
                : (_hovering ? luma.surfaceHover : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? luma.accent : luma.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CustomPaint(
                  painter: _TemplateMiniPainter(
                    slots: widget.template.slots,
                    fillColor: active ? luma.accent : luma.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.template.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? luma.accent : luma.textSecondary,
                  fontSize: 10,
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

/// Paints a miniature representation of a template's slot layout.
class _TemplateMiniPainter extends CustomPainter {
  _TemplateMiniPainter({required this.slots, required this.fillColor});
  final List<CollageSlot> slots;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 1.5;
    final paint = Paint()
      ..color = fillColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    for (final slot in slots) {
      final r = Rect.fromLTRB(
        slot.rect.left * size.width + gap,
        slot.rect.top * size.height + gap,
        slot.rect.right * size.width - gap,
        slot.rect.bottom * size.height - gap,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(3)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TemplateMiniPainter old) =>
      old.fillColor != fillColor || old.slots != slots;
}

// ---------------------------------------------------------------------------
// Collage canvas
// ---------------------------------------------------------------------------

class _CollageCanvas extends StatelessWidget {
  const _CollageCanvas({
    required this.template,
    required this.photos,
    required this.slotAssignments,
    required this.ratio,
    required this.gap,
    required this.borderRadius,
    required this.bgColor,
    required this.onAssign,
    required this.onClear,
  });
  final CollageTemplate template;
  final List<_ImportedPhoto> photos;
  final Map<int, int> slotAssignments;
  final double ratio;
  final double gap;
  final double borderRadius;
  final Color bgColor;
  final void Function(int slotIndex, int photoIndex) onAssign;
  final void Function(int slotIndex) onClear;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ConverterCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_size_select_large_rounded,
                  color: luma.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Canvas',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${template.slotCount} slots · ${slotAssignments.length} filled',
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: ratio,
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor == Colors.transparent
                      ? null
                      : bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: bgColor == Colors.transparent
                    ? CustomPaint(
                        painter: _CheckerboardPainter(),
                        child: _buildSlots(luma),
                      )
                    : _buildSlots(luma),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlots(LumaPalette luma) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: [
            for (int i = 0; i < template.slots.length; i++)
              _buildSlot(i, template.slots[i], w, h, luma),
          ],
        );
      },
    );
  }

  Widget _buildSlot(
      int i, CollageSlot slot, double canvasW, double canvasH, LumaPalette luma) {
    final r = slot.rect;
    final left = r.left * canvasW + gap;
    final top = r.top * canvasH + gap;
    final width = r.width * canvasW - gap * 2;
    final height = r.height * canvasH - gap * 2;

    final photoIdx = slotAssignments[i];
    final hasPhoto = photoIdx != null && photoIdx < photos.length;

    return Positioned(
      left: left,
      top: top,
      width: width.clamp(0, double.infinity),
      height: height.clamp(0, double.infinity),
      child: DragTarget<int>(
        onAcceptWithDetails: (details) => onAssign(i, details.data),
        builder: (context, candidateData, rejectedData) {
          final isHoveredOver = candidateData.isNotEmpty;
          return GestureDetector(
            onDoubleTap: hasPhoto ? () => onClear(i) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: hasPhoto
                    ? Colors.transparent
                    : (isHoveredOver
                        ? luma.accentSubtle
                        : luma.surface.withValues(alpha: 0.7)),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: isHoveredOver
                      ? luma.accent
                      : (hasPhoto ? Colors.transparent : luma.border),
                  width: isHoveredOver ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                    borderRadius > 1 ? borderRadius - 1 : 0),
                child: hasPhoto
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(
                            photos[photoIdx].bytes,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                          if (isHoveredOver)
                            Container(
                              color: luma.accent.withValues(alpha: 0.3),
                              child: Center(
                                child: Icon(Icons.swap_horiz_rounded,
                                    color: Colors.white, size: 28),
                              ),
                            ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isHoveredOver
                                  ? Icons.add_photo_alternate_rounded
                                  : Icons.add_rounded,
                              color: isHoveredOver
                                  ? luma.accent
                                  : luma.textMuted,
                              size: 22,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isHoveredOver ? 'Drop here' : 'Drag photo',
                              style: TextStyle(
                                color: isHoveredOver
                                    ? luma.accent
                                    : luma.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings section
// ---------------------------------------------------------------------------

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.ratio,
    required this.bgColor,
    required this.gap,
    required this.borderRadius,
    required this.onRatioChanged,
    required this.onBgColorChanged,
    required this.onGapChanged,
    required this.onBorderRadiusChanged,
  });
  final _CanvasRatio ratio;
  final _BgColor bgColor;
  final double gap;
  final double borderRadius;
  final ValueChanged<_CanvasRatio> onRatioChanged;
  final ValueChanged<_BgColor> onBgColorChanged;
  final ValueChanged<double> onGapChanged;
  final ValueChanged<double> onBorderRadiusChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ConverterCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: luma.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Settings',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Aspect ratio
          _SettingRow(
            label: 'Aspect ratio',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in _CanvasRatio.values)
                  _OptionChip(
                    label: r.label,
                    active: ratio == r,
                    onTap: () => onRatioChanged(r),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Background color
          _SettingRow(
            label: 'Background',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final bg in _BgColor.values)
                  _OptionChip(
                    label: bg.label,
                    active: bgColor == bg,
                    onTap: () => onBgColorChanged(bg),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Gap slider
          _SettingSlider(
            label: 'Gap',
            value: gap,
            min: 0,
            max: 24,
            display: '${gap.round()}px',
            onChanged: onGapChanged,
          ),
          const SizedBox(height: 8),

          // Border radius slider
          _SettingSlider(
            label: 'Radius',
            value: borderRadius,
            min: 0,
            max: 32,
            display: '${borderRadius.round()}px',
            onChanged: onBorderRadiusChanged,
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: luma.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _OptionChip extends StatefulWidget {
  const _OptionChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_OptionChip> createState() => _OptionChipState();
}

class _OptionChipState extends State<_OptionChip> {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? luma.accentSubtle
                : (_hovering ? luma.surfaceHover : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? luma.accent : luma.border),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: active ? luma.accent : luma.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingSlider extends StatelessWidget {
  const _SettingSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 12.5,
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
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            display,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Checkerboard painter (for transparent bg preview)
// ---------------------------------------------------------------------------

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cellSize = 14.0;
    final paint = Paint();
    for (var y = 0.0; y < size.height; y += cellSize) {
      for (var x = 0.0; x < size.width; x += cellSize) {
        final row = (y / cellSize).floor();
        final col = (x / cellSize).floor();
        paint.color = (row + col).isEven
            ? const Color(0xFFFFFFFF)
            : const Color(0xFFE0E0E0);
        canvas.drawRect(Rect.fromLTWH(x, y, cellSize, cellSize), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
