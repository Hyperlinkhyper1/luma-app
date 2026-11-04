import 'chat_usage.dart';
import 'data/chat_repository.dart';

/// What an earlier picture in the same chat contributes to the next one, so
/// a follow-up such as "now make it night" changes that picture instead of
/// drawing something unrelated.
class PictureContext {
  const PictureContext({required this.prompts, this.lastImagePath});

  /// The prompts that drew this chat's pictures, oldest first.
  final List<String> prompts;

  /// Where the newest picture of this chat is kept on this device.
  final String? lastImagePath;

  bool get isEmpty => prompts.isEmpty && lastImagePath == null;

  static const maxPrompts = 6;
  static const maxPromptChars = 4000;

  /// Reads [history] (oldest first) for the pictures already drawn: each
  /// picture reply and the user prompt right before it.
  factory PictureContext.fromHistory(List<ChatMessageRecord> history) {
    final prompts = <String>[];
    String? lastImagePath;
    for (var i = 0; i < history.length; i++) {
      final message = history[i];
      if (message.role != 'assistant') continue;
      final path = chatImagePathOf(message.metadataJson);
      if (path == null) continue;
      lastImagePath = path;
      for (var j = i - 1; j >= 0; j--) {
        final earlier = history[j];
        if (earlier.role == 'user') {
          final text = earlier.content.trim();
          if (text.isNotEmpty) prompts.add(text);
          break;
        }
        if (earlier.role == 'assistant') break;
      }
    }
    return PictureContext(
      prompts: prompts.length > maxPrompts
          ? prompts.sublist(prompts.length - maxPrompts)
          : prompts,
      lastImagePath: lastImagePath,
    );
  }

  /// The prompt sent to the picture model for [request]. With
  /// [editingImage] the previous picture goes along as the first input
  /// image, so the model is told to change it; without image input the
  /// earlier prompts are folded in so the scene is redrawn with the change.
  String promptFor(String request, {required bool editingImage}) {
    if (prompts.isEmpty && !editingImage) return request;
    final history = <String>[...prompts];
    String build() {
      final earlier = history.isEmpty
          ? ''
          : 'Earlier requests in this conversation, oldest first:\n'
                '${[for (final p in history) '- $p'].join('\n')}\n\n';
      return editingImage
          ? 'The first image is the picture you drew last in this '
                'conversation. Edit that picture: keep its subject, '
                'composition and style, and change only what the new request '
                'asks for.\n\n${earlier}New request: $request'
          : 'Redraw the picture described by these requests, applying the '
                'newest one on top of the earlier ones.\n\n$earlier'
                'New request: $request';
    }

    var prompt = build();
    while (prompt.length > maxPromptChars && history.isNotEmpty) {
      history.removeAt(0);
      prompt = build();
    }
    return prompt.length > maxPromptChars
        ? prompt.substring(prompt.length - maxPromptChars)
        : prompt;
  }
}
