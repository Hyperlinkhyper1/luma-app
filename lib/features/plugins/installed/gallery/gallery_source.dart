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

/// Reports how far a scan has got.
///
/// [done] is how much of the library has been been through, and [total] how
/// much there is where that is knowable — MediaStore says up front, a folder
/// walk cannot know until it has finished. A walk therefore reports the files
/// it has taken in and no total; an index reports its position in the index,
/// which is what the bar should follow even when a confined scan is keeping
/// only a fraction of what it passes.
typedef GalleryScanProgress = void Function(int done, int? total);

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

  /// The whole library, in no particular order — or, when [scanRoot] is set,
  /// only what lives under that one folder.
  ///
  /// [onProgress] is called as the scan goes, often enough for a progress bar
  /// to move and rarely enough not to be the reason the scan is slow.
  Future<List<GalleryItem>> load({GalleryScanProgress? onProgress});

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

  /// Whether the scan can be confined to a single folder. Both real sources
  /// can; they differ only in what a folder is called — an absolute directory
  /// on desktop, a library-relative path like `DCIM/Camera` on the phone.
  bool get supportsScanRoot => false;

  /// The one folder the scan is confined to, everything nested below it
  /// included, or null for the whole library.
  String? get scanRoot => null;

  /// Confines the next scan to [path], or lifts the confinement when null.
  /// Takes effect on the next [load]; the caller rescans.
  Future<void> setScanRoot(String? path) async {}

  /// Called once at startup with the confinement persisted from last time.
  void restoreScanRoot(String? path) {}

  /// Every folder the last scan saw *before* [scanRoot] was applied, so the
  /// picker can still offer the rest of the library while confined. Empty on
  /// sources where the user browses for a directory instead.
  List<String> get knownFolders => const [];

  /// Releases anything the source is holding (decoded thumbnails, caches).
  void dispose() {}
}
