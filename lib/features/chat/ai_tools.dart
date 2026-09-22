import 'dart:convert';

import '../notes/notes_repository.dart';
import '../plugins/plugin_catalog_service.dart';
import '../plugins/plugin_repository.dart';
import '../plugins/installed/calendar/calendar_repository.dart';
import '../plugins/installed/qr_code_generator/qr_code_repository.dart';
import '../plugins/installed/steam_tools/cs2_market_repository.dart';
import 'providers/ai_client.dart';

/// Actions the assistant can perform using the same repositories as Luma's UI.
class AiToolRegistry {
  AiToolRegistry({
    required PluginRepository pluginRepository,
    required QrCodeRepository qrCodeRepository,
    required CalendarRepository calendarRepository,
    required NotesRepository notesRepository,
    required Cs2MarketRepository cs2MarketRepository,
    required void Function(String destination) navigate,
  })  : _pluginRepository = pluginRepository,
        _qrCodeRepository = qrCodeRepository,
        _calendarRepository = calendarRepository,
        _notesRepository = notesRepository,
        _cs2MarketRepository = cs2MarketRepository,
        _navigate = navigate;

  final PluginRepository _pluginRepository;
  final QrCodeRepository _qrCodeRepository;
  final CalendarRepository _calendarRepository;
  final NotesRepository _notesRepository;
  final Cs2MarketRepository _cs2MarketRepository;
  final void Function(String destination) _navigate;

  static const _qrPluginId = 'qr-code-generator';

  List<AiToolDefinition> get schemas => [
        const AiToolDefinition(
          name: 'install_plugin',
          description: 'Install a Luma plugin by its id.',
          parameters: {'type': 'object', 'properties': {'plugin_id': {'type': 'string'}}, 'required': ['plugin_id']},
        ),
        const AiToolDefinition(
          name: 'navigate_luma',
          description: 'Open a Luma destination the user requests. Destinations include home, converter, finance, passwords, notes, assistant, plugins, settings, account, calendar, steam-tools, and any installed plugin id.',
          parameters: {'type': 'object', 'properties': {'destination': {'type': 'string'}}, 'required': ['destination']},
        ),
        const AiToolDefinition(
          name: 'generate_qr_code',
          description: 'Generate a QR code for a URL and save it in the QR plugin.',
          parameters: {'type': 'object', 'properties': {'url': {'type': 'string'}}, 'required': ['url']},
        ),
        const AiToolDefinition(
          name: 'create_note',
          description: 'Create a Luma note from a paragraph. If title or content is missing, ask the user before calling again.',
          parameters: {
            'type': 'object', 'properties': {
              'title': {'type': 'string', 'description': 'Concise note title.'},
              'content': {'type': 'string', 'description': 'Note body, preserving the user’s meaning.'},
            }, 'required': ['title', 'content'],
          },
        ),
        const AiToolDefinition(
          name: 'search_notes',
          description: 'Search existing Luma notes by title and content.',
          parameters: {'type': 'object', 'properties': {'query': {'type': 'string'}}, 'required': ['query']},
        ),
        const AiToolDefinition(
          name: 'create_calendar_event',
          description: 'Create a personal calendar event. Ask for missing or ambiguous date/time before calling this tool.',
          parameters: {
            'type': 'object', 'properties': {
              'title': {'type': 'string'}, 'start': {'type': 'string', 'description': 'ISO 8601 local date/time.'},
              'end': {'type': 'string', 'description': 'ISO 8601 local date/time; defaults to one hour after start.'},
              'description': {'type': 'string'}, 'location': {'type': 'string'},
              'all_day': {'type': 'boolean'}, 'reminder_minutes': {'type': 'integer'},
            }, 'required': ['title', 'start'],
          },
        ),
        const AiToolDefinition(
          name: 'list_upcoming_events',
          description: 'Read upcoming personal calendar events.',
          parameters: {'type': 'object', 'properties': {'days': {'type': 'integer'}}, 'required': []},
        ),
        const AiToolDefinition(
          name: 'plan_dinner',
          description: 'Save a meal plan to the Calendar dinner planner. Ask which date if missing.',
          parameters: {'type': 'object', 'properties': {
            'date': {'type': 'string', 'description': 'ISO 8601 date.'}, 'title': {'type': 'string'},
            'ingredients': {'type': 'array', 'items': {'type': 'string'}}, 'instructions': {'type': 'string'},
            'servings': {'type': 'integer'}, 'minutes': {'type': 'integer'},
          }, 'required': ['date', 'title']},
        ),
        const AiToolDefinition(
          name: 'search_cs2_skins',
          description: 'Find CS2 skins in Luma’s catalog. Use this before tracking if the exact finish is unclear.',
          parameters: {'type': 'object', 'properties': {'query': {'type': 'string'}}, 'required': ['query']},
        ),
        const AiToolDefinition(
          name: 'track_cs2_skin',
          description: 'Track one CS2 skin copy. First search for the skin. Ask for its wear/grade and what the user paid if not stated. Never substitute current market price for purchase cost.',
          parameters: {
            'type': 'object', 'properties': {
              'skin_id': {'type': 'string'}, 'wear': {'type': 'string', 'description': 'Exact wear, e.g. Factory New, Minimal Wear, Field-Tested, Well-Worn, Battle-Scarred; omit for skins without wear variants.'},
              'stat_trak': {'type': 'boolean'}, 'paid': {'type': 'number', 'description': 'User’s purchase price in USD; ask if unknown.'},
            }, 'required': ['skin_id', 'stat_trak'],
          },
        ),
        const AiToolDefinition(
          name: 'check_cs2_skin_price',
          description: 'Check a current CS2 market price without adding the item to tracking.',
          parameters: {'type': 'object', 'properties': {'market_hash_name': {'type': 'string'}}, 'required': ['market_hash_name']},
        ),
      ];

  Future<Map<String, dynamic>> execute(String name, Map<String, dynamic> input) async {
    try {
      switch (name) {
        case 'install_plugin':
          final id = input['plugin_id'] as String?;
          if (id == null || id.isEmpty) return _missing('plugin_id');
          await _installPlugin(id);
          return {'status': 'installed', 'plugin_id': id};
        case 'navigate_luma':
          final destination = (input['destination'] as String? ?? '').trim();
          if (destination.isEmpty) return _missing('destination');
          _navigate(destination);
          return {'status': 'navigating', 'destination': destination};
        case 'generate_qr_code':
          final url = input['url'] as String?;
          if (url == null || url.isEmpty) return _missing('url');
          await _installPlugin(_qrPluginId);
          await _qrCodeRepository.add(url);
          return {'status': 'generated', 'url': url};
        case 'create_note':
          final title = (input['title'] as String?)?.trim() ?? '';
          final content = (input['content'] as String?)?.trim() ?? '';
          if (title.isEmpty || content.isEmpty) return _needInfo('Please ask the user for a note title and its paragraph content.');
          final note = await _notesRepository.create();
          await _notesRepository.update(note.id, title: title, content: content);
          return {'status': 'created', 'title': title};
        case 'search_notes':
          final query = (input['query'] as String? ?? '').trim().toLowerCase();
          if (query.isEmpty) return _missing('query');
          final matches = _notesRepository.notes.where((n) => '${n.title}\n${n.content}'.toLowerCase().contains(query)).take(10);
          return {'status': 'ok', 'notes': [for (final n in matches) {'title': n.title, 'content': n.content}]};
        case 'create_calendar_event':
          final title = (input['title'] as String?)?.trim() ?? '';
          final rawStart = input['start'] as String?;
          final start = rawStart == null ? null : DateTime.tryParse(rawStart);
          if (title.isEmpty || start == null) return _needInfo('Ask the user for the event title and a clear date and start time, then call this tool again.');
          final rawEnd = input['end'] as String?;
          final end = rawEnd == null ? start.add(const Duration(hours: 1)) : DateTime.tryParse(rawEnd);
          if (end == null || !end.isAfter(start)) return _needInfo('Ask the user to clarify the event end time.');
          final id = await _calendarRepository.add(
            title: title, start: start, end: end,
            description: input['description'] as String?, location: input['location'] as String?,
            allDay: input['all_day'] as bool? ?? false,
            reminderMinutes: (input['reminder_minutes'] as num?)?.toInt(),
          );
          return {'status': 'created', 'event_id': id, 'title': title, 'start': start.toIso8601String()};
        case 'list_upcoming_events':
          final days = ((input['days'] as num?)?.toInt() ?? 30).clamp(1, 90);
          final now = DateTime.now();
          final until = now.add(Duration(days: days));
          final events = await _calendarRepository.watchAll().first;
          return {'status': 'ok', 'events': [
            for (final e in events.where((e) => !e.start.isBefore(now) && e.start.isBefore(until)).take(30))
              {'title': e.title, 'start': e.start.toIso8601String(), 'end': e.end.toIso8601String(), 'location': e.location, 'description': e.description}
          ]};
        case 'plan_dinner':
          final day = DateTime.tryParse(input['date'] as String? ?? '');
          final title = (input['title'] as String? ?? '').trim();
          if (day == null || title.isEmpty) return _needInfo('Ask the user for the dinner date and meal name.');
          await _calendarRepository.setDinner(
            day: day, title: title,
            ingredients: (input['ingredients'] as List<dynamic>?)?.whereType<String>().toList() ?? const [],
            instructions: input['instructions'] as String?,
            servings: (input['servings'] as num?)?.toInt(), minutes: (input['minutes'] as num?)?.toInt(),
          );
          return {'status': 'planned', 'title': title, 'date': day.toIso8601String()};
        case 'search_cs2_skins':
          final query = (input['query'] as String? ?? '').trim();
          if (query.isEmpty) return _missing('query');
          if (!_cs2MarketRepository.catalogLoaded) await _cs2MarketRepository.loadCatalog();
          final skins = _cs2MarketRepository.search(query, limit: 12);
          return {'status': 'ok', 'skins': [for (final s in skins) {'skin_id': s.id, 'name': s.name, 'wears': s.wears, 'stattrak_available': s.stattrak}]};
        case 'track_cs2_skin':
          final skinId = input['skin_id'] as String?;
          if (skinId == null || skinId.isEmpty) return _missing('skin_id');
          final skin = _cs2MarketRepository.skinById(skinId);
          if (skin == null) return {'status': 'error', 'message': 'Skin not found. Search the catalog first.'};
          final wear = (input['wear'] as String?)?.trim();
          if (skin.wears.isNotEmpty && (wear == null || wear.isEmpty)) return _needInfo('Ask which wear/grade they want: ${skin.wears.join(', ')}.');
          if (wear != null && wear.isNotEmpty && !skin.wears.any((w) => w.toLowerCase() == wear.toLowerCase())) return _needInfo('Ask the user to choose one of these valid wears: ${skin.wears.join(', ')}.');
          final paid = (input['paid'] as num?)?.toDouble();
          if (paid == null || paid < 0) return _needInfo('Ask what the user paid for this copy. Do not use market price as the purchase price.');
          final statTrak = input['stat_trak'] as bool? ?? false;
          if (statTrak && !skin.stattrak) return {'status': 'error', 'message': 'This skin has no StatTrak version.'};
          await _cs2MarketRepository.track(skin: skin, wear: wear, statTrak: statTrak, startingPriceCents: (paid * 100).round());
          return {'status': 'tracked', 'name': skin.name, 'wear': wear, 'stat_trak': statTrak, 'paid_usd': paid, 'current_price_will_refresh': true};
        case 'check_cs2_skin_price':
          final hash = (input['market_hash_name'] as String?)?.trim();
          if (hash == null || hash.isEmpty) return _missing('market_hash_name');
          final price = await _cs2MarketRepository.checkPriceOnce(hash);
          if (price == null) return {'status': 'unavailable', 'message': _cs2MarketRepository.error ?? 'No market price is available.'};
          return {'status': 'ok', 'lowest_cents': price.lowestCents, 'median_cents': price.medianCents, 'currency': 'USD'};
        default:
          return {'status': 'error', 'message': 'Unknown tool "$name".'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  static Map<String, dynamic> _missing(String key) => {'status': 'needs_info', 'message': 'Missing $key; ask the user and retry.'};
  static Map<String, dynamic> _needInfo(String message) => {'status': 'needs_info', 'message': message};

  static String? metadataFor(String toolName, Map<String, dynamic> result) {
    if (toolName == 'generate_qr_code' && result['status'] == 'generated') return jsonEncode({'qrUrl': result['url']});
    return null;
  }

  Future<void> _installPlugin(String pluginId) => _pluginRepository.install(PluginCatalogEntry(
        id: pluginId, name: pluginId, description: '', icon: 'extension', category: 'Utility', version: '1.0.0',
      ));
}
