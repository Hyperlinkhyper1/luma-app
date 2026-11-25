import 'dart:convert';

import '../../account/plan.dart';
import 'providers/ai_providers.dart';

/// How hard Luma AI thinks before answering. The app only names the level
/// it wants (`luma_effort`); the luma server picks the reasoning setting and
/// output budget and charges the higher levels faster, so usage is always
/// counted there, never here.
enum AssistantEffort {
  low,
  medium,
  high,
  extra,
  max;

  static const recommended = AssistantEffort.medium;

  static AssistantEffort parse(String? raw) => AssistantEffort.values
      .firstWhere((e) => e.name == raw, orElse: () => recommended);

  /// What the server charges per level, for the menu when the server's own
  /// numbers (`AiServerStatus.effortWeights`) aren't in yet.
  double get fallbackWeight => switch (this) {
    AssistantEffort.low || AssistantEffort.medium => 1,
    AssistantEffort.high => 1.5,
    AssistantEffort.extra => 2.5,
    AssistantEffort.max => 3.5,
  };

  /// `reasoning_effort` for a chat on the user's own Google key, which
  /// never touches the luma server. The server applies the same mapping to
  /// proxied chats.
  String? reasoningEffortFor(String? modeDefault) => switch (this) {
    AssistantEffort.low => 'low',
    AssistantEffort.medium => modeDefault,
    _ => 'high',
  };

  /// Output budget asked for. The server clamps proxied requests to the
  /// level's own range whatever is sent.
  int get maxOutputTokens => switch (this) {
    AssistantEffort.low => 1024,
    AssistantEffort.medium => 1024,
    AssistantEffort.high => 4096,
    AssistantEffort.extra => 8192,
    AssistantEffort.max => 16384,
  };

  /// Higher levels think longer, so they wait longer for the first token.
  Duration get timeout => index >= AssistantEffort.extra.index
      ? const Duration(seconds: 180)
      : const Duration(seconds: 120);

  /// Added to the system prompt at the top levels.
  String? get prompt => switch (this) {
    AssistantEffort.extra =>
      'Take extra care: reason the problem through fully, check facts, '
          'numbers and code before answering.',
    AssistantEffort.max =>
      'Take maximum care: reason the problem through fully, consider '
          'alternatives and edge cases, and verify every fact, number and '
          'line of code before answering.',
    _ => null,
  };
}

/// What a reply's metadata says about how hard it was worked on: the review
/// rounds of an Ultra Reasoning turn, or a non-default effort level.
({int? checks, AssistantEffort? effort})? chatEffortOf(String? metadataJson) {
  if (metadataJson == null) return null;
  Object? decoded;
  try {
    decoded = jsonDecode(metadataJson);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) return null;
  if (decoded['ultra'] case {'checks': final int checks}) {
    return (checks: checks, effort: AssistantEffort.max);
  }
  final effort = decoded['effort'];
  if (effort is String && AssistantEffort.values.any((e) => e.name == effort)) {
    return (checks: null, effort: AssistantEffort.parse(effort));
  }
  return null;
}

/// Effort levels apply to Luma AI (its modes and Luma Auto), on the server's
/// shared key or the user's own Google key.
bool effortSupported(String providerId) =>
    providerId == AiProviderId.google.name;

/// The plan Ultra Reasoning is unlocked from: it runs deep research, so it
/// follows the + menu's research gate.
const kUltraReasoningMinPlan = 'nova';

bool ultraReasoningUnlocked(String? planId) =>
    planAtLeast(planId, kUltraReasoningMinPlan);

/// Whether a turn runs Ultra Reasoning: switched on, on a plan that has it,
/// with Luma AI selected.
bool ultraReasoningActive({
  required bool enabled,
  required String? planId,
  required String providerId,
}) => enabled && ultraReasoningUnlocked(planId) && effortSupported(providerId);
