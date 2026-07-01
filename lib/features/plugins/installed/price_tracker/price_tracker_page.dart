import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'price_scraper.dart';
import 'price_tracker_repository.dart';
import 'price_tracker_scope.dart';

/// The Price Tracker plugin: paste a product URL, luma scrapes the current
/// price off the page, and every check is kept so a history graph builds up
/// over time.
class PriceTrackerPage extends StatefulWidget {
  const PriceTrackerPage({super.key});

  @override
  State<PriceTrackerPage> createState() => _PriceTrackerPageState();
}

class _PriceTrackerPageState extends State<PriceTrackerPage> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _scraper = PriceScraper();

  String? _error;
  bool _adding = false;
  final Set<String> _checking = {};

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _add(PriceTrackerRepository repo) async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Enter a product URL.');
      return;
    }
    final name = _nameController.text.trim();

    setState(() {
      _adding = true;
      _error = null;
    });

    final item = await repo.add(name: name.isEmpty ? url : name, url: url);
    _nameController.clear();
    _urlController.clear();

    try {
      final scraped = await _scraper.fetch(url);
      await repo.addSnapshot(item.id, scraped.price);
    } on PriceScraperException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not check the price.');
    }

    if (mounted) setState(() => _adding = false);
  }

  Future<void> _checkNow(PriceTrackerRepository repo, TrackedItem item) async {
    setState(() => _checking.add(item.id));
    try {
      final scraped = await _scraper.fetch(item.url);
      await repo.addSnapshot(item.id, scraped.price);
    } on PriceScraperException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not check the price.');
    }
    if (mounted) setState(() => _checking.remove(item.id));
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = PriceTrackerScope.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LumaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Track a product',
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Paste a product URL and luma checks the price for you.',
                      style: TextStyle(color: luma.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      style: TextStyle(color: luma.textPrimary),
                      decoration: _inputDecoration(luma,
                          hint: 'Name (optional)'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            style: TextStyle(color: luma.textPrimary),
                            decoration: _inputDecoration(luma,
                                hint: 'https://www.amazon.com/dp/...'),
                            onSubmitted: (_) => _add(repo),
                          ),
                        ),
                        const SizedBox(width: 12),
                        LumaPrimaryButton(
                          label: 'Track',
                          icon: Icons.add_rounded,
                          loading: _adding,
                          onTap: () => _add(repo),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: TextStyle(color: luma.danger, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Tracked items',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: repo,
                builder: (context, _) {
                  final items = repo.items;
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: LumaEmptyState(
                        icon: Icons.show_chart_rounded,
                        title: 'Nothing tracked yet',
                        subtitle:
                            'Products you track are saved here with a price-history graph.',
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final item in items) ...[
                        _TrackedItemCard(
                          item: item,
                          checking: _checking.contains(item.id),
                          onCheckNow: () => _checkNow(repo, item),
                          onDelete: () => repo.delete(item.id),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackedItemCard extends StatelessWidget {
  const _TrackedItemCard({
    required this.item,
    required this.checking,
    required this.onCheckNow,
    required this.onDelete,
  });

  final TrackedItem item;
  final bool checking;
  final VoidCallback onCheckNow;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final latest = item.latestPrice;
    final previous = item.previousPrice;
    final delta = (latest != null && previous != null) ? latest - previous : null;
    final up = (delta ?? 0) > 0;
    final down = (delta ?? 0) < 0;
    final deltaColor = up ? luma.danger : (down ? luma.success : luma.textMuted);

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (latest != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      latest.toStringAsFixed(2),
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (delta != null && delta != 0)
                      Text(
                        '${up ? '+' : ''}${delta.toStringAsFixed(2)}',
                        style: TextStyle(color: deltaColor, fontSize: 12),
                      ),
                  ],
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                icon: checking
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(luma.accent),
                        ),
                      )
                    : Icon(Icons.refresh_rounded,
                        color: luma.textMuted, size: 20),
                tooltip: 'Check price now',
                onPressed: checking ? null : onCheckNow,
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    color: luma.textMuted, size: 20),
                tooltip: 'Delete',
                onPressed: onDelete,
              ),
            ],
          ),
          if (item.snapshots.length >= 2) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: CustomPaint(
                painter: _SparklinePainter(
                  values: item.snapshots.map((s) => s.price).toList(),
                  color: luma.accent,
                  fillColor: luma.accent.withValues(alpha: 0.14),
                ),
                size: Size.infinite,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.fillColor,
  });

  final List<double> values;
  final Color color;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    const padV = 6.0;
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);
    final h = size.height;
    final w = size.width;

    Offset pointAt(int i) {
      final x = i / (values.length - 1) * w;
      final y = h - padV - ((values[i] - minV) / span) * (h - 2 * padV);
      return Offset(x, y);
    }

    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < values.length; i++) {
      final p = pointAt(i);
      line.lineTo(p.dx, p.dy);
    }

    final area = Path.from(line)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(area, Paint()..color = fillColor);

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}

InputDecoration _inputDecoration(LumaPalette luma, {String? hint}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: TextStyle(color: luma.textMuted),
    filled: true,
    fillColor: luma.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: border(luma.border),
    focusedBorder: border(luma.accent),
  );
}
