import 'package:flutter/widgets.dart';

import 'calendar_repository.dart';

/// Provides the shared [CalendarRepository] to the Calendar plugin.
class CalendarScope extends InheritedWidget {
  const CalendarScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final CalendarRepository repository;

  static CalendarRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CalendarScope>();
    assert(scope != null, 'CalendarScope was not found in the widget tree');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(CalendarScope oldWidget) =>
      oldWidget.repository != repository;
}
