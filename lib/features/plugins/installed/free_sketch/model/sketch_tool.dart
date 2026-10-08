import 'package:flutter/material.dart';

import '../../../../../l10n/current_l.dart';

enum SketchTool {
  brush(Icons.brush_rounded, 'B'),
  eraser(Icons.auto_fix_normal_rounded, 'E'),
  smudge(Icons.gesture_rounded, 'S'),
  fill(Icons.format_color_fill_rounded, 'G'),
  gradient(Icons.gradient_rounded, 'D'),
  shape(Icons.category_rounded, 'U'),
  select(Icons.highlight_alt_rounded, 'L'),
  transform(Icons.open_with_rounded, 'V'),
  eyedropper(Icons.colorize_rounded, 'I');

  const SketchTool(this.icon, this.shortcut);

  final IconData icon;
  final String shortcut;

  String get label => switch (this) {
        brush => currentL.freeSketchToolBrush,
        eraser => currentL.freeSketchToolEraser,
        smudge => currentL.freeSketchToolSmudge,
        fill => currentL.freeSketchToolFill,
        gradient => currentL.freeSketchToolGradient,
        shape => currentL.freeSketchToolShapes,
        select => currentL.freeSketchToolSelection,
        transform => currentL.freeSketchToolTransform,
        eyedropper => currentL.freeSketchToolEyedropper,
      };

  /// Tools that paint with a brush from the library, each remembering its
  /// own brush — erasing with a soft round while painting with a pencil is
  /// the normal way to work.
  bool get usesBrush => this == brush || this == eraser || this == smudge;

  String get tooltip => '$label ($shortcut)';
}

enum ShapeKind {
  line(Icons.horizontal_rule_rounded),
  rectangle(Icons.crop_square_rounded),
  ellipse(Icons.circle_outlined),
  polygon(Icons.pentagon_outlined);

  const ShapeKind(this.icon);
  final IconData icon;

  String get label => switch (this) {
        line => currentL.freeSketchShapeLine,
        rectangle => currentL.freeSketchShapeRectangle,
        ellipse => currentL.freeSketchShapeEllipse,
        polygon => currentL.freeSketchShapePolygon,
      };
}

enum SelectionShape {
  lasso(Icons.gesture_rounded),
  rectangle(Icons.crop_square_rounded),
  ellipse(Icons.circle_outlined);

  const SelectionShape(this.icon);
  final IconData icon;

  String get label => switch (this) {
        lasso => currentL.freeSketchSelectionLasso,
        rectangle => currentL.freeSketchShapeRectangle,
        ellipse => currentL.freeSketchShapeEllipse,
      };
}

enum SelectionCombine {
  replace(Icons.crop_free_rounded),
  add(Icons.add_box_outlined),
  subtract(Icons.indeterminate_check_box_outlined);

  const SelectionCombine(this.icon);
  final IconData icon;

  String get label => switch (this) {
        replace => currentL.freeSketchSelectionCombineNew,
        add => currentL.freeSketchSelectionCombineAdd,
        subtract => currentL.freeSketchSelectionCombineSubtract,
      };
}

enum GradientKind { linear, radial }
