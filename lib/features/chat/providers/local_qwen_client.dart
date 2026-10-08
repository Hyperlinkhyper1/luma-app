import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:llm_llamacpp/llm_llamacpp.dart';

import '../../../l10n/current_l.dart';
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

  static String get _modelName => LocalModelStore.modelDisplayName;

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
  /// uneven, and a driver fault takes the whole app down. 0 also keeps the
  /// bundled Vulkan backend out entirely (see LUMA_PATCH.md).
  static int get _gpuLayers => Platform.isAndroid ? 0 : 99;

  /// On Android, one thread per performance core. Phones pair a few fast
  /// cores with slower efficiency cores, and llama.cpp's threads wait for
  /// each other every step, so the default of four threads on a 2 + 6
  /// Snapdragon ran at the pace of its little cores. Null (llama.cpp's
  /// default) elsewhere, or when the kernel doesn't describe its cores.
  static final int? _threads = Platform.isAndroid ? _androidThreads() : null;

  static int? _androidThreads() {
    try {
      final cores = Directory(
        '/sys/devices/system/cpu',
      ).listSync().where((entry) => RegExp(r'/cpu\d+$').hasMatch(entry.path));
      final capacities = <int>[];
      final frequencies = <int>[];
      for (final core in cores) {
        final capacity = _readInt('${core.path}/cpu_capacity');
        if (capacity != null) capacities.add(capacity);
        final frequency = _readInt('${core.path}/cpufreq/cpuinfo_max_freq');
        if (frequency != null) frequencies.add(frequency);
      }
      return performanceCoreCount(
        capacities.isNotEmpty ? capacities : frequencies,
      );
    } catch (_) {
      return null;
    }
  }

  static int? _readInt(String path) {
    try {
      return int.tryParse(File(path).readAsStringSync().trim());
    } catch (_) {
      return null;
    }
  }

  /// The number of cores faster than the slowest ones, given one capacity
  /// (or max frequency) per core. When every core is alike there is no
  /// slow tier to leave out, so all of them count, up to eight.
  @visibleForTesting
  static int? performanceCoreCount(List<int> coreSpeeds) {
    if (coreSpeeds.isEmpty) return null;
    final slowest = coreSpeeds.reduce((a, b) => a < b ? a : b);
    final fast = coreSpeeds.where((speed) => speed > slowest).length;
    return fast > 0 ? fast : coreSpeeds.length.clamp(1, 8);
  }

  /// Without a repeat penalty a 0.8B model easily locks onto one sentence
  /// and writes it until the output budget runs out. 1.1 over the last 64
  /// tokens breaks those loops without bending normal prose.
  static const _options = LLMChatOptions(
    toolAttempts: 5,
    maxOutputTokens: 512,
    temperature: 0.7,
    topP: 0.8,
    topK: 20,
    backendOptions: {'repeatPenalty': 1.1},
  );

  /// Qwen3.5 writes every argument as raw text between `<parameter>` tags,
  /// so `7` arrives as the string "7". Converts each one to the type its
  /// schema declares; values that don't convert are left alone.
  @visibleForTesting
  static Map<String, dynamic> coerceArguments(
    Map<String, dynamic> schema,
    Map<String, dynamic> args,
  ) {
    final properties = schema['properties'];
    if (properties is! Map) return args;
    return {
      for (final entry in args.entries)
        entry.key: _coerce(properties[entry.key], entry.value),
    };
  }

  static dynamic _coerce(dynamic schema, dynamic value) {
    if (schema is! Map) return value;
    final type = schema['type'];
    if (value is String) {
      final text = value.trim();
      return switch (type) {
        'integer' =>
          int.tryParse(text) ?? double.tryParse(text)?.round() ?? value,
        'number' => num.tryParse(text) ?? value,
        'boolean' => switch (text.toLowerCase()) {
          'true' => true,
          'false' => false,
          _ => value,
        },
        'array' || 'object' => _decodeJson(text) ?? value,
        _ => value,
      };
    }
    if (type == 'string' && (value is num || value is bool)) {
      return value.toString();
    }
    return value;
  }

  static dynamic _decodeJson(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

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
          threads: _threads,
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
    AiTextProgress? onText,
  }) async {
    final path = await _modelPath();
    if (path == null) {
      throw AiApiError(
        currentL.aiLocalModelMissing(LocalModelStore.modelDisplayName),
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

    // Read the stream rather than awaiting chatResponse, so the reply can be
    // shown while it is written: on a phone CPU the whole reply takes tens
    // of seconds. Text is concatenated across tool rounds and the last
    // round's token counts are kept, exactly as chatResponse does.
    var reply = '';
    var shown = '';
    var promptTokens = 0;
    var outputTokens = 0;
    try {
      await for (final chunk in repository.streamChat(
        _modelName,
        messages: _messages(systemPrompt, _fitHistory(history)),
        tools: nativeTools,
        options: _options,
      )) {
        final message = chunk.message;
        if (message?.role == LLMRole.assistant && message?.content != null) {
          reply += message!.content!;
          final visible = stripThinking(reply);
          if (onText != null && visible != shown) {
            shown = visible;
            onText(visible);
          }
        }
        if (chunk.done ?? false) {
          promptTokens = chunk.promptEvalCount ?? promptTokens;
          outputTokens = chunk.evalCount ?? outputTokens;
        }
      }
      final text = stripThinking(reply);
      return AiChatResult(
        text: text.isNotEmpty ? text : currentL.aiClientNoReply,
        metadataJson: metadataJson,
        usage: AiTokenUsage(
          model: '${LocalModelStore.modelDisplayName} (on-device)',
          inputTokens: promptTokens,
          outputTokens: outputTokens,
        ),
      );
    } on AiError {
      rethrow;
    } catch (error) {
      throw AiApiError(currentL.aiLocalModelFailed('$error'));
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
      run(name, LocalQwenClient.coerceArguments(definition.parameters, args));

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
