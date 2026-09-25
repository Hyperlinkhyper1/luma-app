import 'package:flutter/widgets.dart';

import 'host_server.dart';

/// Exposes the Host tab's [SftpHostServer] down the tree.
///
/// The server is created in `main.dart` rather than by the plugin page. The
/// app shell builds only the plugin that is on screen, so a server owned by
/// the page died the moment the user opened anything else — dropping every
/// device that was browsing or mid-transfer, while the Host tab promised
/// hosting would last until Stop or until luma closed.
class SftpHostScope extends InheritedWidget {
  const SftpHostScope({
    super.key,
    required this.server,
    required super.child,
  });

  final SftpHostServer server;

  /// The app's host server, or null outside the app (widget tests pump the
  /// page on its own).
  static SftpHostServer? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SftpHostScope>()?.server;

  @override
  bool updateShouldNotify(SftpHostScope oldWidget) =>
      !identical(server, oldWidget.server);
}
