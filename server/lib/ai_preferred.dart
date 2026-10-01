import 'dart:convert';
import 'dart:io';

import 'ai_image.dart';
import 'ai_mode_routing.dart';
import 'util.dart';

/// Every model selector on the Assistant tab: the three chat modes, the AI
/// Detector, the book reviewer, the classroom tutor and the picture model.
/// Each has a main model and can name an "if possible" model in front of it.
final kAiModelSelectors = List<String>.unmodifiable(
    [...kAiModeNames.keys, 'detector', 'bookreview', 'classroom', 'picture']);

const _preferredSuffix = '.preferred';

/// The price-guard and dashboard key of [selector]'s "if possible" model.
String aiPreferredKey(String selector) => '$selector$_preferredSuffix';

bool isAiPreferredKey(String key) => key.endsWith(_preferredSuffix);

/// The selector a main or "if possible" key belongs to.
String aiSelectorOf(String key) => isAiPreferredKey(key)
    ? key.substring(0, key.length - _preferredSuffix.length)
    : key;

/// Upstreams [selector] can run on; only some of them can draw.
bool aiSelectorAccepts(String selector, AiUpstream upstream) =>
    selector != 'picture' || kAiImageUpstreams.contains(upstream);

/// The operator's "if possible" model per selector, kept in
/// `ai_preferred_models.json`. A request goes to it whenever its provider
/// has a key and its price guard hasn't paused it, and falls back to the
/// selector's main model otherwise — or when it fails.
class AiPreferredStore {
  AiPreferredStore(String dataDir)
      : _file = File('$dataDir/ai_preferred_models.json') {
    try {
      if (!_file.existsSync()) return;
      final decoded = jsonDecode(_file.readAsStringSync());
      if (decoded is! Map) return;
      decoded.forEach((selector, raw) {
        final route = AiModeRoute.fromJson(raw);
        if (selector is String &&
            kAiModelSelectors.contains(selector) &&
            route != null &&
            aiSelectorAccepts(selector, route.upstream)) {
          _routes[selector] = route;
        }
      });
    } catch (e) {
      stderr.writeln('[luma] could not read ${_file.path}: $e');
    }
  }

  final File _file;
  final Map<String, AiModeRoute> _routes = {};
  final AsyncLock _lock = AsyncLock();

  /// The stored pick for [selector], whether or not its upstream has a key.
  AiModeRoute? stored(String selector) => _routes[selector];

  /// The pick for [selector] when its upstream currently has a key.
  AiModeRoute? resolve(String selector, Set<AiUpstream> configured) {
    final route = _routes[selector];
    return route != null && configured.contains(route.upstream) ? route : null;
  }

  /// Sets or, with a null [route], clears [selector]'s pick.
  Future<void> save(String selector, AiModeRoute? route) =>
      _lock.synchronized(() async {
        final next = Map<String, AiModeRoute>.of(_routes);
        if (route == null) {
          next.remove(selector);
        } else {
          next[selector] = route;
        }
        await atomicWriteString(_file.path,
            jsonEncode({for (final e in next.entries) e.key: e.value.toJson()}));
        _routes
          ..clear()
          ..addAll(next);
      });
}

/// One model a request may be sent to, with the price-guard key it is
/// metered and paused under.
typedef AiRouteCandidate = ({String key, AiModeRoute route});

/// The order a request tries its models in: the "if possible" model unless
/// it is missing or paused, then the main model unless it is paused. Empty
/// when both are paused.
List<AiRouteCandidate> aiRouteCandidates(
  String selector, {
  required AiModeRoute? preferred,
  required bool preferredPaused,
  required AiModeRoute? main,
  required bool mainPaused,
}) {
  final out = <AiRouteCandidate>[];
  if (preferred != null && !preferredPaused) {
    out.add((key: aiPreferredKey(selector), route: preferred));
  }
  final sameAsPreferred = preferred != null &&
      main != null &&
      preferred.upstream == main.upstream &&
      preferred.model == main.model &&
      preferred.reasoningEffort == main.reasoningEffort;
  if (main != null && !mainPaused && !(sameAsPreferred && out.isNotEmpty)) {
    out.add((key: selector, route: main));
  }
  return out;
}
