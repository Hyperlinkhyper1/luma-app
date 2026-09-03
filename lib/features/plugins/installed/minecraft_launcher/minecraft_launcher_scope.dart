import 'package:flutter/widgets.dart';

import 'minecraft_launcher_repository.dart';

/// Provides the shared [MinecraftLauncherRepository] to the Minecraft
/// Launcher plugin.
class MinecraftLauncherScope extends InheritedWidget {
  const MinecraftLauncherScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final MinecraftLauncherRepository repository;

  static MinecraftLauncherRepository of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<MinecraftLauncherScope>();
    assert(scope != null, 'MinecraftLauncherScope was not found in the widget tree');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(MinecraftLauncherScope oldWidget) =>
      oldWidget.repository != repository;
}
