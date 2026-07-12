import 'package:flutter/widgets.dart';

import 'wifi_speed_test_repository.dart';

class WifiSpeedTestScope extends InheritedNotifier<WifiSpeedTestRepository> {
  const WifiSpeedTestScope({
    super.key,
    required WifiSpeedTestRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static WifiSpeedTestRepository of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<WifiSpeedTestScope>();
    assert(scope != null, 'WifiSpeedTestScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
