import 'package:flutter/widgets.dart';

import 'whiteboard_repository.dart';

class WhiteboardScope extends InheritedWidget {
  const WhiteboardScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final WhiteboardRepository repository;

  static WhiteboardRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<WhiteboardScope>();
    assert(scope != null, 'WhiteboardScope was not found in the widget tree');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(WhiteboardScope oldWidget) =>
      oldWidget.repository != repository;
}
