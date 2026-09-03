import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'calc_expression.dart';
import 'calculator_store.dart';

/// Colours handed out to new curves, in order, so two functions never come out
/// the same until you've plotted eight of them.
const graphColors = <int>[
  0xFF7C5AD9,
  0xFF2F80ED,
  0xFF00B8A9,
  0xFF12A372,
  0xFFF5A623,
  0xFFE5484D,
  0xFFF25F9C,
  0xFF5D6470,
];

/// The next colour not already in use.
int nextGraphColor(List<GraphFunction> existing) {
  for (final color in graphColors) {
    if (!existing.any((f) => f.color == color)) return color;
  }
  return graphColors[existing.length % graphColors.length];
}

/// The plotting half of the advanced calculator: a pannable, zoomable set of
/// axes with every visible function drawn on it, the list of those functions
/// underneath, and a tap-to-trace readout.
class GraphPanel extends StatefulWidget {
  const GraphPanel({super.key, required this.store});

  final CalculatorStore store;

  @override
  State<GraphPanel> createState() => _GraphPanelState();
}

class _GraphPanelState extends State<GraphPanel> {
  static const _initialWindow = _Window(-10, 10, -10, 10);

  _Window _window = _initialWindow;
  Size _plotSize = const Size(1, 1);
  double? _traceX;

  double _lastScale = 1;

  // Parsing is far more expensive than evaluating, so each expression is
  // compiled once and reused for every pixel column and every frame.
  final Map<String, CalcExpression?> _compiled = {};

  CalcExpression? _expressionFor(String source) {
    if (_compiled.containsKey(source)) return _compiled[source];
    final parsed = CalcExpression.tryParse(source);
    _compiled[source] = parsed;
    if (_compiled.length > 64) _compiled.remove(_compiled.keys.first);
    return parsed;
  }

  void _zoom(double factor, {Offset? focus}) {
    final point = focus ?? Offset(_plotSize.width / 2, _plotSize.height / 2);
    setState(() {
      _window = _window.zoomAt(
        factor,
        _window.xAt(point.dx, _plotSize.width),
        _window.yAt(point.dy, _plotSize.height),
      );
    });
  }

  void _reset() => setState(() {
        _window = _initialWindow;
        _traceX = null;
      });

  void _onScaleStart(ScaleStartDetails details) => _lastScale = 1;

  void _onScaleUpdate(ScaleUpdateDetails details) {
    var next = _window.translate(
      -details.focalPointDelta.dx * _window.width / _plotSize.width,
      details.focalPointDelta.dy * _window.height / _plotSize.height,
    );
    if (details.scale != 1 && details.pointerCount > 1) {
      final factor = _lastScale / details.scale;
      _lastScale = details.scale;
      next = next.zoomAt(
        factor,
        next.xAt(details.localFocalPoint.dx, _plotSize.width),
        next.yAt(details.localFocalPoint.dy, _plotSize.height),
      );
    }
    setState(() => _window = next);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    _zoom(
      event.scrollDelta.dy > 0 ? 1.15 : 1 / 1.15,
      focus: event.localPosition,
    );
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final store = widget.store;
    final functions = store.functions;
    final drawable = <_Curve>[
      for (final function in functions)
        if (function.visible)
          if (_expressionFor(function.expression) case final parsed?)
            _Curve(parsed, Color(function.color)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: LumaCard(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                _GraphToolbar(
                  degrees: store.degrees,
                  onToggleAngle: () => store.setDegrees(!store.degrees),
                  onZoomIn: () => _zoom(1 / 1.4),
                  onZoomOut: () => _zoom(1.4),
                  onReset: _reset,
                  window: _window,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _plotSize =
                            Size(constraints.maxWidth, constraints.maxHeight);
                        return Listener(
                          onPointerSignal: _onPointerSignal,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onScaleStart: _onScaleStart,
                            onScaleUpdate: _onScaleUpdate,
                            onTapUp: (details) => setState(
                              () => _traceX = _window.xAt(
                                details.localPosition.dx,
                                _plotSize.width,
                              ),
                            ),
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: _GraphPainter(
                                window: _window,
                                curves: drawable,
                                degrees: store.degrees,
                                ans: store.lastAnswer,
                                traceX: _traceX,
                                grid: luma.border,
                                axis: luma.textMuted,
                                label: luma.textMuted,
                                background: luma.background,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (_traceX != null) ...[
                  const SizedBox(height: 8),
                  _TraceReadout(
                    x: _traceX!,
                    functions: functions,
                    resolve: _expressionFor,
                    degrees: store.degrees,
                    ans: store.lastAnswer,
                    onClear: () => setState(() => _traceX = null),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _FunctionList(store: store),
      ],
    );
  }
}

/// Zoom controls and the angle mode. The mode sits here as well as in the
/// header because it's on the graph that it bites: sin x drawn in degrees is a
/// nearly flat line, and this is where you'd notice and want to change it.
class _GraphToolbar extends StatelessWidget {
  const _GraphToolbar({
    required this.degrees,
    required this.onToggleAngle,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
    required this.window,
  });

  final bool degrees;
  final VoidCallback onToggleAngle;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;
  final _Window window;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        const SizedBox(width: 4),
        Icon(Icons.show_chart_rounded, size: 16, color: luma.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'x ${formatCalcNumber(window.minX)} … ${formatCalcNumber(window.maxX)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: luma.textMuted, fontSize: 11.5),
          ),
        ),
        Tooltip(
          message: degrees ? 'Switch to radians' : 'Switch to degrees',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onToggleAngle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Text(
                degrees ? 'DEG' : 'RAD',
                style: TextStyle(
                  color: luma.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
        _ToolbarButton(
          icon: Icons.zoom_in_rounded,
          tooltip: 'Zoom in',
          onTap: onZoomIn,
        ),
        _ToolbarButton(
          icon: Icons.zoom_out_rounded,
          tooltip: 'Zoom out',
          onTap: onZoomOut,
        ),
        _ToolbarButton(
          icon: Icons.center_focus_strong_rounded,
          tooltip: 'Reset view',
          onTap: onReset,
        ),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
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
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: luma.textSecondary),
        ),
      ),
    );
  }
}

/// What every visible curve is worth at the traced x.
class _TraceReadout extends StatelessWidget {
  const _TraceReadout({
    required this.x,
    required this.functions,
    required this.resolve,
    required this.degrees,
    required this.ans,
    required this.onClear,
  });

  final double x;
  final List<GraphFunction> functions;
  final CalcExpression? Function(String) resolve;
  final bool degrees;
  final double ans;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final chips = <Widget>[];
    for (var i = 0; i < functions.length; i++) {
      final function = functions[i];
      if (!function.visible) continue;
      final parsed = resolve(function.expression);
      if (parsed == null) continue;
      String value;
      try {
        value = formatCalcNumber(
          parsed.evaluate(x: x, ans: ans, degrees: degrees),
        );
      } on CalcException {
        value = 'Undefined';
      }
      chips.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Color(function.color),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'y${i + 1} = $value',
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: luma.surfaceHover,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'x = ${formatCalcNumber(x)}',
                  style: TextStyle(
                    color: luma.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                ...chips,
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear trace',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 16, color: luma.textMuted),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

/// The y₁ / y₂ / y₃ list under the plot: tap a row to edit it, the dot to hide
/// it, the bin to drop it.
class _FunctionList extends StatelessWidget {
  const _FunctionList({required this.store});

  final CalculatorStore store;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final functions = store.functions;
    return LumaCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'Functions',
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => showFunctionEditor(context, store),
                icon: Icon(Icons.add_rounded, size: 16, color: luma.accent),
                label: Text(
                  'Add',
                  style: TextStyle(
                    color: luma.accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (functions.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 6, 4),
              child: Text(
                'Nothing plotted yet. Type something with an x — like x^2 - 3 '
                'or sin(x) — and press Plot.',
                style: TextStyle(color: luma.textMuted, fontSize: 12.5),
              ),
            )
          else
            for (var i = 0; i < functions.length; i++)
              _FunctionRow(
                index: i,
                function: functions[i],
                store: store,
              ),
        ],
      ),
    );
  }
}

class _FunctionRow extends StatelessWidget {
  const _FunctionRow({
    required this.index,
    required this.function,
    required this.store,
  });

  final int index;
  final GraphFunction function;
  final CalculatorStore store;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final valid = CalcExpression.tryParse(function.expression) != null;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => showFunctionEditor(context, store, existing: function),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: function.visible ? 'Hide' : 'Show',
              visualDensity: VisualDensity.compact,
              onPressed: () => store.toggleFunction(function.id),
              icon: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: function.visible
                      ? Color(function.color)
                      : Colors.transparent,
                  border: Border.all(color: Color(function.color), width: 2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Text(
              'y${index + 1} =',
              style: TextStyle(
                color: luma.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                function.expression,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: valid ? luma.textPrimary : luma.danger,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              onPressed: () => store.removeFunction(function.id),
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: luma.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add or edit a plotted function, refusing to save anything the parser can't
/// read so a broken curve never reaches the canvas.
Future<void> showFunctionEditor(
  BuildContext context,
  CalculatorStore store, {
  GraphFunction? existing,
  String? initialExpression,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _FunctionDialog(
      store: store,
      existing: existing,
      initialExpression: initialExpression,
    ),
  );
}

class _FunctionDialog extends StatefulWidget {
  const _FunctionDialog({
    required this.store,
    this.existing,
    this.initialExpression,
  });

  final CalculatorStore store;
  final GraphFunction? existing;
  final String? initialExpression;

  @override
  State<_FunctionDialog> createState() => _FunctionDialogState();
}

class _FunctionDialogState extends State<_FunctionDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.existing?.expression ?? widget.initialExpression ?? '',
  );
  late int _color = widget.existing?.color ??
      nextGraphColor(widget.store.functions);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Type a function of x first.');
      return;
    }
    try {
      CalcExpression.parse(text);
    } on CalcException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    final existing = widget.existing;
    if (existing == null) {
      if (widget.store.addFunction(text, _color) == null) {
        setState(() => _error = 'Local storage is full, so this was not saved.');
        return;
      }
    } else {
      widget.store.editFunction(existing.id, expression: text, color: _color);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AlertDialog(
      backgroundColor: luma.surface,
      title: Text(
        widget.existing == null ? 'Plot a function' : 'Edit function',
        style: TextStyle(color: luma.textPrimary, fontSize: 16),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'y = ',
                  style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    style: TextStyle(color: luma.textPrimary),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    onSubmitted: (_) => _save(),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'x^2 - 3',
                      hintStyle:
                          TextStyle(color: luma.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: luma.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: luma.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: luma.accent),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Colour',
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in graphColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = value),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(value),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: _color == value
                              ? luma.textPrimary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: luma.danger, fontSize: 12.5),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () {
              widget.store.removeFunction(widget.existing!.id);
              Navigator.of(context).pop();
            },
            child: Text('Delete', style: TextStyle(color: luma.danger)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
        ),
        TextButton(
          onPressed: _save,
          child: Text(
            widget.existing == null ? 'Plot' : 'Save',
            style: TextStyle(color: luma.accent),
          ),
        ),
      ],
    );
  }
}

// ---- Painting --------------------------------------------------------------

/// The visible slice of the plane, in graph units.
class _Window {
  const _Window(this.minX, this.maxX, this.minY, this.maxY);

  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  double get width => maxX - minX;
  double get height => maxY - minY;

  double screenX(double x, double pixels) => (x - minX) / width * pixels;
  double screenY(double y, double pixels) => (maxY - y) / height * pixels;
  double xAt(double screen, double pixels) => minX + screen / pixels * width;
  double yAt(double screen, double pixels) => maxY - screen / pixels * height;

  _Window translate(double dx, double dy) =>
      _Window(minX + dx, maxX + dx, minY + dy, maxY + dy);

  /// Scales the window by [factor] while keeping ([fx], [fy]) under the same
  /// pixel, clamped so a runaway pinch can't zoom past what a double can hold.
  _Window zoomAt(double factor, double fx, double fy) {
    final nextWidth = width * factor;
    final nextHeight = height * factor;
    if (nextWidth < 1e-9 || nextWidth > 1e12) return this;
    if (nextHeight < 1e-9 || nextHeight > 1e12) return this;
    return _Window(
      fx + (minX - fx) * factor,
      fx + (maxX - fx) * factor,
      fy + (minY - fy) * factor,
      fy + (maxY - fy) * factor,
    );
  }
}

class _Curve {
  const _Curve(this.expression, this.color);
  final CalcExpression expression;
  final Color color;
}

class _GraphPainter extends CustomPainter {
  const _GraphPainter({
    required this.window,
    required this.curves,
    required this.degrees,
    required this.ans,
    required this.traceX,
    required this.grid,
    required this.axis,
    required this.label,
    required this.background,
  });

  final _Window window;
  final List<_Curve> curves;
  final bool degrees;
  final double ans;
  final double? traceX;
  final Color grid;
  final Color axis;
  final Color label;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    _paintGrid(canvas, size);
    for (final curve in curves) {
      _paintCurve(canvas, size, curve);
    }
    _paintTrace(canvas, size);
  }

  void _paintGrid(Canvas canvas, Size size) {
    final stepX = _niceStep(window.width, size.width / 90);
    final stepY = _niceStep(window.height, size.height / 70);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = axis
      ..strokeWidth = 1.6;

    for (var i = (window.minX / stepX).ceil();
        i * stepX <= window.maxX;
        i++) {
      final value = i * stepX;
      final x = window.screenX(value, size.width);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var i = (window.minY / stepY).ceil();
        i * stepY <= window.maxY;
        i++) {
      final value = i * stepY;
      final y = window.screenY(value, size.height);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Axes, pinned to the edge when the origin is scrolled out of view so the
    // number strip never disappears entirely.
    final axisY = window.screenY(0, size.height).clamp(0.0, size.height);
    final axisX = window.screenX(0, size.width).clamp(0.0, size.width);
    canvas.drawLine(Offset(0, axisY), Offset(size.width, axisY), axisPaint);
    canvas.drawLine(Offset(axisX, 0), Offset(axisX, size.height), axisPaint);

    for (var i = (window.minX / stepX).ceil();
        i * stepX <= window.maxX;
        i++) {
      final value = i * stepX;
      if (value == 0) continue;
      _paintLabel(
        canvas,
        formatCalcNumber(value),
        Offset(window.screenX(value, size.width) + 3, axisY + 3),
        size,
      );
    }
    for (var i = (window.minY / stepY).ceil();
        i * stepY <= window.maxY;
        i++) {
      final value = i * stepY;
      if (value == 0) continue;
      _paintLabel(
        canvas,
        formatCalcNumber(value),
        Offset(axisX + 4, window.screenY(value, size.height) + 2),
        size,
      );
    }
  }

  void _paintLabel(Canvas canvas, String text, Offset at, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: label, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = at.dx.clamp(0.0, math.max<double>(0, size.width - painter.width));
    final dy =
        at.dy.clamp(0.0, math.max<double>(0, size.height - painter.height));
    painter.paint(canvas, Offset(dx, dy));
  }

  void _paintCurve(Canvas canvas, Size size, _Curve curve) {
    final paint = Paint()
      ..color = curve.color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    var started = false;
    double? previousY;
    // Well off-screen is far enough: keeping the path near the canvas avoids
    // handing the rasteriser coordinates in the billions near an asymptote.
    final limit = size.height * 8;

    for (var px = 0.0; px <= size.width; px += 1) {
      final x = window.xAt(px, size.width);
      double value;
      try {
        value = curve.expression.evaluate(x: x, ans: ans, degrees: degrees);
      } on CalcException {
        value = double.nan;
      }
      if (!value.isFinite) {
        started = false;
        previousY = null;
        continue;
      }
      final y = window.screenY(value, size.height).clamp(-limit, limit);
      // A jump bigger than several screens is a vertical asymptote, not a
      // line: break the stroke instead of drawing through it (tan x, 1/x).
      if (started && previousY != null && (y - previousY).abs() > limit / 2) {
        started = false;
      }
      if (started) {
        path.lineTo(px, y);
      } else {
        path.moveTo(px, y);
        started = true;
      }
      previousY = y;
    }
    canvas.drawPath(path, paint);
  }

  void _paintTrace(Canvas canvas, Size size) {
    final x = traceX;
    if (x == null) return;
    final px = window.screenX(x, size.width);
    if (px < 0 || px > size.width) return;

    final linePaint = Paint()
      ..color = axis
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 6) {
      canvas.drawLine(Offset(px, y), Offset(px, y + 3), linePaint);
    }

    for (final curve in curves) {
      double value;
      try {
        value = curve.expression.evaluate(x: x, ans: ans, degrees: degrees);
      } on CalcException {
        continue;
      }
      if (!value.isFinite) continue;
      final py = window.screenY(value, size.height);
      if (py < -20 || py > size.height + 20) continue;
      canvas.drawCircle(
        Offset(px, py),
        4.5,
        Paint()..color = curve.color,
      );
      canvas.drawCircle(
        Offset(px, py),
        4.5,
        Paint()
          ..color = background
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }
  }

  /// Rounds a raw spacing up to the nearest 1, 2 or 5 × 10ⁿ so gridlines land
  /// on numbers a person would actually write down.
  static double _niceStep(double span, double targetLines) {
    final lines = targetLines < 1 ? 1.0 : targetLines;
    final raw = span / lines;
    if (raw <= 0 || !raw.isFinite) return 1;
    final magnitude =
        math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final normalized = raw / magnitude;
    final double multiplier;
    if (normalized < 1.5) {
      multiplier = 1;
    } else if (normalized < 3) {
      multiplier = 2;
    } else if (normalized < 7) {
      multiplier = 5;
    } else {
      multiplier = 10;
    }
    return multiplier * magnitude;
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      old.window.minX != window.minX ||
      old.window.maxX != window.maxX ||
      old.window.minY != window.minY ||
      old.window.maxY != window.maxY ||
      old.traceX != traceX ||
      old.degrees != degrees ||
      old.ans != ans ||
      old.background != background ||
      !identical(old.curves, curves);
}
