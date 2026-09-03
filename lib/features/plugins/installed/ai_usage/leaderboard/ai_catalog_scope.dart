import 'package:flutter/widgets.dart';

import 'ai_catalog_repository.dart';

/// Exposes the shared [AiCatalogRepository] to the widget tree.
class AiCatalogScope extends InheritedNotifier<AiCatalogRepository> {
  const AiCatalogScope({
    super.key,
    required AiCatalogRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static AiCatalogRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AiCatalogScope>();
    assert(scope != null, 'AiCatalogScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
