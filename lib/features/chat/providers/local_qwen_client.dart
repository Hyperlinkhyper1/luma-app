import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:llm_llamacpp/llm_llamacpp.dart';

import '../local_model_store.dart';
import 'ai_client.dart';

/// Runs Assistant turns through the optional Qwen model stored on this device.
///
/// The vendored llama.cpp plugin keeps the model loaded between turns and
/// snapshots the evaluated conversation, so a turn only evaluates what's new
/// since the last one (see third_party/llm_llamacpp/LUMA_PATCH.md). [warmUp]
/// does the expensive first load and system-prompt evaluation before the
/// user sends anything.
class LocalQwenClient implements AiClient {
  const LocalQwenClient();

  static final Map<String, LlamaCppChatRepository> _repositories = {};
  static Future<void>? _warmUp;

  static const _modelName = 'Qwen3.5-0.8B';

  /// The tool schemas alone are ~2k tokens, so 4096 left little room for
  /// conversation. 8192 costs a few MB more: only a quarter of Qwen3.5's
  /// layers keep a KV cache.
  static const contextSize = 8192;

  /// Rough cap on the characters of history sent per turn (~3 chars per
  /// token), keeping tools + history + the reply inside [contextSize].
  static const _historyCharBudget = 12000;

  /// Every layer on the GPU on desktop, where llama.cpp's Vulkan backend
  /// ships and falls back to the CPU by itself when there's no usable GPU —
  /// on an RX 9060 XT it evaluates prompts ~2.5× faster than six CPU
  /// threads. Android stays on the CPU: mobile Vulkan drivers are too
  /// uneven, and a driver fault takes the whole app down.
  static int get _gpuLayers => Platform.isAndroid ? 0 : 99;

  static const _options = LLMChatOptions(
    toolAttempts: 5,
    maxOutputTokens: 512,
    temperature: 0.7,
    topP: 0.8,
    topK: 20,
  );

  /// Qwen3.5 opens every reply with a `<think>…</think>` block (usually
  /// empty). Drops it, and anything after an unclosed `<think>` that ran out
  /// of output budget.
  @visibleForTesting
  static String stripThinking(String reply) {
    final closed = reply.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '');
    final open = closed.indexOf('<think>');
    return (open == -1 ? closed : closed.substring(0, open)).trim();
  }

  static List<AiTurn> _fitHistory(List<AiTurn> history) {
    var total = 0;
    var start = history.length;
    while (start > 0) {
      final length = history[start - 1].text.length;
      if (start < history.length && total + length > _historyCharBudget) break;
      total += length;
      start--;
    }
    return history.sublist(start);
  }

  static Future<String?> _modelPath() => LocalModelStore.instance.modelPath();

  static LlamaCppChatRepository _repositoryFor(String path) =>
      _repositories.putIfAbsent(
        path,
        () => LlamaCppChatRepository.withModelPath(
          path,
          contextSize: contextSize,
          nGpuLayers: _gpuLayers,
          maxToolAttempts: 5,
        ),
      );

  static List<LLMMessage> _messages(String systemPrompt, List<AiTurn> turns) =>
      [
        if (systemPrompt.isNotEmpty)
          LLMMessage(role: LLMRole.system, content: systemPrompt),
        for (final turn in turns)
          LLMMessage(
            role: turn.role == 'assistant' ? LLMRole.assistant : LLMRole.user,
            content: turn.text,
          ),
      ];

  /// Loads the model and evaluates the system prompt and tool schemas in
  /// the background, so the first real message only has to evaluate itself.
  /// A no-op when the model isn't installed or a warm-up already ran.
  static Future<void> warmUp({
    required String systemPrompt,
    required List<AiToolDefinition> tools,
  }) {
    return _warmUp ??= () async {
      try {
        final path = await _modelPath();
        if (path == null) {
          _warmUp = null;
          return;
        }
        await _repositoryFor(path).chatResponse(
          _modelName,
          messages: _messages(systemPrompt, const [
            AiTurn(role: 'user', text: 'hi'),
          ]),
          tools: [
            for (final tool in tools)
              _LumaLocalTool(definition: tool, run: (_, _) async => '{}'),
          ],
          options: const LLMChatOptions(toolAttempts: 0, maxOutputTokens: 1),
        );
      } catch (error) {
        debugPrint('Local model warm-up failed: $error');
        _warmUp = null;
      }
    }();
  }

  /// Frees the loaded model, e.g. before its file is deleted — Windows
  /// won't delete a file that is still memory-mapped.
  static Future<void> release() async {
    _warmUp = null;
    await PersistentInferenceIsolate.instance.releaseCachedSession();
  }

  @override
  Future<AiChatResult> chat({
    required String apiKey,
    required List<AiTurn> history,
    required String systemPrompt,
    required List<AiToolDefinition> tools,
    required AiToolExecutor executeTool,
    required AiToolMetadata metadataFor,
  }) async {
    final path = await _modelPath();
    if (path == null) {
      throw AiApiError(
        'Download Qwen3.5-0.8B in Assistant settings before using the on-device model.',
      );
    }

    final repository = _repositoryFor(path);
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

    try {
      final response = await repository.chatResponse(
        _modelName,
        messages: _messages(systemPrompt, _fitHistory(history)),
        tools: nativeTools,
        options: _options,
      );
      final usage = response.usage;
      final text = stripThinking(response.content ?? '');
      return AiChatResult(
        text: text.isNotEmpty
            ? text
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
