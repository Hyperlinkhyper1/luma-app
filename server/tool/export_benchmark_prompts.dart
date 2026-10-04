import 'dart:io';

import 'package:luma_sync_server/benchmark_prompts.dart';

/// Writes every AI Usage test prompt to `benchmarks/prompts/`, so they can be
/// pasted into any chat outside the admin dashboard. Run from `server/`.
void main() {
  final dir = Directory('benchmarks/prompts')..createSync(recursive: true);
  final files = benchmarkPromptFiles();
  for (final stale in dir.listSync().whereType<File>()) {
    if (!files.containsKey(stale.uri.pathSegments.last)) stale.deleteSync();
  }
  for (final e in files.entries) {
    File('${dir.path}/${e.key}').writeAsStringSync(e.value);
  }
  stdout.writeln('Wrote ${files.length} files to ${dir.path}');
}
