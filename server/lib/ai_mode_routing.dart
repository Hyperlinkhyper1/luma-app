import 'dart:convert';
import 'dart:io';

import 'util.dart';

/// An upstream the "Luma AI" modes can be routed to. Both speak the OpenAI
/// chat-completions shape, so the proxy only swaps the URL, key and model.
enum AiUpstream {
  google('Google AI Studio',
      'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions'),
  openrouter('OpenRouter', 'https://openrouter.ai/api/v1/chat/completions');

  const AiUpstream(this.label, this.endpoint);

  final String label;
  final String endpoint;

  static AiUpstream? parse(String? raw) {
    for (final u in values) {
      if (u.name == raw) return u;
    }
    return null;
  }
}

/// The app's three modes, keyed by the id the client sends as `model`.
const kAiModeNames = {
  'normal': 'Aurora 1.0',
  'smarter': 'Nebula 1.0',
  'smartest': 'Pulsar 1.0',
};

/// Reasoning-effort overrides the dashboard offers. An empty string means
/// "leave whatever the app sent alone" (the app sends `high` for Pulsar).
const kAiReasoningEfforts = ['', 'none', 'low', 'medium', 'high'];

final _modelPattern = RegExp(r'^[A-Za-z0-9._:/@+-]{1,200}$');

bool isValidAiModelId(String raw) => _modelPattern.hasMatch(raw);

/// Which upstream and model one mode is served by.
class AiModeRoute {
  const AiModeRoute(this.upstream, this.model, {this.reasoningEffort});

  final AiUpstream upstream;
  final String model;

  /// Null keeps the client's own `reasoning_effort`.
  final String? reasoningEffort;

  Map<String, dynamic> toJson() => {
        'upstream': upstream.name,
        'model': model,
        if (reasoningEffort != null) 'reasoningEffort': reasoningEffort,
      };

  static AiModeRoute? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final upstream = AiUpstream.parse(raw['upstream'] as String?);
    final model = raw['model'];
    if (upstream == null || model is! String || !isValidAiModelId(model)) {
      return null;
    }
    final effort = raw['reasoningEffort'];
    return AiModeRoute(upstream, model,
        reasoningEffort: effort is String &&
                effort.isNotEmpty &&
                kAiReasoningEfforts.contains(effort)
            ? effort
            : null);
  }
}

/// What each mode runs on when the operator hasn't picked anything.
///
/// Google uses its rolling "-latest" aliases, since pinned versions get
/// retired for new keys while still listed. Pulsar shares Nebula's Flash
/// model there because free-tier keys get a hard zero quota on Pro; the app
/// asks for high reasoning effort on Pulsar instead.
const kDefaultAiModeModels = {
  AiUpstream.google: {
    'normal': 'gemini-flash-lite-latest',
    'smarter': 'gemini-flash-latest',
    'smartest': 'gemini-flash-latest',
  },
  AiUpstream.openrouter: {
    'normal': 'google/gemini-2.5-flash-lite',
    'smarter': 'google/gemini-2.5-flash',
    'smartest': 'google/gemini-2.5-flash',
  },
};

/// The operator's mode → upstream/model choices from the admin dashboard,
/// kept in `ai_mode_routes.json` so they survive restarts and deploys.
/// Only explicit choices are stored; everything else falls back to
/// [kDefaultAiModeModels].
class AiModeRoutingStore {
  AiModeRoutingStore(String dataDir)
      : _file = File('$dataDir/ai_mode_routes.json') {
    _load();
  }

  final File _file;
  final Map<String, AiModeRoute> _routes = {};

  void _load() {
    try {
      if (!_file.existsSync()) return;
      final decoded = jsonDecode(_file.readAsStringSync());
      if (decoded is! Map) return;
      decoded.forEach((mode, raw) {
        final route = AiModeRoute.fromJson(raw);
        if (mode is String && kAiModeNames.containsKey(mode) && route != null) {
          _routes[mode] = route;
        }
      });
    } catch (e) {
      stderr.writeln('[luma] could not read ${_file.path}: $e');
    }
  }

  /// The operator's stored choice for [mode], if any — whether or not its
  /// upstream currently has a key.
  AiModeRoute? stored(String mode) => _routes[mode];

  /// The route [mode] is actually served by, given which upstreams have a
  /// key. A stored choice whose key has since been removed falls back to the
  /// defaults of a configured upstream rather than failing every chat.
  AiModeRoute? resolve(String mode, Set<AiUpstream> configured) {
    if (!kAiModeNames.containsKey(mode)) mode = 'normal';
    final chosen = _routes[mode];
    if (chosen != null && configured.contains(chosen.upstream)) return chosen;
    for (final upstream in AiUpstream.values) {
      if (configured.contains(upstream)) {
        return AiModeRoute(upstream, kDefaultAiModeModels[upstream]![mode]!);
      }
    }
    return null;
  }

  Future<void> save(Map<String, AiModeRoute> routes) async {
    _routes
      ..clear()
      ..addAll(routes);
    await atomicWriteString(_file.path,
        jsonEncode({for (final e in _routes.entries) e.key: e.value.toJson()}));
  }
}
