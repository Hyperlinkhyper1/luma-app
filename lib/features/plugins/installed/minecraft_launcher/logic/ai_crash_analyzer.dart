import 'package:flutter/widgets.dart';

import '../../../../../features/chat/ai_key_store.dart';
import '../../../../../features/chat/providers/ai_client.dart';
import '../../../../../features/chat/providers/ai_providers.dart';
import '../../../../../settings/settings_scope.dart';

class AiCrashAnalyzerException implements Exception {
  AiCrashAnalyzerException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Whether the app has an AI provider configured at all (a saved API key
/// for whichever provider is selected in Settings → AI Assistant) — check
/// this before showing an "Analyze with AI" action, since there's no chat
/// subsystem-wide helper for it.
Future<bool> isAiAvailable(BuildContext context) async {
  final settings = SettingsScope.of(context);
  final provider = aiProviderById(settings.aiProviderId);
  final store = await AiKeyStore.load();
  final key = await store.readKey(provider.id.name);
  return key != null && key.isNotEmpty;
}

/// Sends the tail of a Minecraft launch log to the user's configured AI
/// provider for a one-off diagnosis — a single-turn `AiClient.chat()` call
/// (the same primitive the full chat UI is built on), not a conversation.
Future<String> analyzeCrashLog(BuildContext context, String logTail) async {
  final settings = SettingsScope.of(context);
  if (!settings.canSendAiMessage) {
    throw AiCrashAnalyzerException("You've hit today's AI usage limit — try again tomorrow.");
  }

  final provider = aiProviderById(settings.aiProviderId);
  final store = await AiKeyStore.load();
  final apiKey = await store.readKey(provider.id.name);
  if (apiKey == null || apiKey.isEmpty) {
    throw AiCrashAnalyzerException(
      'No API key set for ${provider.displayName}. Add one under Settings → AI Assistant.',
    );
  }

  try {
    final result = await provider.client.chat(
      apiKey: apiKey,
      history: [
        AiTurn(
          role: 'user',
          text: 'Here is the tail of a Minecraft launch log that crashed or failed to '
              'start:\n\n$logTail\n\nWhat most likely went wrong, and what should I do '
              'to fix it? Be concise and specific — a short diagnosis and a short fix, '
              'no filler.',
        ),
      ],
      systemPrompt:
          'You are helping debug a Minecraft game launch that crashed or failed to '
          'start, given the tail of its log output. Identify the most likely root '
          'cause (missing/incompatible mod, wrong Java version, out-of-memory, '
          'corrupted download, mod conflict, etc.) and suggest one concrete next step. '
          'Keep the whole answer under 150 words.',
      tools: const [],
      executeTool: (_, _) async => const {},
      metadataFor: (_, _) => null,
    );
    settings.recordAiCall();
    return result.text;
  } on AiError catch (e) {
    throw AiCrashAnalyzerException(e.message);
  }
}
