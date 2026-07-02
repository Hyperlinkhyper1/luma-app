/// The running app's version and the GitHub repo it updates from.
///
/// [current] is injected at build time via `--dart-define=APP_VERSION=x.y.z`
/// (the CI release workflow passes the release tag here). Local/dev builds
/// leave it at `0.0.0`, which the updater treats as "never up to date" and so
/// simply skips the check (see [AppVersion.isReleaseBuild]).
class AppVersion {
  const AppVersion._();

  static const String current =
      String.fromEnvironment('APP_VERSION', defaultValue: '0.0.0');

  /// GitHub `owner/repo` the app pulls releases from.
  static const String repoOwner = 'Hyperlinkhyper1';
  static const String repoName = 'luma-app';

  /// A dev build has no injected version, so it must not try to "update".
  static bool get isReleaseBuild => current != '0.0.0';

  /// Compares two dotted version strings (leading `v` allowed). Returns
  /// > 0 when [a] is newer than [b], 0 when equal, < 0 when older. Missing
  /// components are treated as 0, so `1.2` == `1.2.0`.
  static int compare(String a, String b) {
    final pa = _parts(a);
    final pb = _parts(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va - vb;
    }
    return 0;
  }

  static List<int> _parts(String v) {
    final cleaned = v.trim().replaceFirst(RegExp(r'^[vV]'), '');
    return cleaned
        .split('.')
        .map((s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }
}
