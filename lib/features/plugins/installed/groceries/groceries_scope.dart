import 'package:flutter/widgets.dart';

import 'groceries_api.dart';
import 'groceries_repository.dart';

/// Exposes the shared [GroceriesRepository] (local lists/items) to the
/// Groceries plugin's widget tree.
class GroceriesScope extends InheritedWidget {
  const GroceriesScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final GroceriesRepository repository;

  static GroceriesRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GroceriesScope>();
    assert(scope != null, 'GroceriesScope was not found in the widget tree');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(GroceriesScope oldWidget) =>
      oldWidget.repository != repository;
}

/// Exposes the shared [GroceriesApi] (remote product search client) to the
/// Groceries plugin's widget tree.
class GroceriesApiScope extends InheritedNotifier<GroceriesApi> {
  const GroceriesApiScope({
    super.key,
    required GroceriesApi api,
    required super.child,
  }) : super(notifier: api);

  static GroceriesApi of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GroceriesApiScope>();
    assert(scope != null, 'GroceriesApiScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
