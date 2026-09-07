import 'package:flutter/widgets.dart';

import 'mind_map_repository.dart';

class MindMapScope extends InheritedWidget {
  const MindMapScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final MindMapRepository repository;

  static MindMapRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MindMapScope>();
    assert(scope != null, 'MindMapScope was not found in the widget tree');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(MindMapScope oldWidget) =>
      oldWidget.repository != repository;
}
