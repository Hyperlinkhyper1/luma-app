import 'package:flutter/widgets.dart';

import 'recipes_repository.dart';

class RecipesScope extends InheritedNotifier<RecipesController> {
  const RecipesScope({
    super.key,
    required RecipesController controller,
    required super.child,
  }) : super(notifier: controller);

  static RecipesController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RecipesScope>();
    assert(scope != null, 'RecipesScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
