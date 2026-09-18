import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Official vendor artwork, bundled under `assets/images/vendors/` (sourced
/// from Wikimedia Commons / the vendors' own brand pages — all trademarks
/// belong to their respective owners).
///
/// Each logo sits on a plain white tile: several marks are pure black and
/// Google's own guidelines ask for a white or black field, so one shared
/// tile keeps every vendor legible in both app themes.
///
/// Vendors with no obtainable artwork (`pickle`, `laguna`, unknown keys)
/// fall back to the hand-drawn marks at the bottom of this file.
class VendorLogo extends StatelessWidget {
  const VendorLogo({
    super.key,
    required this.vendor,
    required this.vendorName,
    this.size = 32,
  });

  final String vendor;
  final String vendorName;
  final double size;

  static const _assets = {
    'anthropic': 'assets/images/vendors/anthropic.svg',
    'openai': 'assets/images/vendors/openai.svg',
    'google': 'assets/images/vendors/google.svg',
    'x-ai': 'assets/images/vendors/x-ai.svg',
    'meta': 'assets/images/vendors/meta.svg',
    'nvidia': 'assets/images/vendors/nvidia.svg',
    'mistralai': 'assets/images/vendors/mistralai.svg',
    'z-ai': 'assets/images/vendors/z-ai.svg',
    'qwen': 'assets/images/vendors/qwen.svg',
    'deepseek': 'assets/images/vendors/deepseek.svg',
    'moonshotai': 'assets/images/vendors/moonshotai-icon.png',
    'minimax': 'assets/images/vendors/minimax.svg',
    'xiaomi': 'assets/images/vendors/xiaomi.svg',
    'github': 'assets/images/vendors/github.svg',
  };

  @override
  Widget build(BuildContext context) {
    final asset = _assets[vendor];
    final mark = asset == null
        ? CustomPaint(
            size: Size(size, size),
            painter: _VendorMarkPainter(vendor),
          )
        : Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(size * 0.11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(size * 0.25),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: asset.endsWith('.svg')
                ? SvgPicture.asset(asset, fit: BoxFit.contain)
                : Image.asset(asset, fit: BoxFit.contain),
          );
    return Tooltip(
      message: vendorName,
      child: Semantics(label: vendorName, child: mark),
    );
  }
}

class _VendorMarkPainter extends CustomPainter {
  _VendorMarkPainter(this.vendor);

  final String vendor;

  @override
  void paint(Canvas canvas, Size size) {
    // All marks are authored on a 32x32 grid.
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    switch (vendor) {
      case 'anthropic':
        _anthropic(canvas);
      case 'openai':
        _openai(canvas);
      case 'google':
        _google(canvas);
      case 'x-ai':
        _xai(canvas);
      case 'meta':
      case 'meta-llama':
        _meta(canvas);
      case 'nvidia':
        _nvidia(canvas);
      case 'mistralai':
        _mistral(canvas);
      case 'z-ai':
        _zai(canvas);
      case 'qwen':
        _qwen(canvas);
      case 'deepseek':
        _deepseek(canvas);
      case 'moonshotai':
        _moonshot(canvas);
      case 'minimax':
        _minimax(canvas);
      case 'xiaomi':
        _xiaomi(canvas);
      case 'github':
        _github(canvas);
      case 'pickle':
        _pickle(canvas);
      case 'laguna':
        _laguna(canvas);
      default:
        _fallback(canvas);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VendorMarkPainter oldDelegate) =>
      oldDelegate.vendor != vendor;
}

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Paint _fill(Color color) => Paint()
  ..color = color
  ..style = PaintingStyle.fill;

RRect _rr(double x, double y, double w, double h, double r) =>
    RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      Radius.circular(r),
    );

/// Anthropic's A clamp mark.
void _anthropic(Canvas c) {
  const color = Color(0xFFF97316);
  c.drawPath(
    Path()
      ..moveTo(8.5, 24)
      ..lineTo(16, 8)
      ..lineTo(23.5, 24),
    _stroke(color, 4),
  );
  c.drawLine(
    const Offset(11.8, 18.5),
    const Offset(20.2, 18.5),
    _stroke(color, 2.8),
  );
}

/// OpenAI's blossom, approximated as six petals around a center.
void _openai(Canvas c) {
  const color = Color(0xFF22C55E);
  final petal = _stroke(color, 2.1);
  for (var i = 0; i < 6; i++) {
    c.save();
    c.translate(16, 16);
    c.rotate(i * math.pi / 3);
    c.drawOval(
      Rect.fromCenter(
        center: const Offset(5.4, 0),
        width: 10.6,
        height: 4.8,
      ),
      petal,
    );
    c.restore();
  }
}

/// Google's four-color G with its blue bar.
void _google(Canvas c) {
  const center = Offset(16, 17);
  const radius = 9.0;
  void arc(Color color, double startDeg, double sweepDeg) {
    c.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startDeg * math.pi / 180,
      sweepDeg * math.pi / 180,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.2
        ..strokeCap = StrokeCap.butt,
    );
  }

  arc(const Color(0xFF4285F4), 95, 150); // left, blue
  arc(const Color(0xFF34A853), 55, 40); // bottom, green
  arc(const Color(0xFFFBBC05), 345, 70); // right, yellow
  arc(const Color(0xFFEA4335), 245, 100); // top, red
  c.drawRect(
    const Rect.fromLTWH(16, 14.9, 9.5, 4.2),
    _fill(const Color(0xFF4285F4)),
  );
}

/// xAI's X cut.
void _xai(Canvas c) {
  const color = Color(0xFF06B6D4);
  c.drawLine(const Offset(9.5, 9.5), const Offset(22.5, 22.5),
      _stroke(color, 4.2));
  c.drawLine(const Offset(22.5, 9.5), const Offset(9.5, 22.5),
      _stroke(color, 4.2));
}

/// Meta's infinity loop, as two stroked rings.
void _meta(Canvas c) {
  const color = Color(0xFF14B8A6);
  final ring = _stroke(color, 3);
  c.drawCircle(const Offset(12, 16), 5.4, ring);
  c.drawCircle(const Offset(20, 16), 5.4, ring);
}

/// NVIDIA's eye on its green tile.
void _nvidia(Canvas c) {
  c.drawRRect(_rr(6, 6, 20, 20, 5), _fill(const Color(0xFF84CC16)));
  c.drawPath(
    Path()
      ..moveTo(10, 16)
      ..quadraticBezierTo(16, 10.5, 22, 16)
      ..quadraticBezierTo(16, 21.5, 10, 16),
    _stroke(Colors.white, 2.2),
  );
  c.drawCircle(const Offset(16, 16), 2, _fill(Colors.white));
}

/// Mistral's yellow/orange/red stripe mark.
void _mistral(Canvas c) {
  c.drawRRect(
      _rr(8, 9.5, 16, 3.6, 1.8), _fill(const Color(0xFFFFD800)));
  c.drawRRect(
      _rr(8, 14.2, 16, 3.6, 1.8), _fill(const Color(0xFFFF8205)));
  c.drawRRect(
      _rr(8, 18.9, 16, 3.6, 1.8), _fill(const Color(0xFFE10500)));
}

/// Zhipu's Z cut.
void _zai(Canvas c) {
  c.drawPath(
    Path()
      ..moveTo(9.5, 9.5)
      ..lineTo(22.5, 9.5)
      ..lineTo(9.5, 22.5)
      ..lineTo(22.5, 22.5),
    _stroke(const Color(0xFFD946EF), 4),
  );
}

/// Qwen's Q on its purple tile.
void _qwen(Canvas c) {
  c.drawRRect(_rr(6, 6, 20, 20, 6), _fill(const Color(0xFF8B5CF6)));
  c.drawCircle(const Offset(15.5, 15), 5, _stroke(Colors.white, 2.6));
  c.drawLine(const Offset(19, 18.5), const Offset(22.5, 22),
      _stroke(Colors.white, 2.6));
}

/// DeepSeek's depths, as twin waves on indigo.
void _deepseek(Canvas c) {
  c.drawRRect(_rr(6, 6, 20, 20, 6), _fill(const Color(0xFF6366F1)));
  Path wave(double y) => Path()
    ..moveTo(9.5, y)
    ..cubicTo(12, y - 3.2, 14, y - 3.2, 16.25, y)
    ..cubicTo(18.5, y + 3.2, 20.5, y + 3.2, 22.5, y);
  c.drawPath(wave(13.5), _stroke(Colors.white, 2.2));
  c.drawPath(wave(19), _stroke(Colors.white, 2.2));
}

/// Moonshot's crescent moon on its dark tile.
void _moonshot(Canvas c) {
  const tile = Color(0xFF18181B);
  c.drawRRect(_rr(6, 6, 20, 20, 6), _fill(tile));
  c.drawCircle(const Offset(14.5, 16), 6, _fill(const Color(0xFFFFD21E)));
  c.drawCircle(const Offset(18, 13.8), 5, _fill(tile));
}

/// MiniMax's M cut.
void _minimax(Canvas c) {
  c.drawPath(
    Path()
      ..moveTo(8.5, 23.5)
      ..lineTo(8.5, 9)
      ..lineTo(16, 16.5)
      ..lineTo(23.5, 9)
      ..lineTo(23.5, 23.5),
    _stroke(const Color(0xFFF43F5E), 3.8),
  );
}

/// Xiaomi's orange tile with its MI mark.
void _xiaomi(Canvas c) {
  c.drawRRect(_rr(6, 6, 20, 20, 5), _fill(const Color(0xFFFF6900)));
  final tp = TextPainter(
    text: const TextSpan(
      text: 'MI',
      style: TextStyle(
        color: Colors.white,
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
        height: 1,
        letterSpacing: 0.5,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, Offset(16 - tp.width / 2, 16 - tp.height / 2));
}

/// GitHub's cat head on its dark tile.
void _github(Canvas c) {
  const tile = Color(0xFF24292F);
  c.drawRRect(_rr(6, 6, 20, 20, 6), _fill(tile));
  final head = _fill(Colors.white);
  c.drawPath(
    Path()
      ..moveTo(11.2, 15)
      ..lineTo(12.2, 8.8)
      ..lineTo(16, 12.6)
      ..close(),
    head,
  );
  c.drawPath(
    Path()
      ..moveTo(20.8, 15)
      ..lineTo(19.8, 8.8)
      ..lineTo(16, 12.6)
      ..close(),
    head,
  );
  c.drawCircle(const Offset(16, 17.5), 5.4, head);
}

/// Big Pickle's pickle on green.
void _pickle(Canvas c) {
  c.drawRRect(_rr(6, 6, 20, 20, 6), _fill(const Color(0xFF4C9A2A)));
  c.drawRRect(_rr(13, 9, 6, 14, 3), _fill(const Color(0xFF8FD14F)));
  final speck = _fill(const Color(0xFF2F6B1A));
  c.drawCircle(const Offset(15.2, 13), 0.9, speck);
  c.drawCircle(const Offset(16.8, 16.5), 0.9, speck);
  c.drawCircle(const Offset(14.8, 20), 0.9, speck);
}

/// Laguna's sun-over-wave on cyan.
void _laguna(Canvas c) {
  c.drawRRect(_rr(6, 6, 20, 20, 6), _fill(const Color(0xFF22D3EE)));
  c.drawCircle(const Offset(12.5, 12.5), 2.8, _fill(Colors.white));
  c.drawPath(
    Path()
      ..moveTo(9.5, 19.5)
      ..cubicTo(12, 16.8, 14, 16.8, 16.25, 19.5)
      ..cubicTo(18.5, 22.2, 20.5, 22.2, 22.5, 19.5),
    _stroke(Colors.white, 2.2),
  );
}

/// Fallback: a plain voxel cube outline.
void _fallback(Canvas c) {
  const color = Color(0xFF9CA3AF);
  c.drawRRect(_rr(6, 6, 20, 20, 5), _fill(color.withValues(alpha: 0.25)));
  c.drawRRect(_rr(11, 11, 10, 10, 2), _stroke(color, 2.2));
}
