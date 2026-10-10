import 'package:flutter/widgets.dart';

import 'team_clipboard_controller.dart';

class TeamClipboardScope extends InheritedNotifier<TeamClipboardController> {
  const TeamClipboardScope({
    super.key,
    required TeamClipboardController controller,
    required super.child,
  }) : super(notifier: controller);

  static TeamClipboardController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<TeamClipboardScope>();
    assert(
      scope != null,
      'TeamClipboardScope was not found in the widget tree',
    );
    return scope!.notifier!;
  }

  /// The controller without listening to it, for callbacks.
  static TeamClipboardController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<TeamClipboardScope>();
    assert(
      scope != null,
      'TeamClipboardScope was not found in the widget tree',
    );
    return scope!.notifier!;
  }
}
