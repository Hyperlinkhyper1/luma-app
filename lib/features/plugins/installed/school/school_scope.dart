import 'package:flutter/widgets.dart';

import 'school_repository.dart';

/// Provides the shared [SchoolRepository] to the School plugin.
class SchoolScope extends InheritedWidget {
  const SchoolScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final SchoolRepository repository;

  static SchoolRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SchoolScope>();
    assert(scope != null, 'SchoolScope was not found in the widget tree');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(SchoolScope oldWidget) =>
      oldWidget.repository != repository;
}
