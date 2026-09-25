import 'dart:convert';

import 'package:llm_llamacpp/llm_llamacpp.dart';

import '../local_model_store.dart';
import 'ai_client.dart';

/// Runs Assistant turns through the optional Qwen model stored on this device.
class LocalQwenClient implements AiClient {
  const LocalQwenClient();

  static final Map<String, LlamaCppChatRepository> _repositories = {};
  static const _modelName = 'Qwen3.5-0.8B';

  @override
  Future<AiChatResult> chat({
    required String apiKey,
    required List<AiTurn> history,
    required String systemPrompt,
    required List<AiToolDefinition> tools,
    required AiToolExecutor executeTool,
    required AiToolMetadata metadataFor,
    String? agentId,
  }) async {
    final path = await LocalModelStore.instance.modelPath();
    if (path == null) {
      throw AiApiError(
        'Download Qwen3.5-0.8B in Assistant settings before using the on-device model.',
      );
    }

    final repository = _repositories.putIfAbsent(
      path,
      () => LlamaCppChatRepository.withModelPath(
        path,
        contextSize: 4096,
        maxToolAttempts: 5,
      ),
    );
    String? metadataJson;

    final nativeTools = [
      for (final tool in tools)
        _LumaLocalTool(
          definition: tool,
          run: (name, input) async {
            final result = await executeTool(name, input);
            metadataJson ??= metadataFor(name, result);
            return jsonEncode(result);
          },
        ),
    ];
    final messages = [
      if (systemPrompt.isNotEmpty)
        LLMMessage(role: LLMRole.system, content: systemPrompt),
      for (final turn in history)
        LLMMessage(
          role: turn.role == 'assistant' ? LLMRole.assistant : LLMRole.user,
          content: turn.text,
        ),
    ];

    try {
      final response = await repository.chatResponse(
        _modelName,
        messages: messages,
        tools: nativeTools,
        options: const LLMChatOptions(
          toolAttempts: 5,
          maxOutputTokens: 512,
          temperature: 0.7,
          topP: 0.8,
          topK: 20,
        ),
      );
      final usage = response.usage;
      return AiChatResult(
        text: response.content?.trim().isNotEmpty == true
            ? response.content!.trim()
            : "I couldn't come up with a reply for that.",
        metadataJson: metadataJson,
        usage: AiTokenUsage(
          model: 'Qwen3.5-0.8B (on-device)',
          inputTokens: usage.promptTokens,
          outputTokens: usage.completionTokens,
        ),
      );
    } on AiError {
      rethrow;
    } catch (error) {
      throw AiApiError('The on-device model could not answer: $error');
    }
  }
}

class _LumaLocalTool extends LLMTool {
  _LumaLocalTool({required this.definition, required this.run});

  final AiToolDefinition definition;
  final Future<String> Function(String name, Map<String, dynamic> input) run;

  @override
  String get name => definition.name;

  @override
  String get description => definition.description;

  @override
  List<LLMToolParam> get parameters {
    final properties = definition.parameters['properties'];
    if (properties is! Map) return const [];
    final requiredNames =
        (definition.parameters['required'] as List?)
            ?.whereType<String>()
            .toSet() ??
        const <String>{};
    return [
      for (final entry in properties.entries)
        if (entry.key is String && entry.value is Map)
          _parameter(
            entry.key as String,
            (entry.value as Map).cast<String, dynamic>(),
            requiredNames.contains(entry.key),
          ),
    ];
  }

  @override
  Future<dynamic> execute(Map<String, dynamic> args, {dynamic extra}) =>
      run(name, args);

  LLMToolParam _parameter(
    String name,
    Map<String, dynamic> schema,
    bool required,
  ) {
    final type = schema['type'] as String? ?? 'string';
    final properties = schema['properties'];
    final requiredNames =
        (schema['required'] as List?)?.whereType<String>().toSet() ??
        const <String>{};
    final items = schema['items'];
    final enumValues = schema['enum'];
    return LLMToolParam(
      name: name,
      type: type,
      description: schema['description'] as String? ?? '',
      isRequired: required,
      enums: enumValues is List
          ? enumValues.whereType<String>().toList()
          : const [],
      items: items is Map
          ? _parameter('item', items.cast<String, dynamic>(), false)
          : null,
      properties: properties is Map
          ? [
              for (final entry in properties.entries)
                if (entry.key is String && entry.value is Map)
                  _parameter(
                    entry.key as String,
                    (entry.value as Map).cast<String, dynamic>(),
                    requiredNames.contains(entry.key),
                  ),
            ]
          : null,
      additionalProperties: schema['additionalProperties'] as bool?,
      minItems: (schema['minItems'] as num?)?.toInt(),
      maxItems: (schema['maxItems'] as num?)?.toInt(),
      uniqueItems: schema['uniqueItems'] as bool?,
      minimum: schema['minimum'] as num?,
      maximum: schema['maximum'] as num?,
    );
  }
}
