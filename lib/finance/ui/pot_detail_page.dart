import 'package:flutter/material.dart';

import '../../theme/luma_theme.dart';
import '../data/database.dart';
import '../logic/money.dart';
import 'lookups.dart';

/// Opens a dialog showing every transaction for [pot], plus a category
/// breakdown and a balance-over-time chart.
Future<void> showPotDetail(
  BuildContext context, {
  required Pot pot,
  required List<FinanceTransaction> allTxns,
  required List<Category> categories,
  required List<Merchant> merchants,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: dialogContext.luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight:
              (MediaQuery.of(dialogContext).size.height - 48).clamp(360.0, 800.0),
        ),
        child: _PotDetailView(
          pot: pot,
          allTxns: allTxns,
          categories: categories,
          merchants: merchants,
        ),
      ),
    ),
  );
}

class _PotDetailView extends StatelessWidget {
  const _PotDetailView({
    required this.pot,
    required this.allTxns,
    required this.categories,
    required this.merchants,
  });

  final Pot pot;
  final List<FinanceTransaction> allTxns;
  final List<Category> categories;
  final List<Merchant> merchants;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final catById = {for (final c in categories) c.id: c};
    final merchantById = {for (final m in merchants) m.id: m};

    final potTxns = allTxns.where((t) => t.potId == pot.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    var balance = 0;
    for (final t in potTxns) {
      balance += switch (t.kind) {
        TxnKind.allocation => t.amountCents,
        TxnKind.expense => -t.amountCents,
        TxnKind.income => t.amountCents,
      };
    }

    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Color(pot.colorValue).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(materialIcon(pot.iconCodepoint),
                    color: Color(pot.colorValue)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pot.name,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatCents(balance),
                      style: TextStyle(
                        color: balance < 0 ? luma.danger : luma.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: luma.textMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: potTxns.isEmpty
                ? Center(
                    child: Text(
                      'No transactions in this pot yet.',
                      style: TextStyle(color: luma.textMuted),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BalanceOverTimeChart(txns: potTxns),
                        const SizedBox(height: 20),
                        _CategoryBreakdown(txns: potTxns, catById: catById),
                        const SizedBox(height: 20),
                        Text(
                          'Transactions',
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final t in potTxns) ...[
                          _PotTxnRow(
                            txn: t,
                            category: t.categoryId == null ? null : catById[t.categoryId],
                            merchant: t.merchantId == null ? null : merchantById[t.merchantId],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BalanceOverTimeChart extends StatelessWidget {
  const _BalanceOverTimeChart({required this.txns});
  final List<FinanceTransaction> txns;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    // Oldest -> newest, running balance after each entry.
    final chronological = txns.toList()..sort((a, b) => a.date.compareTo(b.date));
    var running = 0;
    final points = <double>[0];
    for (final t in chronological) {
      running += switch (t.kind) {
        TxnKind.allocation => t.amountCents,
        TxnKind.expense => -t.amountCents,
        TxnKind.income => t.amountCents,
      };
      points.add(running.toDouble());
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Balance over time',
              style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: _LineChartPainter(
                points: points,
                lineColor: luma.accent,
                gridColor: luma.border,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
  });

  final List<double> points;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final minV = points.reduce((a, b) => a < b ? a : b);
    final maxV = points.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1 ? 1.0 : (maxV - minV);

    double yFor(double v) => size.height - ((v - minV) / range) * size.height;
    double xFor(int i) => points.length == 1
        ? 0
        : (i / (points.length - 1)) * size.width;

    // Zero line, if within range.
    if (minV < 0 && maxV > 0) {
      final zeroY = yFor(0);
      final gridPaint = Paint()
        ..color = gridColor
        ..strokeWidth = 1;
      canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), gridPaint);
    }

    final path = Path()..moveTo(xFor(0), yFor(points[0]));
    for (var i = 1; i < points.length; i++) {
      path.lineTo(xFor(i), yFor(points[i]));
    }

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final fillPath = Path.from(path)
      ..lineTo(xFor(points.length - 1), size.height)
      ..lineTo(xFor(0), size.height)
      ..close();
    final fillPaint = Paint()..color = lineColor.withValues(alpha: 0.08);
    canvas.drawPath(fillPath, fillPaint);

    final dotPaint = Paint()..color = lineColor;
    canvas.drawCircle(
        Offset(xFor(points.length - 1), yFor(points.last)), 3.2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.txns, required this.catById});
  final List<FinanceTransaction> txns;
  final Map<int, Category> catById;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    final byCategory = <int?, int>{};
    var total = 0;
    for (final t in txns) {
      if (t.kind != TxnKind.expense) continue;
      byCategory[t.categoryId] = (byCategory[t.categoryId] ?? 0) + t.amountCents;
      total += t.amountCents;
    }

    if (total == 0) {
      return const SizedBox.shrink();
    }

    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = entries.first.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Spending by category',
                  style: TextStyle(
                      color: luma.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              Text(
                formatCents(total),
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final e in entries) ...[
            _CategoryBar(
              category: e.key == null ? null : catById[e.key],
              amountCents: e.value,
              fraction: e.value / maxValue,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.category,
    required this.amountCents,
    required this.fraction,
  });
  final Category? category;
  final int amountCents;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = category != null ? Color(category!.colorValue) : luma.textMuted;
    final name = category?.name ?? 'Uncategorized';
    final icon =
        category != null ? materialIcon(category!.iconCodepoint) : Icons.help_outline_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 8),
            Text(name, style: TextStyle(color: luma.textPrimary, fontSize: 13)),
            const Spacer(),
            Text(
              formatCents(amountCents),
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.04, 1.0),
            minHeight: 6,
            backgroundColor: luma.surfaceHover,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _PotTxnRow extends StatelessWidget {
  const _PotTxnRow({required this.txn, required this.category, required this.merchant});
  final FinanceTransaction txn;
  final Category? category;
  final Merchant? merchant;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    late final IconData icon;
    late final Color color;
    late final String title;

    switch (txn.kind) {
      case TxnKind.income:
        icon = Icons.south_west_rounded;
        color = luma.success;
        title = txn.note ?? 'Income';
      case TxnKind.allocation:
        icon = Icons.savings_rounded;
        color = luma.accent;
        title = txn.note ?? 'Allocation';
      case TxnKind.expense:
        icon = category != null ? materialIcon(category!.iconCodepoint) : Icons.shopping_bag_rounded;
        color = category != null ? Color(category!.colorValue) : luma.textMuted;
        title = merchant?.name ?? category?.name ?? txn.note ?? 'Expense';
    }

    final amountColor = switch (txn.kind) {
      TxnKind.income => luma.success,
      TxnKind.allocation => luma.accent,
      TxnKind.expense => luma.danger,
    };
    final amountText = switch (txn.kind) {
      TxnKind.allocation => '→ ${formatCents(txn.amountCents)}',
      TxnKind.income => formatSignedCents(txn.amountCents),
      TxnKind.expense => formatSignedCents(-txn.amountCents),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _shortDate(txn.date),
            style: TextStyle(color: luma.textMuted, fontSize: 11),
          ),
          const SizedBox(width: 10),
          Text(
            amountText,
            style: TextStyle(color: amountColor, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

String _shortDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]}';
}
