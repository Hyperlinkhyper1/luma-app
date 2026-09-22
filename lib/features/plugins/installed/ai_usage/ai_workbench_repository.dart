import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'ai_workbench_models.dart';

/// Local-first storage and Codex export helpers for the AI Workbench tabs.
class AiWorkbenchRepository extends ChangeNotifier {
  AiWorkbenchRepository({
    Future<Directory> Function()? supportDirectoryProvider,
  }) : _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory {
    _ready = _load();
  }

  static const _fileName = 'luma_ai_workbench.json';

  final Future<Directory> Function() _supportDirectoryProvider;
  late final Future<void> _ready;
  File? _file;
  bool _loaded = false;
  List<AiMarkdownEntry> _markdownEntries = [];
  List<AiAgentDefinition> _agents = [];

  Future<void> get ready => _ready;
  bool get loaded => _loaded;
  List<AiMarkdownEntry> get markdownEntries =>
      List.unmodifiable(_markdownEntries);
  List<AiAgentDefinition> get agents => List.unmodifiable(_agents);

  Future<File> _storageFile() async {
    if (_file != null) return _file!;
    final directory = await _supportDirectoryProvider();
    await directory.create(recursive: true);
    _file = File('${directory.path}${Platform.pathSeparator}$_fileName');
    return _file!;
  }

  Future<void> _load() async {
    try {
      final file = await _storageFile();
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map) {
          final notes = raw['markdownEntries'];
          final agents = raw['agents'];
          _markdownEntries = [
            for (final item in notes is List ? notes : const [])
              if (item is Map)
                AiMarkdownEntry.fromJson(Map<String, dynamic>.from(item)),
          ];
          _agents = [
            for (final item in agents is List ? agents : const [])
              if (item is Map)
                AiAgentDefinition.fromJson(Map<String, dynamic>.from(item)),
          ];
        }
      }
    } catch (_) {
      _markdownEntries = [];
      _agents = [];
    }
    _sort();
    _loaded = true;
    notifyListeners();
  }

  void _sort() {
    _markdownEntries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _agents.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> _persist() async {
    try {
      final file = await _storageFile();
      await file.writeAsString(
        jsonEncode({
          'markdownEntries': _markdownEntries.map((e) => e.toJson()).toList(),
          'agents': _agents.map((e) => e.toJson()).toList(),
        }),
        flush: true,
      );
    } catch (_) {
      // A failed write must not make the editor unusable. The in-memory state
      // remains available and the next mutation gets another chance to save.
    }
  }

  Future<void> saveMarkdown({
    String? id,
    required String title,
    required String body,
    List<String> tags = const [],
  }) async {
    final now = DateTime.now();
    final old = id == null
        ? null
        : _markdownEntries.where((entry) => entry.id == id).firstOrNull;
    final entry = AiMarkdownEntry(
      id: id ?? now.microsecondsSinceEpoch.toString(),
      title: title.trim().isEmpty ? 'Untitled note' : title.trim(),
      body: body,
      tags: tags,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
    );
    _markdownEntries.removeWhere((item) => item.id == entry.id);
    _markdownEntries.add(entry);
    _sort();
    notifyListeners();
    await _persist();
  }

  Future<void> deleteMarkdown(String id) async {
    _markdownEntries.removeWhere((entry) => entry.id == id);
    for (final agent in _agents) {
      agent.libraryEntryIds.remove(id);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> saveAgent({
    String? id,
    required String name,
    required String description,
    required String instructions,
    required String outputFormat,
    required List<String> libraryEntryIds,
    required String preferredModel,
  }) async {
    final now = DateTime.now();
    final agent = AiAgentDefinition(
      id: id ?? now.microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'Untitled agent' : name.trim(),
      description: description.trim(),
      instructions: instructions.trim(),
      outputFormat: outputFormat.trim(),
      libraryEntryIds: List.of(libraryEntryIds),
      preferredModel: preferredModel.trim(),
      updatedAt: now,
    );
    _agents.removeWhere((item) => item.id == agent.id);
    _agents.add(agent);
    _sort();
    notifyListeners();
    await _persist();
  }

  Future<void> deleteAgent(String id) async {
    _agents.removeWhere((agent) => agent.id == id);
    notifyListeners();
    await _persist();
  }

  AiMarkdownEntry? markdownById(String id) {
    for (final entry in _markdownEntries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// A self-contained prompt for pasting into an existing Codex session.
  String codexPrompt(AiAgentDefinition agent) {
    final buffer = StringBuffer()
      ..writeln('You are the "${agent.name}" specialist.')
      ..writeln()
      ..writeln(agent.instructions.trim());
    if (agent.outputFormat.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Required output format')
        ..writeln(agent.outputFormat.trim());
    }
    _appendLibraryContext(buffer, agent);
    return buffer.toString().trimRight();
  }

  /// Generates the standard Codex skill file for this agent.
  String codexSkill(AiAgentDefinition agent) {
    final slug = slugFor(agent.name);
    final description = agent.description.trim().isEmpty
        ? 'Specialist agent created in Luma.'
        : agent.description.trim().replaceAll('\n', ' ');
    final buffer = StringBuffer()
      ..writeln('---')
      ..writeln('name: $slug')
      ..writeln('description: ${_yamlText(description)}')
      ..writeln('---')
      ..writeln()
      ..writeln('# ${agent.name}')
      ..writeln()
      ..writeln(agent.instructions.trim());
    if (agent.preferredModel.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Preferred model')
        ..writeln(agent.preferredModel.trim());
    }
    if (agent.outputFormat.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Required output format')
        ..writeln(agent.outputFormat.trim());
    }
    _appendLibraryContext(buffer, agent);
    return buffer.toString().trimRight() + '\n';
  }

  Future<String> installCodexSkill(
    AiAgentDefinition agent,
    String projectDirectory,
  ) async {
    final skillDirectory = Directory(
      '${projectDirectory}${Platform.pathSeparator}.agents'
      '${Platform.pathSeparator}skills${Platform.pathSeparator}${slugFor(agent.name)}',
    );
    await skillDirectory.create(recursive: true);
    final skillFile = File(
      '${skillDirectory.path}${Platform.pathSeparator}SKILL.md',
    );
    await skillFile.writeAsString(codexSkill(agent), flush: true);
    return skillFile.path;
  }

  static String slugFor(String value) {
    final slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'luma-agent' : slug;
  }

  void _appendLibraryContext(StringBuffer buffer, AiAgentDefinition agent) {
    final context = [
      for (final id in agent.libraryEntryIds)
        if (markdownById(id) case final entry?) entry,
    ];
    if (context.isEmpty) return;
    buffer
      ..writeln()
      ..writeln('## Library context');
    for (final entry in context) {
      buffer
        ..writeln()
        ..writeln('### ${entry.title}')
        ..writeln(entry.body.trim());
    }
  }

  static String _yamlText(String value) =>
      '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
}
