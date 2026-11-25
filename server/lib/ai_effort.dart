/// The Assistant's effort levels. The app only names the level it wants
/// (`luma_effort`); this server decides what that means upstream and how
/// much of the allowance it costs, so a modified client can't buy more
/// thinking than it pays for.
enum AssistantEffort {
  low(10, minTokens: 0, maxTokens: 4096),
  medium(10, minTokens: 0, maxTokens: 4096),
  high(15, minTokens: 4096, maxTokens: 8192),
  extra(25, minTokens: 8192, maxTokens: 16384),
  max(35, minTokens: 16384, maxTokens: 32768);

  const AssistantEffort(
    this.weightTenths, {
    required this.minTokens,
    required this.maxTokens,
  });

  /// How much faster than normal this level drains the allowance, in
  /// tenths, on top of the mode's own weight and the extra tokens the model
  /// actually spends thinking.
  final int weightTenths;

  /// The output budget: the app's own request, raised to at least
  /// [minTokens] and capped at [maxTokens].
  final int minTokens;
  final int maxTokens;

  static AssistantEffort? parse(Object? raw) {
    for (final level in values) {
      if (level.name == raw) return level;
    }
    return null;
  }
}

/// What one Assistant request runs with, decided from the client body.
class AssistantEffortPlan {
  const AssistantEffortPlan({
    required this.level,
    required this.reasoningEffort,
    required this.maxTokens,
  });

  final AssistantEffort level;

  /// `reasoning_effort` for the upstream, or null for the model's default.
  /// At [AssistantEffort.medium] an effort the operator pinned on the route
  /// wins; any other level is the user's explicit choice and wins instead.
  final String? reasoningEffort;

  bool get overridesRoute => level != AssistantEffort.medium;
  final int maxTokens;

  int get weightTenths => level.weightTenths;
}

/// Reads the effort a client asked for. Apps from before effort levels
/// send a raw `reasoning_effort` instead (Pulsar sends `high`); that is
/// mapped onto a level too, so it is charged like one rather than passed
/// through for free.
AssistantEffortPlan planAssistantEffort(Map<String, dynamic> body, String mode) {
  final level = AssistantEffort.parse(body['luma_effort']) ??
      _legacyLevel(body['reasoning_effort'], mode);
  final requested = body['max_tokens'];
  final maxTokens = (requested is int ? requested : 1024)
      .clamp(level.minTokens, level.maxTokens)
      .clamp(1, level.maxTokens);
  return AssistantEffortPlan(
    level: level,
    reasoningEffort: switch (level) {
      AssistantEffort.low => 'low',
      AssistantEffort.medium => mode == 'smartest' ? 'high' : null,
      _ => 'high',
    },
    maxTokens: maxTokens,
  );
}

AssistantEffort _legacyLevel(Object? raw, String mode) => switch (raw) {
      'none' || 'low' => AssistantEffort.low,
      'high' when mode != 'smartest' => AssistantEffort.high,
      _ => AssistantEffort.medium,
    };

/// For the app's effort menu: how much faster each level drains usage.
Map<String, double> get assistantEffortWeights => {
      for (final level in AssistantEffort.values)
        level.name: level.weightTenths / 10,
    };
