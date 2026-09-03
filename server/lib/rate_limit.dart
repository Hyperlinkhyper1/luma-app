/// Simple sliding-window rate limiter, keyed by caller (usually IP).
/// In-memory only — resets on restart, which is fine for abuse protection.
class RateLimiter {
  RateLimiter({required this.maxRequests, required this.window});

  final int maxRequests;
  final Duration window;

  final Map<String, List<int>> _hits = {};
  int _sincePrune = 0;

  /// True if [key] is currently over its budget, without recording a hit.
  bool isLimited(String key) {
    final cutoff = DateTime.now().millisecondsSinceEpoch - window.inMilliseconds;
    final times = _hits[key];
    if (times == null) return false;
    times.removeWhere((t) => t < cutoff);
    return times.length >= maxRequests;
  }

  /// Returns true if the request is allowed (and records it).
  bool allow(String key) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - window.inMilliseconds;

    // Periodically drop stale keys so the map cannot grow unbounded.
    if (++_sincePrune > 500) {
      _sincePrune = 0;
      _hits.removeWhere((_, times) => times.isEmpty || times.last < cutoff);
    }

    final times = _hits.putIfAbsent(key, () => <int>[]);
    times.removeWhere((t) => t < cutoff);
    if (times.length >= maxRequests) return false;
    times.add(now);
    return true;
  }

  /// Seconds until [key]'s oldest hit ages out of the window and a slot
  /// frees up — 0 if [key] isn't currently over budget. Lets a 429 response
  /// carry a `Retry-After` header instead of leaving the caller to guess.
  int retryAfterSeconds(String key) {
    final times = _hits[key];
    if (times == null || times.length < maxRequests) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final resetAt = times.first + window.inMilliseconds;
    final seconds = ((resetAt - now) / 1000).ceil();
    return seconds.clamp(1, window.inSeconds);
  }
}
