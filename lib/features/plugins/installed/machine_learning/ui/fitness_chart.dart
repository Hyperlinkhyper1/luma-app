import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../creature/evolution.dart';

/// Best and average fitness for every generation so far. Tap or drag anywhere
/// on it to jump the viewport to that generation's champion.
class FitnessChart extends StatelessWidget {
  const FitnessChart({
    super.key,
    required this.history,
    required this.selected,
    required this.onScrub,
  });

  final List<GenerationResult> history;
  final int selected;
  final ValueChanged<int> onScrub;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (history.isEmpty) {
      return Center(
        child: Text(
          'Every generation will leave a mark here.',
          style: TextStyle(color: luma.textMuted, fontSize: 12),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        void scrub(Offset local) {
          const left = _FitnessPainter.leftGutter;
          final width = math.max(1.0, constraints.maxWidth - left);
          final fraction = ((local.dx - left) / width).clamp(0.0, 1.0);
          onScrub((fraction * (history.length - 1)).round());
        }

        return Semantics(
          label: 'Fitness over ${history.length} generations. '
              'Best ${history.last.best.toStringAsFixed(1)} metres.',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => scrub(d.localPosition),
            onHorizontalDragUpdate: (d) => scrub(d.localPosition),
            child: CustomPaint(
              size: Size.infinite,
              painter: _FitnessPainter(
                history: history,
                selected: selected,
                luma: luma,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FitnessPainter extends CustomPainter {
  _FitnessPainter({
    required this.history,
    required this.selected,
    required this.luma,
  });

  final List<GenerationResult> history;
  final int selected;
  final LumaPalette luma;

  static const leftGutter = 34.0;
  static const bottomGutter = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      leftGutter,
      6,
      size.width,
      size.height - bottomGutter,
    );
    if (plot.width <= 2 || plot.height <= 2) return;

    var top = 1.0;
    for (final g in history) {
      top = math.max(top, g.best);
    }
    top *= 1.12;

    double px(int index) => history.length == 1
        ? plot.left
        : plot.left + plot.width * index / (history.length - 1);
    double py(double value) =>
        plot.bottom - (value.clamp(0, top) / top) * plot.height;

    _paintAxes(canvas, plot, top, py);

    final columns = math.min(history.length, plot.width.round().clamp(2, 2000));
    final bestPath = Path();
    final meanPath = Path();
    for (var c = 0; c < columns; c++) {
      final from = (c * history.length / columns).floor();
      final to = math.max(from + 1, ((c + 1) * history.length / columns).floor());
      var best = double.negativeInfinity;
      var mean = 0.0;
      for (var i = from; i < to && i < history.length; i++) {
        best = math.max(best, history[i].best);
        mean += history[i].mean;
      }
      mean /= to - from;
      final x = history.length == 1
          ? plot.left
          : plot.left + plot.width * from / (history.length - 1);
      if (c == 0) {
        bestPath.moveTo(x, py(best));
        meanPath.moveTo(x, py(mean));
      } else {
        bestPath.lineTo(x, py(best));
        meanPath.lineTo(x, py(mean));
      }
    }

    canvas.drawPath(
      _dashed(meanPath),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = luma.textSecondary.withValues(alpha: 0.75),
    );
    canvas.drawPath(
      bestPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = luma.accent,
    );

    final index = selected.clamp(0, history.length - 1);
    final markerX = px(index);
    canvas.drawLine(
      Offset(markerX, plot.top),
      Offset(markerX, plot.bottom),
      Paint()
        ..strokeWidth = 1
        ..color = luma.warning.withValues(alpha: 0.85),
    );
    canvas.drawCircle(
      Offset(markerX, py(history[index].best)),
      3.5,
      Paint()..color = luma.warning,
    );
  }

  void _paintAxes(
    Canvas canvas,
    Rect plot,
    double top,
    double Function(double) py,
  ) {
    final grid = Paint()
      ..color = luma.border.withValues(alpha: 0.75)
      ..strokeWidth = 1;
    final label = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i <= 4; i++) {
      final value = top * i / 4;
      final y = py(value);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      label
        ..text = TextSpan(
          text: value >= 10 ? value.round().toString() : value.toStringAsFixed(1),
          style: TextStyle(
            color: luma.textMuted,
            fontSize: 9,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        )
        ..layout();
      label.paint(canvas, Offset(plot.left - label.width - 6, y - 6));
    }

    label
      ..text = TextSpan(
        text: 'metres',
        style: TextStyle(color: luma.textMuted, fontSize: 9),
      )
      ..layout();
    canvas.save();
    canvas.translate(10, plot.center.dy + label.width / 2);
    canvas.rotate(-math.pi / 2);
    label.paint(canvas, Offset.zero);
    canvas.restore();

    for (final entry in <int, Alignment>{
      0: Alignment.centerLeft,
      history.length - 1: Alignment.centerRight,
    }.entries) {
      label
        ..text = TextSpan(
          text: 'gen ${entry.key + 1}',
          style: TextStyle(
            color: luma.textMuted,
            fontSize: 9,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        )
        ..layout();
      final x = entry.value == Alignment.centerLeft
          ? plot.left
          : plot.right - label.width;
      label.paint(canvas, Offset(x, plot.bottom + 4));
    }
  }

  /// The average line is dashed as well as dimmer, so the two series stay
  /// apart for anyone who cannot separate them by colour.
  Path _dashed(Path source) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + 4, metric.length);
        out.addPath(metric.extractPath(distance, next), Offset.zero);
        distance = next + 3;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(_FitnessPainter old) =>
      old.history.length != history.length ||
      old.selected != selected ||
      old.luma != luma;
}
