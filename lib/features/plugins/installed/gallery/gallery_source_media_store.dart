import 'dart:io';
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

import 'gallery_media.dart';
import 'gallery_source.dart';

/// The phone's own media index. MediaStore already knows every photo and
/// video on the device, where it lives and when it was taken, so the gallery
/// asks it rather than walking the filesystem — which scoped storage would
/// not allow anyway.
class MediaStoreGallerySource extends GallerySource {
  /// Assets are kept by id so a thumbnail request doesn't have to re-query.
  final Map<String, AssetEntity> _assets = {};

  /// How many assets to pull over the platform channel at a time. A single
  /// call for a 20 000-photo library stalls the UI isolate for seconds.
  static const _pageSize = 2000;

  @override
  Future<GalleryAccess> requestAccess() async {
    final state = await PhotoManager.requestPermissionExtend();
    return switch (state) {
      PermissionState.authorized => GalleryAccess.granted,
      PermissionState.limited => GalleryAccess.limited,
      _ => GalleryAccess.denied,
    };
  }

  @override
  Future<List<GalleryItem>> load() async {
    final albums = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.common,
      filterOption: FilterOptionGroup(
        orders: const [
          OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );
    if (albums.isEmpty) return const [];

    final all = albums.first;
    final total = await all.assetCountAsync;
    final items = <GalleryItem>[];
    _assets.clear();

    for (var start = 0; start < total; start += _pageSize) {
      final end = (start + _pageSize) > total ? total : start + _pageSize;
      final page = await all.getAssetListRange(start: start, end: end);
      for (final asset in page) {
        _assets[asset.id] = asset;
        items.add(_toItem(asset));
      }
    }
    return items;
  }

  GalleryItem _toItem(AssetEntity asset) {
    final name = (asset.title ?? '').isNotEmpty
        ? asset.title!
        : 'Item ${asset.id}';
    // MediaStore's create date is 0 for the odd file that never had one; the
    // modified date is always there, and a wrong-but-plausible date sorts
    // better than 1970.
    final created = asset.createDateTime;
    final taken = created.millisecondsSinceEpoch <= 0
        ? asset.modifiedDateTime
        : created;
    return GalleryItem(
      id: asset.id,
      name: name,
      type: asset.type == AssetType.video
          ? GalleryMediaType.video
          : GalleryMediaType.image,
      folder: _folderOf(asset),
      takenAt: taken,
      mimeType: asset.mimeType,
      width: asset.width,
      height: asset.height,
      duration: asset.type == AssetType.video
          ? asset.videoDuration
          : Duration.zero,
      latitude: _coordinate(asset.latitude),
      longitude: _coordinate(asset.longitude),
    );
  }

  /// MediaStore hands out a relative path (`DCIM/Camera/`) on Android 10 and
  /// up, and the absolute parent directory below that. Both become the same
  /// root-relative folder so the categories don't care which OS wrote them.
  static String _folderOf(AssetEntity asset) {
    var raw = asset.relativePath ?? '';
    if (raw.isEmpty) return '';
    for (final prefix in _storagePrefixes) {
      if (raw.startsWith(prefix)) {
        raw = raw.substring(prefix.length);
        break;
      }
    }
    // Removable cards mount as /storage/XXXX-XXXX/…, which no fixed prefix
    // covers.
    final card = RegExp(r'^/storage/[A-Za-z0-9-]+/');
    raw = raw.replaceFirst(card, '');
    return normaliseFolder(raw);
  }

  static const _storagePrefixes = [
    '/storage/emulated/0/',
    '/storage/self/primary/',
    '/sdcard/',
  ];

  /// Android returns 0 for "no tag" rather than null, and a photo taken at
  /// exactly 0°N 0°E is in the Atlantic — treat it as missing.
  static double? _coordinate(double? value) =>
      (value == null || value == 0) ? null : value;

  @override
  Future<Uint8List?> thumbnail(GalleryItem item, int pixels) async {
    final asset = _assets[item.id];
    if (asset == null) return null;
    return asset.thumbnailDataWithSize(
      ThumbnailSize.square(pixels),
      quality: 80,
    );
  }

  @override
  Future<String?> resolvePath(GalleryItem item) async {
    if (item.path != null) return item.path;
    final asset = _assets[item.id];
    if (asset == null) return null;
    final file = await asset.file;
    return file?.path;
  }

  @override
  Future<GalleryItem> enrich(GalleryItem item) async {
    if (item.hasLocation) return item;
    final asset = _assets[item.id];
    if (asset == null) return item;
    // Reads the EXIF GPS tag through MediaStore, which needs
    // ACCESS_MEDIA_LOCATION — without that grant every photo comes back
    // redacted and the map stays empty. Byte size is deliberately not
    // fetched here: it costs a file resolution per asset, and only the
    // detail sheet ever shows it.
    final latLng = await asset.latlngAsync();
    final lat = _coordinate(latLng?.latitude);
    final lng = _coordinate(latLng?.longitude);
    if (lat == null || lng == null) return item;
    return item.copyWith(latitude: lat, longitude: lng);
  }

  @override
  Future<int?> fileSize(GalleryItem item) async {
    final path = await resolvePath(item);
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file.lengthSync() : null;
  }

  @override
  bool get canPresentPicker => true;

  @override
  Future<void> presentPicker() => PhotoManager.presentLimited();

  @override
  Future<void> openSettings() => PhotoManager.openSetting();

  @override
  void dispose() {
    _assets.clear();
    PhotoManager.clearFileCache();
  }
}
