import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Full-screen "installing an update" experience, styled after the app's
/// night-sky splash so an update feels like part of the same brand moment
/// rather than a generic system dialog.
///
/// Real work (downloading the installer) happens concurrently via
/// [downloadDone]/[progress]; the on-screen timeline is paced independently
/// so the screen is guaranteed to stay up for a minimum of ~6.3s even if the
/// download itself finishes instantly, and will keep waiting (parked near
/// full) if the download takes longer than that.
class UpdatingScreen extends StatefulWidget {
  const UpdatingScreen({
    super.key,
    required this.currentVersion,
    required this.newVersion,
    required this.progress,
    required this.downloadDone,
    required this.onFinished,
    this.accent = const Color(0xFFB49DF5),
  });

  final String currentVersion;
  final String newVersion;

  /// Live 0..1 download byte progress.
  final ValueListenable<double> progress;

  /// Resolves to whether the download (and write-to-disk) succeeded.
  final Future<bool> downloadDone;

  /// Called once with the final outcome — true once the minimum on-screen
  /// time has elapsed AND the download succeeded, or false as soon as the
  /// download is known to have failed.
  final void Function(bool success) onFinished;

  final Color accent;

  @override
  State<UpdatingScreen> createState() => _UpdatingScreenState();
}

class _UpdatingScreenState extends State<UpdatingScreen>
    with TickerProviderStateMixin {
  // Minimum-visible-time timeline: the bar creeps toward [_holdCap] over this
  // duration, so the screen reads as a real, deliberate step even when the
  // download itself is instant.
  late final AnimationController _timeline = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6000),
  );

  // Looping clock driving the glow pulse + rotating ring.
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  // Quick fill from [_holdCap] to 100% once the real download is confirmed
  // done, so completion never feels like it snapped shut.
  late final AnimationController _finish = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  static const _holdCap = 0.94;

  bool _timelineDone = false;
  bool _downloadOk = false;
  bool _finishing = false;

  static const _stages = <_Stage>[
    _Stage(0.00, 'Downloading update'),
    _Stage(0.45, 'Verifying files'),
    _Stage(0.80, 'Preparing installer'),
  ];

  @override
  void initState() {
    super.initState();

    final reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (reduceMotion) _ambient.stop();

    widget.downloadDone.then((ok) {
      if (!mounted) return;
      if (!ok) {
        widget.onFinished(false);
        return;
      }
      setState(() => _downloadOk = true);
      _tryFinish();
    });

    _timeline
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _timelineDone = true;
          _tryFinish();
        }
      })
      ..addListener(() => setState(() {}))
      ..forward();

    widget.progress.addListener(_onProgress);
  }

  void _onProgress() => setState(() {});

  Future<void> _tryFinish() async {
    if (!_downloadOk || !_timelineDone || _finishing) return;
    _finishing = true;
    setState(() {});
    await _finish.forward();
    // Let "Restarting luma" sit on screen for a beat before the process
    // actually hands off to the installer.
    await Future.delayed(const Duration(milliseconds: 450));
    if (mounted) widget.onFinished(true);
  }

  @override
  void dispose() {
    widget.progress.removeListener(_onProgress);
    _timeline.dispose();
    _ambient.dispose();
    _finish.dispose();
    super.dispose();
  }

  double get _displayProgress {
    if (_finishing) {
      return _holdCap + (1 - _holdCap) * _finish.value;
    }
    final timeCapped = (_timeline.value * _holdCap).clamp(0.0, _holdCap);
    final real = widget.progress.value;
    final realCapped = real > 0 ? math.min(real, _holdCap) : 0.0;
    return math.max(timeCapped, realCapped);
  }

  String get _status {
    if (_finishing) return 'Restarting luma';
    var line = _stages.first.label;
    for (final s in _stages) {
      if (_timeline.value >= s.at) line = s.label;
    }
    return line;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0B0A14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final ringSize = math.min(w, h) * 0.16 + 64;
          final barWidth = math.min(420.0, w * 0.6);

          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.3),
                    radius: 1.3,
                    colors: [
                      Color.lerp(widget.accent, const Color(0xFF0B0A14), 0.6)!,
                      const Color(0xFF120F1F),
                      const Color(0xFF09080F),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),

              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: Listenable.merge([_ambient, _finish]),
                      builder: (context, _) => CustomPaint(
                        size: Size.square(ringSize),
                        painter: _UpdateRingPainter(
                          t: _ambient.value,
                          accent: widget.accent,
                          settled: _finishing,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Updating luma',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _VersionRow(
                      from: widget.currentVersion,
                      to: widget.newVersion,
                      accent: widget.accent,
                    ),
                  ],
                ),
              ),

              Positioned(
                left: (w - barWidth) / 2,
                right: (w - barWidth) / 2,
                bottom: math.max(56, h * 0.14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _status,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${(_displayProgress * 100).round()}%',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12.5,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ProgressBar(value: _displayProgress, accent: widget.accent),
                    const SizedBox(height: 20),
                    Text(
                      'Don\'t close luma — it will relaunch on its own.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.from, required this.to, required this.accent});

  final String from;
  final String to;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final mutedStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.45),
      fontSize: 13.5,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('v$from', style: mutedStyle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.arrow_forward_rounded,
              size: 15, color: Colors.white.withValues(alpha: 0.35)),
        ),
        Text(
          'v$to',
          style: TextStyle(
            color: Color.lerp(accent, Colors.white, 0.25),
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// The thin glowing track + fill, matching the splash screen's progress bar.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.accent});
  final double value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Stack(
        children: [
          Container(height: 4, color: Colors.white.withValues(alpha: 0.1)),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color.lerp(accent, Colors.white, 0.3)!, accent],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.7),
                    blurRadius: 8,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A pulsing glow halo behind a rotating dashed ring, with a center icon that
/// swaps to a check once the update is settling in — the focal point of the
/// screen while the real download runs behind it.
class _UpdateRingPainter extends CustomPainter {
  _UpdateRingPainter({required this.t, required this.accent, required this.settled});

  final double t; // 0..1 looping ambient clock
  final Color accent;
  final bool settled;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 * 0.78;

    // Soft outer glow, breathing in and out.
    final pulse = 0.85 + 0.15 * math.sin(t * 2 * math.pi);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: 0.35),
          accent.withValues(alpha: 0.10),
          accent.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r * 2.0 * pulse));
    canvas.drawCircle(center, r * 2.0 * pulse, glow);

    // Static faint track.
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawCircle(center, r, track);

    // Rotating dashed arc sweeping around the track, like an active sync
    // indicator.
    final sweep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        colors: [
          accent.withValues(alpha: 0.0),
          accent,
          accent.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(t * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      0,
      2 * math.pi,
      false,
      sweep,
    );

    // Center icon: a rounded upward arrow inside a soft disc.
    final discPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          Color.lerp(accent, const Color(0xFF0B0A14), 0.15)!,
          Color.lerp(accent, Colors.white, 0.25)!,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.62));
    canvas.drawCircle(center, r * 0.62, discPaint);

    final iconPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(
          (settled ? Icons.check_rounded : Icons.system_update_rounded)
              .codePoint,
        ),
        style: TextStyle(
          fontSize: r * 0.62,
          fontFamily:
              (settled ? Icons.check_rounded : Icons.system_update_rounded)
                  .fontFamily,
          package: (settled ? Icons.check_rounded : Icons.system_update_rounded)
              .fontPackage,
          color: Colors.white.withValues(alpha: 0.95),
        ),
      ),
    )..layout();
    iconPainter.paint(
      canvas,
      center - Offset(iconPainter.width / 2, iconPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_UpdateRingPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.settled != settled;
}

class _Stage {
  const _Stage(this.at, this.label);
  final double at;
  final String label;
}
