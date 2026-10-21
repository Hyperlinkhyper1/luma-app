import 'package:flutter/widgets.dart';

import 'command_dashboard_repository.dart';

/// Exposes the shared [CommandDashboardRepository] to the widget tree.
class CommandDashboardScope
    extends InheritedNotifier<CommandDashboardRepository> {
  const CommandDashboardScope({
    super.key,
    required CommandDashboardRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static CommandDashboardRepository of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<CommandDashboardScope>();
    assert(scope != null, 'CommandDashboardScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
