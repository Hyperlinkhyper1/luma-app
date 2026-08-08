import 'package:flutter/widgets.dart';

import 'gallery_repository.dart';

/// Provides the shared [GalleryRepository] to the Gallery plugin. It is an
/// [InheritedNotifier] rather than a plain scope because the library fills in
/// over time — the scan, then locations, then smart labels — and every screen
/// showing it wants to follow along.
class GalleryScope extends InheritedNotifier<GalleryRepository> {
  const GalleryScope({
    super.key,
    required GalleryRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static GalleryRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GalleryScope>();
    assert(scope != null, 'GalleryScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
