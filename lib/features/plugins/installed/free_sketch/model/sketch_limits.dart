import 'package:flutter/foundation.dart';

/// How much GPU memory a document may use. Every layer and every undo step
/// is a full canvas-sized texture, and a phone shares a few gigabytes between
/// the GPU, the OS and every other app, so it gets a far smaller share than
/// a desktop with dedicated video memory.
class SketchLimits {
  const SketchLimits._();

  static bool get _mobile =>
      defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  /// Images held only by undo history before the oldest steps are dropped.
  static int get historyBytes => (_mobile ? 320 : 900) * 1024 * 1024;

  /// Pixels all layers together may occupy.
  static int get layerBytes => (_mobile ? 480 : 1200) * 1024 * 1024;

  static int maxLayers(int width, int height) => (layerBytes ~/ (width * height * 4)).clamp(6, 100);
}
