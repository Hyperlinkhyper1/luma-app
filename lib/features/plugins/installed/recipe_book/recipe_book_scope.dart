import 'package:flutter/widgets.dart';

import 'recipe_book_controller.dart';

class RecipeBookScope extends InheritedNotifier<RecipeBookController> {
  const RecipeBookScope({
    super.key,
    required RecipeBookController controller,
    required super.child,
  }) : super(notifier: controller);

  static RecipeBookController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RecipeBookScope>();
    assert(scope != null, 'RecipeBookScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
