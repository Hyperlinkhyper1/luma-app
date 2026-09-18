import 'package:flutter/widgets.dart';

import 'home_repository.dart';

class HomeScope extends InheritedNotifier<HomeRepository> {
  const HomeScope({
    super.key,
    required HomeRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static HomeRepository of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeScope>()!.notifier!;
}
