import 'package:flutter/widgets.dart';

import 'password_repository.dart';

/// Provides the shared [PasswordRepository] to the password manager subtree.
class PasswordScope extends InheritedWidget {
  const PasswordScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final PasswordRepository repository;

  static PasswordRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PasswordScope>();
    assert(scope != null, 'PasswordScope was not found in the widget tree');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(PasswordScope oldWidget) =>
      oldWidget.repository != repository;
}
