import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/plugins/plugin_icons.dart';
import '../features/plugins/plugin_repository.dart';

/// Android home-screen widgets: a 1x1 tile per plugin that opens luma
/// straight onto that plugin.
///
/// The widget itself is native (`PluginWidgetProvider.kt`) and cannot draw
/// Flutter icons, so this side paints every installed plugin's icon on the
/// current accent into a PNG and hands the set over. Native code keeps the
/// images and redraws placed widgets whenever the set or the accent changes.
/// Taps come back through [launches] (or [takeLaunchPlugin] on a cold start).
class PluginHomeWidgets {
  PluginHomeWidgets._() {
    if (supported) _channel.setMethodCallHandler(_handleCall);
  }

  static final PluginHomeWidgets instance = PluginHomeWidgets._();

  static const _channel = MethodChannel('luma/home_widgets');

  static const _iconPixels = 192;

  /// Only Android has home-screen widgets luma can place.
  static bool get supported => !kIsWeb && Platform.isAndroid;

  final _launches = StreamController<String>.broadcast();
  String? _lastSignature;
  bool? _canPin;

  /// Plugin ids from widget taps while luma is already running.
  Stream<String> get launches => _launches.stream;

  Future<dynamic> _handleCall(MethodCall call) async {
    if (call.method == 'openPlugin' && call.arguments is String) {
      _launches.add(call.arguments as String);
    }
    return null;
  }

  /// The plugin a widget tap started luma with, if any. Returned once.
  Future<String?> takeLaunchPlugin() async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<String>('takeLaunchPlugin');
    } catch (_) {
      return null;
    }
  }

  /// Whether the launcher accepts "add this widget" requests from the app.
  Future<bool> canPin() async {
    if (!supported) return false;
    if (_canPin != null) return _canPin!;
    try {
      _canPin = await _channel.invokeMethod<bool>('canPin') ?? false;
    } catch (_) {
      _canPin = false;
    }
    return _canPin!;
  }

  /// Asks the launcher to place a widget for [pluginId]. The launcher shows
  /// its own confirmation; false means the request could not be made.
  Future<bool> pin(String pluginId) async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('pin', pluginId) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Redraws every plugin's widget icon on [background] with an [foreground]
  /// glyph. Cheap to call on every build: nothing happens unless the plugin
  /// list or the colors changed since the last call.
  Future<void> sync(
    List<InstalledPluginRecord> plugins, {
    required Color background,
    required Color foreground,
  }) async {
    if (!supported) return;
    final signature = [
      background.toARGB32(),
      foreground.toARGB32(),
      for (final p in plugins) '${p.pluginId}|${p.name}|${p.icon}',
    ].join(';');
    if (signature == _lastSignature) return;
    _lastSignature = signature;
    try {
      final entries = <Map<String, Object>>[];
      for (final p in plugins) {
        entries.add({
          'id': p.pluginId,
          'name': p.name,
          'png': await renderIcon(
            pluginIconFor(p.icon),
            background: background,
            foreground: foreground,
          ),
        });
      }
      if (signature != _lastSignature) return;
      await _channel.invokeMethod<void>('sync', entries);
    } catch (_) {
      if (_lastSignature == signature) _lastSignature = null;
    }
  }

  /// [icon] centred on a rounded square of [background], as PNG bytes.
  @visibleForTesting
  static Future<Uint8List> renderIcon(
    IconData icon, {
    required Color background,
    required Color foreground,
    int size = _iconPixels,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final extent = size.toDouble();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, extent, extent),
        Radius.circular(extent * 0.28),
      ),
      Paint()..color = background,
    );
    final glyph = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: extent * 0.56,
          color: foreground,
          height: 1,
        ),
      ),
    )..layout();
    glyph.paint(
      canvas,
      Offset((extent - glyph.width) / 2, (extent - glyph.height) / 2),
    );
    final image = await recorder.endRecording().toImage(size, size);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}
