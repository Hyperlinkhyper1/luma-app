import 'dart:async';

import '../../../../../account/plan.dart';
import '../../../../../settings/settings_controller.dart';
import '../../../../../sync/sync_service.dart';
import 'classroom_api.dart';
import 'classroom_store.dart';

/// The plan the classroom door opens for. The server checks it again on
/// every call; this only decides what the page shows.
const kClassroomMinPlan = 'nova';

/// The Minecraft hall's classroom, on the app's side: tells the page whether
/// the door opens (`ok`), why not (`plan`, `signin`, `offline`) and the
/// account's country, and runs the page's requests against the luma server.
///
/// Page → app: `{type: 'classroom', op, request?, …}` with op `country`,
/// `question`, `review` or `save`. App → page: `{type: 'classroom', state}`
/// whenever access changes, and `{type: 'classroom', request, data | error}`
/// in answer to a request.
class ClassroomBridge {
  ClassroomBridge({required this.send});

  final void Function(Map<String, Object?> message) send;

  SyncService? _sync;
  SettingsController? _settings;
  String _language = 'en';
  String? _shownKey;
  bool _ready = false;

  /// Follows [sync] and [settings] so signing in or upgrading opens the
  /// door without reopening the hall.
  void attach(
    SyncService? sync,
    SettingsController? settings, {
    required String language,
  }) {
    _language = language;
    if (!identical(sync, _sync)) {
      _sync?.removeListener(_changed);
      _sync = sync?..addListener(_changed);
    }
    if (!identical(settings, _settings)) {
      _settings?.removeListener(_changed);
      _settings = settings?..addListener(_changed);
    }
    _changed();
  }

  /// The page has loaded: hand it the saved lesson and the door's state.
  Future<void> ready() async {
    _ready = true;
    send({'type': 'classroom', 'saved': await loadClassroom()});
    _shownKey = null;
    _changed();
  }

  String get _key =>
      '${_sync?.serverReady ?? false}|${_settings?.selectedPlanId}';

  void _changed() {
    if (!_ready || _key == _shownKey) return;
    _shownKey = _key;
    unawaited(_pushState());
  }

  ClassroomApi? _api() {
    final sync = _sync;
    final url = sync?.serverUrl;
    if (sync == null || !sync.serverReady || url == null) return null;
    return ClassroomApi(url, token: sync.authToken);
  }

  Future<void> _pushState() async {
    final api = _api();
    if (api == null) {
      send({
        'type': 'classroom',
        'state': {'access': 'signin', 'country': null},
      });
      return;
    }
    try {
      final state = await api.state();
      send({
        'type': 'classroom',
        'state': {
          'access': state['allowed'] == true ? 'ok' : 'plan',
          'country': state['country'],
        },
      });
    } on ClassroomException {
      // The server can't be asked; the plan this device knows still says
      // whether the door is worth trying.
      final nova = planAtLeast(_settings?.selectedPlanId, kClassroomMinPlan);
      send({
        'type': 'classroom',
        'state': {'access': nova ? 'offline' : 'plan', 'country': null},
      });
    } finally {
      api.close();
    }
  }

  Future<void> handle(Map<String, Object?> message) async {
    final op = message['op'];
    if (op == 'save') {
      try {
        await saveClassroom(message['state']);
      } catch (_) {
        // The next change saves it again.
      }
      return;
    }
    final request = message['request'];
    if (op == 'state') {
      _shownKey = null;
      _changed();
      if (request != null) {
        send({'type': 'classroom', 'request': request, 'data': true});
      }
      return;
    }
    final api = _api();
    try {
      if (api == null) {
        throw const ClassroomException(
          'Sign in to an approved luma account to use the classroom.',
          code: 'signin',
        );
      }
      final data = switch (op) {
        'country' => await api.setCountry('${message['country'] ?? ''}'),
        'question' => await api.question({
          'lesson': message['lesson'],
          'asked': message['asked'],
          'number': message['number'],
          'language': _language,
        }),
        'review' => await api.review({
          'lesson': message['lesson'],
          'items': message['items'],
          'language': _language,
        }),
        _ => throw const ClassroomException('Unknown classroom request.'),
      };
      send({'type': 'classroom', 'request': request, 'data': data});
    } on ClassroomException catch (e) {
      send({
        'type': 'classroom',
        'request': request,
        'error': {'code': e.code, 'message': e.message},
      });
      // A refusal can mean the plan or the country changed on the server.
      if (e.code == 'plan_required' || e.code == 'no_country') {
        _shownKey = null;
        _changed();
      }
    } finally {
      api?.close();
    }
  }

  void dispose() {
    _sync?.removeListener(_changed);
    _settings?.removeListener(_changed);
    _sync = null;
    _settings = null;
  }
}
