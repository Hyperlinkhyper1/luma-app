import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/server_tycoon/server_tycoon_page.dart';
import 'package:luma/features/plugins/installed/server_tycoon/server_tycoon_repository.dart';
import 'package:luma/features/plugins/installed/server_tycoon/server_tycoon_scope.dart';
import 'package:luma/storage/storage_guard.dart';
import 'package:luma/theme/luma_theme.dart';

Widget _app(ServerTycoonRepository repo) => MaterialApp(
      theme: LumaTheme.dark,
      home: ServerTycoonScope(
        repository: repo,
        child: const ServerTycoonPage(),
      ),
    );

/// Drags a node by long-pressing it and moving in steps, the way the canvas
/// expects (a plain drag pans the map instead).
Future<void> _dragNode(WidgetTester tester, Finder node, Offset by) async {
  final gesture = await tester.startGesture(tester.getCenter(node));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  // Several samples, mimicking real pointer delivery.
  for (var i = 0; i < 4; i++) {
    await gesture.moveBy(by / 4);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    StorageGuardService.instance = StorageGuardService();
  });

  late ServerTycoonRepository repo;

  setUp(() {
    repo = ServerTycoonRepository();
    // The day timer would otherwise roll days over mid-test.
    repo.pause();
    repo.state.money = 100000;
  });

  tearDown(() => repo.dispose());

  testWidgets('the canvas renders its nodes', (tester) async {
    repo.installService(repo.state.rigs.keys.first, 'STATIC_WEBSITE', 4);
    await tester.pumpWidget(_app(repo));
    await tester.pump();

    expect(find.text('Rig 1'), findsOneWidget);
    expect(find.text('Router 1'), findsOneWidget);
    expect(find.text('Static Website'), findsWidgets);
  });

  testWidgets('long-press dragging a rig commits its new position', (tester) async {
    await tester.pumpWidget(_app(repo));
    await tester.pump();

    final rigId = repo.state.rigs.keys.first;
    final before = repo.state.rigs[rigId]!.pos;

    await _dragNode(tester, find.text('Rig 1'), const Offset(120, 80));

    final after = repo.state.rigs[rigId]!.pos;
    expect(after.x, isNot(before.x), reason: 'the drag should have been committed');
    expect(after.y, isNot(before.y));
  });

  testWidgets('a dragged service node keeps the position it was dropped at', (tester) async {
    repo.installService(null, 'STATIC_WEBSITE', 1);
    await tester.pumpWidget(_app(repo));
    await tester.pump();

    final instanceId = repo.state.services.keys.first;
    final before = repo.state.services[instanceId]!.pos;

    await _dragNode(tester, find.text('Static Website').first, const Offset(100, 60));

    final after = repo.state.services[instanceId]!.pos;
    expect(after.x, isNot(before.x));
    expect(after.y, isNot(before.y));
  });

  testWidgets('the tile tracks the finger while the drag is in flight', (tester) async {
    await tester.pumpWidget(_app(repo));
    await tester.pump();

    final rigId = repo.state.rigs.keys.first;
    final start = tester.getTopLeft(find.text('Rig 1'));

    final gesture = await tester.startGesture(tester.getCenter(find.text('Rig 1')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

    const step = Offset(60, 40);
    await gesture.moveBy(step);
    await tester.pump(const Duration(milliseconds: 16));

    // The tile must have moved with the finger on the very next frame, not
    // lagged behind it or waited for the drag to finish.
    final moved = tester.getTopLeft(find.text('Rig 1'));
    expect(moved.dx - start.dx, moreOrLessEquals(step.dx, epsilon: 1));
    expect(moved.dy - start.dy, moreOrLessEquals(step.dy, epsilon: 1));
    // Nothing is committed until release.
    expect(repo.state.rigs[rigId]!.pos.x, 380);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
  });
}
