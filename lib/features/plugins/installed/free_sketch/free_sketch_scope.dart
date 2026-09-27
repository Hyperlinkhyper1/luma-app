import 'package:flutter/widgets.dart';

import 'free_sketch_repository.dart';

class FreeSketchScope extends InheritedWidget {
  const FreeSketchScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final FreeSketchRepository repository;

  static FreeSketchRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FreeSketchScope>();
    assert(scope != null, 'FreeSketchScope was not found in the widget tree');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(FreeSketchScope oldWidget) => oldWidget.repository != repository;
}
