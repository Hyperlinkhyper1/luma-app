import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../l10n/current_l.dart';

/// The sync collection the assistant's memory, profile and chat preferences
/// travel in. It is automatic (see `isAutomaticSyncCollection`): on for
/// every plan, including Core, and never counted against the plan's
/// collection limit — but its blob still counts toward server storage.
const kAssistantMemoryCollectionId = 'assistant_memory';

/// The three groups the memory screen lists entries under, after the
/// Claude app: one profile about the user, topics, and ongoing areas.
enum MemorySection { you, topics, areas }

/// The typeface assistant replies are set in.
enum ChatFont { serif, sans, mono }

/// Transcript text size.
enum ChatTextSize { small, medium, large }

extension ChatTextSizeScale on ChatTextSize {
  double get scale => switch (this) {
    ChatTextSize.small => 0.9,
    ChatTextSize.medium => 1.0,
    ChatTextSize.large => 1.14,
  };
}

/// Languages the assistant can be told to answer in. [code] is stored;
/// [englishName] is what goes into the system prompt. `auto` means "reply
/// in whatever language the user writes in".
class AssistantLanguage {
  const AssistantLanguage(this.code, this.englishName, this.nativeName);

  final String code;
  final String englishName;
  final String nativeName;
}

const kAssistantLanguages = <AssistantLanguage>[
  AssistantLanguage('auto', '', ''),
  AssistantLanguage('en', 'English', 'English'),
  AssistantLanguage('nl', 'Dutch', 'Nederlands'),
  AssistantLanguage('fr', 'French', 'Français'),
  AssistantLanguage('es', 'Spanish', 'Español'),
  AssistantLanguage('de', 'German', 'Deutsch'),
  AssistantLanguage('it', 'Italian', 'Italiano'),
  AssistantLanguage('pt', 'Portuguese', 'Português'),
  AssistantLanguage('pl', 'Polish', 'Polski'),
  AssistantLanguage('tr', 'Turkish', 'Türkçe'),
  AssistantLanguage('zh', 'Chinese', '中文'),
  AssistantLanguage('ja', 'Japanese', '日本語'),
];

AssistantLanguage assistantLanguageByCode(String code) => kAssistantLanguages
    .firstWhere((l) => l.code == code, orElse: () => kAssistantLanguages.first);

/// One remembered page, e.g. "Hardware — Ayden's PC hardware".
class AssistantMemoryEntry {
  const AssistantMemoryEntry({
    required this.id,
    required this.section,
    required this.title,
    required this.description,
    required this.body,
    required this.updatedAt,
  });

  factory AssistantMemoryEntry.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return AssistantMemoryEntry(
      id: json['id']?.toString() ?? now.microsecondsSinceEpoch.toString(),
      section:
          MemorySection.values.asNameMap()[json['section']] ??
          MemorySection.topics,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? now,
    );
  }

  final String id;
  final MemorySection section;
  final String title;

  /// The one-line summary shown in the memory list.
  final String description;

  /// The remembered facts themselves, one per line.
  final String body;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'section': section.name,
    'title': title,
    'description': description,
    'body': body,
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// What the user told the assistant about themselves on the User tab.
class AssistantUserProfile {
  const AssistantUserProfile({
    this.callMe = '',
    this.occupation = '',
    this.summary = '',
    this.instructions = '',
  });

  factory AssistantUserProfile.fromJson(Object? json) {
    if (json is! Map) return const AssistantUserProfile();
    String field(String key) => json[key]?.toString() ?? '';
    return AssistantUserProfile(
      callMe: field('callMe'),
      occupation: field('occupation'),
      summary: field('summary'),
      instructions: field('instructions'),
    );
  }

  /// What the assistant should call the user.
  final String callMe;
  final String occupation;

  /// A few sentences about the user, in their own words.
  final String summary;

  /// How the user wants replies written.
  final String instructions;

  bool get isEmpty =>
      callMe.trim().isEmpty &&
      occupation.trim().isEmpty &&
      summary.trim().isEmpty &&
      instructions.trim().isEmpty;

  Map<String, Object?> toJson() => {
    'callMe': callMe,
    'occupation': occupation,
    'summary': summary,
    'instructions': instructions,
  };
}

/// Everything the assistant knows about the user beyond a single chat: the
/// profile from the User tab, the memory pages it keeps across chats, and
/// the chat preferences (reply language, font, text size). One small JSON
/// file, synced as [kAssistantMemoryCollectionId].
class AssistantMemoryRepository extends ChangeNotifier {
  AssistantMemoryRepository({
    Future<Directory> Function()? supportDirectoryProvider,
  }) : _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory {
    _ready = _load();
  }

  static const _fileName = 'luma_assistant_memory.json';

  /// The most memory text that is ever put into a system prompt, so a
  /// long-lived memory can't crowd the on-device model's small context.
  static const maxPromptMemoryChars = 6000;

  final Future<Directory> Function() _supportDirectoryProvider;
  late final Future<void> _ready;
  File? _file;

  List<AssistantMemoryEntry> _entries = [];
  AssistantUserProfile _profile = const AssistantUserProfile();
  bool _memoryEnabled = true;
  String _languageCode = 'auto';
  ChatFont _font = ChatFont.serif;
  ChatTextSize _textSize = ChatTextSize.medium;

  Future<void> get ready => _ready;
  List<AssistantMemoryEntry> get entries => List.unmodifiable(_entries);
  AssistantUserProfile get profile => _profile;

  /// Whether memory is read into chats and the assistant may add to it.
  bool get memoryEnabled => _memoryEnabled;
  String get languageCode => _languageCode;
  ChatFont get font => _font;
  ChatTextSize get textSize => _textSize;

  List<AssistantMemoryEntry> entriesIn(MemorySection section) =>
      _entries.where((e) => e.section == section).toList();

  /// Roughly what this store occupies on the sync server (before the
  /// encryption envelope), for the usage and memory screens.
  int get approximateBytes => utf8.encode(jsonEncode(_snapshot())).length;

  Future<File> _storageFile() async {
    if (_file != null) return _file!;
    final directory = await _supportDirectoryProvider();
    await directory.create(recursive: true);
    return _file = File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  Future<void> _load() async {
    try {
      final file = await _storageFile();
      if (await file.exists()) {
        _apply(jsonDecode(await file.readAsString()));
      }
    } catch (_) {
      _entries = [];
    }
    notifyListeners();
  }

  void _apply(Object? raw) {
    if (raw is! Map) throw const FormatException('Invalid assistant memory.');
    final entries = raw['entries'];
    _entries = [
      for (final item in entries is List ? entries : const [])
        if (item is Map)
          AssistantMemoryEntry.fromJson(Map<String, dynamic>.from(item)),
    ];
    _profile = AssistantUserProfile.fromJson(raw['profile']);
    _memoryEnabled = raw['memoryEnabled'] != false;
    _languageCode = assistantLanguageByCode(
      raw['language']?.toString() ?? 'auto',
    ).code;
    _font = ChatFont.values.asNameMap()[raw['font']] ?? ChatFont.serif;
    _textSize =
        ChatTextSize.values.asNameMap()[raw['textSize']] ?? ChatTextSize.medium;
    _sort();
  }

  void _sort() => _entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Map<String, Object?> _snapshot() => {
    'entries': _entries.map((e) => e.toJson()).toList(),
    'profile': _profile.toJson(),
    'memoryEnabled': _memoryEnabled,
    'language': _languageCode,
    'font': _font.name,
    'textSize': _textSize.name,
  };

  Future<void> _changed() async {
    notifyListeners();
    try {
      final file = await _storageFile();
      await file.writeAsString(jsonEncode(_snapshot()), flush: true);
    } catch (_) {
      // Best effort, like the other JSON stores: the in-memory state stays
      // usable and the next change tries the write again.
    }
  }

  /// Snapshot for the sync collection.
  Future<Object?> exportData() async {
    await _ready;
    return _snapshot();
  }

  /// Replaces everything with a synced snapshot.
  Future<void> importData(Object? data) async {
    await _ready;
    _apply(data);
    await _changed();
  }

  Future<void> setProfile(AssistantUserProfile profile) async {
    _profile = profile;
    await _changed();
  }

  Future<void> setMemoryEnabled(bool enabled) async {
    _memoryEnabled = enabled;
    await _changed();
  }

  Future<void> setLanguageCode(String code) async {
    _languageCode = assistantLanguageByCode(code).code;
    await _changed();
  }

  Future<void> setFont(ChatFont font) async {
    _font = font;
    await _changed();
  }

  Future<void> setTextSize(ChatTextSize size) async {
    _textSize = size;
    await _changed();
  }

  /// Creates or replaces an entry; returns its id.
  Future<String> saveEntry({
    String? id,
    required MemorySection section,
    required String title,
    String description = '',
    required String body,
  }) async {
    final entry = AssistantMemoryEntry(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      section: section,
      title: title.trim().isEmpty ? currentL.commonUntitled : title.trim(),
      description: description.trim(),
      body: body.trim(),
      updatedAt: DateTime.now(),
    );
    _entries.removeWhere((e) => e.id == entry.id);
    _entries.add(entry);
    _sort();
    await _changed();
    return entry.id;
  }

  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    await _changed();
  }

  Future<void> clearMemory() async {
    _entries = [];
    await _changed();
  }

  /// What the assistant's `remember` tool calls: adds [fact] as a new line
  /// to the entry titled [title] in [section] (case-insensitive), creating
  /// the entry when there is none. A fact already on the page is skipped.
  Future<AssistantMemoryEntry> remember({
    required MemorySection section,
    required String title,
    required String fact,
    String? description,
  }) async {
    final key = title.trim().toLowerCase();
    final existing = _entries
        .where((e) => e.section == section && e.title.toLowerCase() == key)
        .firstOrNull;
    final line = fact.trim();
    final lines = [
      ...?existing?.body.split('\n').where((l) => l.trim().isNotEmpty),
    ];
    if (!lines.any((l) => l.trim().toLowerCase() == line.toLowerCase())) {
      lines.add(line);
    }
    final id = await saveEntry(
      id: existing?.id,
      section: section,
      title: existing?.title ?? title,
      description: (description?.trim().isNotEmpty ?? false)
          ? description!
          : existing?.description ?? '',
      body: lines.join('\n'),
    );
    return _entries.firstWhere((e) => e.id == id);
  }

  /// The block appended to the assistant's system prompt: reply language,
  /// the User tab's profile, and — when memory is on — the memory pages,
  /// newest first and capped at [maxPromptMemoryChars]. Empty when there is
  /// nothing to say.
  String promptContext() {
    final out = StringBuffer();
    final language = assistantLanguageByCode(_languageCode);
    if (language.code != 'auto') {
      out.writeln(
        'Always reply in ${language.englishName}, whatever language the '
        'user writes in.',
      );
    }
    final p = _profile;
    if (!p.isEmpty) {
      out.writeln('About the user, in their own words:');
      if (p.callMe.trim().isNotEmpty) {
        out.writeln('- Call them: ${p.callMe.trim()}');
      }
      if (p.occupation.trim().isNotEmpty) {
        out.writeln('- What they do: ${p.occupation.trim()}');
      }
      if (p.summary.trim().isNotEmpty) {
        out.writeln('- Summary: ${p.summary.trim()}');
      }
      if (p.instructions.trim().isNotEmpty) {
        out.writeln('- How they want replies: ${p.instructions.trim()}');
      }
    }
    if (_memoryEnabled) {
      final memory = StringBuffer();
      for (final section in MemorySection.values) {
        for (final e in entriesIn(section)) {
          final page = '## ${e.title}\n${e.body}\n';
          if (memory.length + page.length > maxPromptMemoryChars) break;
          memory.write(page);
        }
      }
      if (memory.isNotEmpty) {
        out.writeln(
          'What you remember about the user from earlier chats (use it when '
          'relevant; never recite it unprompted):',
        );
        out.write(memory);
      }
      out.writeln(
        'When the user shares a lasting fact about themselves — a '
        'preference, project, device, routine — save it with the remember '
        'tool. Never save passwords, keys or other secrets.',
      );
    }
    return out.toString().trim();
  }
}
