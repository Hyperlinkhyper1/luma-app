import 'dart:convert';

import 'package:llm_llamacpp/src/isolate_messages.dart';
import 'package:llm_llamacpp/src/tool_calls/tool_call_syntax.dart';
import 'package:llm_llamacpp/src/tool_calls/tool_definition_formatter.dart';

/// Injects tool definitions into a list of [IsolateMessage]s.
///
/// The definitions are either appended to the existing `system` message or
/// prepended as a new one, mirroring `injectResponseFormat`.
///
/// [toolSchemasJson] holds JSON-encoded OpenAI-style function schemas — encoded
/// because these cross an isolate boundary, and a plain `String` is cheaper and
/// safer to send than a nested map. [format] is the family the model was trained
/// on, resolved by the caller from the chat template and, failing that, the
/// tokenizer vocabulary.
///
/// Returns [messages] unchanged when there are no tools.
List<IsolateMessage> injectToolDefinitions(
  List<IsolateMessage> messages,
  List<String> toolSchemasJson, {
  required ToolCallFormat format,
}) {
  if (toolSchemasJson.isEmpty) return messages;

  final schemas = <Map<String, dynamic>>[];
  for (final encoded in toolSchemasJson) {
    final decoded = json.decode(encoded);
    if (decoded is Map<String, dynamic>) schemas.add(decoded);
  }
  if (schemas.isEmpty) return messages;

  final instruction = formatToolDefinitions(schemas, format);
  if (instruction == null) return messages;
  if (format == ToolCallFormat.qwenXml) {
    messages = _qwenToolResponses(messages);
  }

  final systemIndex = messages.indexWhere((m) => m.role == 'system');
  if (systemIndex >= 0) {
    final existing = messages[systemIndex].content;
    final updated = List<IsolateMessage>.from(messages);
    // Qwen's template puts the tool list ahead of the system prompt.
    updated[systemIndex] = IsolateMessage(
      role: 'system',
      content: existing.isEmpty
          ? instruction
          : format == ToolCallFormat.qwenXml
          ? '$instruction\n\n$existing'
          : '$existing\n$instruction',
    );
    return updated;
  }

  return [IsolateMessage(role: 'system', content: instruction), ...messages];
}

/// Rewrites `tool` messages the way Qwen's template renders them: one `user`
/// turn per run of results, each wrapped in `<tool_response>` tags.
/// `llama_chat_apply_template` would otherwise emit a `tool` role the model
/// never saw in training.
List<IsolateMessage> _qwenToolResponses(List<IsolateMessage> messages) {
  final rewritten = <IsolateMessage>[];
  for (final message in messages) {
    if (message.role != 'tool') {
      rewritten.add(message);
      continue;
    }
    final response = '<tool_response>\n${message.content}\n</tool_response>';
    final previous = rewritten.isEmpty ? null : rewritten.last;
    if (previous != null &&
        previous.role == 'user' &&
        previous.content.endsWith('</tool_response>')) {
      rewritten.last = IsolateMessage(
        role: 'user',
        content: '${previous.content}\n$response',
      );
    } else {
      rewritten.add(IsolateMessage(role: 'user', content: response));
    }
  }
  return rewritten;
}
