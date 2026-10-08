import 'package:flutter/material.dart';

import '../../../l10n/current_l.dart';
import 'ai_client.dart';
import 'anthropic_client.dart';
import 'google_client.dart';
import 'mistral_client.dart';
import 'openai_client.dart';
import 'local_qwen_client.dart';

enum AiProviderId { anthropic, openai, mistral, google, local }

/// One selectable AI provider in Settings: its display identity plus the
/// [AiClient] that actually talks to it.
class AiProviderInfo {
  const AiProviderInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.keyHint,
    required this.client,
  });

  final AiProviderId id;

  /// Read at the point of use so the label follows the language setting.
  final String Function() name;

  String get displayName => name();
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
    name: () => 'Anthropic Claude',
    icon: Icons.smart_toy_rounded,
    keyHint: 'sk-ant-...',
    client: AnthropicClient(),
  ),
  AiProviderInfo(
    id: AiProviderId.openai,
    name: () => 'OpenAI',
    icon: Icons.psychology_rounded,
    keyHint: 'sk-...',
    client: OpenAiClient(),
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

AiProviderInfo aiProviderById(String id) => kAiProviders.firstWhere(
  (p) => p.id.name == id,
  orElse: () => kAiProviders.first,
);
