import 'package:flutter/widgets.dart';

import 'model_viewer_repository.dart';

class ModelViewerScope extends InheritedWidget {
  const ModelViewerScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final ModelViewerRepository repository;

  static ModelViewerRepository of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ModelViewerScope>()!
      .repository;

  @override
  bool updateShouldNotify(ModelViewerScope oldWidget) =>
      repository != oldWidget.repository;
}
