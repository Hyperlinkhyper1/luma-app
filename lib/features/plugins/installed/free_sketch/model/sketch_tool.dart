import 'package:flutter/material.dart';

enum SketchTool {
  brush('Brush', Icons.brush_rounded, 'B'),
  eraser('Eraser', Icons.auto_fix_normal_rounded, 'E'),
  smudge('Smudge', Icons.gesture_rounded, 'S'),
  fill('Fill', Icons.format_color_fill_rounded, 'G'),
  gradient('Gradient', Icons.gradient_rounded, 'D'),
  shape('Shapes', Icons.category_rounded, 'U'),
  select('Selection', Icons.highlight_alt_rounded, 'L'),
  transform('Transform', Icons.open_with_rounded, 'V'),
  eyedropper('Eyedropper', Icons.colorize_rounded, 'I');

  const SketchTool(this.label, this.icon, this.shortcut);

  final String label;
  final IconData icon;
  final String shortcut;

  /// Tools that paint with a brush from the library, each remembering its
  /// own brush — erasing with a soft round while painting with a pencil is
  /// the normal way to work.
  bool get usesBrush => this == brush || this == eraser || this == smudge;

  String get tooltip => '$label ($shortcut)';
}

enum ShapeKind {
  line('Line', Icons.horizontal_rule_rounded),
  rectangle('Rectangle', Icons.crop_square_rounded),
  ellipse('Ellipse', Icons.circle_outlined),
  polygon('Polygon', Icons.pentagon_outlined);

  const ShapeKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum SelectionShape {
  lasso('Lasso', Icons.gesture_rounded),
  rectangle('Rectangle', Icons.crop_square_rounded),
  ellipse('Ellipse', Icons.circle_outlined);

  const SelectionShape(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum SelectionCombine {
  replace('New', Icons.crop_free_rounded),
  add('Add', Icons.add_box_outlined),
  subtract('Subtract', Icons.indeterminate_check_box_outlined);

  const SelectionCombine(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum GradientKind { linear, radial }
