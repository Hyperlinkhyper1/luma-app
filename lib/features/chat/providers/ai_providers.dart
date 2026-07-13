import 'package:flutter/material.dart';

import 'ai_client.dart';
import 'anthropic_client.dart';
import 'google_client.dart';
import 'mistral_client.dart';
import 'openai_client.dart';

enum AiProviderId { anthropic, openai, mistral, google }

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
/// Two of these wear luma branding — product decisions, not technical ones:
/// Mistral is presented as "Luma Support" with a moon icon, and Google AI
/// (Gemini) as "Luma AI" with three selectable intelligence modes (Aurora /
/// Nebula / Pulsar — see `providers/ai_modes.dart`). The clients still
/// speak each vendor's actual API underneath.
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
    displayName: 'Luma Support',
    icon: Icons.support_agent_rounded,
    keyHint: 'API key...',
    client: MistralClient(),
  ),
  AiProviderInfo(
    id: AiProviderId.google,
    displayName: 'Luma AI',
    icon: Icons.nightlight_round,
    keyHint: 'AIza...',
    client: GoogleClient(),
  ),
];

AiProviderInfo aiProviderById(String id) => kAiProviders.firstWhere(
      (p) => p.id.name == id,
      orElse: () => kAiProviders.first,
    );
