import 'dart:convert';
import 'dart:io';

import 'ai_mode_routing.dart';
import 'util.dart';

/// Share of the selected mode's weekly token budget one picture costs, per
/// plan. Plans missing here can't use picture mode at all.
const Map<String, int> kAiImageWeeklyPercent = {
  'orbit': 7,
  'nova': 3,
};

int? aiImageWeeklyPercentForPlan(String? planId) =>
    kAiImageWeeklyPercent[planId];

/// Longest prompt forwarded to the image model.
const kAiImageMaxPromptChars = 4000;

/// The upstreams that can draw. Mistral has no image model behind the
/// OpenAI-shape API, so it is left out of the dashboard's picker.
const kAiImageUpstreams = [AiUpstream.google, AiUpstream.openrouter];

/// What the picture mode runs on when the operator hasn't picked a model.
const kDefaultAiImageModels = {
  AiUpstream.google: 'imagen-4.0-generate-001',
  AiUpstream.openrouter: 'google/gemini-2.5-flash-image',
};

/// Google serves Imagen on the OpenAI-compat images endpoint. OpenRouter
/// draws through its unified images endpoint, which takes every image model;
/// image-only ones (Ming, FLUX…) refuse chat completions outright.
Uri aiImageEndpoint(AiUpstream upstream) => switch (upstream) {
      AiUpstream.google => Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/openai/images/generations'),
      AiUpstream.openrouter =>
        Uri.parse('https://openrouter.ai/api/v1/images'),
      _ => Uri.parse(upstream.endpoint),
    };

Map<String, dynamic> aiImageRequestBody(AiModeRoute route, String prompt) =>
    switch (route.upstream) {
      AiUpstream.google => {
          'model': route.model,
          'prompt': prompt,
          'n': 1,
          'response_format': 'b64_json',
        },
      _ => {
          'model': route.model,
          'prompt': prompt,
          'n': 1,
        },
    };

/// One generated picture, still base64 so it can go straight back out as
/// JSON.
class AiImageResult {
  const AiImageResult(
      {required this.base64, required this.mimeType, this.text});

  final String base64;
  final String mimeType;

  /// Any caption the model wrote alongside the picture.
  final String? text;
}

/// Pulls the first picture out of either response shape: an images
/// endpoint's `data[].b64_json` (with OpenRouter's `media_type`), or a chat
/// completion's `choices[].message.images[].image_url.url` data URL. Null
/// when the model answered without one.
AiImageResult? parseAiImageResponse(String body) {
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) return null;

  final data = decoded['data'];
  if (data is List) {
    for (final item in data) {
      if (item is Map && item['b64_json'] is String) {
        final b64 = (item['b64_json'] as String).trim();
        if (b64.isEmpty) continue;
        final mediaType = item['media_type'];
        return AiImageResult(
            base64: b64,
            mimeType: mediaType is String && mediaType.startsWith('image/')
                ? mediaType
                : _sniffMime(b64));
      }
    }
  }

  final choices = decoded['choices'];
  if (choices is List && choices.isNotEmpty && choices.first is Map) {
    final message = (choices.first as Map)['message'];
    if (message is Map) {
      final content = message['content'];
      final text =
          content is String && content.trim().isNotEmpty ? content.trim() : null;
      final images = message['images'];
      if (images is List) {
        for (final image in images) {
          final url = image is Map && image['image_url'] is Map
              ? (image['image_url'] as Map)['url']
              : null;
          if (url is! String) continue;
          final match =
              RegExp(r'^data:(image/[a-zA-Z0-9.+-]+);base64,(.+)$', dotAll: true)
                  .firstMatch(url);
          if (match == null) continue;
          return AiImageResult(
              base64: match.group(2)!.trim(),
              mimeType: match.group(1)!,
              text: text);
        }
      }
    }
  }
  return null;
}

String _sniffMime(String b64) {
  if (b64.startsWith('/9j/')) return 'image/jpeg';
  if (b64.startsWith('UklGR')) return 'image/webp';
  return 'image/png';
}

/// Keeps the operator's picture-model choice in `ai_image.json`.
class AiImageConfigStore {
  AiImageConfigStore(String dataDir)
      : _file = File('$dataDir/ai_image.json') {
    try {
      if (_file.existsSync()) {
        final decoded = jsonDecode(_file.readAsStringSync());
        final route =
            AiModeRoute.fromJson(decoded is Map ? decoded['route'] : null);
        if (route != null && kAiImageUpstreams.contains(route.upstream)) {
          _route = route;
        }
      }
    } catch (e) {
      stderr.writeln('[luma] could not read ${_file.path}: $e');
    }
  }

  final File _file;
  AiModeRoute? _route;

  /// The operator's stored pick, whether or not its upstream has a key.
  AiModeRoute? get stored => _route;

  /// The route pictures are drawn with: the stored pick when its upstream
  /// has a key, otherwise the default of the first configured upstream
  /// that can draw.
  AiModeRoute? resolve(Set<AiUpstream> configured) {
    final chosen = _route;
    if (chosen != null && configured.contains(chosen.upstream)) return chosen;
    for (final upstream in kAiImageUpstreams) {
      if (configured.contains(upstream)) {
        return AiModeRoute(upstream, kDefaultAiImageModels[upstream]!);
      }
    }
    return null;
  }

  Future<void> save(AiModeRoute? route) async {
    _route = route;
    await atomicWriteString(
        _file.path, jsonEncode({if (route != null) 'route': route.toJson()}));
  }
}
