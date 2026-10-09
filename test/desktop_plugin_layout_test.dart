import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/app/widgets.dart';
import 'package:luma/features/plugins/installed/small_games/small_games_page.dart';
import 'package:luma/features/plugins/installed/smart_home/smart_home_page.dart';
import 'package:luma/features/plugins/installed/smart_home/smart_home_repository.dart';
import 'package:luma/features/plugins/installed/smart_home/smart_home_scope.dart';
import 'package:luma/features/plugins/installed/wifi_speed_test/wifi_speed_test_page.dart';
import 'package:luma/features/plugins/installed/wifi_speed_test/wifi_speed_test_repository.dart';
import 'package:luma/features/plugins/installed/wifi_speed_test/wifi_speed_test_scope.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';

class _SmartHome extends SmartHomeRepository {
  @override
  bool get loading => false;
  @override
  Future<void> discoverHubs() async {}
}

Widget _host(Widget body) => MaterialApp(
  theme: LumaTheme.dark,
  localizationsDelegates: L.localizationsDelegates,
  supportedLocales: L.supportedLocales,
  home: Scaffold(body: body),
);

void main() {
  testWidgets(
    'Speed Test places history beside its gauge on desktop and stacks on a phone',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = WifiSpeedTestRepository();
      await tester.pumpWidget(
        _host(
          WifiSpeedTestScope(
            repository: repository,
            child: const WifiSpeedTestPage(),
          ),
        ),
      );
      final gauge = tester.getRect(find.byType(LumaCard).first);
      final history = tester.getTopLeft(find.text('History'));
      expect(gauge.left, 24);
      expect(history.dx, greaterThan(gauge.right));
      expect(history.dy, lessThan(gauge.bottom));
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(390, 900);
      await tester.pump();
      expect(
        tester.getTopLeft(find.text('History')).dy,
        greaterThan(tester.getRect(find.byType(LumaCard).first).bottom),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      repository.dispose();
    },
  );
  testWidgets('Small Games uses a wide left-aligned desktop column', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(const SmallGamesPage()));
    final card = tester.getRect(find.byType(LumaCard).first);
    expect(card.left, 24);
    expect(card.width, 1440);
    expect(find.text('BINGO'), findsOneWidget);
    expect(find.text('Card Games'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Smart Home connection fills a wide left-aligned desktop column',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _SmartHome();
      await tester.pumpWidget(
        _host(
          SmartHomeScope(repository: repository, child: const SmartHomePage()),
        ),
      );
      final card = tester.getRect(find.byType(LumaCard).first);
      expect(card.left, 24);
      expect(card.width, 1440);
      expect(find.text('Connect a DIRIGERA hub'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      repository.dispose();
    },
  );
}
