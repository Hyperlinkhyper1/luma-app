import 'package:flutter/widgets.dart';

import 'qr_code_repository.dart';

/// Provides the shared [QrCodeRepository] to the QR Code Generator plugin.
class QrCodeScope extends InheritedWidget {
  const QrCodeScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final QrCodeRepository repository;

  static QrCodeRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<QrCodeScope>();
    assert(scope != null, 'QrCodeScope was not found in the widget tree');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(QrCodeScope oldWidget) =>
      oldWidget.repository != repository;
}
