import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

/// Reads what Ctrl+V should attach to a chat: files copied in Explorer, or
/// a copied picture (a screenshot, an image copied from a browser), which
/// is written to a temporary PNG first. Plain text is left to the text
/// field. Only Windows has a file clipboard Flutter can't see; elsewhere
/// this finds nothing.
class ClipboardFiles {
  ClipboardFiles._();

  static Future<List<File>> read() async {
    if (!Platform.isWindows) return const [];
    final _Clip clip;
    try {
      clip = _readWindows();
    } catch (_) {
      return const [];
    }
    if (clip.paths.isNotEmpty) {
      return [
        for (final path in clip.paths)
          if (FileSystemEntity.isFileSync(path)) File(path),
      ];
    }
    final Uint8List? png = clip.png ?? await _dibToPng(clip.dib);
    if (png == null) return const [];
    final file = File(
      p.join(
        Directory.systemTemp.path,
        'luma-paste-${DateTime.now().microsecondsSinceEpoch}.png',
      ),
    );
    await file.writeAsBytes(png, flush: true);
    return [file];
  }

  static _Clip _readWindows() {
    if (OpenClipboard(NULL) == 0) return const _Clip();
    try {
      if (IsClipboardFormatAvailable(CF_HDROP) != 0) {
        final handle = GetClipboardData(CF_HDROP);
        if (handle != 0) {
          final count = DragQueryFile(handle, 0xFFFFFFFF, nullptr, 0);
          final paths = <String>[];
          for (var i = 0; i < count; i++) {
            final length = DragQueryFile(handle, i, nullptr, 0);
            final buffer = wsalloc(length + 1);
            try {
              DragQueryFile(handle, i, buffer, length + 1);
              paths.add(buffer.toDartString());
            } finally {
              free(buffer);
            }
          }
          if (paths.isNotEmpty) return _Clip(paths: paths);
        }
      }
      final name = 'PNG'.toNativeUtf16();
      final pngFormat = RegisterClipboardFormat(name);
      free(name);
      if (pngFormat != 0 && IsClipboardFormatAvailable(pngFormat) != 0) {
        final bytes = _globalBytes(GetClipboardData(pngFormat));
        if (bytes != null) return _Clip(png: bytes);
      }
      if (IsClipboardFormatAvailable(CF_DIB) != 0) {
        final bytes = _globalBytes(GetClipboardData(CF_DIB));
        if (bytes != null) return _Clip(dib: bytes);
      }
      return const _Clip();
    } finally {
      CloseClipboard();
    }
  }

  static Uint8List? _globalBytes(int clipHandle) {
    final handle = Pointer<NativeType>.fromAddress(clipHandle);
    if (clipHandle == 0) return null;
    final size = GlobalSize(handle);
    if (size <= 0 || size > 64 * 1024 * 1024) return null;
    final pointer = GlobalLock(handle);
    if (pointer == nullptr) return null;
    try {
      return Uint8List.fromList(pointer.cast<Uint8>().asTypedList(size));
    } finally {
      GlobalUnlock(handle);
    }
  }

  static Future<Uint8List?> _dibToPng(Uint8List? dib) async {
    if (dib == null || dib.length < 40) return null;
    return Isolate.run(() => dibToPng(dib));
  }

  /// Turns a CF_DIB block (a BITMAPINFOHEADER and pixels, no file header)
  /// into PNG bytes. Screenshots arrive as 32-bit DIBs whose alpha byte is
  /// all zero, which would decode fully transparent, so such an image is
  /// made opaque.
  static Uint8List? dibToPng(Uint8List dib) {
    final view = ByteData.sublistView(dib);
    final headerSize = view.getUint32(0, Endian.little);
    final bitCount = view.getUint16(14, Endian.little);
    final compression = view.getUint32(16, Endian.little);
    final colorsUsed = headerSize >= 36 ? view.getUint32(32, Endian.little) : 0;
    final colors = colorsUsed != 0
        ? colorsUsed
        : bitCount <= 8
        ? 1 << bitCount
        : 0;
    final masks = headerSize == 40 && compression == 3
        ? 12
        : headerSize == 40 && compression == 6
        ? 16
        : 0;
    final offset = 14 + headerSize + masks + colors * 4;
    final bmp = Uint8List(14 + dib.length);
    ByteData.sublistView(bmp)
      ..setUint8(0, 0x42)
      ..setUint8(1, 0x4D)
      ..setUint32(2, bmp.length, Endian.little)
      ..setUint32(10, offset, Endian.little);
    bmp.setRange(14, bmp.length, dib);
    final decoded = img.decodeBmp(bmp);
    if (decoded == null) return null;
    final image = decoded;
    if (image.numChannels == 4) {
      var anyAlpha = false;
      for (final pixel in image) {
        if (pixel.a != 0) {
          anyAlpha = true;
          break;
        }
      }
      if (!anyAlpha) {
        for (final pixel in image) {
          pixel.a = image.maxChannelValue;
        }
      }
    }
    return img.encodePng(image);
  }
}

class _Clip {
  const _Clip({this.paths = const [], this.png, this.dib});

  final List<String> paths;
  final Uint8List? png;
  final Uint8List? dib;
}
