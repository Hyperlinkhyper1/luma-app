import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

/// What a single element on the board is.
///
/// The order matters only for the toolbar; persistence goes through [name].
enum WhiteboardKind {
  pen,
  highlighter,
  line,
  arrow,
  rect,
  ellipse,
  note,
  text;

  static WhiteboardKind parse(String raw) =>
      WhiteboardKind.values.firstWhere(
        (kind) => kind.name == raw,
        orElse: () => WhiteboardKind.pen,
      );

  /// True for the kinds whose geometry is a free path rather than a box.
  bool get isFreehand =>
      this == WhiteboardKind.pen || this == WhiteboardKind.highlighter;

  /// True for the kinds that carry typed text rather than ink.
  bool get isTextual =>
      this == WhiteboardKind.note || this == WhiteboardKind.text;
}

/// One drawn thing, in board (scene) coordinates.
///
/// A single class covers all eight kinds because they only differ in how
/// [points] and [size] are read:
///
/// * freehand — [points] is the whole path, [size] unused.
/// * line / arrow / rect / ellipse — [points] is `[start, end]`, [size] unused.
/// * note — [points] is `[topLeft]` and [size] is the box.
/// * text — [points] is `[topLeft]`, [size] is `(wrapWidth, fontSize)`.
///
/// Keeping them in one shape is what lets move, resize, hit-testing, undo and
/// the painter each have exactly one code path instead of eight.
class WhiteboardElement {
  const WhiteboardElement({
    this.id = 0,
    this.boardId = 0,
    required this.kind,
    required this.points,
    required this.color,
    this.strokeWidth = 3,
    this.filled = false,
    this.text = '',
    this.size = Size.zero,
    this.z = 0,
  });

  final int id;
  final int boardId;
  final WhiteboardKind kind;
  final List<Offset> points;
  final int color;
  final double strokeWidth;
  final bool filled;
  final String text;
  final Size size;
  final int z;

  WhiteboardElement copyWith({
    int? id,
    int? boardId,
    List<Offset>? points,
    int? color,
    double? strokeWidth,
    bool? filled,
    String? text,
    Size? size,
    int? z,
  }) {
    return WhiteboardElement(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      kind: kind,
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      filled: filled ?? this.filled,
      text: text ?? this.text,
      size: size ?? this.size,
      z: z ?? this.z,
    );
  }

  /// Half the ink width — how far the drawn stroke reaches past its points.
  double get _inkMargin =>
      kind.isTextual ? 0 : math.max(strokeWidth, 2) / 2;

  /// The box the points themselves span, before any ink is laid over them.
  Rect get _pointExtent {
    if (kind.isTextual) {
      final origin = points.isEmpty ? Offset.zero : points.first;
      return Rect.fromLTWH(
        origin.dx,
        origin.dy,
        math.max(size.width, 8),
        math.max(
          kind == WhiteboardKind.text ? size.height * 1.4 : size.height,
          8,
        ),
      );
    }
    if (points.isEmpty) return Rect.zero;
    var left = points.first.dx;
    var top = points.first.dy;
    var right = left;
    var bottom = top;
    for (final point in points) {
      left = math.min(left, point.dx);
      top = math.min(top, point.dy);
      right = math.max(right, point.dx);
      bottom = math.max(bottom, point.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// The box the element occupies, ink width included.
  Rect get bounds {
    if (points.isEmpty && !kind.isTextual) return Rect.zero;
    return _pointExtent.inflate(_inkMargin);
  }

  /// Moves every point by [delta]. Text boxes move their origin.
  WhiteboardElement translated(Offset delta) => copyWith(
        points: [for (final point in points) point + delta],
      );

  /// Rescales the element so its [bounds] become [target].
  ///
  /// One implementation serves every kind: freehand paths, two-point shapes
  /// and text boxes are all just points relative to the old box.
  WhiteboardElement resizedTo(Rect target) {
    // Both boxes are measured without the ink so that the element's [bounds]
    // land on [target] exactly. Scaling the inked box instead would leave the
    // result short by half a stroke on each side — an error that grows with
    // the scale factor, so a bold stroke dragged out large visibly lags the
    // handle.
    final current = _pointExtent;
    if (current.width <= 0 || current.height <= 0) return this;
    final destination = _inkMargin == 0
        ? target
        : Rect.fromLTRB(
            target.left + _inkMargin,
            target.top + _inkMargin,
            math.max(target.left + _inkMargin, target.right - _inkMargin),
            math.max(target.top + _inkMargin, target.bottom - _inkMargin),
          );
    final scaleX = destination.width / current.width;
    final scaleY = destination.height / current.height;
    final moved = [
      for (final point in points)
        Offset(
          destination.left + (point.dx - current.left) * scaleX,
          destination.top + (point.dy - current.top) * scaleY,
        ),
    ];
    if (kind == WhiteboardKind.note) {
      return copyWith(points: moved, size: target.size);
    }
    if (kind == WhiteboardKind.text) {
      // Text keeps its font size readable: only the wrap width follows the
      // drag, so resizing reflows the paragraph instead of distorting it.
      return copyWith(points: moved, size: Size(target.width, size.height));
    }
    return copyWith(points: moved);
  }

  /// Whether [probe] lands on this element, within [tolerance] board units.
  ///
  /// Filled shapes and text boxes are hit anywhere inside; outlines are hit
  /// only near the stroke, so you can select something drawn inside a big
  /// empty rectangle.
  bool hitTest(Offset probe, {double tolerance = 8}) {
    final slack = tolerance + strokeWidth / 2;
    switch (kind) {
      case WhiteboardKind.note:
      case WhiteboardKind.text:
        return bounds.inflate(tolerance).contains(probe);
      case WhiteboardKind.pen:
      case WhiteboardKind.highlighter:
      case WhiteboardKind.line:
      case WhiteboardKind.arrow:
        if (points.length == 1) {
          return (points.first - probe).distance <= slack;
        }
        for (var i = 0; i < points.length - 1; i++) {
          if (_distanceToSegment(probe, points[i], points[i + 1]) <= slack) {
            return true;
          }
        }
        return false;
      case WhiteboardKind.rect:
      case WhiteboardKind.ellipse:
        final box = bounds;
        if (!box.inflate(tolerance).contains(probe)) return false;
        if (filled) return true;
        final inner = box.deflate(slack * 2);
        return inner.width <= 0 || inner.height <= 0 || !inner.contains(probe);
    }
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return (p - a).distance;
    final ap = p - a;
    final t =
        ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  /// The JSON payload stored in `BoardElements.data`.
  ///
  /// Points are a flat `[x, y, x, y, ...]` list: a long pen stroke is the
  /// common case and a list of objects would roughly triple its size.
  String encode() {
    final map = <String, Object?>{
      'p': [
        for (final point in points) ...[
          _round(point.dx),
          _round(point.dy),
        ],
      ],
      'c': color,
      'w': _round(strokeWidth),
    };
    if (filled) map['f'] = true;
    if (text.isNotEmpty) map['t'] = text;
    if (size != Size.zero) {
      map['s'] = [_round(size.width), _round(size.height)];
    }
    return jsonEncode(map);
  }

  static WhiteboardElement decode({
    required int id,
    required int boardId,
    required String kind,
    required String data,
    required int z,
  }) {
    final map = jsonDecode(data) as Map<String, dynamic>;
    final flat = (map['p'] as List<dynamic>? ?? const []).cast<num>();
    final points = <Offset>[
      for (var i = 0; i + 1 < flat.length; i += 2)
        Offset(flat[i].toDouble(), flat[i + 1].toDouble()),
    ];
    final rawSize = (map['s'] as List<dynamic>?)?.cast<num>();
    return WhiteboardElement(
      id: id,
      boardId: boardId,
      kind: WhiteboardKind.parse(kind),
      points: points,
      color: (map['c'] as num?)?.toInt() ?? 0xFF000000,
      strokeWidth: (map['w'] as num?)?.toDouble() ?? 3,
      filled: map['f'] as bool? ?? false,
      text: map['t'] as String? ?? '',
      size: rawSize == null || rawSize.length < 2
          ? Size.zero
          : Size(rawSize[0].toDouble(), rawSize[1].toDouble()),
      z: z,
    );
  }

  /// Two decimals is finer than a pixel at maximum zoom and keeps a
  /// thousand-point stroke from bloating the row with float noise.
  static double _round(double value) => (value * 100).roundToDouble() / 100;
}
