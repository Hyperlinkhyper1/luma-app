import 'package:flutter/material.dart';

import '../../../l10n/current_l.dart';
import 'ai_client.dart';
import 'anthropic_client.dart';
import 'google_client.dart';
import 'mistral_client.dart';
import 'openai_client.dart';
import 'local_qwen_client.dart';

enum AiProviderId {
  anthropic,
  openai,
  mistral,
  google,
  local,
  openrouter,
  gemini,
}

/// One selectable AI provider in Settings: its display identity plus the
/// [AiClient] that actually talks to it.
class AiProviderInfo {
  const AiProviderInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.keyHint,
    required this.client,
    this.defaultModel,
    this.keyUrl,
    this.modelFor,
  });

  final AiProviderId id;

  /// Read at the point of use so the label follows the language setting.
  final String Function() name;

  String get displayName => name();
  final IconData icon;

  /// Placeholder text for the API key field, e.g. "sk-ant-...".
  final String keyHint;
  final AiClient client;

  /// For the bring-your-own-key providers on the API screen: the model used
  /// when the user hasn't typed one, where to get a key, and how to build a
  /// client for a chosen model.
  final String? defaultModel;
  final String? keyUrl;
  final AiClient Function(String model)? modelFor;
}

/// Every provider the assistant can talk to.
///
/// Two of these wear luma branding — product decisions, not technical ones:
/// Mistral is presented as "Luma Support" with a moon icon, and Google AI
/// (Gemini) as "Luma AI" with three selectable intelligence modes (Aurora /
/// Nebula / Pulsar — see `providers/ai_modes.dart`). The clients still
/// speak each vendor's actual API underneath.
final List<AiProviderInfo> kAiProviders = [
  AiProviderInfo(
    id: AiProviderId.anthropic,
    name: () => 'Anthropic Claude',
    icon: Icons.smart_toy_rounded,
    keyHint: 'sk-ant-...',
    client: AnthropicClient(),
    defaultModel: AnthropicClient.defaultModel,
    keyUrl: 'https://platform.claude.com/settings/keys',
    modelFor: (model) => AnthropicClient(model: model),
  ),
  AiProviderInfo(
    id: AiProviderId.openai,
    name: () => 'OpenAI',
    icon: Icons.psychology_rounded,
    keyHint: 'sk-...',
    client: OpenAiClient(),
    defaultModel: OpenAiClient.defaultModelId,
    keyUrl: 'https://platform.openai.com/api-keys',
    modelFor: (model) => OpenAiClient(model: model),
  ),
  AiProviderInfo(
    id: AiProviderId.openrouter,
    name: () => 'OpenRouter',
    icon: Icons.alt_route_rounded,
    keyHint: 'sk-or-...',
    client: OpenRouterClient(),
    defaultModel: OpenRouterClient.defaultModelId,
    keyUrl: 'https://openrouter.ai/settings/keys',
    modelFor: (model) => OpenRouterClient(model: model),
  ),
  AiProviderInfo(
    id: AiProviderId.gemini,
    name: () => 'Google Gemini',
    icon: Icons.auto_awesome_rounded,
    keyHint: 'AIza...',
    client: GeminiClient(),
    defaultModel: GeminiClient.defaultModelId,
    keyUrl: 'https://aistudio.google.com/apikey',
    modelFor: (model) => GeminiClient(model: model),
  ),
  AiProviderInfo(
    id: AiProviderId.mistral,
    name: () => 'Luma Support',
    icon: Icons.support_agent_rounded,
    keyHint: 'API key...',
    client: MistralClient(),
  ),
  AiProviderInfo(
    id: AiProviderId.google,
    name: () => 'Luma AI',
    icon: Icons.nightlight_round,
    keyHint: 'AIza...',
    client: GoogleClient(),
  ),
  AiProviderInfo(
    id: AiProviderId.local,
    name: () => currentL.chatProviderLocalName,
    icon: Icons.phone_android_rounded,
    keyHint: '',
    client: LocalQwenClient(),
  ),
];

/// The providers the user brings their own key for, in API settings order.
List<AiProviderInfo> get kApiKeyProviders => [
  for (final p in kAiProviders)
    if (p.modelFor != null) p,
];

bool isApiKeyProvider(String id) =>
    kApiKeyProviders.any((p) => p.id.name == id);

/// The client for [providerId], on [model] when the user picked one for a
/// bring-your-own-key provider.
AiClient aiClientFor(String providerId, {String? model}) {
  final provider = aiProviderById(providerId);
  final build = provider.modelFor;
  final chosen = model?.trim() ?? '';
  if (build == null || chosen.isEmpty) return provider.client;
  return build(chosen);
}

AiProviderInfo aiProviderById(String id) => kAiProviders.firstWhere(
  (p) => p.id.name == id,
  orElse: () => kAiProviders.first,
);
