import '../../../../l10n/current_l.dart';
import 'ai_usage_pricing_freebuff.dart';
import 'ai_usage_pricing_luma.dart';
import 'ai_usage_source.dart';

/// Display formatting shared by the Usage tab and the widgets split out of
/// it. Lives here rather than privately in ai_usage_page.dart so a new
/// section does not have to choose between reaching into that file and
/// growing its own near-duplicate.


/// Source-prefixed display name, e.g. "claude-opus-4-8" -> "Claude · Opus
/// 4.8", "gpt-5.4-mini" -> "Codex · GPT 5.4 mini". Names outside the
/// recognized families for that source fall back to the raw model string
/// with just the source prefix.
String displayName(AiUsageSource source, String model) {
  return switch (source) {
      AiUsageSource.claudeCode => 'Claude · ${_shortModelName(model)}',
      AiUsageSource.codexCli => 'Codex · ${_shortOpenAiModelName(model)}',
      // Already a human-readable name extracted from Antigravity's own UI
      // text (e.g. "Claude Opus 4.6 (Thinking)") — no family-name shortening
      // needed the way the other two sources' raw API model IDs require.
      AiUsageSource.antigravity =>
        'Antigravity · ${model == 'Unknown model' ? currentL.aiUsageUnknownModel : model}',
      AiUsageSource.opencode => 'OpenCode · ${_shortOpencodeModelName(model)}',
      AiUsageSource.freebuff => 'Freebuff · ${_shortFreebuffModelName(model)}',
      AiUsageSource.luma => 'Luma · ${_shortLumaModelName(model)}',
    };
}

/// "anthropic/claude-opus-4-6" -> "Opus 4.6", "openai/gpt-5.4" -> "GPT 5.4",
/// "opencode/x-preview-f-free" -> "x-preview-f-free". Undoes the
/// `"<providerID>/<modelID>"` prefix opencode_scanner.dart stores models
/// with (so cost can route to the right provider's pricing table — see
/// ai_usage_pricing.dart), applying that provider's own short-name style
/// where recognized and falling back to the raw model id otherwise.
String _shortOpencodeModelName(String model) {
  final split = splitOpencodeModel(model);
  if (split == null) return model;
  final (provider, modelId) = split;
  return switch (provider) {
    'anthropic' => _shortModelName(modelId),
    'openai' => _shortOpenAiModelName(modelId),
    _ => modelId,
  };
}

/// "z-ai/glm-5.3-flash" -> "glm-5.3-flash", "anthropic/claude-opus-4-8" ->
/// "Opus 4.8", "gpt-5.6-luna" (no provider prefix at all — an embedded
/// Claude Code/Codex CLI thread, see `splitFreebuffModel`'s doc) -> "GPT 5.6
/// luna". Undoes the same `"<providerID>/<modelID>"` prefix opencode's own
/// short name does, applying that provider's short-name style where
/// recognized and falling back to the raw model id otherwise.
String _shortFreebuffModelName(String model) {
  final split = splitFreebuffModel(model);
  if (split == null) {
    final m = model.toLowerCase();
    if (m.contains('gpt-') || m.contains('codex-')) return _shortOpenAiModelName(model);
    return _shortModelName(model);
  }
  final (provider, modelId) = split;
  return switch (provider) {
    'anthropic' || 'fbc' => _shortModelName(modelId),
    'openai' => _shortOpenAiModelName(modelId),
    _ => _kFreebuffModelNames['$provider/$modelId'] ?? modelId,
  };
}

/// The names Freebuff's own model picker shows for its native catalog, so a
/// row reads "MiMo 2.6 Pro" rather than "mimo-v2.6-pro". Anthropic and
/// OpenAI models keep this app's own short names instead.
const Map<String, String> _kFreebuffModelNames = {
  'google/gemini-4-argon': 'Gemini 4 Argon',
  'google/gemini-3.8-flash': 'Gemini 3.8 Flash',
  'google/gemini-3.7-flash': 'Gemini 3.7 Flash',
  'google/gemini-3.6-flash': 'Gemini 3.6 Flash',
  'google/gemini-3.5-flash': 'Gemini 3.5 Flash',
  'google/gemini-3.1-pro-preview': 'Gemini 3.1 Pro',
  'z-ai/glm-5.3': 'GLM 5.3',
  'z-ai/glm-5.3-prime': 'GLM 5.3 Prime',
  'z-ai/glm-5.3-flash': 'GLM 5.3 Flash',
  'z-ai/glm-5.3-flashx': 'GLM 5.3 FlashX',
  'z-ai/glm-5.2': 'GLM 5.2',
  'z-ai/glm-5-turbo': 'GLM 5 Turbo',
  'deepseek/deepseek-v4-pro': 'DeepSeek V4 Pro',
  'deepseek/deepseek-v4-flash': 'DeepSeek V4 Flash',
  'deepseek/deepseek-v4-flash-fast': 'DeepSeek V4 Flash Fast',
  'deepseek/deepseek-v4.1-flash': 'DeepSeek V4.1 Flash',
  'mimo/mimo-v2.5': 'MiMo 2.6 Flash Fast',
  'mimo/mimo-v2.5-pro': 'MiMo 2.5 Pro',
  'mimo/mimo-v2.6-pro': 'MiMo 2.6 Pro',
  'upstage/solar-pro4': 'Solar Pro 4',
  'upstage/solar-mini4': 'Solar Mini 4',
  'moonshotai/kimi-k3': 'Kimi K3',
  'crof/kimi-k3-eco': 'Kimi K3 Eco',
  'minimax/minimax-m3': 'MiniMax M3',
  'qwen/qwen3.8-max-prime': 'Qwen 3.8 Max Prime',
  'qwen/qwen3.8-max-0902': 'Qwen 3.8 Max',
  'qwen/qwen3.8-flash': 'Qwen 3.8 Flash',
  'qwen/qwen3.8-27b': 'Qwen 3.8 27B',
  'qwen/qwen3.7-max': 'Qwen 3.7 Max',
  'qwen/qwen3.7-plus': 'Qwen 3.7 Plus',
  'qwen/qwen3.6-max-preview': 'Qwen 3.6 Max',
  'qwen/qwen3.6-plus': 'Qwen 3.6 Plus',
  'x-ai/grok-4.7': 'Grok 4.7',
  'x-ai/grok-4.6': 'Grok 4.6',
  'x-ai/grok-4.5': 'Grok 4.5',
  'x-ai/grok-4.20': 'Grok 4.20',
  'meta/muse-spark-1.3-contributor': 'Muse Spark 1.3',
  'meta/muse-spark-1.2-contributor': 'Muse Spark 1.2',
  'meta-llama/llama-4-maverick': 'Llama 4 Maverick',
  'mistralai/mistral-large': 'Mistral Large',
  'mistralai/codestral-2508': 'Codestral',
  'stealth/space-bunny-alpha': 'Space Bunny Alpha',
  'stealth/ox-alpha': 'Ox Alpha',
};

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

/// "gpt-5.4-mini" -> "GPT 5.4 mini", "gpt-5.5" -> "GPT 5.5". A Codex-internal
/// alias such as "codex-auto-review" (the sandbox approval reviewer, not a
/// public model) is title-cased instead — "Auto Review". Names outside both
/// conventions fall back to the raw string.
String _shortOpenAiModelName(String model) {
  final m = model.toLowerCase();
  if (m.startsWith('codex-')) {
    return model
        .substring('codex-'.length)
        .split('-')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
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

/// "anthropic/claude-3-5-haiku-20241022" -> "Haiku 3.5", "openai/gpt-4o-mini"
/// -> "GPT 4o mini". Gemini and Mistral slugs are already readable and stay
/// as they are, rather than naming a release their `-latest` alias only
/// probably points at.
String _shortLumaModelName(String model) {
  final split = splitLumaModel(model);
  if (split == null) return model;
  final (provider, modelId) = split;
  return switch (provider) {
    'anthropic' => _shortModelName(modelId),
    'openai' => _shortOpenAiModelName(modelId),
    _ => modelId,
  };
}
