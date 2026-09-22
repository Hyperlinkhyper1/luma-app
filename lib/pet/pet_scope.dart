import 'package:flutter/widgets.dart';

import 'pet_repository.dart';

/// Exposes the app-wide [PetRepository] to the widget tree, following the same
/// scope pattern as every other feature (see `main.dart`).
class PetScope extends InheritedNotifier<PetRepository> {
  const PetScope({
    super.key,
    required PetRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static PetRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PetScope>();
    assert(scope != null, 'No PetScope found in context');
    return scope!.notifier!;
  }

  /// Reads the repository without subscribing to it — for callbacks that only
  /// need to open or close the pet.
  static PetRepository read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<PetScope>();
    assert(scope != null, 'No PetScope found in context');
    return scope!.notifier!;
  }
}
