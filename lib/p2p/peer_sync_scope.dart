import 'package:flutter/widgets.dart';

import 'peer_sync_controller.dart';

/// Exposes the [PeerSyncController] down the widget tree. Same InheritedNotifier
/// pattern used by [SettingsScope] and [CloudFilesScope].
class PeerSyncScope extends InheritedNotifier<PeerSyncController> {
  const PeerSyncScope({
    super.key,
    required PeerSyncController controller,
    required super.child,
  }) : super(notifier: controller);

  static PeerSyncController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<PeerSyncScope>();
    assert(scope != null, 'PeerSyncScope not found in widget tree');
    return scope!.notifier!;
  }
}
