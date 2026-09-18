import 'package:flutter/widgets.dart';

import 'airline_tycoon_repository.dart';

class AirlineTycoonScope extends InheritedNotifier<AirlineTycoonRepository> {
  const AirlineTycoonScope({
    super.key,
    required this.repository,
    required super.child,
  }) : super(notifier: repository);

  final AirlineTycoonRepository repository;

  static AirlineTycoonRepository of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AirlineTycoonScope>();
    assert(scope != null, 'No AirlineTycoonScope found in context');
    return scope!.repository;
  }
}
