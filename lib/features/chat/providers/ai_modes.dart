/// The user-facing "Luma AI" intelligence modes, powered by Google AI
/// (Gemini) underneath. The branded names are the product identity — the
/// user never sees a Gemini model name.
enum AiMode {
  normal('Aurora 1.0', 'gemini-flash-lite-latest'),
  smarter('Nebula 1.0', 'gemini-flash-latest'),
  smartest('Pulsar 1.0', 'gemini-pro-latest');

  const AiMode(this.displayName, this.geminiModel);

  /// What the user sees in the mode picker.
  final String displayName;

  /// The real model, used only when chatting with the user's own Google
  /// key. Server-proxied chats send [name] instead and the server does its
  /// own mode→model mapping (Api._googleModeModels), so it can upgrade
  /// models without an app release.
  ///
  /// Uses Google's rolling "-latest" aliases rather than a pinned version
  /// (e.g. "gemini-2.5-flash") — pinned versions get retired for
  /// newer API keys/projects even while still listed in /models, which is
  /// what broke this the first time (404 "no longer available to new
  /// users" despite the model appearing in the models list). The aliases
  /// always resolve to whatever Google currently serves for that tier.
  final String geminiModel;
}

AiMode aiModeById(String id) => AiMode.values.firstWhere(
      (m) => m.name == id,
      orElse: () => AiMode.normal,
    );
