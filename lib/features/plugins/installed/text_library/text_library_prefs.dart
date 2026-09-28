import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Which view the plugin opens in. Kept per device on purpose — the library
/// syncs, but whether this machine prefers the Minecraft hall does not.
enum LibraryViewMode { classic, minecraft }

/// The Minecraft view needs the WebGL hosts: WebView2 on Windows and the
/// system WebView on Android. Linux and the web have neither.
bool get minecraftViewSupported =>
    !kIsWeb && (Platform.isWindows || Platform.isAndroid);

Future<File> _file() async {
  final support = await getApplicationSupportDirectory();
  return File('${support.path}${Platform.pathSeparator}text_library_view.txt');
}

Future<LibraryViewMode> loadViewMode() async {
  try {
    final file = await _file();
    if (!await file.exists()) return LibraryViewMode.classic;
    final name = (await file.readAsString()).trim();
    final mode = LibraryViewMode.values.where((m) => m.name == name);
    if (mode.isEmpty) return LibraryViewMode.classic;
    if (mode.first == LibraryViewMode.minecraft && !minecraftViewSupported) {
      return LibraryViewMode.classic;
    }
    return mode.first;
  } catch (_) {
    return LibraryViewMode.classic;
  }
}

Future<void> saveViewMode(LibraryViewMode mode) async {
  try {
    await (await _file()).writeAsString(mode.name);
  } catch (_) {
    // Only the remembered choice is lost.
  }
}
