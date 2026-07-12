/// One entry in the admin dashboard's activity feed — account lifecycle and
/// admin actions worth an operator seeing, e.g. "user@x.com registered".
/// Persisted to disk (see Store.activity) so the feed survives a restart,
/// unlike the live-only /admin/metrics numbers.
class ActivityEvent {
  ActivityEvent({
    required this.type,
    required this.message,
    required this.createdAtMs,
  });

  final String type;
  final String message;
  final int createdAtMs;

  Map<String, dynamic> toJson() => {
        'type': type,
        'message': message,
        'createdAtMs': createdAtMs,
      };

  factory ActivityEvent.fromJson(Map<String, dynamic> j) => ActivityEvent(
        type: j['type'] as String,
        message: j['message'] as String,
        createdAtMs: j['createdAtMs'] as int,
      );
}
