/// Derives a friendly project name from a working-directory path, e.g.
/// `C:\Users\ayden\Files\Intellij-Programs\luma-app` ->
/// `Intellij-Programs/luma-app` — the last two path segments joined. Matches
/// the reference `claude-usage` CLI tool's own `project_name_from_cwd`, so
/// names read the same as what they're compared against.
///
/// Returns null for a null/empty/segment-less [cwd] — callers show this as
/// "Unknown project" rather than guessing.
String? projectNameFromCwd(String? cwd) {
  if (cwd == null || cwd.trim().isEmpty) return null;
  final segments = cwd
      .replaceAll('\\', '/')
      .split('/')
      .where((s) => s.isNotEmpty)
      .toList();
  if (segments.isEmpty) return null;
  if (segments.length == 1) return segments.single;
  return segments.sublist(segments.length - 2).join('/');
}
