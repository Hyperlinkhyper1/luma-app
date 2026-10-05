import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/app/lazy_indexed_stack.dart';

void main() {
  testWidgets('opening Home does not initialize the other sections', (
    tester,
  ) async {
    final started = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: LazyIndexedStack(
          children: [
            _Page('Home', started),
            _Page('Assistant', started),
            _Page('Settings', started),
          ],
        ),
      ),
    );

    expect(started, ['Home']);
    expect(find.text('Home: 0'), findsOneWidget);
  });

  testWidgets('visiting another section preserves the previous page state', (
    tester,
  ) async {
    final started = <String>[];
    var index = 0;
    late StateSetter select;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            select = setState;
            return LazyIndexedStack(
              index: index,
              children: [_Page('Home', started), _Page('Assistant', started)],
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Home: 0'));
    await tester.pump();
    select(() => index = 1);
    await tester.pump();
    expect(started, ['Home', 'Assistant']);
    expect(find.text('Assistant: 0'), findsOneWidget);
    select(() => index = 0);
    await tester.pump();
    expect(find.text('Home: 1'), findsOneWidget);
    expect(started, ['Home', 'Assistant']);
  });

  testWidgets('an active plugin does not initialize an unvisited fixed page', (
    tester,
  ) async {
    final started = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: LazyIndexedStack(
          index: null,
          children: [_Page('Home', started), _Page('Assistant', started)],
        ),
      ),
    );

    expect(started, isEmpty);
  });

  testWidgets('a visited page stops scheduling animation frames when hidden', (
    tester,
  ) async {
    final started = <String>[];
    int? index = 1;
    late StateSetter select;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            select = setState;
            return LazyIndexedStack(
              index: index,
              children: [
                _Page('Home', started),
                const Center(child: CircularProgressIndicator()),
              ],
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);

    select(() => index = 0);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('Home: 0'), findsOneWidget);

    select(() => index = null);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Page extends StatefulWidget {
  const _Page(this.name, this.started);

  final String name;
  final List<String> started;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  var count = 0;

  @override
  void initState() {
    super.initState();
    widget.started.add(widget.name);
  }

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => setState(() => count++),
      child: Text('${widget.name}: $count'),
    ),
  );
}
