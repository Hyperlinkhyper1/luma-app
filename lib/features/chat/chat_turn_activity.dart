import 'dart:convert';

enum ChatToolState {
  running,
  completed,
  needsInfo,
  unavailable,
  failed;

  static ChatToolState fromResult(Map<String, dynamic> result) =>
      switch (result['status']) {
        'needs_info' => needsInfo,
        'unavailable' || 'rate_limited' => unavailable,
        'error' || 'invalid' => failed,
        _ => completed,
      };
}

sealed class ChatTurnActivity {
  const ChatTurnActivity();

  Map<String, String> toJson();

  static List<ChatTurnActivity> fromMetadata(String? metadataJson) {
    if (metadataJson == null) return const [];
    try {
      final metadata = jsonDecode(metadataJson);
      if (metadata is! Map || metadata['activity'] is! List) return const [];
      final states = ChatToolState.values.asNameMap();
      return [
        for (final entry in metadata['activity'] as List)
          if (entry case {
            'commentary': final String text,
          } when text.trim().isNotEmpty)
            ChatCommentary(text)
          else if (entry case {
            'tool': final String name,
            'state': final String state,
          })
            if (states[state] case final value?
                when value != ChatToolState.running)
              ChatToolActivity(name, value),
      ];
    } on FormatException {
      return const [];
    }
  }
}

final class ChatCommentary extends ChatTurnActivity {
  const ChatCommentary(this.text);

  final String text;

  @override
  Map<String, String> toJson() => {'commentary': text};
}

final class ChatToolActivity extends ChatTurnActivity {
  const ChatToolActivity(this.name, this.state);

  final String name;
  final ChatToolState state;

  @override
  Map<String, String> toJson() => {'tool': name, 'state': state.name};
}
