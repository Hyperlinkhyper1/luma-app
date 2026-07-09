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
  const AiChatResult({required this.text, this.metadataJson});
  final String text;
  final String? metadataJson;
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
