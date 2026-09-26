import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/chat/chat_usage.dart';
import 'package:luma/features/chat/data/chat_repository.dart';
import 'package:luma/features/chat/providers/ai_client.dart';
import 'package:luma/features/chat/widgets/chat_bubble.dart';
import 'package:luma/features/chat/widgets/chat_input_bar.dart';
import 'package:luma/features/chat/widgets/chat_markdown.dart';
import 'package:luma/features/chat/widgets/chat_moon.dart';
import 'package:luma/features/chat/widgets/chat_usage_meter.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';

Widget _host(Widget child) => MaterialApp(
  theme: LumaTheme.dark,
  localizationsDelegates: L.localizationsDelegates,
  supportedLocales: L.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('composer sends on Enter and keeps Shift+Enter as a newline', (
    tester,
  ) async {
    final sent = <String>[];
    await tester.pumpWidget(
      _host(
        ChatInputBar(
          onSend: sent.add,
          sending: false,
          enabled: true,
          caption: 'usage caption',
          modelSelector: const Text('Model'),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(sent, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sent, ['hello']);
    expect(find.text('usage caption'), findsOneWidget);
    expect(find.text('Model'), findsOneWidget);
  });

  testWidgets('blocked composer shows the out-of-messages hint', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatInputBar(
          onSend: (_) {},
          sending: false,
          enabled: false,
          caption: '',
          modelSelector: const SizedBox(),
        ),
      ),
    );
    expect(find.text("You're out of messages for now"), findsOneWidget);
  });

  testWidgets('markdown renders code blocks, lists and keeps line breaks', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SingleChildScrollView(
          child: ChatMarkdown(
            source:
                '## Title\nfirst line\nsecond line\n\n- one\n- **two**\n\n'
                '```dart\nprint(1);\n```',
          ),
        ),
      ),
    );

    expect(find.text('dart'), findsOneWidget);
    expect(find.text('print(1);'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.textContaining('first line\nsecond line'), findsOneWidget);
    expect(find.text('•'), findsNWidgets(2));
  });

  testWidgets('user turns are bubbles; assistant turns show a copy action', (
    tester,
  ) async {
    ChatMessageRecord message(int id, String role, String content) =>
        ChatMessageRecord(
          id: id,
          conversationId: 1,
          role: role,
          content: content,
          createdAt: DateTime(2026),
        );

    await tester.pumpWidget(
      _host(
        Column(
          children: [
            ChatBubble(
              message: message(1, 'user', 'hi there'),
              onOpenQrPlugin: () {},
            ),
            ChatBubble(
              message: message(2, 'assistant', 'hello **friend**'),
              onOpenQrPlugin: () {},
              isLast: true,
            ),
          ],
        ),
      ),
    );

    expect(find.text('hi there'), findsOneWidget);
    expect(find.byIcon(Icons.content_copy_rounded), findsNWidgets(2));
    expect(find.byTooltip('Copy'), findsNWidgets(2));
  });

  group('reply usage', () {
    ChatMessageRecord assistant(int id, String? metadataJson) =>
        ChatMessageRecord(
          id: id,
          conversationId: 1,
          role: 'assistant',
          content: 'reply',
          createdAt: DateTime(2026),
          metadataJson: metadataJson,
        );

    test('is stored next to existing metadata and read back', () {
      final json = chatMetadataWithUsage(
        '{"qrUrl":"https://luma.test/qr"}',
        const AiTokenUsage(
          model: 'm',
          inputTokens: 900,
          cacheReadTokens: 100,
          outputTokens: 24,
        ),
      );
      expect(jsonDecode(json!)['qrUrl'], 'https://luma.test/qr');

      final usage = ChatReplyUsage.latest([
        assistant(
          1,
          chatMetadataWithUsage(null, const AiTokenUsage(model: 'old')),
        ),
        assistant(2, json),
        assistant(3, null),
      ])!;
      expect(usage.model, 'm');
      expect(usage.inputTokens, 1000);
      expect(usage.contextTokens, 1024);
    });

    test('is absent when no reply carries it', () {
      expect(ChatReplyUsage.latest([assistant(1, null)]), isNull);
      expect(chatMetadataWithUsage('{"a":1}', null), '{"a":1}');
    });

    test('compact token counts read like the Claude app', () {
      expect(compactTokens(512), '512');
      expect(compactTokens(1016), '1.0k');
      expect(compactTokens(179800), '180k');
      expect(compactTokens(1048576), '1.0M');
      expect(compactTokens(2000000), '2M');
    });
  });

  testWidgets('usage meter opens a panel with context, limits and last reply', (
    tester,
  ) async {
    var openedBreakdown = false;
    await tester.pumpWidget(
      _host(
        Center(
          child: ChatUsageMeter(
            contextWindow: 8192,
            lastReply: const ChatReplyUsage(
              model: 'Qwen',
              inputTokens: 1000,
              outputTokens: 24,
            ),
            limits: const [
              ChatUsageLimit(
                label: '5-hour limit',
                detail: '13%',
                fraction: 0.13,
              ),
            ],
            limitsTitle: 'Usage limits · Luma AI',
            onOpenBreakdown: () => openedBreakdown = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Usage'));
    await tester.pumpAndSettle();

    expect(find.text('Context window'), findsOneWidget);
    expect(find.text('1.0k / 8.2k (13%)'), findsOneWidget);
    expect(find.text('Usage limits · Luma AI'), findsOneWidget);
    expect(find.text('5-hour limit'), findsOneWidget);
    expect(find.text('1.0k in · 24 out'), findsOneWidget);

    await tester.tap(find.text('See detailed breakdown'));
    await tester.pumpAndSettle();
    expect(openedBreakdown, isTrue);
    expect(find.text('Context window'), findsNothing);
  });

  testWidgets('the moon mark paints, resting and animating', (tester) async {
    await tester.pumpWidget(
      _host(const Row(children: [ChatMoon(), ChatMoon(animating: true)])),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ChatMoon), findsNWidgets(2));
  });
}
