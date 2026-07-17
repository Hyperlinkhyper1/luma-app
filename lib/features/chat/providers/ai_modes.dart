/// The user-facing "Luma AI" intelligence modes, powered by Google AI
/// (Gemini) underneath. The branded names are the product identity — the
/// user never sees a Gemini model name.
enum AiMode {
  normal('Aurora 1.0', 'gemini-flash-lite-latest', null),
  smarter('Nebula 1.0', 'gemini-flash-latest', null),
  smartest('Pulsar 1.0', 'gemini-flash-latest', 'high');

  const AiMode(this.displayName, this.geminiModel, this.reasoningEffort);

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
  /// users" despite the model appearing in the models list).
  ///
  /// Pulsar shares Nebula's Flash model rather than a Pro one — Google's
  /// free-tier API keys get a hard `limit: 0` quota on every Pro-tier
  /// model (2.5-pro, 3.1-pro, ...), confirmed directly against the API,
  /// so Pro isn't usable without enabling billing. Pulsar's "smartest"
  /// distinction instead comes from [reasoningEffort] forcing deeper
  /// thinking on the same model.
  final String geminiModel;

  /// Sent as `reasoning_effort` to Gemini's OpenAI-compat endpoint, which
  /// maps it to the model's internal thinking-token budget — null leaves
  /// the model's default thinking behavior alone. Only Pulsar sets this,
  /// so it visibly reasons more before answering even on the same
  /// underlying Flash model as Nebula.
  final String? reasoningEffort;
}

AiMode aiModeById(String id) => AiMode.values.firstWhere(
      (m) => m.name == id,
      orElse: () => AiMode.normal,
    );
