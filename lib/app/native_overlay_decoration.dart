import 'package:flutter/rendering.dart';

/// Marks Flutter tooltip backgrounds that must remain above native windows.
class NativeOverlayDecoration extends Decoration {
  const NativeOverlayDecoration(this.decoration);

  final BoxDecoration decoration;
  static int _painters = 0;

  /// No render-tree traversal is needed when there are no painted tooltips.
  static bool get hasActivePainters => _painters > 0;

  /// Uses render transforms so overlay portals, scrolling and DPI keep working.
  static List<RRect> regionsIn(RenderObject root) {
    if (!hasActivePainters) return const [];
    final regions = <RRect>[];
    void visit(RenderObject object) {
      if (!object.attached ||
          (object is RenderOffstage && object.offstage) ||
          (object is RenderOpacity && object.opacity == 0) ||
          (object is RenderAnimatedOpacity && object.opacity.value == 0)) {
        return;
      }
      if (object is RenderDecoratedBox &&
          object.hasSize &&
          !object.size.isEmpty &&
          object.decoration is NativeOverlayDecoration) {
        final marker = object.decoration as NativeOverlayDecoration;
        final rect = MatrixUtils.transformRect(
          object.getTransformTo(null),
          Offset.zero & object.size,
        );
        final radius = marker.decoration.borderRadius
            ?.resolve(object.configuration.textDirection)
            .topLeft;
        regions.add(
          RRect.fromRectAndRadius(
            rect,
            Radius.elliptical(
              (radius?.x ?? 0) * rect.width / object.size.width,
              (radius?.y ?? 0) * rect.height / object.size.height,
            ),
          ),
        );
        return;
      }
      object.visitChildren(visit);
    }

    visit(root);
    return regions;
  }

  @override
  EdgeInsetsGeometry get padding => decoration.padding;

  @override
  bool get isComplex => decoration.isComplex;

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) =>
      decoration.getClipPath(rect, textDirection);

  @override
  bool hitTest(Size size, Offset position, {TextDirection? textDirection}) =>
      decoration.hitTest(size, position, textDirection: textDirection);

  @override
  Decoration? lerpFrom(Decoration? a, double t) {
    if (a == null || a is NativeOverlayDecoration) {
      return NativeOverlayDecoration(
        BoxDecoration.lerp(
          (a as NativeOverlayDecoration?)?.decoration,
          decoration,
          t,
        )!,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  Decoration? lerpTo(Decoration? b, double t) {
    if (b == null || b is NativeOverlayDecoration) {
      return NativeOverlayDecoration(
        BoxDecoration.lerp(
          decoration,
          (b as NativeOverlayDecoration?)?.decoration,
          t,
        )!,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _NativeOverlayPainter(decoration.createBoxPainter(onChanged), onChanged);

  @override
  bool operator ==(Object other) =>
      other is NativeOverlayDecoration && other.decoration == decoration;

  @override
  int get hashCode => Object.hash(NativeOverlayDecoration, decoration);
}

class _NativeOverlayPainter extends BoxPainter {
  _NativeOverlayPainter(this.painter, super.onChanged) {
    NativeOverlayDecoration._painters++;
  }

  final BoxPainter painter;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) =>
      painter.paint(canvas, offset, configuration);

  @override
  void dispose() {
    NativeOverlayDecoration._painters--;
    painter.dispose();
    super.dispose();
  }
}
