import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/chat/widgets/assistant_sidebar_transition.dart';

void main() {
  testWidgets(
    'collapse retains sidebar content and width throughout animation',
    (tester) async {
      final open = ValueNotifier(true);
      final controller = TextEditingController(text: 'keep my search');
      addTearDown(open.dispose);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: open,
              builder: (context, value, _) => Row(
                children: [
                  AssistantSidebarTransition(
                    open: value,
                    child: Column(
                      children: [TextField(controller: controller)],
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        ),
      );
      final field = tester.element(find.byType(TextField));
      open.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.getSize(find.byType(TextField)).width, 264);
      expect(
        tester.getSize(find.byType(AssistantSidebarTransition)).width,
        inExclusiveRange(0, 264),
      );
      expect(tester.element(find.byType(TextField)), same(field));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AssistantSidebarTransition)).width, 0);
      open.value = true;
      await tester.pumpAndSettle();
      expect(controller.text, 'keep my search');
      expect(tester.element(find.byType(TextField)), same(field));
    },
  );
}
