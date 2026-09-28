import 'package:flutter/widgets.dart';

import 'text_library_repository.dart';

class TextLibraryScope extends InheritedWidget {
  const TextLibraryScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final TextLibraryRepository repository;

  static TextLibraryRepository of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<TextLibraryScope>();
    assert(scope != null, 'TextLibraryScope was not found in the widget tree');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(TextLibraryScope oldWidget) =>
      oldWidget.repository != repository;
}
