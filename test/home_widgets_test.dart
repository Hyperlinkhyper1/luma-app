import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/app/home_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('widget icons are square PNGs filled with the accent', () async {
    const accent = Color(0xFF7C5AD9);
    final png = await PluginHomeWidgets.renderIcon(
      Icons.calculate_rounded,
      background: accent,
      foreground: Colors.white,
      size: 64,
    );
    expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);

    final codec = await ui.instantiateImageCodec(png);
    final image = (await codec.getNextFrame()).image;
    expect(image.width, 64);
    expect(image.height, 64);
    final pixels = (await image.toByteData())!;
    int alphaAt(int x, int y) => pixels.getUint8((y * 64 + x) * 4 + 3);
    int redAt(int x, int y) => pixels.getUint8((y * 64 + x) * 4);
    expect(alphaAt(0, 0), lessThan(255), reason: 'corners are rounded off');
    expect(alphaAt(4, 32), 255);
    expect(redAt(4, 32), (accent.r * 255).round());
  });

  test('nothing is sent off Android', () async {
    expect(PluginHomeWidgets.supported, isFalse);
    expect(await PluginHomeWidgets.instance.canPin(), isFalse);
    expect(await PluginHomeWidgets.instance.pin('calculator'), isFalse);
    expect(await PluginHomeWidgets.instance.takeLaunchPlugin(), isNull);
  });
}
