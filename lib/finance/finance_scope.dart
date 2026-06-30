import 'package:flutter/widgets.dart';

import 'finance_repository.dart';

/// Provides the shared [FinanceRepository] to the finance widget subtree.
class FinanceScope extends InheritedWidget {
  const FinanceScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final FinanceRepository repository;

  static FinanceRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FinanceScope>();
    assert(scope != null, 'FinanceScope was not found in the widget tree');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(FinanceScope oldWidget) =>
      oldWidget.repository != repository;
}
