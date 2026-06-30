// Icons are stored as codepoints and rebuilt dynamically, so the const-icon
// lint doesn't apply. Release builds must use `--no-tree-shake-icons`.
// ignore_for_file: non_const_argument_for_const_parameter
import 'package:flutter/widgets.dart';

/// Rebuilds a Material [IconData] from a stored codepoint.
IconData materialIcon(int codepoint) =>
    IconData(codepoint, fontFamily: 'MaterialIcons');
