import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../assistant_files.dart';
import '../data/chat_repository.dart';
import '../providers/ai_client.dart';
import 'office_document.dart';
import 'office_export.dart';
import 'office_import.dart';

/// A file shown in the Assistant's preview panel.
class AssistantPreviewFile {
  const AssistantPreviewFile({
    required this.path,
    required this.name,
    this.artifactId,
  });
  final String path;
  final String name;
  final int? artifactId;

  String get extension => p.extension(name).replaceFirst('.', '').toLowerCase();
  OfficeKind? get officeKind => officeKindOf(name);
}

/// One Office file the Assistant is building, with the editable model that
/// produces it.
class OfficeSession {
  OfficeSession({required this.file, required this.document});
  final AssistantPreviewFile file;
  final OfficeDocument document;

  /// The last save could not overwrite the file, usually because it is open
  /// in another program. The preview and sidecar still hold the edit.
  String? saveError;
}

/// Builds Word, PowerPoint and Excel files a few blocks at a time through
/// three Assistant tools, and holds what the preview panel shows: the open
/// file, the document behind it and where the model is reading or writing.
///
/// Each edit is written straight to disk, with a `.luma.json` sidecar that
/// keeps the editable structure so a later turn can read and change the file.
class AssistantWorkbench extends ChangeNotifier {
  AssistantWorkbench(this.repository, {Future<Directory> Function()? directory})
    : _directory = directory ?? _defaultDirectory;

  final ChatRepository repository;
  final Future<Directory> Function() _directory;

  static Future<Directory> _defaultDirectory() async => Directory(
    p.join(
      (await getApplicationSupportDirectory()).path,
      'assistant_artifacts',
    ),
  );

  static const createTool = 'create_office_file';
  static const editTool = 'edit_office_file';
  static const readTool = 'read_office_file';
  static const toolNames = {createTool, editTool, readTool};

  static String sidecarPath(String path) => '$path.luma.json';

  final Map<int, OfficeSession> _sessions = {};

  AssistantPreviewFile? _file;
  OfficeSession? _session;
  OfficeFocus? _focus;
  bool _modelActive = false;
  int _revision = 0;

  AssistantPreviewFile? get file => _file;
  bool get hasFile => _file != null;

  /// The editable document behind [file], when it is an Office file luma
  /// built.
  OfficeSession? get session => _session;

  /// What the model touched last in [session].
  OfficeFocus? get focus => _focus;

  /// True while a reply that may still edit the file is being generated.
  bool get modelActive => _modelActive;

  /// Bumped on every change to the open document, so the panel can flash
  /// what just changed.
  int get revision => _revision;

  set modelActive(bool value) {
    if (_modelActive == value) return;
    _modelActive = value;
    if (!value) _focus = null;
    notifyListeners();
  }

  Future<void> open(AssistantPreviewFile file) async {
    _file = file;
    _focus = null;
    _session = file.officeKind == null ? null : await _loadSession(file);
    _revision++;
    notifyListeners();
  }

  /// Opens the file at [path], looking up its artifact record for the name.
  Future<void> openPath(String path) async {
    ChatArtifactRecord? record;
    try {
      final artifacts = await repository.watchArtifacts().first;
      record = artifacts.where((a) => a.path == path).firstOrNull;
    } catch (_) {
      record = null;
    }
    await open(
      AssistantPreviewFile(
        path: path,
        name: record?.name ?? _displayName(path),
        artifactId: record?.id,
      ),
    );
  }

  void close() {
    _file = null;
    _session = null;
    _focus = null;
    notifyListeners();
  }

  static String _displayName(String path) =>
      p.basename(path).replaceFirst(RegExp(r'^\d{10,}_'), '');

  Future<OfficeSession?> _loadSession(AssistantPreviewFile file) async {
    final id = file.artifactId;
    if (id != null && _sessions[id] != null) return _sessions[id];
    final sidecar = File(sidecarPath(file.path));
    if (!await sidecar.exists()) return null;
    try {
      final document = OfficeDocument.fromJson(
        jsonDecode(await sidecar.readAsString()) as Map<String, dynamic>,
      );
      final session = OfficeSession(file: file, document: document);
      if (id != null) _sessions[id] = session;
      return session;
    } catch (_) {
      return null;
    }
  }

  static final schemas = <AiToolDefinition>[
    const AiToolDefinition(
      name: createTool,
      description:
          'Start a Word (.docx), PowerPoint (.pptx) or Excel (.xlsx) file. The user watches it '
          'fill in live beside the chat. Then build it with edit_office_file, one section, a few '
          'slides or one table per call, in reading order. Never claim the file is finished '
          'before your last edit succeeds.',
      parameters: {
        'type': 'object',
        'properties': {
          'type': {
            'type': 'string',
            'enum': ['docx', 'pptx', 'xlsx'],
          },
          'name': {
            'type': 'string',
            'description': 'Short file name without directories.',
          },
          'title': {
            'type': 'string',
            'description': 'Document title, shown in the file properties.',
          },
        },
        'required': ['type', 'name'],
      },
    ),
    const AiToolDefinition(
      name: editTool,
      description:
          'Change a file made with create_office_file. Word: content is Markdown blocks '
          '(# headings, paragraphs, - or 1. lists indented two spaces per level, > quotes, '
          '| pipe | tables |, --- page break, **bold**, *italic*). PowerPoint: content is '
          'slides separated by --- lines, each with "# Title", an optional "## Subtitle" and '
          '- bullets; the first slide without bullets is the cover. Actions append, insert '
          '(before index), replace (the block or slide at index) and delete use 0-based indices '
          'from read_office_file. Excel: give sheet, cell (top-left, e.g. A1) and rows (an '
          'array of rows of values; text, numbers, or formulas such as =SUM(B2:B9)); action '
          'delete_sheet removes a sheet.',
      parameters: {
        'type': 'object',
        'properties': {
          'file_id': {'type': 'integer'},
          'action': {
            'type': 'string',
            'enum': [
              'append',
              'insert',
              'replace',
              'delete',
              'write',
              'delete_sheet',
            ],
          },
          'index': {'type': 'integer'},
          'content': {'type': 'string'},
          'sheet': {'type': 'string'},
          'cell': {'type': 'string'},
          'rows': {
            'type': 'array',
            'items': {
              'type': 'array',
              'items': {
                'type': 'string',
                'description':
                    'Text, a plain number such as 1250.5, or a formula.',
              },
            },
          },
        },
        'required': ['file_id', 'action'],
      },
    ),
    const AiToolDefinition(
      name: readTool,
      description:
          'Look inside an Office file before changing it. Without file_id: lists the Office '
          'files in this chat. With file_id only: a numbered outline. With index (and '
          'optionally end_index): those blocks, slides or sheets in full, in the Markdown '
          'edit_office_file accepts. For a sheet, range (e.g. A1:D20) limits the cells returned.',
      parameters: {
        'type': 'object',
        'properties': {
          'file_id': {'type': 'integer'},
          'index': {'type': 'integer'},
          'end_index': {'type': 'integer'},
          'range': {'type': 'string'},
        },
        'required': [],
      },
    ),
  ];

  /// Runs one of the [toolNames] for [conversationId]. The returned map is
  /// what the model sees; a `created` result also describes the artifact.
  Future<Map<String, dynamic>> execute(
    int conversationId,
    String name,
    Map<String, dynamic> input,
  ) async {
    try {
      return switch (name) {
        createTool => await _create(conversationId, input),
        editTool => await _edit(input),
        readTool => await _read(conversationId, input),
        _ => {'status': 'error', 'message': 'Unknown tool "$name".'},
      };
    } on FormatException catch (e) {
      return {'status': 'invalid', 'message': e.message};
    }
  }

  Future<Map<String, dynamic>> _create(
    int conversationId,
    Map<String, dynamic> input,
  ) async {
    final kind = officeKindOf(input['type']?.toString() ?? '');
    if (kind == null) {
      throw const FormatException('type must be docx, pptx or xlsx.');
    }
    final name = _safeName(input['name']?.toString() ?? 'document', kind);
    final title = (input['title']?.toString().trim().isNotEmpty ?? false)
        ? input['title'].toString().trim()
        : p.basenameWithoutExtension(name);
    final session = await _register(
      conversationId,
      OfficeDocument(kind, title: title),
      name,
    );
    return {
      'status': 'created',
      'file_id': session.file.artifactId,
      'id': session.file.artifactId,
      'name': name,
      'path': session.file.path,
      'mimeType': officeMimeTypes[kind],
    };
  }

  static String _safeName(String raw, OfficeKind kind) {
    final stem = p
        .basenameWithoutExtension(p.basename(raw))
        .replaceAll(RegExp(r'[^\p{L}\p{N} _-]', unicode: true), '_')
        .trim();
    return '${stem.isEmpty ? 'document' : stem.substring(0, stem.length.clamp(0, 80))}.${kind.name}';
  }

  /// Writes [document] as a new artifact in [conversationId] and opens it.
  Future<OfficeSession> _register(
    int conversationId,
    OfficeDocument document,
    String name,
  ) async {
    final kind = document.kind;
    final directory = await _directory();
    await directory.create(recursive: true);
    final path = p.join(
      directory.path,
      '${DateTime.now().microsecondsSinceEpoch}_$name',
    );
    await File(path).writeAsBytes(exportOfficeDocument(document), flush: true);
    await File(sidecarPath(path)).writeAsString(jsonEncode(document.toJson()));
    final int id;
    try {
      id = await repository.addArtifact(
        conversationId: conversationId,
        name: name,
        path: path,
        mimeType: officeMimeTypes[kind]!,
      );
    } catch (_) {
      await File(path).delete();
      await File(sidecarPath(path)).delete();
      rethrow;
    }
    final file = AssistantPreviewFile(path: path, name: name, artifactId: id);
    final session = OfficeSession(file: file, document: document);
    _sessions[id] = session;
    _file = file;
    _session = session;
    _focus = null;
    _revision++;
    notifyListeners();
    return session;
  }

  /// Turns an uploaded Word, PowerPoint or Excel file into an editable copy
  /// in [conversationId], opens it in the panel, and returns the text
  /// attachment the model sees in its place: the copy's file_id and its
  /// numbered contents. The uploaded original is never written to.
  Future<AssistantAttachment> importUpload(
    int conversationId,
    AssistantAttachment upload,
  ) async {
    final kind = officeKindOf(upload.name);
    final data = upload.base64Data;
    if (kind == null || data == null) {
      throw const FormatException(
        'Only .docx, .pptx and .xlsx files can be edited.',
      );
    }
    final imported = importOfficeFile(upload.name, base64Decode(data));
    final document = imported.document;
    final name = _safeName(upload.name, kind);
    if (document.title.isEmpty) {
      document.title = p.basenameWithoutExtension(name);
    }
    final session = await _register(conversationId, document, name);
    final label = switch (kind) {
      OfficeKind.docx => 'Word document',
      OfficeKind.pptx => 'PowerPoint deck',
      OfficeKind.xlsx => 'Excel workbook',
    };
    final text = [
      'The user uploaded the $label "$name". luma imported it as an editable '
          'copy with file_id ${session.file.artifactId}, now open beside the '
          'chat. Change it with edit_office_file (indices below) and look '
          'closer with read_office_file. Edits go to this copy; the uploaded '
          'original is not changed. Text, headings, lists, tables, slides and '
          'cell values were kept; pictures, charts and custom styling were not.',
      if (imported.truncated)
        "The file was larger than luma's limits, so only the first part was imported.",
      if (document.partCount == 0) 'The file has no text content yet.',
      '',
      officeContentsForPrompt(document),
    ].join('\n');
    return AssistantAttachment(
      name: name,
      mimeType: 'text/plain',
      text: text.length > 30000 ? text.substring(0, 30000) : text,
    );
  }

  Future<OfficeSession> _sessionFor(Object? rawId) async {
    final id = rawId is num ? rawId.toInt() : int.tryParse('$rawId');
    if (id == null) throw const FormatException('file_id is required.');
    final cached = _sessions[id];
    if (cached != null) return cached;
    final artifacts = await repository.watchArtifacts().first;
    final record = artifacts.where((a) => a.id == id).firstOrNull;
    if (record == null || officeKindOf(record.name) == null) {
      throw FormatException('There is no Office file with id $id.');
    }
    final session = await _loadSession(
      AssistantPreviewFile(
        path: record.path,
        name: record.name,
        artifactId: id,
      ),
    );
    if (session == null) {
      throw const FormatException(
        'This file was not made by luma, so it cannot be edited here.',
      );
    }
    return session;
  }

  /// Puts [session] in the panel with [focus] highlighted.
  void _show(OfficeSession session, OfficeFocus? focus) {
    _file = session.file;
    _session = session;
    _focus = focus;
    _revision++;
    notifyListeners();
  }

  Future<Map<String, dynamic>> _edit(Map<String, dynamic> input) async {
    final session = await _sessionFor(input['file_id']);
    final document = session.document;
    final action = input['action']?.toString() ?? '';
    final OfficeFocus focus;
    if (document.kind == OfficeKind.xlsx) {
      final sheet =
          input['sheet']?.toString() ??
          (document.sheets.isEmpty ? 'Sheet1' : document.sheets.first.name);
      if (action == 'delete_sheet') {
        focus = document.deleteSheet(sheet);
      } else {
        final rows = input['rows'];
        if (rows is! List) {
          throw const FormatException('rows must be an array of rows.');
        }
        focus = document.writeCells(
          sheetName: sheet,
          cell: input['cell']?.toString() ?? 'A1',
          values: [
            for (final row in rows)
              [
                for (final value in row is List ? row : [row])
                  value is num ? formatSheetNumber(value) : '${value ?? ''}',
              ],
          ],
        );
      }
    } else {
      final content = input['content']?.toString() ?? '';
      if (content.length > 60000) {
        throw const FormatException(
          'Send at most 60,000 characters per edit; split it up.',
        );
      }
      focus = document.edit(
        action: action,
        index: (input['index'] as num?)?.toInt(),
        content: content,
      );
    }
    await _save(session);
    _show(session, focus);
    return {
      'status': session.saveError == null ? 'saved' : 'saved_in_luma_only',
      if (session.saveError != null) 'message': session.saveError,
      'file_id': session.file.artifactId,
      'parts': document.partCount,
      'changed': _describe(document.kind, focus),
    };
  }

  Future<Map<String, dynamic>> _read(
    int conversationId,
    Map<String, dynamic> input,
  ) async {
    if (input['file_id'] == null) {
      final artifacts = await repository.watchArtifacts().first;
      return {
        'status': 'ok',
        'files': [
          for (final a in artifacts)
            if (a.conversationId == conversationId &&
                officeKindOf(a.name) != null)
              {'file_id': a.id, 'name': a.name},
        ],
      };
    }
    final session = await _sessionFor(input['file_id']);
    final document = session.document;
    final index = (input['index'] as num?)?.toInt();
    if (index == null) {
      _show(
        session,
        const OfficeFocus(activity: OfficeActivity.reading, start: -1),
      );
      return {
        'status': 'ok',
        'file_id': session.file.artifactId,
        'type': document.kind.name,
        'title': document.title,
        'outline': document.outline(),
      };
    }
    if (index < 0 || index >= document.partCount) {
      throw FormatException(
        document.partCount == 0
            ? 'The file is still empty.'
            : 'index must be between 0 and ${document.partCount - 1}.',
      );
    }
    final end = ((input['end_index'] as num?)?.toInt() ?? index).clamp(
      index,
      document.partCount - 1,
    );
    if (document.kind == OfficeKind.xlsx) {
      final sheet = document.sheets[index];
      final range = input['range']?.toString().split(':');
      final from = range == null ? (0, 0) : parseCellName(range.first);
      final to = range == null
          ? (sheet.rows.length - 1, sheet.columnCount - 1)
          : parseCellName(range.last);
      if (from == null || to == null) {
        throw const FormatException('range must look like A1:D20.');
      }
      _show(
        session,
        OfficeFocus(
          activity: OfficeActivity.reading,
          start: index,
          cellStart: from,
          cellEnd: (to.$1.clamp(from.$1, from.$1 + 199), to.$2),
        ),
      );
      return {
        'status': 'ok',
        'sheet': sheet.name,
        'rows': [
          for (var r = from.$1; r <= to.$1 && r < from.$1 + 200; r++)
            {
              'row': r + 1,
              'cells': [
                for (var c = from.$2; c <= to.$2; c++) sheet.cell(r, c),
              ],
            },
        ],
      };
    }
    _show(
      session,
      OfficeFocus(
        activity: OfficeActivity.reading,
        start: index,
        end: end == index ? null : end,
      ),
    );
    final text = [
      for (var i = index; i <= end; i++) '[$i]\n${document.readPart(i)}',
    ].join('\n\n');
    return {
      'status': 'ok',
      'content': text.length > 20000 ? '${text.substring(0, 20000)}…' : text,
    };
  }

  Future<void> _save(OfficeSession session) async {
    final path = session.file.path;
    await File(
      sidecarPath(path),
    ).writeAsString(jsonEncode(session.document.toJson()), flush: true);
    try {
      await File(
        path,
      ).writeAsBytes(exportOfficeDocument(session.document), flush: true);
      session.saveError = null;
    } on FileSystemException {
      session.saveError =
          'The file is open in another program, so only luma\'s copy was '
          'updated. Ask the user to close it; the next edit saves everything.';
    }
  }

  static String _describe(OfficeKind kind, OfficeFocus focus) {
    if (kind == OfficeKind.xlsx) {
      final from = focus.cellStart;
      final to = focus.cellEnd;
      if (from == null) return 'sheet ${focus.start}';
      return '${cellName(from.$1, from.$2)}:${cellName((to ?? from).$1, (to ?? from).$2)}';
    }
    final noun = kind == OfficeKind.docx ? 'block' : 'slide';
    if (focus.activity == OfficeActivity.deleting) return '$noun removed';
    return focus.end == null
        ? '$noun ${focus.start}'
        : '${noun}s ${focus.start}-${focus.end}';
  }
}

/// Makes the [AssistantWorkbench] reachable from chat bubbles and the
/// Artifacts library, so opening a file shows it in the preview panel.
class AssistantWorkbenchScope extends InheritedWidget {
  const AssistantWorkbenchScope({
    super.key,
    required this.workbench,
    required super.child,
  });
  final AssistantWorkbench workbench;

  static AssistantWorkbench? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<AssistantWorkbenchScope>()
      ?.workbench;

  @override
  bool updateShouldNotify(AssistantWorkbenchScope oldWidget) =>
      workbench != oldWidget.workbench;
}
