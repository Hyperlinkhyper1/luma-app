import 'package:flutter/material.dart';

import 'ai_client.dart';
import 'anthropic_client.dart';
import 'mistral_client.dart';
import 'openai_client.dart';

enum AiProviderId { anthropic, openai, mistral }

/// One selectable AI provider in Settings: its display identity plus the
/// [AiClient] that actually talks to it.
class AiProviderInfo {
  const AiProviderInfo({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.keyHint,
    required this.client,
  });

  final AiProviderId id;
  final String displayName;
  final IconData icon;

  /// Placeholder text for the API key field, e.g. "sk-ant-...".
  final String keyHint;
  final AiClient client;
}

/// Every provider the assistant can talk to.
///
/// Mistral is presented to the user as "Luma" with a moon icon — a product
/// decision, not a technical one — while [MistralClient] still speaks
/// Mistral's actual API underneath.
final List<AiProviderInfo> kAiProviders = [
  AiProviderInfo(
    id: AiProviderId.anthropic,
    displayName: 'Anthropic Claude',
    icon: Icons.smart_toy_rounded,
    keyHint: 'sk-ant-...',
    client: AnthropicClient(),
  ),
  AiProviderInfo(
    id: AiProviderId.openai,
    displayName: 'OpenAI',
    icon: Icons.psychology_rounded,
    keyHint: 'sk-...',
    client: OpenAiClient(),
  ),
  AiProviderInfo(
    id: AiProviderId.mistral,
    displayName: 'Luma',
    icon: Icons.nightlight_round,
    keyHint: 'API key...',
    client: MistralClient(),
  ),
];

AiProviderInfo aiProviderById(String id) => kAiProviders.firstWhere(
      (p) => p.id.name == id,
      orElse: () => kAiProviders.first,
    );
