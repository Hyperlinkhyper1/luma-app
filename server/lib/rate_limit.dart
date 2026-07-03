/// Simple sliding-window rate limiter, keyed by caller (usually IP).
/// In-memory only — resets on restart, which is fine for abuse protection.
class RateLimiter {
  RateLimiter({required this.maxRequests, required this.window});

  final int maxRequests;
  final Duration window;

  final Map<String, List<int>> _hits = {};
  int _sincePrune = 0;

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
}
