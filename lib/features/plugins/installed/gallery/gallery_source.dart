import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import 'gallery_media.dart';
import 'gallery_source_folders.dart';
import 'gallery_source_media_store.dart';

/// How much of the library this device is willing to show us.
enum GalleryAccess {
  /// Everything.
  granted,

  /// Android 14 / iOS "selected photos only": a real library, just a subset
  /// of one. The gallery works exactly the same, with an affordance to hand
  /// it more.
  limited,

  /// Asked and refused. Only the system settings can undo this.
  denied,

  /// Nothing to ask — no media index on this platform.
  unsupported,
}

/// Where a build gets its photos and videos from. Two implementations:
/// [MediaStoreGallerySource] on the phone, where the OS keeps the index, and
/// [FolderGallerySource] on desktop, where we walk the picture folders
/// ourselves.
abstract class GallerySource {
  GallerySource();

  /// Picks the implementation for the platform this build is running on.
  factory GallerySource.forPlatform() {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return MediaStoreGallerySource();
    }
    return FolderGallerySource();
  }

  /// Asks for whatever grant this platform needs. Safe to call repeatedly —
  /// once a decision exists the OS returns it without prompting again.
  Future<GalleryAccess> requestAccess();

  /// The whole library, in no particular order.
  Future<List<GalleryItem>> load();

  /// A square-ish thumbnail of at most [pixels] on the long edge, or null if
  /// one can't be made (a video on desktop, a corrupt file).
  Future<Uint8List?> thumbnail(GalleryItem item, int pixels);

  /// The file behind [item], materialising it if the platform hands out ids
  /// rather than paths. Null when it can't be resolved.
  Future<String?> resolvePath(GalleryItem item);

  /// Reads [item]'s GPS tag, the one thing the index doesn't carry. Returns
  /// [item] unchanged when there is no tag to read. Called once per file by a
  /// background pass, so it must not do more work than that.
  Future<GalleryItem> enrich(GalleryItem item);

  /// The file's size on disk, looked up only when something is about to show
  /// it. Null when the file can't be resolved.
  Future<int?> fileSize(GalleryItem item) async => item.sizeBytes;

  /// Whether the user can widen a [GalleryAccess.limited] grant from inside
  /// the app.
  bool get canPresentPicker => false;

  /// Shows the system "select more photos" sheet.
  Future<void> presentPicker() async {}

  /// Opens the OS settings page for this app, the only way back from a
  /// permanently denied grant. No-op where there is nothing to open.
  Future<void> openSettings() async {}

  /// Whether this source lets the user point the gallery at extra folders.
  bool get supportsCustomFolders => false;

  /// Folders being scanned, and the two calls that change that set. Only
  /// meaningful when [supportsCustomFolders].
  List<String> get roots => const [];
  Future<void> addRoot(String path) async {}
  Future<void> removeRoot(String path) async {}

  /// Called once at startup with the roots persisted from last time.
  void restoreRoots(List<String> paths) {}

  /// Releases anything the source is holding (decoded thumbnails, caches).
  void dispose() {}
}
