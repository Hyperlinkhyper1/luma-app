import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/app/native_overlay_decoration.dart';
import 'package:luma/features/plugins/installed/_shared/native_webview.dart';
import 'package:luma/theme/luma_theme.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Paths extends PathProviderPlatform {
  @override
  Future<String> getApplicationSupportPath() async => 'C:/temp/luma-test';
}

void main() {
  test('theme transitions retain native tooltip handling', () {
    for (final progress in [0.0, 0.5, 1.0]) {
      final theme = ThemeData.lerp(LumaTheme.light, LumaTheme.dark, progress);
      expect(theme.tooltipTheme.decoration, isA<NativeOverlayDecoration>());
    }
  });

  for (final implicitTooltip in [false, true]) {
    testWidgets(
      'hover tooltip crossing a webview cuts out its native host (implicit: $implicitTooltip)',
      (tester) async {
        tester.view.devicePixelRatio = 1.5;
        final previousPaths = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _Paths();
        addTearDown(() => PathProviderPlatform.instance = previousPaths);
        tester.view.physicalSize = const Size(1200, 900);
        addTearDown(tester.view.reset);
        final railWidth = ValueNotifier<double>(72);
        addTearDown(railWidth.dispose);
        final calls = <MethodCall>[];
        const channel = MethodChannel('luma/native_webview');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            calls.add(call);
            return call.method == 'create' ? 1 : null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: LumaTheme.dark,
            home: Scaffold(
              body: ValueListenableBuilder<double>(
                valueListenable: railWidth,
                builder: (context, width, _) => Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: width,
                      child: Center(
                        child: implicitTooltip
                            ? IconButton(
                                tooltip: 'Machine Learning Tools',
                                onPressed: () {},
                                icon: const Icon(Icons.extension),
                              )
                            : Tooltip(
                                message: 'Machine Learning Tools',
                                child: IconButton(
                                  onPressed: () {},
                                  icon: const Icon(Icons.extension),
                                ),
                              ),
                      ),
                    ),
                    Expanded(
                      child: NativeWebview(
                        fileUrl: 'file:///test.html',
                        onMessage: (_) {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(36, 300));
        await tester.pumpAndSettle();
        final label = tester.getRect(find.text('Machine Learning Tools'));
        expect(label.right, greaterThan(72));

        final updates = calls.where(
          (call) => call.method == 'setOcclusionRects',
        );
        expect(updates, isNotEmpty);
        final rects = (updates.last.arguments as Map)['rects'] as List;
        expect(rects, hasLength(1));
        final rect = rects.single as Map;
        final nativeCutout = Rect.fromLTWH(
          (rect['x'] as num).toDouble() / 1.5 + 72,
          (rect['y'] as num).toDouble() / 1.5,
          (rect['width'] as num).toDouble() / 1.5,
          (rect['height'] as num).toDouble() / 1.5,
        );
        expect(nativeCutout.contains(label.topLeft), isTrue);
        expect(nativeCutout.contains(label.bottomRight), isTrue);
        expect(
          calls.where((call) => call.method == 'setVisible').last.arguments,
          containsPair('visible', true),
        );
        final focusCount = calls.where((call) => call.method == 'focus').length;

        final updateCount = updates.length;
        await tester.pump();
        expect(updates.length, updateCount);
        railWidth.value = 96;
        await tester.pumpAndSettle();
        final moved =
            ((updates.last.arguments as Map)['rects'] as List).single as Map;
        expect(moved['x'], (rect['x'] as int) - 36);
        expect(moved['radiusX'], greaterThan(0));

        await mouse.moveTo(const Offset(20, 20));
        await tester.pumpAndSettle();
        expect((updates.last.arguments as Map)['rects'], isEmpty);
        expect(
          calls.where((call) => call.method == 'focus').length,
          focusCount,
        );
        await mouse.removePointer();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(NativeOverlayDecoration.hasActivePainters, isFalse);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
