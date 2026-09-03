import 'package:flutter/widgets.dart';

import 'steam_repository.dart';

/// Exposes the shared [SteamRepository] to the widget tree.
class SteamScope extends InheritedNotifier<SteamRepository> {
  const SteamScope({
    super.key,
    required SteamRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static SteamRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SteamScope>();
    assert(scope != null, 'SteamScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
