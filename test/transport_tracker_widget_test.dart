import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/_shared/windows_webview.dart';
import 'package:luma/features/plugins/installed/transport_tracker/transport_tracker_page.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';
import 'package:webview_windows/webview_windows.dart';

class _MapController extends Fake implements WebviewController {
  final messages = <Map<String, dynamic>>[];

  @override
  Stream<dynamic> get webMessage => const Stream.empty();

  @override
  Future<void> postWebMessage(String message) async {
    messages.add(jsonDecode(message) as Map<String, dynamic>);
  }

  @override
  Future<void> dispose() async {}
}

Widget _app(Locale locale) => MaterialApp(
  locale: locale,
  localizationsDelegates: L.localizationsDelegates,
  supportedLocales: L.supportedLocales,
  theme: LumaTheme.dark,
  home: const Scaffold(body: TransportTrackerPage()),
);

void main() {
  testWidgets(
    'initializes map locale on document load and updates it before mapReady',
    (tester) async {
      // The native surface stays uninitialized; its real host callbacks are
      // driven below with a controller that records messages to the page.
      const channel = MethodChannel('io.jns.webview.win');
      final initialization = Completer<Map<String, Object?>>();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) => initialization.future,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );

      await tester.pumpWidget(_app(const Locale('nl')));
      await tester.pump();
      final view = tester.widget<WindowsWebview>(find.byType(WindowsWebview));
      final controller = _MapController();
      view.onController!(controller);
      view.onLoaded!();
      await tester.pump();

      expect(controller.messages, hasLength(1));
      expect(controller.messages.single['type'], 'luma-locale');
      expect(controller.messages.single['language'], 'nl');
      final context = tester.element(find.byType(TransportTrackerPage));
      expect(controller.messages.single['sourceStrings'], {
        'Transport Tracker': L.of(context).pluginNameTransportTracker,
      });
      expect(
        controller.messages.single['strings'],
        contains('pluginNameTransportTracker'),
      );

      await tester.pumpWidget(_app(const Locale('fr')));
      await tester.pump();
      expect(controller.messages, hasLength(2));
      expect(controller.messages.last['language'], 'fr');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
    skip: !Platform.isWindows,
  );
}
