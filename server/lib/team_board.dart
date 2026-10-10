import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'util.dart';

/// The Team Clipboard: one shared board where an invited team keeps track of
/// bugs, suggestions and models still to add to their Minecraft mods. Each
/// entry has a brief, a stage, the files that belong to it (models,
/// textures, animation metadata) and a chat thread.
///
/// Like the recipe catalogue this is plain shared content, not a
/// zero-knowledge sync collection: everyone on the team reads the same
/// entries. Nobody gets in by default — the operator adds each account from
/// the dashboard's Users tab, as a member or as a lead.

/// What an entry is about.
const kTeamBoardKinds = ['bug', 'suggestion', 'model'];

/// An entry's stage, in board order. `idea` is a bug's "open" and `added` a
/// bug's "fixed"; the app picks the wording per kind.
const kTeamBoardStages = ['idea', 'claimed', 'done', 'added'];

/// The two ways onto the board. A lead can also mark things added, close
/// any thread and remove anything; a member can do everything else.
const kTeamBoardRoles = ['member', 'lead'];

/// The only files the board takes: models and textures, and the `.mcmeta`
/// that animates a texture.
const kTeamBoardFileExtensions = ['png', 'json', 'mcmeta'];

const kTeamBoardMaxFileBytes = 10 * 1024 * 1024;
const kTeamBoardMaxTitleChars = 140;
const kTeamBoardMaxBriefChars = 4000;
const kTeamBoardMaxMessageChars = 4000;
const kTeamBoardMaxEntries = 2000;
const kTeamBoardMaxFilesPerEntry = 60;
const kTeamBoardMaxMessagesPerEntry = 1000;

/// Every attachment on the board together. The server is a home machine,
/// so the board can't grow without bound.
const kTeamBoardMaxTotalFileBytes = 1024 * 1024 * 1024;

class TeamBoardFile {
  TeamBoardFile({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.uploaderId,
    required this.uploaderEmail,
    required this.createdAtMs,
  });

  final String id;
  final String name;
  final int sizeBytes;
  final String uploaderId;
  String uploaderEmail;
  final int createdAtMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sizeBytes': sizeBytes,
        'uploaderId': uploaderId,
        'uploaderEmail': uploaderEmail,
        'createdAtMs': createdAtMs,
      };

  static TeamBoardFile? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'], name = raw['name'];
    if (id is! String || name is! String) return null;
    return TeamBoardFile(
      id: id,
      name: name,
      sizeBytes: raw['sizeBytes'] as int? ?? 0,
      uploaderId: raw['uploaderId'] as String? ?? '',
      uploaderEmail: raw['uploaderEmail'] as String? ?? '',
      createdAtMs: raw['createdAtMs'] as int? ?? 0,
    );
  }
}

class TeamBoardMessage {
  TeamBoardMessage({
    required this.id,
    required this.authorId,
    required this.authorEmail,
    required this.text,
    required this.createdAtMs,
  });

  final String id;
  final String authorId;
  String authorEmail;
  final String text;
  final int createdAtMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorEmail': authorEmail,
        'text': text,
        'createdAtMs': createdAtMs,
      };

  static TeamBoardMessage? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'], text = raw['text'];
    if (id is! String || text is! String) return null;
    return TeamBoardMessage(
      id: id,
      authorId: raw['authorId'] as String? ?? '',
      authorEmail: raw['authorEmail'] as String? ?? '',
      text: text,
      createdAtMs: raw['createdAtMs'] as int? ?? 0,
    );
  }
}

class TeamBoardEntry {
  TeamBoardEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.brief,
    required this.authorId,
    required this.authorEmail,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.stage = 'idea',
    this.closed = false,
    this.claimedById,
    this.claimedByEmail,
    List<TeamBoardFile>? files,
    List<TeamBoardMessage>? messages,
  })  : files = files ?? [],
        messages = messages ?? [];

  final String id;
  String kind;
  String title;
  String brief;
  String stage;
  bool closed;
  final String authorId;
  String authorEmail;
  String? claimedById;
  String? claimedByEmail;
  final int createdAtMs;

  /// The last time anything happened to the entry — an edit, a stage, a
  /// file or a message. The board sorts on it and the app polls on it.
  int updatedAtMs;

  final List<TeamBoardFile> files;
  final List<TeamBoardMessage> messages;

  /// Where the entry sits on the board: work still to do on top, then done,
  /// then added, and closed threads at the very bottom.
  int get boardRank {
    if (closed) return 3;
    return switch (stage) { 'done' => 1, 'added' => 2, _ => 0 };
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'title': title,
        'brief': brief,
        'stage': stage,
        'closed': closed,
        'authorId': authorId,
        'authorEmail': authorEmail,
        'claimedById': claimedById,
        'claimedByEmail': claimedByEmail,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
        'files': files.map((f) => f.toJson()).toList(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  static TeamBoardEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'], title = raw['title'];
    if (id is! String || title is! String) return null;
    final kind = raw['kind'];
    final stage = raw['stage'];
    return TeamBoardEntry(
      id: id,
      kind: kTeamBoardKinds.contains(kind) ? kind as String : 'suggestion',
      title: title,
      brief: raw['brief'] as String? ?? '',
      stage: kTeamBoardStages.contains(stage) ? stage as String : 'idea',
      closed: raw['closed'] == true,
      authorId: raw['authorId'] as String? ?? '',
      authorEmail: raw['authorEmail'] as String? ?? '',
      claimedById: raw['claimedById'] as String?,
      claimedByEmail: raw['claimedByEmail'] as String?,
      createdAtMs: raw['createdAtMs'] as int? ?? 0,
      updatedAtMs: raw['updatedAtMs'] as int? ?? 0,
      files: [
        for (final f in raw['files'] as List? ?? const [])
          if (TeamBoardFile.fromJson(f) case final file?) file,
      ],
      messages: [
        for (final m in raw['messages'] as List? ?? const [])
          if (TeamBoardMessage.fromJson(m) case final message?) message,
      ],
    );
  }
}

/// A trimmed title, or null when it is empty or too long.
String? cleanTeamBoardTitle(Object? raw) {
  if (raw is! String) return null;
  final title = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (title.isEmpty || title.length > kTeamBoardMaxTitleChars) return null;
  return title;
}

/// A trimmed multi-line text of at most [max] characters, or null when it is
/// too long (or, with [required], empty).
String? cleanTeamBoardText(Object? raw, int max, {bool required = false}) {
  if (raw == null && !required) return '';
  if (raw is! String) return null;
  final text = raw
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'[\x00-\x08\x0B-\x1F\x7F]'), '')
      .trim();
  if (text.length > max || (required && text.isEmpty)) return null;
  return text;
}

/// The name an uploaded file is listed and downloaded under: the last path
/// segment, without control characters, ending in one of
/// [kTeamBoardFileExtensions]. Null when it can't be one.
String? cleanTeamBoardFileName(String? raw) {
  if (raw == null) return null;
  var name = raw.split(RegExp(r'[\\/]')).last;
  name = name
      .replaceAll(RegExp(r'[\x00-\x1F\x7F"<>:|?*]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  while (name.startsWith('.')) {
    name = name.substring(1);
  }
  if (name.isEmpty || name.length > 120) return null;
  final ext = teamBoardFileExtension(name);
  if (ext == null || name.length == ext.length + 1) return null;
  return name;
}

/// The allowed extension [name] ends in, lowercased, or null.
String? teamBoardFileExtension(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return null;
  final ext = name.substring(dot + 1).toLowerCase();
  return kTeamBoardFileExtensions.contains(ext) ? ext : null;
}

const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// The largest texture the board takes: wide enough for any block or item
/// texture, tall enough for a long animated strip, and few enough pixels
/// that decoding one never needs more than 64 MB.
const kTeamBoardMaxImageWidth = 4096;
const kTeamBoardMaxImageHeight = 16384;
const kTeamBoardMaxImagePixels = 16 * 1024 * 1024;

/// How deep brackets may nest in a model. Real models stay under ten;
/// the cap keeps a hostile file from overflowing the parser's stack.
const kTeamBoardMaxJsonDepth = 64;

/// Why [bytes] can't be attached as [name], or null when they can.
///
/// The file has to be exactly what its extension says. A PNG is walked
/// chunk by chunk: IHDR first, every chunk's CRC right, IEND last and
/// nothing hidden after it. A model or `.mcmeta` has to be UTF-8 text that
/// parses as a JSON object. Nothing here runs or renders the file; the
/// server only reads its bytes. The app makes the same check before it
/// uploads anything.
String? teamBoardFileProblem(String name, Uint8List bytes) {
  if (bytes.isEmpty) return '$name is empty.';
  if (bytes.length > kTeamBoardMaxFileBytes) {
    return '$name is over ${kTeamBoardMaxFileBytes ~/ (1024 * 1024)} MB.';
  }
  return switch (teamBoardFileExtension(name)) {
    'png' => _pngProblem(name, bytes),
    'json' || 'mcmeta' => _jsonProblem(name, bytes),
    _ => 'Only .png, .json and .mcmeta files can be attached.',
  };
}

String? _pngProblem(String name, Uint8List bytes) {
  final bad = '$name is not a valid PNG image.';
  if (bytes.length < 8 + 25 + 12) return bad;
  for (var i = 0; i < _pngSignature.length; i++) {
    if (bytes[i] != _pngSignature[i]) return bad;
  }
  final data = ByteData.sublistView(bytes);
  var at = 8;
  var first = true;
  var sawData = false;
  while (true) {
    if (at + 12 > bytes.length) return bad;
    final length = data.getUint32(at);
    if (length > bytes.length - at - 12) return bad;
    final type = String.fromCharCodes(bytes, at + 4, at + 8);
    if (!RegExp(r'^[A-Za-z]{4}$').hasMatch(type)) return bad;
    final crc = data.getUint32(at + 8 + length);
    if (_crc32(bytes, at + 4, at + 8 + length) != crc) return bad;
    if (first) {
      if (type != 'IHDR' || length != 13) return bad;
      final width = data.getUint32(at + 8);
      final height = data.getUint32(at + 12);
      if (width == 0 || height == 0) return bad;
      if (width > kTeamBoardMaxImageWidth ||
          height > kTeamBoardMaxImageHeight ||
          width * height > kTeamBoardMaxImagePixels) {
        return '$name is too big an image: textures can be at most '
            '$kTeamBoardMaxImageWidth × $kTeamBoardMaxImageHeight pixels.';
      }
      first = false;
    } else if (type == 'IHDR') {
      return bad;
    }
    if (type == 'IDAT') sawData = true;
    at += 12 + length;
    if (type == 'IEND') {
      return sawData && length == 0 && at == bytes.length ? null : bad;
    }
  }
}

String? _jsonProblem(String name, Uint8List bytes) {
  var start = 0;
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    start = 3;
  }
  final String text;
  try {
    text = utf8.decode(Uint8List.sublistView(bytes, start));
  } on FormatException {
    return '$name is not UTF-8 text.';
  }
  var depth = 0;
  var inString = false;
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (inString) {
      if (c == 0x5C) {
        i++;
      } else if (c == 0x22) {
        inString = false;
      }
    } else if (c == 0x22) {
      inString = true;
    } else if (c == 0x7B || c == 0x5B) {
      if (++depth > kTeamBoardMaxJsonDepth) {
        return '$name nests deeper than $kTeamBoardMaxJsonDepth levels.';
      }
    } else if (c == 0x7D || c == 0x5D) {
      depth--;
    }
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    final (line, column) = _position(text, e.offset);
    return '$name is not valid JSON (line $line, column $column).';
  }
  if (decoded is! Map) return '$name must hold a JSON object.';
  return null;
}

(int, int) _position(String text, int? offset) {
  final end = (offset ?? 0).clamp(0, text.length);
  var line = 1, column = 1;
  for (var i = 0; i < end; i++) {
    if (text.codeUnitAt(i) == 0x0A) {
      line++;
      column = 1;
    } else {
      column++;
    }
  }
  return (line, column);
}

final List<int> _crcTable = List.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(Uint8List bytes, int start, int end) {
  var crc = 0xFFFFFFFF;
  for (var i = start; i < end; i++) {
    crc = _crcTable[(crc ^ bytes[i]) & 0xFF] ^ (crc >> 8);
  }
  return crc ^ 0xFFFFFFFF;
}

/// The Content-Type a file is served with.
String teamBoardFileContentType(String name) =>
    teamBoardFileExtension(name) == 'png'
        ? 'image/png'
        : 'application/json; charset=utf-8';

/// What [userId] (on the board as [role]) may do to [entry].
class TeamBoardPermissions {
  const TeamBoardPermissions(this.entry, this.userId, this.role);

  final TeamBoardEntry entry;
  final String userId;
  final String role;

  bool get isLead => role == 'lead';
  bool get isAuthor => entry.authorId == userId;

  bool get canEdit => isLead || isAuthor;
  bool get canClose => isLead || isAuthor;

  /// A lead can remove anything. An author can take back their own entry
  /// only while nobody else has put anything in it.
  bool get canDelete =>
      isLead ||
      (isAuthor &&
          entry.messages.every((m) => m.authorId == userId) &&
          entry.files.every((f) => f.uploaderId == userId));

  bool get canPost => !entry.closed;

  bool canRemoveFile(TeamBoardFile file) =>
      !entry.closed && (isLead || file.uploaderId == userId);

  /// Why moving the entry to [stage] is refused, or null when it is allowed.
  /// Anyone can move between idea, claimed and done; only a lead can mark
  /// something added or take it back out of added.
  String? stageRefusal(String stage) {
    if (!kTeamBoardStages.contains(stage)) return 'Unknown stage.';
    if (entry.closed) return 'Reopen the thread first.';
    if ((stage == 'added' || entry.stage == 'added') && !isLead) {
      return 'Only a team lead can mark something added.';
    }
    return null;
  }
}

/// File-backed store for the board: every entry, with its chat and file
/// list, in one JSON document, the file contents beside it under `files/`,
/// and who is on the team. Mutations go through [mutate] so they are
/// serialised and the [revision] the app polls on always moves.
class TeamBoardStore {
  TeamBoardStore(String dataDir) : _dir = '$dataDir/team_board' {
    try {
      final file = File(_boardPath);
      if (!file.existsSync()) return;
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return;
      revision = decoded['revision'] as int? ?? 0;
      final members = decoded['members'];
      if (members is Map) {
        members.forEach((userId, role) {
          if (userId is String && kTeamBoardRoles.contains(role)) {
            _roles[userId] = role as String;
          }
        });
      }
      for (final raw in decoded['entries'] as List? ?? const []) {
        final entry = TeamBoardEntry.fromJson(raw);
        if (entry != null) _entries[entry.id] = entry;
      }
    } catch (e) {
      stderr.writeln('[luma] could not read $_boardPath: $e');
    }
  }

  final String _dir;
  final Map<String, String> _roles = {};
  final Map<String, TeamBoardEntry> _entries = {};
  final AsyncLock _lock = AsyncLock();

  /// Bumped by every change, so the app can ask "anything new?" cheaply.
  int revision = 0;

  String get _boardPath => '$_dir/board.json';
  String _filePath(String fileId) => '$_dir/files/$fileId';

  static final RegExp idPattern = RegExp(r'^[a-f0-9]{24}$');

  static String newId() =>
      randomBytes(12).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// 'member', 'lead', or null when [userId] is not on the team.
  String? roleOf(String userId) => _roles[userId];

  Map<String, String> get roles => Map.unmodifiable(_roles);

  TeamBoardEntry? entry(String id) => _entries[id];

  int get entryCount => _entries.length;

  int get totalFileBytes => _entries.values
      .expand((e) => e.files)
      .fold(0, (sum, f) => sum + f.sizeBytes);

  /// The board in display order: to-do first, closed last, and the most
  /// recently active first within each group.
  List<TeamBoardEntry> board() => _entries.values.toList()
    ..sort((a, b) {
      final rank = a.boardRank.compareTo(b.boardRank);
      return rank != 0 ? rank : b.updatedAtMs.compareTo(a.updatedAtMs);
    });

  /// Puts [userId] on the team as [role], or takes them off with null.
  Future<void> setRole(String userId, String? role) => mutate(() {
        if (role == null) {
          _roles.remove(userId);
        } else {
          _roles[userId] = role;
        }
      });

  /// Runs [change] alone, then bumps [revision] and saves the board.
  Future<T> mutate<T>(T Function() change) => _lock.synchronized(() async {
        final result = change();
        revision++;
        await _save();
        return result;
      });

  void addEntry(TeamBoardEntry entry) => _entries[entry.id] = entry;

  /// Takes [id] off the board. Call inside [mutate], then [deleteFile] each
  /// of the returned entry's files.
  TeamBoardEntry? removeEntry(String id) => _entries.remove(id);

  Future<void> _save() async {
    await Directory(_dir).create(recursive: true);
    await atomicWriteString(
        _boardPath,
        jsonEncode({
          'revision': revision,
          'members': _roles,
          'entries': _entries.values.map((e) => e.toJson()).toList(),
        }));
  }

  /// Stores an attachment as inert bytes: under a random id the server
  /// made up, with no extension, in a directory nothing executes from, with
  /// the default non-executable mode. The uploader's file name never
  /// reaches the disk.
  Future<void> writeFile(String fileId, List<int> bytes) async {
    await Directory('$_dir/files').create(recursive: true);
    await atomicWriteBytes(_filePath(fileId), bytes);
  }

  Future<Uint8List?> readFile(String fileId) async {
    if (!idPattern.hasMatch(fileId)) return null;
    final file = File(_filePath(fileId));
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<void> deleteFile(String fileId) async {
    if (!idPattern.hasMatch(fileId)) return;
    final file = File(_filePath(fileId));
    if (await file.exists()) await file.delete();
  }

  /// The entry [fileId] is attached to, with the file itself.
  ({TeamBoardEntry entry, TeamBoardFile file})? findFile(String fileId) {
    for (final entry in _entries.values) {
      for (final file in entry.files) {
        if (file.id == fileId) return (entry: entry, file: file);
      }
    }
    return null;
  }

  /// A deleted account leaves the team, and its email leaves the board.
  /// What it wrote and uploaded stays: the rest of the team still works
  /// from it.
  Future<void> forgetUser(String userId) => mutate(() {
        _roles.remove(userId);
        for (final entry in _entries.values) {
          if (entry.authorId == userId) entry.authorEmail = '';
          if (entry.claimedById == userId) entry.claimedByEmail = '';
          for (final m in entry.messages) {
            if (m.authorId == userId) m.authorEmail = '';
          }
          for (final f in entry.files) {
            if (f.uploaderId == userId) f.uploaderEmail = '';
          }
        }
      });
}
