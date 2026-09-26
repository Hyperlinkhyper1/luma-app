import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/luma_theme.dart';

/// luma's mark in the chat: a crescent moon in the accent colour with a
/// soft glow. Static by default; with [animating] the crescent slowly waxes
/// and wanes and the glow breathes, which is how the chat shows a reply is
/// on its way.
class ChatMoon extends StatefulWidget {
  const ChatMoon({super.key, this.size = 28, this.animating = false});

  final double size;
  final bool animating;

  @override
  State<ChatMoon> createState() => _ChatMoonState();
}

class _ChatMoonState extends State<ChatMoon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animating) _controller.repeat();
  }

  @override
  void didUpdateWidget(ChatMoon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animating && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animating && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.luma.accent;
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _MoonPainter(
            color: color,
            phase: widget.animating ? _controller.value : null,
          ),
        ),
      ),
    );
  }
}

class _MoonPainter extends CustomPainter {
  _MoonPainter({required this.color, required this.phase});

  final Color color;

  /// 0..1 through one animation loop, or null for the resting crescent.
  final double? phase;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.4;
    final wave = phase == null ? 0.0 : math.sin(phase! * math.pi * 2);

    canvas.drawCircle(
      center,
      radius * (1.05 + 0.08 * wave),
      Paint()
        ..color = color.withValues(alpha: 0.22 + 0.1 * wave)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.45),
    );

    final shadowShift = radius * (0.62 + 0.22 * wave);
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      Path()..addOval(
        Rect.fromCircle(
          center: center + Offset(shadowShift * 0.8, -shadowShift * 0.55),
          radius: radius * 0.86,
        ),
      ),
    );
    canvas.drawPath(crescent, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MoonPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}
