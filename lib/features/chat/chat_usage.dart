import 'dart:convert';

import 'assistant_compose_mode.dart';
import 'data/chat_repository.dart';
import 'providers/ai_client.dart';
import 'providers/ai_providers.dart';
import 'providers/local_qwen_client.dart';

/// Folds a reply's token usage into its message metadata (next to the
/// `qrUrl` a tool may have left there), so the composer's usage meter can
/// show how full the conversation's context is — even after a restart.
String? chatMetadataWithUsage(String? metadataJson, AiTokenUsage? usage) {
  if (usage == null) return metadataJson;
  var map = <String, dynamic>{};
  if (metadataJson != null) {
    try {
      map = (jsonDecode(metadataJson) as Map).cast<String, dynamic>();
    } catch (_) {}
  }
  map['usage'] = {
    'model': usage.model,
    'input': usage.inputTokens + usage.cacheReadTokens + usage.cacheWriteTokens,
    'output': usage.outputTokens,
  };
  return jsonEncode(map);
}

/// Tags a reply with the + menu mode that produced it, so the transcript
/// can label plan, deep research and picture replies. Plain chats are left
/// untagged.
String? chatMetadataWithComposeMode(
  String? metadataJson,
  AssistantComposeMode mode,
) {
  if (mode == AssistantComposeMode.chat) return metadataJson;
  return jsonEncode({..._decodeMetadata(metadataJson), 'composeMode': mode.name});
}

/// The + menu mode stored by [chatMetadataWithComposeMode], if any.
AssistantComposeMode? chatComposeModeOf(String? metadataJson) {
  final name = _decodeMetadata(metadataJson)['composeMode'];
  return name is String
      ? AssistantComposeMode.values.asNameMap()[name]
      : null;
}

/// Where a picture mode reply's picture was saved on this device.
String? chatImagePathOf(String? metadataJson) {
  final path = _decodeMetadata(metadataJson)['imagePath'];
  return path is String && path.isNotEmpty ? path : null;
}

Map<String, dynamic> _decodeMetadata(String? metadataJson) {
  if (metadataJson == null) return const {};
  try {
    final decoded = jsonDecode(metadataJson);
    if (decoded is Map) return decoded.cast<String, dynamic>();
  } catch (_) {}
  return const {};
}

/// What the newest reply in a conversation cost, as stored by
/// [chatMetadataWithUsage].
class ChatReplyUsage {
  const ChatReplyUsage({
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
  });

  final String model;
  final int inputTokens;
  final int outputTokens;

  /// Roughly what the conversation occupies in the model's context window:
  /// everything sent with the last turn plus the reply itself.
  int get contextTokens => inputTokens + outputTokens;

  /// The usage on the newest assistant message that carries one, or null.
  static ChatReplyUsage? latest(List<ChatMessageRecord> messages) {
    for (final message in messages.reversed) {
      if (message.role != 'assistant' || message.metadataJson == null) {
        continue;
      }
      try {
        final decoded = jsonDecode(message.metadataJson!);
        final usage = decoded is Map ? decoded['usage'] : null;
        if (usage is! Map) continue;
        return ChatReplyUsage(
          model: usage['model'] as String? ?? '',
          inputTokens: (usage['input'] as num?)?.toInt() ?? 0,
          outputTokens: (usage['output'] as num?)?.toInt() ?? 0,
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}

/// The context window of the model each provider is wired to (see the
/// clients' default models and `ai_modes.dart`).
int contextWindowFor(String providerId) =>
    switch (AiProviderId.values.asNameMap()[providerId]) {
      AiProviderId.local => LocalQwenClient.contextSize,
      AiProviderId.google => 1048576,
      AiProviderId.anthropic => 200000,
      AiProviderId.openai => 128000,
      AiProviderId.mistral => 128000,
      null => 128000,
    };

/// "1.2k", "180k", "1M" — the compact counts the usage meter shows.
String compactTokens(int tokens) {
  if (tokens < 1000) return '$tokens';
  if (tokens < 1000000) {
    final k = tokens / 1000;
    return '${k < 10 ? k.toStringAsFixed(1) : k.toStringAsFixed(0)}k';
  }
  final m = tokens / 1000000;
  return '${m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1)}M';
}
