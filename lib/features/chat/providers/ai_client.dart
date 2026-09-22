/// One tool the assistant can call, in a provider-agnostic shape. Each
/// [AiClient] implementation translates this into its own wire format
/// (Anthropic's `input_schema`, OpenAI/Mistral's `function.parameters`, ...).
class AiToolDefinition {
  const AiToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;

  /// JSON Schema object describing the tool's input.
  final Map<String, dynamic> parameters;
}

/// A single prior turn in the conversation, kept provider-agnostic — plain
/// text only. The tool_use/tool_result bookkeeping needed mid-turn is each
/// client's own internal concern, not part of persisted history.
class AiTurn {
  const AiTurn({required this.role, required this.text});

  /// 'user' or 'assistant'.
  final String role;
  final String text;
}

/// Runs a tool by name and returns a small JSON-able result.
typedef AiToolExecutor = Future<Map<String, dynamic>> Function(
  String name,
  Map<String, dynamic> input,
);

/// Given a tool name + its result, returns optional render metadata (e.g.
/// `{"qrUrl": "..."}`) to attach to the final assistant message.
typedef AiToolMetadata = String? Function(
  String name,
  Map<String, dynamic> result,
);

/// The assistant's finished reply for one user turn, after any tool calls
/// the model requested have been resolved.
class AiChatResult {
  const AiChatResult({required this.text, this.metadataJson, this.usage});
  final String text;
  final String? metadataJson;

  /// Tokens this reply cost, summed over every request its tool loop made.
  /// Null when the provider reported no usage at all.
  final AiTokenUsage? usage;
}

/// What one reply cost in tokens, as the provider itself reported it.
///
/// [inputTokens] excludes [cacheReadTokens]: providers that fold cached
/// input into their prompt count (the OpenAI shape) are split apart here, so
/// each field can be priced at its own rate without double counting.
/// Reasoning ("thinking") tokens are billed as output and counted in
/// [outputTokens].
class AiTokenUsage {
  const AiTokenUsage({
    required this.model,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheReadTokens = 0,
    this.cacheWriteTokens = 0,
    this.requests = 1,
  });

  /// The model that actually answered — the provider's own `model` field
  /// when the response carries one, otherwise the model that was asked for.
  final String model;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheWriteTokens;

  /// How many API requests went into this reply (one per tool hop).
  final int requests;

  int get totalTokens =>
      inputTokens + outputTokens + cacheReadTokens + cacheWriteTokens;

  /// Adds [other]'s counts to this one's, keeping [other]'s model — the
  /// last request of a tool loop is the one that produced the reply.
  AiTokenUsage operator +(AiTokenUsage other) => AiTokenUsage(
        model: other.model,
        inputTokens: inputTokens + other.inputTokens,
        outputTokens: outputTokens + other.outputTokens,
        cacheReadTokens: cacheReadTokens + other.cacheReadTokens,
        cacheWriteTokens: cacheWriteTokens + other.cacheWriteTokens,
        requests: requests + other.requests,
      );
}

/// Sums two optional usages, where either side may be missing.
AiTokenUsage? addAiUsage(AiTokenUsage? a, AiTokenUsage? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a + b;
}

/// Base for anything that goes wrong talking to an AI provider.
sealed class AiError implements Exception {
  AiError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The API key is missing, malformed, or rejected (HTTP 401).
class AiAuthError extends AiError {
  AiAuthError(super.message);
}

/// The provider is rate-limiting this key (HTTP 429).
class AiRateLimitError extends AiError {
  AiRateLimitError(super.message);
}

/// The request never reached the provider (timeout, offline, DNS, etc).
class AiNetworkError extends AiError {
  AiNetworkError(super.message);
}

/// Any other non-200 response.
class AiApiError extends AiError {
  AiApiError(super.message);
}

/// A chat completion provider — Anthropic, OpenAI, Mistral, etc. Each
/// implementation owns its own wire format and tool-call loop internally;
/// callers only see plain text in, plain text (+ optional tool metadata) out.
abstract class AiClient {
  Future<AiChatResult> chat({
    required String apiKey,
    required List<AiTurn> history,
    required String systemPrompt,
    required List<AiToolDefinition> tools,
    required AiToolExecutor executeTool,
    required AiToolMetadata metadataFor,

    /// A hosted agent id (e.g. Mistral's Agents API `agent_id`) to run
    /// against instead of the client's default model. Ignored by clients
    /// that don't support hosted agents.
    String? agentId,
  });
}
