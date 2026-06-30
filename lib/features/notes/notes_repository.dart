import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class Note {
  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  final String id;
  String title;
  String content;
  DateTime updatedAt;

  Note copyWith({String? title, String? content}) => Note(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

class NotesRepository extends ChangeNotifier {
  NotesRepository() {
    _load();
  }

  List<Note> _notes = [];
  List<Note> get notes => List.unmodifiable(_notes);

  File? _file;

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}/luma_notes.json');
    return _file!;
  }

  Future<void> _load() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final raw = await file.readAsString();
        final list = jsonDecode(raw) as List<dynamic>;
        _notes = list
            .map((e) => Note.fromJson(e as Map<String, dynamic>))
            .toList();
        _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final file = await _getFile();
      await file.writeAsString(jsonEncode(_notes.map((n) => n.toJson()).toList()));
    } catch (_) {}
  }

  Future<Note> create() async {
    final note = Note(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: '',
      content: '',
      updatedAt: DateTime.now(),
    );
    _notes.insert(0, note);
    notifyListeners();
    await _persist();
    return note;
  }

  Future<void> update(String id, {String? title, String? content}) async {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final updated = _notes[idx].copyWith(title: title, content: content);
    _notes.removeAt(idx);
    _notes.insert(0, updated);
    notifyListeners();
    await _persist();
  }

  Future<void> delete(String id) async {
    _notes.removeWhere((n) => n.id == id);
    notifyListeners();
    await _persist();
  }
}
