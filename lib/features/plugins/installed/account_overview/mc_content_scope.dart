import 'package:flutter/widgets.dart';

import 'mc_content_repository.dart';

/// Exposes the shared [McContentRepository] to the widget tree.
class McContentScope extends InheritedNotifier<McContentRepository> {
  const McContentScope({
    super.key,
    required McContentRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static McContentRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<McContentScope>();
    assert(scope != null, 'McContentScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
