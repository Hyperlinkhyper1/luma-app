import 'package:flutter/foundation.dart';

import 'game_process_manager.dart';

/// Tracks which instances currently have a running game process, so any
/// screen (library grid, instance detail) can reflect "Running" state and
/// the live log view can find the handle for an instance it didn't itself
/// launch (e.g. after navigating away and back).
class ActiveLaunchRegistry extends ChangeNotifier {
  ActiveLaunchRegistry._();
  static final ActiveLaunchRegistry instance = ActiveLaunchRegistry._();

  final Map<String, GameProcessHandle> _handles = {};

  GameProcessHandle? handleFor(String instanceId) => _handles[instanceId];
  bool isRunning(String instanceId) => _handles.containsKey(instanceId);

  void register(String instanceId, GameProcessHandle handle) {
    _handles[instanceId] = handle;
    notifyListeners();
    handle.exitCode.whenComplete(() {
      _handles.remove(instanceId);
      notifyListeners();
    });
  }
}
