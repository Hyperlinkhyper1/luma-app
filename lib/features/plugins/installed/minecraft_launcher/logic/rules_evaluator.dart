import 'dart:io';

/// Evaluates a version JSON `rules` array — used identically for filtering
/// `libraries[]` entries and for selecting which `arguments.jvm`/`arguments.game`
/// conditional tokens apply on this machine.
///
/// Each rule looks like `{"action": "allow"|"disallow", "os"?: {"name",
/// "arch"}, "features"?: {...}}`. With no rules at all, the item is always
/// allowed. Otherwise the *last* matching rule wins (mirrors the vanilla
/// launcher's own evaluation order), and if no rule matches, the item is
/// denied.
///
/// [activeFeatures] covers `arguments.game` entries gated on launch-time
/// features (e.g. `is_demo_user`, `has_custom_resolution`) — omitted/false
/// for anything not explicitly enabled.
bool evaluateRules(
  List<Map<String, dynamic>> rules, {
  Set<String> activeFeatures = const {},
}) {
  if (rules.isEmpty) return true;

  var allowed = false;
  for (final rule in rules) {
    if (!_ruleMatchesPlatform(rule) || !_ruleMatchesFeatures(rule, activeFeatures)) {
      continue;
    }
    allowed = (rule['action'] as String?) == 'allow';
  }
  return allowed;
}

bool _ruleMatchesPlatform(Map<String, dynamic> rule) {
  final os = rule['os'] as Map<String, dynamic>?;
  if (os == null) return true;

  final name = os['name'] as String?;
  if (name != null && name != _currentOsName) return false;

  final arch = os['arch'] as String?;
  if (arch != null && arch != _currentArch) return false;

  final versionPattern = os['version'] as String?;
  if (versionPattern != null &&
      !RegExp(versionPattern).hasMatch(Platform.operatingSystemVersion)) {
    return false;
  }
  return true;
}

bool _ruleMatchesFeatures(Map<String, dynamic> rule, Set<String> activeFeatures) {
  final features = rule['features'] as Map<String, dynamic>?;
  if (features == null) return true;
  for (final entry in features.entries) {
    final wants = entry.value == true;
    final has = activeFeatures.contains(entry.key);
    if (wants != has) return false;
  }
  return true;
}

String get _currentOsName {
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'osx';
  if (Platform.isLinux) return 'linux';
  return 'unknown';
}

/// This plugin only targets 64-bit Windows (see the platform gate in
/// `minecraft_launcher_page.dart`), so `arch` rules — which in practice only
/// ever gate a legacy 32-bit `x86` build — always resolve to "not x86".
const String _currentArch = 'x64';
