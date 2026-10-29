import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';

/// Compares benchmark scores with the current catalog's input-token prices.
class WikiSearchCostChart extends StatelessWidget {
  const WikiSearchCostChart({super.key, required this.models});

  final List<Map> models;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final priced = models.where((model) => _price(model) != null).toList();
    final missing = models.where((model) => _price(model) == null).toList();
    final maxPrice = priced.fold<double>(
      0,
      (maximum, model) => math.max(maximum, _price(model)!),
    );
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cost vs performance',
            style: TextStyle(
              color: luma.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Retrieval score vs OpenRouter catalog price per 1M input tokens. Prices may be cached. Hover or tap a point for model details.',
            style: TextStyle(color: luma.textSecondary),
          ),
          const SizedBox(height: 20),
          if (priced.isEmpty)
            Text(
              'No model prices are available for this comparison.',
              style: TextStyle(color: luma.textSecondary),
            )
          else ...[
            Text(
              'Retrieval score',
              style: TextStyle(color: luma.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 240,
                  width: 42,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final label in ['100%', '75%', '50%', '25%', '0%'])
                        Text(
                          label,
                          style: TextStyle(color: luma.textMuted, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const height = 240.0;
                      const inset = 8.0;
                      final width = constraints.maxWidth;
                      final plotWidth = math.max(0.0, width - inset * 2);
                      const plotHeight = height - inset * 2;
                      final groups = <String, List<Map>>{};
                      for (final model in priced) {
                        final key = '${_price(model)}:${model['score']}';
                        groups.putIfAbsent(key, () => []).add(model);
                      }
                      return SizedBox(
                        height: height,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _GridPainter(
                                  luma.textMuted.withValues(alpha: 0.25),
                                ),
                              ),
                            ),
                            for (final group in groups.values)
                              Positioned(
                                left:
                                    (maxPrice == 0
                                        ? 0
                                        : _price(group.first)! / maxPrice) *
                                    plotWidth,
                                top:
                                    (1 -
                                        (group.first['score'] as num)
                                                .toDouble() /
                                            100) *
                                    plotHeight,
                                child: Tooltip(
                                  message: group
                                      .map(
                                        (model) =>
                                            '${model['model']}\n${_formatPrice(_price(model)!)} / 1M tokens · ${(model['score'] as num).toStringAsFixed(1)}%',
                                      )
                                      .join('\n\n'),
                                  triggerMode: TooltipTriggerMode.tap,
                                  child: Semantics(
                                    label: group
                                        .map(
                                          (model) =>
                                              '${model['model']}, ${_formatPrice(_price(model)!)} per million input tokens, ${(model['score'] as num).toStringAsFixed(1)} percent',
                                        )
                                        .join('; '),
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: luma.background,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatPrice(0),
                    style: TextStyle(color: luma.textMuted, fontSize: 11),
                  ),
                  Text(
                    _formatPrice(maxPrice / 2),
                    style: TextStyle(color: luma.textMuted, fontSize: 11),
                  ),
                  Text(
                    _formatPrice(maxPrice),
                    style: TextStyle(color: luma.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Cost per 1M input tokens (USD)',
                style: TextStyle(color: luma.textSecondary),
              ),
            ),
          ],
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Price unavailable for ${missing.length} ${missing.length == 1 ? 'model' : 'models'}; excluded from the graph.',
              style: TextStyle(color: luma.textSecondary),
            ),
          ],
          Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Model prices and scores'),
              children: [
                for (final model in models)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(model['model'] as String),
                        Text(
                          '${_price(model) == null ? 'Price unavailable' : '${_formatPrice(_price(model)!)} / 1M'} · ${(model['score'] as num).toStringAsFixed(1)}%',
                          style: TextStyle(color: luma.textSecondary),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

double? _price(Map model) {
  final price = model['pricePerMillion'];
  return price is num && price.isFinite && price >= 0 ? price.toDouble() : null;
}

String _formatPrice(double value) {
  if (value == 0) return r'$0';
  if (value < 0.000001) return '\$${value.toStringAsPrecision(3)}';
  var formatted = value.toStringAsFixed(6);
  while (formatted.endsWith('0') && formatted.split('.').last.length > 2) {
    formatted = formatted.substring(0, formatted.length - 1);
  }
  return '\$$formatted';
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const inset = 8.0;
    for (var i = 0; i <= 4; i++) {
      final y = inset + (size.height - inset * 2) * i / 4;
      canvas.drawLine(Offset(inset, y), Offset(size.width - inset, y), paint);
    }
    for (var i = 0; i <= 2; i++) {
      final x = inset + (size.width - inset * 2) * i / 2;
      canvas.drawLine(Offset(x, inset), Offset(x, size.height - inset), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => color != oldDelegate.color;
}
