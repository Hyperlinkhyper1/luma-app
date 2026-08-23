import 'ai_usage_source.dart';

/// Display formatting shared by the Usage tab and the widgets split out of
/// it. Lives here rather than privately in ai_usage_page.dart so a new
/// section does not have to choose between reaching into that file and
/// growing its own near-duplicate.


/// Source-prefixed display name, e.g. "claude-opus-4-8" -> "Claude · Opus
/// 4.8", "gpt-5.4-mini" -> "Codex · GPT 5.4 mini". Names outside the
/// recognized families for that source fall back to the raw model string
/// with just the source prefix.
String displayName(AiUsageSource source, String model) => switch (source) {
      AiUsageSource.claudeCode => 'Claude · ${_shortModelName(model)}',
      AiUsageSource.codexCli => 'Codex · ${_shortOpenAiModelName(model)}',
      // Already a human-readable name extracted from Antigravity's own UI
      // text (e.g. "Claude Opus 4.6 (Thinking)") — no family-name shortening
      // needed the way the other two sources' raw API model IDs require.
      AiUsageSource.antigravity => 'Antigravity · $model',
      AiUsageSource.opencode => 'OpenCode · ${_shortOpencodeModelName(model)}',
    };

/// "anthropic/claude-opus-4-6" -> "Opus 4.6", "openai/gpt-5.4" -> "GPT 5.4",
/// "opencode/x-preview-f-free" -> "x-preview-f-free". Undoes the
/// `"<providerID>/<modelID>"` prefix opencode_scanner.dart stores models
/// with (so cost can route to the right provider's pricing table — see
/// ai_usage_pricing.dart), applying that provider's own short-name style
/// where recognized and falling back to the raw model id otherwise.
String _shortOpencodeModelName(String model) {
  final slash = model.indexOf('/');
  if (slash < 0) return model;
  final provider = model.substring(0, slash);
  final modelId = model.substring(slash + 1);
  return switch (provider) {
    'anthropic' => _shortModelName(modelId),
    'openai' => _shortOpenAiModelName(modelId),
    _ => modelId,
  };
}

/// "claude-opus-4-8" -> "Opus 4.8", "claude-fable-5" -> "Fable 5". Names
/// outside the recognized Anthropic families fall back to the raw string.
String _shortModelName(String model) {
  final m = model.toLowerCase();
  String? family;
  if (m.contains('fable')) {
    family = 'Fable';
  } else if (m.contains('mythos')) {
    family = 'Mythos';
  } else if (m.contains('opus')) {
    family = 'Opus';
  } else if (m.contains('sonnet')) {
    family = 'Sonnet';
  } else if (m.contains('haiku')) {
    family = 'Haiku';
  }
  if (family == null) return model;
  final versioned = RegExp(r'(\d+)[._-](\d+)').firstMatch(model);
  if (versioned != null) return '$family ${versioned.group(1)}.${versioned.group(2)}';
  final single = RegExp(r'(\d+)').firstMatch(model);
  return single != null ? '$family ${single.group(1)}' : family;
}

/// "gpt-5.4-mini" -> "GPT 5.4 mini", "gpt-5.5" -> "GPT 5.5". Names outside
/// the "gpt-" naming convention fall back to the raw string.
String _shortOpenAiModelName(String model) {
  final m = model.toLowerCase();
  if (!m.startsWith('gpt-')) return model;
  final rest = model.substring('gpt-'.length); // e.g. "5.4-mini"
  return 'GPT ${rest.replaceAll('-', ' ')}';
}

String formatTokens(int n) {
  if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(2)}B';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(2)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

String formatCost(double cost) => '\$${cost.toStringAsFixed(2)}';
