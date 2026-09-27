import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../theme/luma_theme.dart';
import 'studio_controller.dart';
import 'studio_widgets.dart';

/// Colour picker: a hue ring around a saturation/brightness square, HSB and
/// RGB sliders, hex entry, palettes and the recently used colours.
class ColorPanel extends StatefulWidget {
  const ColorPanel({super.key, required this.controller, this.onClose});

  final StudioController controller;
  final VoidCallback? onClose;

  @override
  State<ColorPanel> createState() => _ColorPanelState();
}

enum _ColorTab { wheel, sliders, palettes }

class _ColorPanelState extends State<ColorPanel> {
  late HSVColor _hsv = HSVColor.fromColor(widget.controller.color);
  late final Color _original = widget.controller.color;
  final _hex = TextEditingController();
  final _hexFocus = FocusNode();
  _ColorTab _tab = _ColorTab.wheel;

  StudioController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _hex.text = _hexOf(c.color);
    c.addListener(_sync);
  }

  @override
  void dispose() {
    c.removeListener(_sync);
    _hex.dispose();
    _hexFocus.dispose();
    super.dispose();
  }

  /// Follows colour changes made elsewhere (eyedropper, swap), keeping the
  /// hue we had when the new colour is a grey and has none of its own.
  void _sync() {
    if (!mounted) return;
    if (_hsv.toColor().toARGB32() == c.color.toARGB32()) return;
    final next = HSVColor.fromColor(c.color);
    setState(() {
      _hsv = next.saturation == 0 || next.value == 0 ? next.withHue(_hsv.hue) : next;
      if (!_hexFocus.hasFocus) _hex.text = _hexOf(c.color);
    });
  }

  void _set(HSVColor hsv) {
    setState(() => _hsv = hsv);
    c.setColor(hsv.toColor());
    if (!_hexFocus.hasFocus) _hex.text = _hexOf(hsv.toColor());
  }

  static String _hexOf(Color color) =>
      (color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  void _applyHex(String text) {
    final cleaned = text.replaceAll('#', '').trim();
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleaned) && !RegExp(r'^[0-9a-fA-F]{3}$').hasMatch(cleaned)) {
      _hex.text = _hexOf(c.color);
      return;
    }
    final full = cleaned.length == 3 ? cleaned.split('').map((ch) => '$ch$ch').join() : cleaned;
    final color = Color(0xFF000000 | int.parse(full, radix: 16));
    _set(HSVColor.fromColor(color));
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return StudioPanel(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(
            title: 'Colour',
            onClose: widget.onClose,
            trailing: [
              _SwatchPair(
                current: _hsv.toColor(),
                previous: _original,
                onPrevious: () => _set(HSVColor.fromColor(_original)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<_ColorTab>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: _ColorTab.wheel, label: Text('Wheel')),
              ButtonSegment(value: _ColorTab.sliders, label: Text('Sliders')),
              ButtonSegment(value: _ColorTab.palettes, label: Text('Palettes')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          const SizedBox(height: 10),
          switch (_tab) {
            _ColorTab.wheel => Center(
                child: _HueRingPicker(hsv: _hsv, size: 250, onChanged: _set),
              ),
            _ColorTab.sliders => _Sliders(hsv: _hsv, onChanged: _set),
            _ColorTab.palettes => _Palettes(controller: c, current: _hsv.toColor(), onPick: (color) => _set(HSVColor.fromColor(color))),
          },
          const SizedBox(height: 10),
          Row(
            children: [
              Text('#', style: TextStyle(color: luma.textMuted, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              SizedBox(
                width: 92,
                child: TextField(
                  controller: _hex,
                  focusNode: _hexFocus,
                  maxLength: 6,
                  style: TextStyle(color: luma.textPrimary, fontSize: 13, letterSpacing: 0.5),
                  decoration: const InputDecoration(isDense: true, counterText: '', hintText: 'RRGGBB'),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F#]'))],
                  onSubmitted: _applyHex,
                  onTapOutside: (_) {
                    if (_hexFocus.hasFocus) {
                      _applyHex(_hex.text);
                      _hexFocus.unfocus();
                    }
                  },
                ),
              ),
              const Spacer(),
              StudioIconButton(
                icon: Icons.swap_horiz_rounded,
                tooltip: 'Swap with secondary colour (X)',
                size: 34,
                onTap: c.swapColors,
              ),
              ColorDot(color: c.secondary, size: 22, tooltip: 'Secondary colour', onTap: c.swapColors),
            ],
          ),
          if (c.recentColors.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Recent', style: TextStyle(color: luma.textMuted, fontSize: 11.5)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final color in c.recentColors.take(16))
                  ColorDot(
                    color: color,
                    size: 24,
                    selected: color.toARGB32() == c.color.toARGB32(),
                    onTap: () => _set(HSVColor.fromColor(color)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SwatchPair extends StatelessWidget {
  const _SwatchPair({required this.current, required this.previous, required this.onPrevious});

  final Color current;
  final Color previous;
  final VoidCallback onPrevious;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Tooltip(
      message: 'Left: new colour · right: tap to go back to the colour you started with',
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: luma.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Container(width: 30, height: 22, color: current),
            GestureDetector(onTap: onPrevious, child: Container(width: 30, height: 22, color: previous)),
          ],
        ),
      ),
    );
  }
}

class _HueRingPicker extends StatefulWidget {
  const _HueRingPicker({required this.hsv, required this.size, required this.onChanged});

  final HSVColor hsv;
  final double size;
  final ValueChanged<HSVColor> onChanged;

  @override
  State<_HueRingPicker> createState() => _HueRingPickerState();
}

class _HueRingPickerState extends State<_HueRingPicker> {
  bool _dragRing = false;

  double get _ring => widget.size * 0.1;
  double get _radius => widget.size / 2;
  double get _square => (_radius - _ring - 8) * math.sqrt2;

  void _handle(Offset local, {required bool start}) {
    final center = Offset(_radius, _radius);
    final d = local - center;
    if (start) _dragRing = d.distance > _radius - _ring - 4;
    if (_dragRing) {
      final hue = (d.direction * 180 / math.pi + 360) % 360;
      widget.onChanged(widget.hsv.withHue(hue));
    } else {
      final half = _square / 2;
      final s = ((d.dx + half) / _square).clamp(0.0, 1.0);
      final v = (1 - (d.dy + half) / _square).clamp(0.0, 1.0);
      widget.onChanged(widget.hsv.withSaturation(s).withValue(v));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) => _handle(d.localPosition, start: true),
      onPanUpdate: (d) => _handle(d.localPosition, start: false),
      onTapDown: (d) => _handle(d.localPosition, start: true),
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _HueRingPainter(hsv: widget.hsv, ring: _ring, square: _square),
      ),
    );
  }
}

class _HueRingPainter extends CustomPainter {
  _HueRingPainter({required this.hsv, required this.ring, required this.square});

  final HSVColor hsv;
  final double ring;
  final double square;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final ringRect = Rect.fromCircle(center: center, radius: radius - ring / 2);
    canvas.drawCircle(
      center,
      radius - ring / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring
        ..shader = SweepGradient(
          colors: [
            for (var h = 0; h <= 360; h += 30) HSVColor.fromAHSV(1, h % 360, 1, 1).toColor(),
          ],
        ).createShader(ringRect),
    );

    final hueAngle = hsv.hue * math.pi / 180;
    final knob = center + Offset.fromDirection(hueAngle, radius - ring / 2);
    canvas.drawCircle(knob, ring / 2 + 1, Paint()..color = Colors.white);
    canvas.drawCircle(knob, ring / 2 - 2, Paint()..color = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor());

    final rect = Rect.fromCenter(center: center, width: square, height: square);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(rect, Paint()..color = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor());
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(colors: [Colors.white, Color(0x00FFFFFF)]).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Colors.black],
        ).createShader(rect),
    );
    canvas.restore();

    final point = Offset(rect.left + hsv.saturation * square, rect.top + (1 - hsv.value) * square);
    canvas.drawCircle(point, 8, Paint()..color = Colors.white);
    canvas.drawCircle(point, 6, Paint()..color = hsv.toColor());
    canvas.drawCircle(
      point,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x55000000),
    );
  }

  @override
  bool shouldRepaint(_HueRingPainter old) => old.hsv != hsv || old.square != square;
}

class _Sliders extends StatelessWidget {
  const _Sliders({required this.hsv, required this.onChanged});

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = hsv.toColor();
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    Color rgb(int r, int g, int b) => Color.fromARGB(255, r, g, b);
    void setRgb(Color next) {
      final n = HSVColor.fromColor(next);
      onChanged(n.saturation == 0 ? n.withHue(hsv.hue) : n);
    }

    return Column(
      children: [
        _GradientSlider(
          label: 'H',
          value: hsv.hue / 360,
          display: '${hsv.hue.round()}°',
          colors: [for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h % 360, 1, 1).toColor()],
          onChanged: (t) => onChanged(hsv.withHue((t * 360).clamp(0, 359.9))),
        ),
        _GradientSlider(
          label: 'S',
          value: hsv.saturation,
          display: '${(hsv.saturation * 100).round()}%',
          colors: [hsv.withSaturation(0).toColor(), hsv.withSaturation(1).toColor()],
          onChanged: (t) => onChanged(hsv.withSaturation(t)),
        ),
        _GradientSlider(
          label: 'B',
          value: hsv.value,
          display: '${(hsv.value * 100).round()}%',
          colors: [Colors.black, hsv.withValue(1).toColor()],
          onChanged: (t) => onChanged(hsv.withValue(t)),
        ),
        const SizedBox(height: 6),
        _GradientSlider(
          label: 'R',
          value: r / 255,
          display: '$r',
          colors: [rgb(0, g, b), rgb(255, g, b)],
          onChanged: (t) => setRgb(rgb((t * 255).round(), g, b)),
        ),
        _GradientSlider(
          label: 'G',
          value: g / 255,
          display: '$g',
          colors: [rgb(r, 0, b), rgb(r, 255, b)],
          onChanged: (t) => setRgb(rgb(r, (t * 255).round(), b)),
        ),
        _GradientSlider(
          label: 'B',
          value: b / 255,
          display: '$b',
          colors: [rgb(r, g, 0), rgb(r, g, 255)],
          onChanged: (t) => setRgb(rgb(r, g, (t * 255).round())),
        ),
      ],
    );
  }
}

class _GradientSlider extends StatelessWidget {
  const _GradientSlider({
    required this.label,
    required this.value,
    required this.display,
    required this.colors,
    required this.onChanged,
  });

  final String label;
  final double value;
  final String display;
  final List<Color> colors;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: Text(label, style: TextStyle(color: luma.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                void update(Offset local) => onChanged((local.dx / width).clamp(0.0, 1.0));
                return GestureDetector(
                  onTapDown: (d) => update(d.localPosition),
                  onHorizontalDragUpdate: (d) => update(d.localPosition),
                  onHorizontalDragStart: (d) => update(d.localPosition),
                  child: SizedBox(
                    height: 22,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 14,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            gradient: LinearGradient(colors: colors),
                            border: Border.all(color: luma.border),
                          ),
                        ),
                        Positioned(
                          left: (value.clamp(0.0, 1.0) * width) - 7,
                          child: Container(
                            width: 14,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(5),
                              boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 3)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              display,
              textAlign: TextAlign.right,
              style: TextStyle(color: luma.textMuted, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _Palettes extends StatelessWidget {
  const _Palettes({required this.controller, required this.current, required this.onPick});

  final StudioController controller;
  final Color current;
  final ValueChanged<Color> onPick;

  static const builtIn = <(String, List<int>)>[
    ('Basics', [
      0xFF000000, 0xFF3A3A3A, 0xFF7A7A7A, 0xFFBDBDBD, 0xFFFFFFFF, 0xFFE53935, 0xFFFB8C00, 0xFFFDD835,
      0xFF43A047, 0xFF00ACC1, 0xFF1E88E5, 0xFF3949AB, 0xFF8E24AA, 0xFFD81B60, 0xFF6D4C41, 0xFF2B2440,
    ]),
    ('Skin tones', [
      0xFFFFE0CC, 0xFFF9D2B6, 0xFFF1C27D, 0xFFE0AC69, 0xFFD2996C, 0xFFC68642, 0xFFA86B3C, 0xFF8D5524,
      0xFF6F4125, 0xFF4E2A18, 0xFFF4B6A3, 0xFFE89B8A, 0xFFB5655A, 0xFF7A3E36,
    ]),
    ('Nature', [
      0xFF1B4332, 0xFF2D6A4F, 0xFF40916C, 0xFF74C69D, 0xFFB7E4C7, 0xFF7F5539, 0xFF9C6644, 0xFFB08968,
      0xFFDDB892, 0xFF023E8A, 0xFF0077B6, 0xFF48CAE4, 0xFFADE8F4, 0xFFF4A261, 0xFFE76F51, 0xFF264653,
    ]),
    ('Pastel', [
      0xFFFFADAD, 0xFFFFD6A5, 0xFFFDFFB6, 0xFFCAFFBF, 0xFF9BF6FF, 0xFFA0C4FF, 0xFFBDB2FF, 0xFFFFC6FF,
      0xFFFFF1E6, 0xFFE2ECE9, 0xFFDFE7FD, 0xFFF0EFEB,
    ]),
    ('Greys', [
      0xFF000000, 0xFF1A1A1A, 0xFF333333, 0xFF4D4D4D, 0xFF666666, 0xFF808080, 0xFF999999, 0xFFB3B3B3,
      0xFFCCCCCC, 0xFFE6E6E6, 0xFFF2F2F2, 0xFFFFFFFF,
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    Widget swatches(List<Color> colors, {bool removable = false}) => Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (final color in colors)
              ColorDot(
                color: color,
                size: 26,
                selected: color.toARGB32() == current.toARGB32(),
                onTap: () => onPick(color),
                onLongPress: removable ? () => controller.removeFromPalette(color) : null,
                tooltip: removable ? 'Long-press or right-click to remove' : null,
              ),
          ],
        );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('My palette', style: TextStyle(color: luma.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                TextButton.icon(
                  onPressed: () => controller.addToPalette(current),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add colour'),
                ),
              ],
            ),
            if (controller.palette.isEmpty)
              Text(
                'Save colours you reuse here.',
                style: TextStyle(color: luma.textMuted, fontSize: 11.5),
              )
            else
              swatches(controller.palette, removable: true),
            for (final (name, colors) in builtIn) ...[
              const SizedBox(height: 12),
              Text(name, style: TextStyle(color: luma.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              swatches([for (final v in colors) Color(v)]),
            ],
          ],
        ),
      ),
    );
  }
}
