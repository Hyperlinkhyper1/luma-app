import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/home/dashboard_tiles.dart';
import 'package:luma/features/home/home_layout.dart';
import 'package:luma/features/notes/notes_repository.dart';
import 'package:luma/features/plugins/plugin_repository.dart';
import 'package:luma/features/plugins/plugin_scope.dart';
import 'package:luma/theme/luma_theme.dart';

class _InstalledCalculator implements PluginRepository {
  @override
  Stream<List<InstalledPluginRecord>> watchInstalled() => Stream.value([
    InstalledPluginRecord(
      pluginId: 'calculator',
      name: 'Calculator',
      icon: 'calculate',
      version: '1',
      installedAt: DateTime(2026),
      downloadCount: 1,
    ),
  ]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

HomeTile tile(
  String kind, {
  String? id,
  Map<String, dynamic> config = const {},
}) => HomeTile(
  id: id ?? kind,
  kind: kind,
  x: 0,
  y: 0,
  w: 6,
  h: 6,
  config: config,
);

Widget host(HomeTile value) => MaterialApp(
  theme: ThemeData(extensions: const [LumaPalette.light]),
  home: Scaffold(
    body: PluginScope(
      repository: _InstalledCalculator(),
      child: SizedBox(
        width: 500,
        height: 550,
        child: DashboardTileContent(
          tile: value,
          onNavigate: (_) {},
          onPlugin: (_) {},
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('timer signals completion while another page is open', (
    tester,
  ) async {
    var alerts = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemSound.play' &&
            call.arguments == 'SystemSoundType.alert') {
          alerts++;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final timer = tile('timer', id: 'background-timer', config: {'minutes': 1});
    await tester.pumpWidget(host(timer));
    await tester.tap(find.text('Start'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
    expect(alerts, 1);
    await tester.pumpWidget(host(timer));
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('Time is up. Take a breath.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('note checkboxes change the shared note content', (tester) async {
    final repo = NotesRepository.instance;
    await tester.runAsync(
      () => repo.importData([
        {
          'id': 'dashboard-note',
          'title': 'Packing',
          'content': '[ ] Charger\nPlain text\n[x] Passport',
          'updatedAt': DateTime(2026).toIso8601String(),
        },
      ]),
    );
    await tester.pumpWidget(
      host(tile('note', config: {'noteId': 'dashboard-note'})),
    );
    expect(find.text('Packing'), findsOneWidget);
    expect(find.text('Plain text'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(repo.notes.single.content, '[x] Charger\nPlain text\n[x] Passport');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('calculator evaluates expressions and previous answer', (
    tester,
  ) async {
    await tester.pumpWidget(host(tile('calculator')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '(42 + 8) / 2');
    await tester.tap(find.text('='));
    await tester.pump();
    expect(find.text('25'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ans * 2');
    await tester.tap(find.text('='));
    await tester.pump();
    expect(find.text('50'), findsOneWidget);
  });

  testWidgets('timer survives leaving home and supports pause and reset', (
    tester,
  ) async {
    final timer = tile('timer', id: 'navigation-timer', config: {'minutes': 3});
    await tester.pumpWidget(host(timer));
    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host(timer));
    expect(find.text('Pause'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Start'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(find.text('03:00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('invalid remote configuration falls back without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(host(tile('note', config: {'noteId': 123})));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      host(tile('timer', id: 'invalid-timer', config: {'minutes': 'oops'})),
    );
    expect(find.text('25:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
