import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/airline_tycoon_page.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/airline_tycoon_repository.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/airline_tycoon_scope.dart';
import 'package:luma/l10n/app_localizations.dart';

class _VisibilityRepository extends AirlineTycoonRepository {
  _VisibilityRepository() : super(autoStart: false, airportMode: true);

  final pages = <Object, bool>{};

  @override
  void setAirportPageVisible(Object page, bool visible) {
    pages[page] = visible;
    super.setAirportPageVisible(page, visible);
  }
}

void main() {
  testWidgets('cached airport tabs report visibility and unregister on close', (
    tester,
  ) async {
    final repo = _VisibilityRepository();
    final selected = ValueNotifier(0);
    addTearDown(repo.dispose);
    addTearDown(selected.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: AirlineTycoonScope(
          repository: repo,
          child: ValueListenableBuilder<int>(
            valueListenable: selected,
            builder: (context, index, child) => IndexedStack(
              index: index,
              children: [
                for (var i = 0; i < 2; i++)
                  TickerMode(
                    enabled: index == i,
                    child: AirlineTycoonPage(key: ValueKey(i)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(repo.pages.values, [true, false]);
    selected.value = 1;
    await tester.pump();
    expect(repo.pages.values, [false, true]);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(repo.pages.values, [false, false]);
  });
}
