import 'package:flutter/widgets.dart';

import 'data_management_repository.dart';

/// Provides the shared [DataManagementRepository] to the Data Management plugin.
class DataManagementScope extends InheritedWidget {
  const DataManagementScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final DataManagementRepository repository;

  static DataManagementRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DataManagementScope>();
    assert(scope != null, 'DataManagementScope was not found in the widget tree');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(DataManagementScope oldWidget) =>
      oldWidget.repository != repository;
}
