import 'package:flutter/widgets.dart';

import 'family_repository.dart';

/// Provides the shared [FamilyRepository] to the widget tree. Consumers
/// listen for changes with `ListenableBuilder` (the repository is a
/// `ChangeNotifier`), the same way `SyncScope`'s `SyncService` is consumed.
class FamilyScope extends InheritedWidget {
  const FamilyScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final FamilyRepository repository;

  static FamilyRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FamilyScope>();
    assert(scope != null, 'FamilyScope was not found in the widget tree');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(FamilyScope oldWidget) =>
      oldWidget.repository != repository;
}
