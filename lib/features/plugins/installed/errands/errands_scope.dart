import 'package:flutter/widgets.dart';

import 'errands_repository.dart';

/// Provides the shared [ErrandsRepository] to the Errand Manager plugin.
class ErrandsScope extends InheritedWidget {
  const ErrandsScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final ErrandsRepository repository;

  static ErrandsRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ErrandsScope>();
    assert(scope != null, 'ErrandsScope was not found in the widget tree');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(ErrandsScope oldWidget) =>
      repository != oldWidget.repository;
}
