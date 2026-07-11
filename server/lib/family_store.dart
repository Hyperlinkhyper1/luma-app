import 'dart:convert';
import 'dart:io';

import 'util.dart';

/// Max family members (including the owner) per plan tier. Mirrors the
/// client-side `Plan.maxFamilyMembers` in lib/account/plan.dart — keep the
/// two in sync if either changes.
const kFamilyMemberLimit = <String, int>{
  'core': 4,
  'orbit': 6,
  'nova': 12,
};

/// A family "household". Sharing calendar entries with a family is a
/// deliberately server-readable channel (unlike the zero-knowledge sync
/// blobs) — see FamilySharedEvent.
class Family {
  Family({
    required this.id,
    required this.name,
    required this.ownerUserId,
    required this.createdAtMs,
  });

  final String id;
  String name;
  final String ownerUserId;
  final int createdAtMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ownerUserId': ownerUserId,
        'createdAtMs': createdAtMs,
      };

  factory Family.fromJson(Map<String, dynamic> j) => Family(
        id: j['id'] as String,
        name: j['name'] as String,
        ownerUserId: j['ownerUserId'] as String,
        createdAtMs: j['createdAtMs'] as int,
      );
}

class FamilyMember {
  FamilyMember({
    required this.familyId,
    required this.userId,
    required this.role,
    required this.joinedAtMs,
  });

  final String familyId;
  final String userId;
  String role; // 'owner' | 'member'
  final int joinedAtMs;

  bool get isOwner => role == 'owner';

  Map<String, dynamic> toJson() => {
        'familyId': familyId,
        'userId': userId,
        'role': role,
        'joinedAtMs': joinedAtMs,
      };

  factory FamilyMember.fromJson(Map<String, dynamic> j) => FamilyMember(
        familyId: j['familyId'] as String,
        userId: j['userId'] as String,
        role: j['role'] as String,
        joinedAtMs: j['joinedAtMs'] as int,
      );
}

class FamilyInvite {
  FamilyInvite({
    required this.id,
    required this.familyId,
    required this.inviteeEmail,
    required this.invitedByUserId,
    required this.createdAtMs,
    required this.expiresAtMs,
    this.status = 'pending',
    this.respondedAtMs,
  });

  final String id;
  final String familyId;
  final String inviteeEmail; // lowercased
  final String invitedByUserId;
  String status; // 'pending' | 'accepted' | 'declined' | 'revoked' | 'expired'
  final int createdAtMs;
  final int expiresAtMs;
  int? respondedAtMs;

  bool isPendingAt(int nowMs) => status == 'pending' && expiresAtMs > nowMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'familyId': familyId,
        'inviteeEmail': inviteeEmail,
        'invitedByUserId': invitedByUserId,
        'status': status,
        'createdAtMs': createdAtMs,
        'expiresAtMs': expiresAtMs,
        'respondedAtMs': respondedAtMs,
      };

  factory FamilyInvite.fromJson(Map<String, dynamic> j) => FamilyInvite(
        id: j['id'] as String,
        familyId: j['familyId'] as String,
        inviteeEmail: j['inviteeEmail'] as String,
        invitedByUserId: j['invitedByUserId'] as String,
        status: j['status'] as String? ?? 'pending',
        createdAtMs: j['createdAtMs'] as int,
        expiresAtMs: j['expiresAtMs'] as int,
        respondedAtMs: j['respondedAtMs'] as int?,
      );
}

/// A calendar entry shared with (part of) a family. Deliberately stored and
/// readable in the clear server-side — the user chose this trade-off over
/// building a per-family encryption/key-distribution scheme, since this data
/// is far less sensitive than the password-manager vault. Personal, non-shared
/// events never pass through here; they stay in the existing per-account,
/// zero-knowledge `calendar` sync collection untouched.
class FamilySharedEvent {
  FamilySharedEvent({
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
  String title;
  String? description;
  String? location;
  int startMs;
  int endMs;
  bool allDay;
  int color;
  String recurrence;
  int? recurrenceEndMs;
  int? reminderMinutes;
  String visibility; // 'all' | 'subset'
  List<String> visibleMemberUserIds; // meaningful only when visibility=='subset'
  final int createdAtMs;
  int updatedAtMs;

  /// Whether [userId] may see this event, per the visibility rule chosen by
  /// the author at share time.
  bool visibleTo(String userId) =>
      userId == authorUserId ||
      visibility == 'all' ||
      visibleMemberUserIds.contains(userId);

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

  factory FamilySharedEvent.fromJson(Map<String, dynamic> j) =>
      FamilySharedEvent(
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
        visibleMemberUserIds: (j['visibleMemberUserIds'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        createdAtMs: j['createdAtMs'] as int,
        updatedAtMs: j['updatedAtMs'] as int,
      );
}

/// File-backed store for the family/invite/shared-event data, mirroring the
/// structure and persistence conventions of [Store] (in server/lib/store.dart)
/// but kept as a separate file/lock since this data is a distinct, newer
/// subsystem with its own access-control shape. Mutations should still go
/// through the shared [Store.lock] at the call site (Api holds both stores)
/// so writes never interleave with account/session mutations that might
/// affect the same user.
class FamilyStore {
  FamilyStore._(this.rootPath);

  final String rootPath;

  final Map<String, Family> familiesById = {};
  final Map<String, Map<String, FamilyMember>> membersByFamilyId = {};
  final Map<String, String> familyIdByUserId = {}; // one family per user
  final Map<String, FamilyInvite> invitesById = {};
  final Map<String, Map<String, FamilySharedEvent>> sharedEventsByFamilyId =
      {};

  String get _familiesFile => '$rootPath/families.json';
  String get _membersFile => '$rootPath/family_members.json';
  String get _invitesFile => '$rootPath/family_invites.json';
  String get _eventsFile => '$rootPath/family_shared_events.json';

  static Future<FamilyStore> open(String path) async {
    final store = FamilyStore._(path);

    for (final f in await _readJsonList(store._familiesFile)) {
      final family = Family.fromJson(f as Map<String, dynamic>);
      store.familiesById[family.id] = family;
    }

    for (final m in await _readJsonList(store._membersFile)) {
      final member = FamilyMember.fromJson(m as Map<String, dynamic>);
      store.membersByFamilyId
          .putIfAbsent(member.familyId, () => {})[member.userId] = member;
      store.familyIdByUserId[member.userId] = member.familyId;
    }

    for (final i in await _readJsonList(store._invitesFile)) {
      final invite = FamilyInvite.fromJson(i as Map<String, dynamic>);
      store.invitesById[invite.id] = invite;
    }

    for (final e in await _readJsonList(store._eventsFile)) {
      final event = FamilySharedEvent.fromJson(e as Map<String, dynamic>);
      store.sharedEventsByFamilyId
          .putIfAbsent(event.familyId, () => {})[event.id] = event;
    }

    return store;
  }

  static Future<List<dynamic>> _readJsonList(String path) async {
    final file = File(path);
    if (!await file.exists()) return const [];
    final decoded = jsonDecode(await file.readAsString());
    return decoded is List ? decoded : const [];
  }

  // ---- Persistence -------------------------------------------------------

  Future<void> saveFamilies() => atomicWriteString(_familiesFile,
      jsonEncode(familiesById.values.map((f) => f.toJson()).toList()));

  Future<void> saveMembers() => atomicWriteString(
      _membersFile,
      jsonEncode(membersByFamilyId.values
          .expand((byUser) => byUser.values)
          .map((m) => m.toJson())
          .toList()));

  Future<void> saveInvites() => atomicWriteString(_invitesFile,
      jsonEncode(invitesById.values.map((i) => i.toJson()).toList()));

  Future<void> saveEvents() => atomicWriteString(
      _eventsFile,
      jsonEncode(sharedEventsByFamilyId.values
          .expand((byId) => byId.values)
          .map((e) => e.toJson())
          .toList()));

  // ---- Queries -------------------------------------------------------------

  Family? familyForUser(String userId) {
    final familyId = familyIdByUserId[userId];
    return familyId == null ? null : familiesById[familyId];
  }

  List<FamilyMember> membersOf(String familyId) =>
      membersByFamilyId[familyId]?.values.toList() ?? const [];

  bool isMember(String familyId, String userId) =>
      membersByFamilyId[familyId]?.containsKey(userId) ?? false;

  int slotsUsed(String familyId, int nowMs) {
    final members = membersByFamilyId[familyId]?.length ?? 0;
    final pendingInvites = invitesById.values
        .where((i) => i.familyId == familyId && i.isPendingAt(nowMs))
        .length;
    return members + pendingInvites;
  }

  List<FamilyInvite> pendingInvitesForEmail(String email, int nowMs) =>
      invitesById.values
          .where((i) => i.inviteeEmail == email && i.isPendingAt(nowMs))
          .toList();

  List<FamilyInvite> pendingInvitesForFamily(String familyId, int nowMs) =>
      invitesById.values
          .where((i) => i.familyId == familyId && i.isPendingAt(nowMs))
          .toList();

  List<FamilySharedEvent> visibleEvents(String familyId, String userId) =>
      sharedEventsByFamilyId[familyId]
          ?.values
          .where((e) => e.visibleTo(userId))
          .toList() ??
      const [];

  /// Removes every trace of a family (members, invites, shared events). The
  /// family record itself is also dropped. Caller must persist afterwards.
  void deleteFamilyData(String familyId) {
    familiesById.remove(familyId);
    final members = membersByFamilyId.remove(familyId);
    if (members != null) {
      for (final userId in members.keys) {
        if (familyIdByUserId[userId] == familyId) {
          familyIdByUserId.remove(userId);
        }
      }
    }
    invitesById.removeWhere((_, i) => i.familyId == familyId);
    sharedEventsByFamilyId.remove(familyId);
  }
}
