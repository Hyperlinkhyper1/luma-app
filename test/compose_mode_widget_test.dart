import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/chat/assistant_compose_mode.dart';
import 'package:luma/features/chat/widgets/chat_activity_card.dart';
import 'package:luma/features/chat/widgets/chat_input_bar.dart';
import 'package:luma/features/chat/widgets/compose_mode_menu.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';

Widget _host(Widget child) => MaterialApp(
  theme: LumaTheme.dark,
  localizationsDelegates: L.localizationsDelegates,
  supportedLocales: L.supportedLocales,
  home: Scaffold(body: Center(child: SizedBox(width: 700, child: child))),
);

class _ModeHost extends StatefulWidget {
  const _ModeHost({required this.availability});

  final ComposeModeAvailability availability;

  @override
  State<_ModeHost> createState() => _ModeHostState();
}

class _ModeHostState extends State<_ModeHost> {
  AssistantComposeMode mode = AssistantComposeMode.chat;

  @override
  Widget build(BuildContext context) => ChatInputBar(
    onSend: (_) {},
    sending: false,
    enabled: true,
    caption: '',
    modelSelector: const Text('Model'),
    leading: ComposeModeButton(
      mode: mode,
      onChanged: (value) => setState(() => mode = value),
      availability: () async => widget.availability,
    ),
  );
}

void main() {
  testWidgets('the + menu turns a mode on and its pill turns it off', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const _ModeHost(
          availability: ComposeModeAvailability(
            research: true,
            picture: true,
            picturePercent: 3,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Add'), findsWidgets);
    expect(find.text('Plan mode'), findsOneWidget);
    expect(find.text('Deep research'), findsOneWidget);
    expect(
      find.text('Draw an image · uses 3% of your weekly limit'),
      findsOneWidget,
    );

    await tester.tap(find.text('Plan mode'));
    await tester.pumpAndSettle();
    expect(find.text('Plan mode'), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Plan mode'), findsNothing);
  });

  testWidgets('unavailable modes are shown but cannot be picked', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const _ModeHost(
          availability: ComposeModeAvailability(research: false, picture: false),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(
      find.text('Switch to Nebula, Pulsar or Luma Assistant'),
      findsOneWidget,
    );
    expect(find.text('Needs a signed-in luma account'), findsOneWidget);

    await tester.tap(find.text('Deep research'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });

  testWidgets('research activity lists the agents and who is done', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ChatActivityCard(
          activity: AssistantActivity.research(
            questions: ['First?', 'Second?'],
            done: {0},
            parallel: true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('1 of 2 agents done'), findsOneWidget);
    expect(find.text('First?'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}
