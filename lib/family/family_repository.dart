import 'dart:async';

import 'package:flutter/foundation.dart';

import '../sync/sync_service.dart';
import 'family_api.dart';
import 'family_cache_store.dart';

/// Thrown by [FamilyRepository.inviteMember] (and surfaced from
/// [FamilyRepository.acceptInvite]) when the family is already at its plan's
/// member-slot limit. Mirrors [SyncLimitExceededException]'s shape — a
/// friendly `toString()` the UI can show directly.
class FamilyLimitExceededException implements Exception {
  const FamilyLimitExceededException(this.limit);
  final int limit;

  @override
  String toString() =>
      'This family plan allows up to $limit member${limit == 1 ? '' : 's'}. '
      'Upgrade the owner\'s plan to add more.';
}

/// Orchestrates the client side of the Families feature: talks to the
/// family/invite/shared-event server endpoints (deliberately NOT the
/// zero-knowledge sync ones — see the note atop server/lib/family_store.dart),
/// keeps a small local cache so the roster/inbox/calendar merge have
/// something to show immediately on launch, and polls periodically so an
/// invite sent from another device shows up without the user having to
/// manually refresh.
class FamilyRepository extends ChangeNotifier {
  FamilyRepository(this._sync);

  final SyncService _sync;

  FamilyCacheStore? _cache;
  FamilyApi? _api;
  String? _apiServerUrl;
  String? _apiToken;
  Timer? _periodic;
  bool _refreshing = false;
  String? _lastError;

  static const _periodicInterval = Duration(seconds: 30);

  // ---- Public state -----------------------------------------------------

  bool get ready => _cache != null;

  RemoteFamily? get family {
    final j = _cache?.familyJson;
    return j == null ? null : RemoteFamily.fromJson(j);
  }

  List<RemoteIncomingInvite> get pendingInvites => (_cache?.invitesJson ?? const [])
      .map((j) => RemoteIncomingInvite.fromJson(j as Map<String, dynamic>))
      .toList();

  /// Every shared event visible to the current user, across their family.
  /// Used by the Calendar plugin to merge into its own (local, personal)
  /// event list — see calendar_page.dart.
  List<RemoteSharedEvent> get sharedEvents => (_cache?.eventsJson ?? const [])
      .map((j) => RemoteSharedEvent.fromJson(j as Map<String, dynamic>))
      .toList();

  String? get lastError => _lastError;

  /// The signed-in user's own id within their family, resolved by matching
  /// their account email against the roster (the family endpoints never
  /// hand the client its own userId directly outside of membership rows).
  /// Null until in a family, or before the first successful [refresh].
  String? get myUserId {
    final f = family;
    final email = _sync.email?.toLowerCase();
    if (f == null || email == null) return null;
    for (final m in f.members) {
      if (m.email.toLowerCase() == email) return m.userId;
    }
    return null;
  }

  bool get isOwner {
    final f = family;
    final me = myUserId;
    return f != null && me != null && f.ownerUserId == me;
  }

  // ---- Lifecycle ----------------------------------------------------------

  Future<void> init() async {
    _cache = await FamilyCacheStore.load();
    notifyListeners();
    _sync.addListener(_onSyncChanged);
    _onSyncChanged();
    _periodic = Timer.periodic(_periodicInterval, (_) {
      if (_sync.signedIn) unawaited(refresh());
    });
  }

  @override
  void dispose() {
    _periodic?.cancel();
    _sync.removeListener(_onSyncChanged);
    _api?.close();
    super.dispose();
  }

  void _onSyncChanged() {
    if (!_sync.signedIn) {
      _api?.close();
      _api = null;
      _apiServerUrl = null;
      _apiToken = null;
      return;
    }
    if (_api != null &&
        _apiServerUrl == _sync.serverUrl &&
        _apiToken == _sync.authToken) {
      return;
    }
    _api?.close();
    _apiServerUrl = _sync.serverUrl;
    _apiToken = _sync.authToken;
    _api = FamilyApi(_sync.serverUrl!, token: _sync.authToken);
    unawaited(refresh());
  }

  /// Pulls the current family, incoming invites, and visible shared events
  /// from the server and updates the local cache. Safe to call anytime;
  /// concurrent calls collapse into a no-op.
  Future<void> refresh() async {
    final api = _api;
    if (api == null || _cache == null || _refreshing) return;
    _refreshing = true;
    try {
      final invites = await api.listMyInvites();
      RemoteFamily? fam;
      try {
        fam = await api.getMyFamily();
      } on FamilyApiException catch (e) {
        if (!e.isNotFound) rethrow;
      }
      final events =
          fam == null ? const <RemoteSharedEvent>[] : await api.listSharedEvents(fam.id);

      _cache!
        ..familyJson = fam?.toJson()
        ..invitesJson = invites.map((i) => i.toJson()).toList()
        ..eventsJson = events.map((e) => e.toJson()).toList();
      await _cache!.save();
      _lastError = null;
    } catch (e) {
      _lastError = '$e';
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  // ---- Mutations ------------------------------------------------------------

  Future<void> createFamily(String name) async {
    final api = _requireApi();
    final fam = await api.createFamily(name);
    _cache!.familyJson = fam.toJson();
    await _cache!.save();
    notifyListeners();
    unawaited(refresh());
  }

  /// Throws [FamilyLimitExceededException] if the family is already full.
  Future<void> inviteMember(String email) async {
    final api = _requireApi();
    final fam = family;
    if (fam == null) throw StateError('Not in a family.');
    try {
      await api.inviteMember(fam.id, email);
    } on FamilyApiException catch (e) {
      if (e.isLimitExceeded) {
        throw FamilyLimitExceededException(fam.slotLimit ?? fam.slotsUsed);
      }
      rethrow;
    }
    await refresh();
  }

  /// Throws [FamilyApiException] (whose `toString()` is already a friendly
  /// message, e.g. "This family is full.") if the invite can no longer be
  /// accepted.
  Future<void> acceptInvite(String inviteId) async {
    final api = _requireApi();
    final fam = await api.acceptInvite(inviteId);
    _cache!.familyJson = fam.toJson();
    await _cache!.save();
    await refresh();
  }

  Future<void> declineInvite(String inviteId) async {
    final api = _requireApi();
    await api.declineInvite(inviteId);
    await refresh();
  }

  Future<void> removeMember(String userId) async {
    final api = _requireApi();
    final fam = family;
    if (fam == null) throw StateError('Not in a family.');
    await api.removeMember(fam.id, userId);
    await refresh();
  }

  /// Removes the current (non-owner) user from their family.
  Future<void> leaveFamily() async {
    final me = myUserId;
    if (me == null) throw StateError('Not in a family.');
    await removeMember(me);
  }

  Future<void> deleteFamily() async {
    final api = _requireApi();
    final fam = family;
    if (fam == null) throw StateError('Not in a family.');
    await api.deleteFamily(fam.id);
    _cache!.familyJson = null;
    _cache!.eventsJson = const [];
    await _cache!.save();
    notifyListeners();
  }

  Future<void> addSharedEvent({
    required String title,
    String? description,
    String? location,
    required DateTime start,
    required DateTime end,
    required bool allDay,
    required int color,
    required String recurrence,
    DateTime? recurrenceEnd,
    int? reminderMinutes,
    required bool shareWithWholeFamily,
    List<String> memberUserIds = const [],
  }) async {
    final api = _requireApi();
    final fam = family;
    if (fam == null) throw StateError('Not in a family.');
    await api.addSharedEvent(
      fam.id,
      title: title,
      description: description,
      location: location,
      startMs: start.millisecondsSinceEpoch,
      endMs: end.millisecondsSinceEpoch,
      allDay: allDay,
      color: color,
      recurrence: recurrence,
      recurrenceEndMs: recurrenceEnd?.millisecondsSinceEpoch,
      reminderMinutes: reminderMinutes,
      visibility: shareWithWholeFamily ? 'all' : 'subset',
      memberUserIds: memberUserIds,
    );
    await refresh();
  }

  Future<void> updateSharedEvent({
    required String eventId,
    required String title,
    String? description,
    String? location,
    required DateTime start,
    required DateTime end,
    required bool allDay,
    required int color,
    required String recurrence,
    DateTime? recurrenceEnd,
    int? reminderMinutes,
    required bool shareWithWholeFamily,
    List<String> memberUserIds = const [],
  }) async {
    final api = _requireApi();
    final fam = family;
    if (fam == null) throw StateError('Not in a family.');
    await api.updateSharedEvent(
      fam.id,
      eventId,
      title: title,
      description: description,
      location: location,
      startMs: start.millisecondsSinceEpoch,
      endMs: end.millisecondsSinceEpoch,
      allDay: allDay,
      color: color,
      recurrence: recurrence,
      recurrenceEndMs: recurrenceEnd?.millisecondsSinceEpoch,
      reminderMinutes: reminderMinutes,
      visibility: shareWithWholeFamily ? 'all' : 'subset',
      memberUserIds: memberUserIds,
    );
    await refresh();
  }

  Future<void> deleteSharedEvent(String eventId) async {
    final api = _requireApi();
    final fam = family;
    if (fam == null) throw StateError('Not in a family.');
    await api.deleteSharedEvent(fam.id, eventId);
    await refresh();
  }

  FamilyApi _requireApi() {
    final api = _api;
    if (api == null) throw StateError('Not signed in.');
    return api;
  }
}
