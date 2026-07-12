import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'speed_test_engine.dart';
import 'wifi_speed_test_repository.dart';
import 'wifi_speed_test_scope.dart';

class WifiSpeedTestPage extends StatefulWidget {
  const WifiSpeedTestPage({super.key});

  @override
  State<WifiSpeedTestPage> createState() => _WifiSpeedTestPageState();
}

class _WifiSpeedTestPageState extends State<WifiSpeedTestPage> {
  SpeedTestEngine? _engine;
  SpeedTestProgress? _progress;
  bool _testing = false;
  bool _error = false;

  @override
  void dispose() {
    _engine?.dispose();
    super.dispose();
  }

  Future<void> _startTest(WifiSpeedTestRepository repo) async {
    _engine?.dispose();
    _engine = SpeedTestEngine();
    setState(() {
      _testing = true;
      _error = false;
      _progress = null;
    });

    try {
      double? downloadMbps;
      double? uploadMbps;
      var latencyMs = 0;

      await for (final p in _engine!.runTest()) {
        if (!mounted) return;
        setState(() => _progress = p);
        if (p.downloadMbps != null) downloadMbps = p.downloadMbps;
        if (p.uploadMbps != null) uploadMbps = p.uploadMbps;
        if (p.latencyMs > 0) latencyMs = p.latencyMs;
      }

      if (mounted && downloadMbps != null && uploadMbps != null) {
        await repo.add(SpeedTestResult(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          testedAt: DateTime.now(),
          downloadMbps: downloadMbps,
          uploadMbps: uploadMbps,
          latencyMs: latencyMs,
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = WifiSpeedTestScope.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GaugeSection(
                progress: _progress,
                testing: _testing,
                error: _error,
                onStart: () => _startTest(repo),
              ),
              const SizedBox(height: 32),
              _HistorySection(repo: repo),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugeSection extends StatelessWidget {
  const _GaugeSection({
    required this.progress,
    required this.testing,
    required this.error,
    required this.onStart,
  });

  final SpeedTestProgress? progress;
  final bool testing;
  final bool error;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    return LumaCard(
      child: Column(
        children: [
          SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  painter: _SpeedGaugePainter(
                    fraction: _gaugeFraction(),
                    color: _gaugeColor(luma),
                    trackColor: luma.border,
                  ),
                  size: const Size(240, 240),
                ),
                _gaugeCenter(luma),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PhaseDots(progress: progress),
          const SizedBox(height: 20),
          if (!testing)
            LumaPrimaryButton(
              label: error ? 'Try Again' : 'Start Test',
              icon: Icons.speed_rounded,
              onTap: onStart,
              expand: true,
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Testing — please wait…',
                style: TextStyle(fontSize: 13),
              ),
            ),
          if (error) ...[
            const SizedBox(height: 10),
            Text(
              'Test failed. Check your connection and try again.',
              style: TextStyle(color: luma.danger, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          _ResultRow(progress: progress),
        ],
      ),
    );
  }

  double _gaugeFraction() {
    if (progress == null) return 0;
    if (progress!.phase == SpeedTestPhase.latency) return 0;
    if (progress!.phase == SpeedTestPhase.done) return 1.0;
    return progress!.fraction;
  }

  Color _gaugeColor(LumaPalette luma) {
    if (progress == null) return luma.accent;
    switch (progress!.phase) {
      case SpeedTestPhase.download:
        return luma.accent;
      case SpeedTestPhase.upload:
        return luma.success;
      case SpeedTestPhase.latency:
        return luma.textMuted;
      case SpeedTestPhase.done:
        return luma.accent;
    }
  }

  Widget _gaugeCenter(LumaPalette luma) {
    if (progress == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.speed_rounded, size: 40, color: luma.textMuted),
          const SizedBox(height: 8),
          Text(
            'Ready',
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    switch (progress!.phase) {
      case SpeedTestPhase.latency:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(luma.accent),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Pinging…',
              style: TextStyle(
                color: luma.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case SpeedTestPhase.download:
      case SpeedTestPhase.upload:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              progress!.currentSpeedMbps.toStringAsFixed(1),
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 42,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Mbps',
              style: TextStyle(
                color: luma.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              progress!.phase == SpeedTestPhase.download
                  ? 'Downloading'
                  : 'Uploading',
              style: TextStyle(
                color: _gaugeColor(luma),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case SpeedTestPhase.done:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 36, color: luma.success),
            const SizedBox(height: 8),
            Text(
              'Done',
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
    }
  }
}

class _PhaseDots extends StatelessWidget {
  const _PhaseDots({required this.progress});

  final SpeedTestProgress? progress;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final phases = [
      ('Ping', SpeedTestPhase.latency),
      ('Download', SpeedTestPhase.download),
      ('Upload', SpeedTestPhase.upload),
    ];

    final currentPhase = progress?.phase;
    final done = progress?.phase == SpeedTestPhase.done;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < phases.length; i++) ...[
          _phaseDot(
            luma,
            label: phases[i].$1,
            active: !done && currentPhase == phases[i].$2,
            completed: done ||
                (currentPhase != null &&
                    currentPhase.index > phases[i].$2.index),
          ),
          if (i < phases.length - 1) ...[
            Container(
              width: 24,
              height: 2,
              color: luma.border,
            ),
          ],
        ],
      ],
    );
  }

  Widget _phaseDot(
    LumaPalette luma, {
    required String label,
    required bool active,
    required bool completed,
  }) {
    final color = completed
        ? luma.success
        : active
            ? luma.accent
            : luma.textMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.progress});

  final SpeedTestProgress? progress;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final ping = progress?.latencyMs;
    final down = progress?.downloadMbps;
    final up = progress?.uploadMbps;

    return Row(
      children: [
        Expanded(
          child: _ResultCard(
            icon: Icons.signal_cellular_alt_rounded,
            label: 'Ping',
            value: ping != null ? '$ping ms' : '—',
            color: luma.textSecondary,
            luma: luma,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ResultCard(
            icon: Icons.download_rounded,
            label: 'Download',
            value: down != null ? '${down.toStringAsFixed(1)} Mbps' : '—',
            color: luma.accent,
            luma: luma,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ResultCard(
            icon: Icons.upload_rounded,
            label: 'Upload',
            value: up != null ? '${up.toStringAsFixed(1)} Mbps' : '—',
            color: luma.success,
            luma: luma,
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.luma,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.repo});

  final WifiSpeedTestRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'History',
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            AnimatedBuilder(
              animation: repo,
              builder: (context, _) {
                if (repo.results.isEmpty) return const SizedBox.shrink();
                return TextButton(
                  onPressed: () => _confirmClear(context),
                  child: Text(
                    'Clear all',
                    style: TextStyle(
                      color: luma.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: repo,
          builder: (context, _) {
            final results = repo.results;
            if (results.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: LumaEmptyState(
                  icon: Icons.history_rounded,
                  title: 'No tests yet',
                  subtitle:
                      'Run your first speed test to start tracking your connection over time.',
                ),
              );
            }

            final downloads = results.map((r) => r.downloadMbps).toList();
            final uploads = results.map((r) => r.uploadMbps).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LumaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HistoryLabel(
                        luma: luma,
                        color: luma.accent,
                        label: 'Download speed (Mbps)',
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 70,
                        child: CustomPaint(
                          painter: _SparklinePainter(
                            values: downloads,
                            color: luma.accent,
                            fillColor: luma.accent.withValues(alpha: 0.14),
                          ),
                          size: Size.infinite,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _HistoryLabel(
                        luma: luma,
                        color: luma.success,
                        label: 'Upload speed (Mbps)',
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 70,
                        child: CustomPaint(
                          painter: _SparklinePainter(
                            values: uploads,
                            color: luma.success,
                            fillColor: luma.success.withValues(alpha: 0.14),
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final r in results.reversed) ...[
                  _HistoryCard(result: r, luma: luma, onDelete: () => repo.delete(r.id)),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  void _confirmClear(BuildContext context) {
    final luma = context.luma;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: luma.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear history?'),
        content: const Text('All past speed test results will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: luma.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              repo.clearHistory();
              Navigator.pop(context);
            },
            child: Text('Clear',
                style: TextStyle(
                    color: luma.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _HistoryLabel extends StatelessWidget {
  const _HistoryLabel({
    required this.luma,
    required this.color,
    required this.label,
  });

  final LumaPalette luma;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: luma.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.result,
    required this.luma,
    required this.onDelete,
  });

  final SpeedTestResult result;
  final LumaPalette luma;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return LumaCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('d MMM yyyy — HH:mm').format(result.testedAt),
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _miniStat(
                      luma,
                      icon: Icons.download_rounded,
                      value: '${result.downloadMbps.toStringAsFixed(1)} Mbps',
                      color: luma.accent,
                    ),
                    const SizedBox(width: 16),
                    _miniStat(
                      luma,
                      icon: Icons.upload_rounded,
                      value: '${result.uploadMbps.toStringAsFixed(1)} Mbps',
                      color: luma.success,
                    ),
                    const SizedBox(width: 16),
                    _miniStat(
                      luma,
                      icon: Icons.signal_cellular_alt_rounded,
                      value: '${result.latencyMs} ms',
                      color: luma.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                color: luma.textMuted, size: 18),
            onPressed: onDelete,
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  Widget _miniStat(
    LumaPalette luma, {
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: luma.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SpeedGaugePainter extends CustomPainter {
  _SpeedGaugePainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
  });

  final double fraction;
  final Color color;
  final Color trackColor;

  static const _startAngle = 135.0 * math.pi / 180.0;
  static const _sweepAngle = 270.0 * math.pi / 180.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      _startAngle,
      _sweepAngle,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );

    if (fraction > 0.001) {
      canvas.drawArc(
        rect,
        _startAngle,
        _sweepAngle * fraction.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round,
      );
    }

    final tickCount = 10;
    final paint = Paint()
      ..color = trackColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i <= tickCount; i++) {
      final t = i / tickCount;
      final angle = _startAngle + _sweepAngle * t;
      final inner = radius - 2;
      final outer = radius + 4;
      canvas.drawLine(
        Offset(
          center.dx + inner * math.cos(angle),
          center.dy + inner * math.sin(angle),
        ),
        Offset(
          center.dx + outer * math.cos(angle),
          center.dy + outer * math.sin(angle),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SpeedGaugePainter old) =>
      old.fraction != fraction || old.color != color;
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
    if (values.length < 2) {
      final paint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
      return;
    }

    const padV = 8.0;
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

    final last = pointAt(values.length - 1);
    canvas.drawCircle(last, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}
