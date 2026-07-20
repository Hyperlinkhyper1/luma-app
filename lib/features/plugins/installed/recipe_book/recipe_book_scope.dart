import 'package:flutter/widgets.dart';

import 'recipe_book_repository.dart';

class RecipeBookScope extends InheritedWidget {
  const RecipeBookScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final RecipeBookRepository repository;

  static RecipeBookRepository of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<RecipeBookScope>();
    assert(scope != null, 'RecipeBookScope was not found in the widget tree');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(RecipeBookScope oldWidget) =>
      oldWidget.repository != repository;
}
