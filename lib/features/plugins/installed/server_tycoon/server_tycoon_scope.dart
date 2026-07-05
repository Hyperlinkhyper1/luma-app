import 'package:flutter/material.dart';

import 'server_tycoon_repository.dart';

class ServerTycoonScope extends InheritedWidget {
  final ServerTycoonRepository repository;

  const ServerTycoonScope({
    super.key,
    required this.repository,
    required super.child,
  });

  static ServerTycoonRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ServerTycoonScope>();
    assert(scope != null, 'No ServerTycoonScope found in context');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(ServerTycoonScope oldWidget) => repository != oldWidget.repository;
}
