import 'package:flutter/widgets.dart';

import 'cs2_market_repository.dart';

/// Exposes the shared [Cs2MarketRepository] to the widget tree.
class Cs2MarketScope extends InheritedNotifier<Cs2MarketRepository> {
  const Cs2MarketScope({
    super.key,
    required Cs2MarketRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static Cs2MarketRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<Cs2MarketScope>();
    assert(scope != null, 'Cs2MarketScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
