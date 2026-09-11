import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final kTabs = GlobalKey(debugLabel: 'tabs');
final kStatus = GlobalKey(debugLabel: 'status');
final kSpacer = GlobalKey(debugLabel: 'spacer');
final kRefresh = GlobalKey(debugLabel: 'refresh');
final kGear = GlobalKey(debugLabel: 'gear');

void dump(String name, GlobalKey key) {
  final ctx = key.currentContext;
  if (ctx == null) {
    print('$name: (no ctx)');
    return;
  }
  final ro = ctx.findRenderObject() as RenderBox;
  final tl = ro.localToGlobal(Offset.zero);
  print(
      '$name: left=${tl.dx.toStringAsFixed(1)} right=${(tl.dx + ro.size.width).toStringAsFixed(1)} w=${ro.size.width.toStringAsFixed(1)} h=${ro.size.height.toStringAsFixed(1)}');
}

Future<void> pump({required bool useFix, required WidgetTester tester}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1652, 400);

  final leading = Wrap(
    key: kTabs,
    spacing: 6,
    children: [
      for (final label in ['Today', '7d', '30d', 'All']) _pill(label),
    ],
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Row(
            children: [
              if (useFix)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: leading,
                  ),
                )
              else
                Flexible(child: leading),
              const SizedBox(width: 12),
              Text(
                '302 new turns · 11:38 PM',
                key: kStatus,
                style: const TextStyle(fontSize: 12),
              ),
              Spacer(key: kSpacer),
              IconButton(
                key: kRefresh,
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {},
              ),
              IconButton(
                key: kGear,
                icon: const Icon(Icons.settings_rounded),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  dump('tabs', kTabs);
  dump('status', kStatus);
  dump('spacer', kSpacer);
  dump('refresh', kRefresh);
  dump('gear', kGear);
  print('content right edge should be 1628.0');
}

void main() {
  testWidgets('A: current structure (Flexible + Spacer)', (tester) async {
    await pump(useFix: false, tester: tester);
  });

  testWidgets('B: fix (Expanded+Align + Spacer)', (tester) async {
    await pump(useFix: true, tester: tester);
  });
}

Widget _pill(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(border: Border.all()),
      child: Text(label),
    );
