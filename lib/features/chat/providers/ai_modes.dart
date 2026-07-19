/// The user-facing "Luma AI" intelligence modes, powered by Google AI
/// (Gemini) underneath. The branded names are the product identity — the
/// user never sees a Gemini model name.
enum AiMode {
  normal('Aurora 1.0', 'gemini-2.5-flash-lite'),
  smarter('Nebula 1.0', 'gemini-2.5-flash'),
  smartest('Pulsar 1.0', 'gemini-2.5-pro');

  const AiMode(this.displayName, this.geminiModel);

  /// What the user sees in the mode picker.
  final String displayName;

  /// The real model, used only when chatting with the user's own Google
  /// key. Server-proxied chats send [name] instead and the server does its
  /// own mode→model mapping (Api._googleModeModels), so it can upgrade
  /// models without an app release.
  final String geminiModel;
}

AiMode aiModeById(String id) => AiMode.values.firstWhere(
      (m) => m.name == id,
      orElse: () => AiMode.normal,
    );
