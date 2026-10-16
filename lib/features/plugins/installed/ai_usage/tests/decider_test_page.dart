import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import 'ai_benchmark_scope.dart';
import 'decider_results.dart';

/// AI Usage → Tests → Decider Test (Moderation): the results of the admin
/// dashboard's Decider test. Decision models are scored on the server; this
/// page only shows each model's latest run, cost against accuracy.
class DeciderTestPage extends StatefulWidget {
  const DeciderTestPage({super.key});

  @override
  State<DeciderTestPage> createState() => _DeciderTestPageState();
}

class _DeciderTestPageState extends State<DeciderTestPage> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    AiBenchmarkScope.of(context).loadDecider();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final repo = AiBenchmarkScope.of(context);
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        title: Text(t.aiTestDeciderTitle),
        actions: [
          if (repo.canRefresh)
            IconButton(
              tooltip: t.commonRefresh,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: repo.deciderLoading ? null : repo.loadDecider,
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final board = repo.decider;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.aiDeciderIntro,
                  style: TextStyle(color: luma.textSecondary, fontSize: 13),
                ),
                if (board != null && board.cases > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    t.aiDeciderSuiteLine(
                      '${board.cases}',
                      board.chance.toStringAsFixed(1),
                    ),
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 20),
                if (board == null && repo.deciderLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    ),
                  )
                else if (board == null || board.entries.isEmpty)
                  LumaEmptyState(
                    icon: Icons.gavel_rounded,
                    title: t.aiDeciderEmpty,
                    subtitle: !repo.canRefresh
                        ? t.aiBenchmarkSignInToFetch
                        : repo.deciderError ?? t.aiDeciderEmptyDetail,
                  )
                else ...[
                  LumaCard(child: _chart(context, board)),
                  const SizedBox(height: 20),
                  Text(
                    t.aiDeciderRanking,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final (i, e) in board.entries.indexed) ...[
                    _row(context, i + 1, e),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _chart(BuildContext context, DeciderBoard board) {
    final luma = context.luma;
    final t = L.of(context);
    final vendors = {for (final e in board.entries) e.vendor}.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.aiDeciderChartTitle,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: context.isPhoneWidth ? 1.1 : 2.1,
          child: CustomPaint(
            painter: DeciderChartPainter(
              board: board,
              text: luma.textMuted,
              label: luma.textPrimary,
              grid: luma.border,
              accent: luma.accent,
              danger: luma.danger,
              warning: luma.warning,
              axisLabel: t.aiDeciderCostAxis,
              guessingLabel: t.aiDeciderGuessing(
                board.chance.toStringAsFixed(1),
              ),
              ceilingLabel: t.aiDeciderCeiling,
              freeLabel: t.aiDeciderFree,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final v in vendors)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: deciderVendorColor(v),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    v,
                    style: TextStyle(color: luma.textSecondary, fontSize: 12),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _row(BuildContext context, int rank, DeciderEntry e) {
    final luma = context.luma;
    final t = L.of(context);
    final color = deciderVendorColor(e.vendor);
    return LumaCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: TextStyle(
                color: luma.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.shortName,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${e.vendor}${e.direct ? ' · ${t.aiDeciderDirect}' : ''}'
                  ' · ${t.aiDeciderPerThousand(deciderMoney(e.costPer1k))}',
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            t.aiDeciderRight(e.accuracy.toStringAsFixed(1)),
            style: TextStyle(
              color: e.accuracy >= 50
                  ? luma.success
                  : e.accuracy >= 30
                      ? luma.warning
                      : luma.danger,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cost per 1,000 cases (log scale) across, accuracy up. One dot per model
/// in its company's colour, the cost/accuracy frontier as a line, and
/// guides for random guessing and the suite's 50% ceiling.
class DeciderChartPainter extends CustomPainter {
  DeciderChartPainter({
    required this.board,
    required this.text,
    required this.label,
    required this.grid,
    required this.accent,
    required this.danger,
    required this.warning,
    required this.axisLabel,
    required this.guessingLabel,
    required this.ceilingLabel,
    required this.freeLabel,
  });

  final DeciderBoard board;
  final Color text;
  final Color label;
  final Color grid;
  final Color accent;
  final Color danger;
  final Color warning;
  final String axisLabel;
  final String guessingLabel;
  final String ceilingLabel;
  final String freeLabel;

  static const _left = 44.0, _right = 12.0, _top = 10.0, _bottom = 40.0;

  void _text(Canvas canvas, String s, Offset at, Color color,
      {double size = 11, TextAlign align = TextAlign.left, FontWeight? weight}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: color, fontSize: size, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.right => at.dx - tp.width,
      TextAlign.center => at.dx - tp.width / 2,
      _ => at.dx,
    };
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  void _dashed(Canvas canvas, double y, double x0, double x1, Paint paint,
      double dash, double gap) {
    for (var x = x0; x < x1; x += dash + gap) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + dash, x1), y), paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final plotLeft = _left, plotRight = w - _right;
    final plotTop = _top, plotBottom = h - _bottom;
    final costs = [
      for (final e in board.entries)
        if (e.costPer1k > 0) e.costPer1k,
    ];
    var lo = costs.isEmpty ? -4 : (math.log(costs.reduce(math.min)) / math.ln10).floor();
    var hi = costs.isEmpty ? -2 : (math.log(costs.reduce(math.max)) / math.ln10).ceil();
    if (hi - lo < 2) {
      lo -= 1;
      hi += 1;
    }
    const freeGap = 34.0;
    double x(double c) => c > 0
        ? plotLeft + freeGap +
            (math.log(c) / math.ln10 - lo) / (hi - lo) * (plotRight - plotLeft - freeGap)
        : plotLeft + 10;
    double y(double v) => plotTop + (1 - v / 100) * (plotBottom - plotTop);

    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var v = 0; v <= 100; v += 20) {
      canvas.drawLine(Offset(plotLeft, y(v.toDouble())),
          Offset(plotRight, y(v.toDouble())), gridPaint);
      _text(canvas, '$v%', Offset(plotLeft - 6, y(v.toDouble())), text,
          align: TextAlign.right);
    }
    for (var e = lo; e <= hi; e++) {
      final c = math.pow(10, e).toDouble();
      canvas.drawLine(Offset(x(c), plotTop), Offset(x(c), plotBottom), gridPaint);
      _text(canvas, deciderMoney(c), Offset(x(c), plotBottom + 12), text,
          align: TextAlign.center);
    }
    if (board.entries.any((e) => e.costPer1k <= 0)) {
      _text(canvas, freeLabel, Offset(plotLeft + 10, plotBottom + 12), text,
          align: TextAlign.center);
    }
    _text(canvas, axisLabel, Offset((plotLeft + plotRight) / 2, h - 8), text,
        align: TextAlign.center);

    final ceiling = Paint()
      ..color = warning.withValues(alpha: 0.75)
      ..strokeWidth = 1;
    _dashed(canvas, y(50), plotLeft, plotRight, ceiling, 2, 4);
    _text(canvas, ceilingLabel, Offset(plotRight, y(50) - 9), text,
        align: TextAlign.right);
    if (board.chance > 0) {
      final guess = Paint()
        ..color = danger.withValues(alpha: 0.7)
        ..strokeWidth = 1;
      _dashed(canvas, y(board.chance), plotLeft, plotRight, guess, 5, 4);
      _text(canvas, guessingLabel, Offset(plotRight, y(board.chance) - 9), text,
          align: TextAlign.right);
    }

    final front = board.frontier;
    if (front.length > 1) {
      final path = Path()
        ..moveTo(x(front.first.costPer1k), y(front.first.accuracy));
      for (final e in front.skip(1)) {
        path.lineTo(x(e.costPer1k), y(e.accuracy));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = accent.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    final placed = <Offset>[];
    final byCost = [...board.entries]
      ..sort((a, b) => a.costPer1k.compareTo(b.costPer1k));
    for (final e in byCost) {
      final p = Offset(x(e.costPer1k), y(e.accuracy));
      canvas.drawCircle(p, front.contains(e) ? 7 : 6,
          Paint()..color = deciderVendorColor(e.vendor));
      canvas.drawCircle(
        p,
        front.contains(e) ? 7 : 6,
        Paint()
          ..color = e.direct ? Colors.white : Colors.black.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = e.direct ? 2 : 1.2,
      );
      var ly = p.dy - 12;
      while (placed.any((q) => (q.dy - ly).abs() < 13 && (q.dx - p.dx).abs() < 150)) {
        ly -= 13;
      }
      placed.add(Offset(p.dx, ly));
      final rightSide = p.dx > w - 170;
      _text(
        canvas,
        '${e.shortName} · ${e.accuracy.toStringAsFixed(1)}%',
        Offset(p.dx + (rightSide ? -9 : 9), ly),
        label,
        size: 11.5,
        align: rightSide ? TextAlign.right : TextAlign.left,
      );
    }
  }

  @override
  bool shouldRepaint(DeciderChartPainter old) =>
      old.board != board || old.text != text || old.label != label;
}
