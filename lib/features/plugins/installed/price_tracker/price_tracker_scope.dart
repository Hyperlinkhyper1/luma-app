import 'package:flutter/widgets.dart';

import 'price_tracker_repository.dart';

class PriceTrackerScope extends InheritedNotifier<PriceTrackerRepository> {
  const PriceTrackerScope({
    super.key,
    required PriceTrackerRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static PriceTrackerRepository of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<PriceTrackerScope>();
    assert(scope != null, 'PriceTrackerScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
