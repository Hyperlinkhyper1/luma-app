import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// The classroom as the reader left it: the lesson form (school, year,
/// level, subject, book, chapter, paragraph, topic) and the lesson in
/// progress — its questions, the answers so far and, once handed in, the
/// tutor's verdicts. The page owns the shape; this keeps it on this device
/// only, trimmed so a bad page can't fill the disk.
///
/// The country is not here: it lives with the account on the server.
Object? cleanClassroomState(Object? raw, [int depth = 0]) {
  if (depth > 6) return null;
  return switch (raw) {
    final String s => s.length > 2000 ? s.substring(0, 2000) : s,
    final num n when n.isFinite => n,
    final bool b => b,
    final List list => [
      for (final v in list.take(40)) cleanClassroomState(v, depth + 1),
    ],
    final Map map => {
      for (final e in map.entries.take(40))
        if (e.key is String && (e.key as String).length <= 40)
          e.key as String: cleanClassroomState(e.value, depth + 1),
    },
    _ => null,
  };
}

Future<File> _file() async {
  final support = await getApplicationSupportDirectory();
  return File(
    '${support.path}${Platform.pathSeparator}text_library_classroom.json',
  );
}

Future<Object?> loadClassroom() async {
  try {
    final file = await _file();
    if (!await file.exists()) return null;
    return cleanClassroomState(jsonDecode(await file.readAsString()));
  } catch (_) {
    return null;
  }
}

Future<void> _saving = Future.value();

/// Saves one after another, so a quick run of changes lands in order.
Future<void> saveClassroom(Object? state) {
  final next = _saving.catchError((Object _) {}).then((_) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode(cleanClassroomState(state)),
      flush: true,
    );
    await temp.rename(file.path);
  });
  _saving = next;
  return next;
}
