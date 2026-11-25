import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/chat/assistant_auto_router.dart';
import 'package:luma/features/chat/assistant_compose_mode.dart';
import 'package:luma/features/chat/providers/ai_modes.dart';

void main() {
  const nova = AutoRouteContext(
    planId: 'nova',
    pictureAvailable: true,
    pictureProAvailable: true,
  );
  const orbit = AutoRouteContext(planId: 'orbit', pictureAvailable: true);
  const free = AutoRouteContext(planId: null, pictureAvailable: true);

  AutoRoute route(String text, [AutoRouteContext context = nova]) =>
      routeAutoRequest(text, context);

  group('chat questions', () {
    test('easy questions go to the cheapest model', () {
      for (final text in ['hi!', 'what is the capital of France?', 'thanks']) {
        final r = route(text);
        expect(r.kind, AutoRouteKind.quick, reason: text);
        expect(r.chatMode, AiMode.normal, reason: text);
        expect(r.composeMode, AssistantComposeMode.chat);
      }
    });

    test('explanations go to the middle model', () {
      final r = route('explain how vaccines work');
      expect(r.kind, AutoRouteKind.standard);
      expect(r.chatMode, AiMode.smarter);
      expect(route('waarom is de lucht blauw?').chatMode, AiMode.smarter);
    });

    test('code, maths and long inputs go to the strongest model', () {
      expect(route('fix this python function for me').chatMode, AiMode.smartest);
      expect(route('solve this equation: x^2 + 3x = 10').kind, AutoRouteKind.hard);
      expect(route('a' * 700).kind, AutoRouteKind.hard);
      expect(
        route(
          'what does it say?',
          const AutoRouteContext(planId: 'nova', textAttachments: 1),
        ).kind,
        AutoRouteKind.hard,
      );
    });

    test('the strongest model stops at what the plan has', () {
      expect(route('refactor this dart class', orbit).chatMode, AiMode.smarter);
    });

    test('accented words match as whole words', () {
      expect(route('écris un poème court', orbit).kind, AutoRouteKind.standard);
      expect(route('résous cette équation', orbit).kind, AutoRouteKind.hard);
    });
  });

  group('deep research', () {
    test('runs on the best model on Nova', () {
      final r = route('research the best e-bikes under 2000 euro');
      expect(r.kind, AutoRouteKind.research);
      expect(r.composeMode, AssistantComposeMode.deepResearch);
      expect(r.chatMode, AiMode.smartest);
      expect(route('doe een diepgaand onderzoek naar zonnepanelen').kind,
          AutoRouteKind.research);
    });

    test('falls back to a strong chat without the Nova modes', () {
      final r = route('do an in-depth comparison of index funds', orbit);
      expect(r.kind, AutoRouteKind.hard);
      expect(r.composeMode, AssistantComposeMode.chat);
      expect(r.chatMode, AiMode.smarter);
    });
  });

  group('pictures', () {
    test('a simple picture uses the cheaper model', () {
      final r = route('draw a cat wearing a hat');
      expect(r.kind, AutoRouteKind.picture);
      expect(r.composeMode, AssistantComposeMode.picture);
      expect(r.pictureTier, 'standard');
      expect(route('generate an image of a sunset').pictureTier, 'standard');
    });

    test('a detailed picture uses Pro when the plan has it', () {
      expect(
        route('create a photorealistic image of a mountain lake').pictureTier,
        'pro',
      );
      expect(
        route('create a photorealistic image of a mountain lake', orbit)
            .pictureTier,
        'standard',
      );
    });

    test('editing an attached picture uses Pro', () {
      final r = route(
        'make it look like a watercolor painting',
        const AutoRouteContext(
          planId: 'nova',
          pictureAvailable: true,
          pictureProAvailable: true,
          imageAttachments: 1,
        ),
      );
      expect(r.kind, AutoRouteKind.pictureEdit);
      expect(r.pictureTier, 'pro');
    });

    test('a short follow-up to the last picture edits it', () {
      const after = AutoRouteContext(
        planId: 'nova',
        pictureAvailable: true,
        pictureProAvailable: true,
        lastReplyWasPicture: true,
      );
      expect(route('now make it night', after).kind, AutoRouteKind.pictureEdit);
      expect(route('add a dog next to him', after).kind,
          AutoRouteKind.pictureEdit);
      expect(route('what is the tallest building?', after).kind,
          AutoRouteKind.quick);
    });

    test('a question about an attached picture stays a chat', () {
      final r = route(
        'what is in this picture?',
        const AutoRouteContext(
          planId: 'nova',
          pictureAvailable: true,
          imageAttachments: 1,
        ),
      );
      expect(r.composeMode, AssistantComposeMode.chat);
      expect(r.kind, AutoRouteKind.standard);
    });

    test('never routes to pictures the server cannot draw', () {
      final r = route(
        'draw a cat',
        const AutoRouteContext(planId: 'nova'),
      );
      expect(r.composeMode, AssistantComposeMode.chat);
    });
  });

  group('files', () {
    test('a requested file is created directly', () {
      final cases = {
        'make me a pdf with my weekly schedule': 'pdf',
        'export this table as csv': 'csv',
        'create a spreadsheet of my expenses': 'csv',
        'generate a json file with 10 users': 'json',
        'make an svg logo for my bakery': 'svg',
        'build a landing page for my app': 'html',
        'write a markdown file with the notes': 'md',
        'maak een pdf van dit recept': 'pdf',
      };
      for (final entry in cases.entries) {
        final r = route(entry.key);
        expect(r.kind, AutoRouteKind.file, reason: entry.key);
        expect(r.artifactType, entry.value, reason: entry.key);
        expect(r.composeMode, AssistantComposeMode.chat);
      }
    });

    test('mentioning a format is not asking for a file', () {
      for (final text in [
        'summarize this pdf',
        'answer in markdown please',
        'what is json?',
        'what is the dot product of two vectors',
      ]) {
        expect(route(text).kind, isNot(AutoRouteKind.file), reason: text);
      }
    });

    test('plans without files never request one', () {
      expect(route('make me a pdf of this', free).kind,
          isNot(AutoRouteKind.file));
    });
  });

  test('only the Luma AI provider can be on auto', () {
    expect(isAutoAiMode('google', kAutoAiMode), isTrue);
    expect(isAutoAiMode('openai', kAutoAiMode), isFalse);
    expect(isAutoAiMode('google', 'smarter'), isFalse);
  });
}
