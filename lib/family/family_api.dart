import 'dart:convert';

import 'package:http/http.dart' as http;

/// A member of a family, as seen from the server.
class RemoteFamilyMember {
  const RemoteFamilyMember({
    required this.userId,
    required this.email,
    required this.role,
    required this.joinedAtMs,
  });

  final String userId;
  final String email;
  final String role; // 'owner' | 'member'
  final int joinedAtMs;

  bool get isOwner => role == 'owner';

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'email': email,
        'role': role,
        'joinedAtMs': joinedAtMs,
      };

  factory RemoteFamilyMember.fromJson(Map<String, dynamic> j) =>
      RemoteFamilyMember(
        userId: j['userId'] as String,
        email: j['email'] as String,
        role: j['role'] as String,
        joinedAtMs: j['joinedAtMs'] as int,
      );
}

/// An invite the family owner has sent that's still awaiting a response.
class RemoteOutgoingInvite {
  const RemoteOutgoingInvite({
    required this.id,
    required this.email,
    required this.createdAtMs,
    required this.expiresAtMs,
  });

  final String id;
  final String email;
  final int createdAtMs;
  final int expiresAtMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'createdAtMs': createdAtMs,
        'expiresAtMs': expiresAtMs,
      };

  factory RemoteOutgoingInvite.fromJson(Map<String, dynamic> j) =>
      RemoteOutgoingInvite(
        id: j['id'] as String,
        email: j['email'] as String,
        createdAtMs: j['createdAtMs'] as int,
        expiresAtMs: j['expiresAtMs'] as int,
      );
}

/// The current user's family: roster, slot usage, and (owner-only) pending
/// invites sent.
class RemoteFamily {
  const RemoteFamily({
    required this.id,
    required this.name,
    required this.ownerUserId,
    required this.createdAtMs,
    required this.slotLimit,
    required this.slotsUsed,
    required this.members,
    required this.pendingInvites,
  });

  final String id;
  final String name;
  final String ownerUserId;
  final int createdAtMs;
  final int? slotLimit;
  final int slotsUsed;
  final List<RemoteFamilyMember> members;
  final List<RemoteOutgoingInvite> pendingInvites;

  bool isOwner(String userId) => ownerUserId == userId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ownerUserId': ownerUserId,
        'createdAtMs': createdAtMs,
        'slotLimit': slotLimit,
        'slotsUsed': slotsUsed,
        'members': members.map((m) => m.toJson()).toList(),
        'pendingInvites': pendingInvites.map((i) => i.toJson()).toList(),
      };

  factory RemoteFamily.fromJson(Map<String, dynamic> j) => RemoteFamily(
        id: j['id'] as String,
        name: j['name'] as String,
        ownerUserId: j['ownerUserId'] as String,
        createdAtMs: j['createdAtMs'] as int,
        slotLimit: j['slotLimit'] as int?,
        slotsUsed: j['slotsUsed'] as int? ?? 0,
        members: (j['members'] as List? ?? const [])
            .map((m) => RemoteFamilyMember.fromJson(m as Map<String, dynamic>))
            .toList(),
        pendingInvites: (j['pendingInvites'] as List? ?? const [])
            .map((i) =>
                RemoteOutgoingInvite.fromJson(i as Map<String, dynamic>))
            .toList(),
      );
}

/// An invite addressed to the current user's own email — feeds the inbox.
class RemoteIncomingInvite {
  const RemoteIncomingInvite({
    required this.id,
    required this.familyId,
    required this.familyName,
    required this.inviterEmail,
    required this.createdAtMs,
    required this.expiresAtMs,
  });

  final String id;
  final String familyId;
  final String familyName;
  final String inviterEmail;
  final int createdAtMs;
  final int expiresAtMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'familyId': familyId,
        'familyName': familyName,
        'inviterEmail': inviterEmail,
        'createdAtMs': createdAtMs,
        'expiresAtMs': expiresAtMs,
      };

  factory RemoteIncomingInvite.fromJson(Map<String, dynamic> j) =>
      RemoteIncomingInvite(
        id: j['id'] as String,
        familyId: j['familyId'] as String,
        familyName: j['familyName'] as String,
        inviterEmail: j['inviterEmail'] as String,
        createdAtMs: j['createdAtMs'] as int,
        expiresAtMs: j['expiresAtMs'] as int,
      );
}

/// A calendar entry shared with (part of) a family. Unlike everything synced
/// through [SyncApi], this data is deliberately readable by the server — see
/// the note atop server/lib/family_store.dart.
class RemoteSharedEvent {
  const RemoteSharedEvent({
    required this.id,
    required this.familyId,
    required this.authorUserId,
    required this.title,
    this.description,
    this.location,
    required this.startMs,
    required this.endMs,
    required this.allDay,
    required this.color,
    required this.recurrence,
    this.recurrenceEndMs,
    this.reminderMinutes,
    required this.visibility,
    required this.visibleMemberUserIds,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String id;
  final String familyId;
  final String authorUserId;
  final String title;
  final String? description;
  final String? location;
  final int startMs;
  final int endMs;
  final bool allDay;
  final int color;
  final String recurrence;
  final int? recurrenceEndMs;
  final int? reminderMinutes;
  final String visibility; // 'all' | 'subset'
  final List<String> visibleMemberUserIds;
  final int createdAtMs;
  final int updatedAtMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'familyId': familyId,
        'authorUserId': authorUserId,
        'title': title,
        'description': description,
        'location': location,
        'startMs': startMs,
        'endMs': endMs,
        'allDay': allDay,
        'color': color,
        'recurrence': recurrence,
        'recurrenceEndMs': recurrenceEndMs,
        'reminderMinutes': reminderMinutes,
        'visibility': visibility,
        'visibleMemberUserIds': visibleMemberUserIds,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
      };

  factory RemoteSharedEvent.fromJson(Map<String, dynamic> j) =>
      RemoteSharedEvent(
        id: j['id'] as String,
        familyId: j['familyId'] as String,
        authorUserId: j['authorUserId'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        location: j['location'] as String?,
        startMs: j['startMs'] as int,
        endMs: j['endMs'] as int,
        allDay: j['allDay'] as bool,
        color: j['color'] as int,
        recurrence: j['recurrence'] as String? ?? 'none',
        recurrenceEndMs: j['recurrenceEndMs'] as int?,
        reminderMinutes: j['reminderMinutes'] as int?,
        visibility: j['visibility'] as String? ?? 'all',
        visibleMemberUserIds: (j['visibleMemberUserIds'] as List? ?? const [])
            .map((e) => e as String)
            .toList(),
        createdAtMs: j['createdAtMs'] as int,
        updatedAtMs: j['updatedAtMs'] as int,
      );
}

/// Raised for every non-successful server response, mirroring [SyncApiException].
class FamilyApiException implements Exception {
  const FamilyApiException(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;

  bool get isNotFound => status == 404;
  bool get isLimitExceeded => code == 'family_limit_exceeded';

  @override
  String toString() => message;
}

/// Thin typed HTTP client for the family/invite/shared-event endpoints.
/// Deliberately separate from [SyncApi]: these bodies are plain JSON, never
/// sealed with the account's zero-knowledge encryption key, since the whole
/// point of this channel is that it's shared across accounts.
class FamilyApi {
  FamilyApi(String baseUrl, {this.token, http.Client? client})
      : baseUrl = _normalizeBaseUrl(baseUrl),
        _client = client ?? http.Client();

  final String baseUrl;
  String? token;
  final http.Client _client;

  static const _timeout = Duration(seconds: 30);

  static String _normalizeBaseUrl(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Uri _uri(String path) => Uri.parse('$baseUrl/api/v1$path');

  Map<String, String> get _authHeaders =>
      {if (token != null) 'Authorization': 'Bearer $token'};

  Future<RemoteFamily?> getMyFamily() async {
    final response = await _client
        .get(_uri('/family'), headers: _authHeaders)
        .timeout(_timeout);
    if (response.statusCode == 404) return null;
    return RemoteFamily.fromJson(_decodeOrThrow(response));
  }

  Future<RemoteFamily> createFamily(String name) async =>
      RemoteFamily.fromJson(await _postJson('/family', {'name': name}));

  Future<void> inviteMember(String familyId, String email) async {
    await _postJson('/family/$familyId/invite', {'email': email});
  }

  Future<List<RemoteIncomingInvite>> listMyInvites() async {
    final response = await _client
        .get(_uri('/family/invites'), headers: _authHeaders)
        .timeout(_timeout);
    final body = _decodeOrThrow(response);
    return (body['invites'] as List? ?? const [])
        .map((i) =>
            RemoteIncomingInvite.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  Future<RemoteFamily> acceptInvite(String inviteId) async =>
      RemoteFamily.fromJson(
          await _postJson('/family/invites/$inviteId/accept', const {}));

  Future<void> declineInvite(String inviteId) async {
    await _postJson('/family/invites/$inviteId/decline', const {});
  }

  Future<void> removeMember(String familyId, String userId) async {
    await _postJson('/family/$familyId/members/$userId/remove', const {});
  }

  Future<void> deleteFamily(String familyId) async {
    await _postJson('/family/$familyId/delete', const {});
  }

  Future<List<RemoteSharedEvent>> listSharedEvents(String familyId) async {
    final response = await _client
        .get(_uri('/family/$familyId/events'), headers: _authHeaders)
        .timeout(_timeout);
    final body = _decodeOrThrow(response);
    return (body['events'] as List? ?? const [])
        .map((e) => RemoteSharedEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RemoteSharedEvent> addSharedEvent(
    String familyId, {
    required String title,
    String? description,
    String? location,
    required int startMs,
    required int endMs,
    required bool allDay,
    required int color,
    required String recurrence,
    int? recurrenceEndMs,
    int? reminderMinutes,
    required String visibility,
    List<String> memberUserIds = const [],
  }) async {
    final body = await _postJson('/family/$familyId/events', {
      'title': title,
      'description': description,
      'location': location,
      'startMs': startMs,
      'endMs': endMs,
      'allDay': allDay,
      'color': color,
      'recurrence': recurrence,
      'recurrenceEndMs': recurrenceEndMs,
      'reminderMinutes': reminderMinutes,
      'visibility': visibility,
      'memberUserIds': memberUserIds,
    });
    return RemoteSharedEvent.fromJson(body);
  }

  Future<RemoteSharedEvent> updateSharedEvent(
    String familyId,
    String eventId, {
    required String title,
    String? description,
    String? location,
    required int startMs,
    required int endMs,
    required bool allDay,
    required int color,
    required String recurrence,
    int? recurrenceEndMs,
    int? reminderMinutes,
    required String visibility,
    List<String> memberUserIds = const [],
  }) async {
    final response = await _client
        .put(
          _uri('/family/$familyId/events/$eventId'),
          headers: {..._authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'title': title,
            'description': description,
            'location': location,
            'startMs': startMs,
            'endMs': endMs,
            'allDay': allDay,
            'color': color,
            'recurrence': recurrence,
            'recurrenceEndMs': recurrenceEndMs,
            'reminderMinutes': reminderMinutes,
            'visibility': visibility,
            'memberUserIds': memberUserIds,
          }),
        )
        .timeout(_timeout);
    return RemoteSharedEvent.fromJson(_decodeOrThrow(response));
  }

  Future<void> deleteSharedEvent(String familyId, String eventId) async {
    final response = await _client
        .delete(_uri('/family/$familyId/events/$eventId'),
            headers: _authHeaders)
        .timeout(_timeout);
    _decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> _postJson(
      String path, Map<String, dynamic> body) async {
    final response = await _client
        .post(
          _uri(path),
          headers: {..._authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _decodeOrThrow(response);
  }

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    Map<String, dynamic>? decoded;
    try {
      final raw = jsonDecode(utf8.decode(response.bodyBytes));
      if (raw is Map<String, dynamic>) decoded = raw;
    } catch (_) {}

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded ?? const {};
    }
    throw FamilyApiException(
      response.statusCode,
      decoded?['error'] as String? ?? 'http_${response.statusCode}',
      decoded?['message'] as String? ??
          'Server error (${response.statusCode}).',
    );
  }

  void close() => _client.close();
}
