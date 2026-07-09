import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A named hosted-agent profile, e.g. Mistral's Agents API `agent_id`.
class AgentProfile {
  const AgentProfile({required this.name, required this.agentId});
  final String name;
  final String agentId;

  Map<String, dynamic> toJson() => {'name': name, 'agentId': agentId};

  factory AgentProfile.fromJson(Map<String, dynamic> json) => AgentProfile(
        name: json['name'] as String,
        agentId: json['agentId'] as String,
      );
}

/// Stores named hosted-agent profiles per provider, plus which one is
/// active. Agent IDs identify a pre-configured hosted agent — they aren't
/// secrets the way API keys are, so unlike [AiKeyStore] this is plain JSON,
/// not encrypted.
class AiAgentStore {
  AiAgentStore._(this._file);
  final File _file;

  static AiAgentStore? _instance;

  static Future<AiAgentStore> load() async {
    if (_instance != null) return _instance!;
    final dir = await getApplicationSupportDirectory();
    final file =
        File('${dir.path}${Platform.pathSeparator}luma_ai_agents.json');
    return _instance = AiAgentStore._(file);
  }

  Future<Map<String, dynamic>> _readAll() async {
    if (!await _file.exists()) return {};
    try {
      final decoded = jsonDecode(await _file.readAsString());
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeAll(Map<String, dynamic> data) async {
    await _file.writeAsString(jsonEncode(data), flush: true);
  }

  Future<List<AgentProfile>> listProfiles(String providerId) async {
    final all = await _readAll();
    final entry = all[providerId] as Map<String, dynamic>?;
    final profiles = (entry?['profiles'] as List?) ?? const [];
    return profiles
        .cast<Map<String, dynamic>>()
        .map(AgentProfile.fromJson)
        .toList(growable: false);
  }

  /// The currently selected agent id for [providerId], or null if none is
  /// selected (meaning: use the provider's plain model, no hosted agent).
  Future<String?> activeAgentId(String providerId) async {
    final all = await _readAll();
    final entry = all[providerId] as Map<String, dynamic>?;
    return entry?['activeAgentId'] as String?;
  }

  Future<void> setActiveAgentId(String providerId, String? agentId) async {
    final all = await _readAll();
    final entry = Map<String, dynamic>.from(
        all[providerId] as Map<String, dynamic>? ?? {});
    entry['activeAgentId'] = agentId;
    all[providerId] = entry;
    await _writeAll(all);
  }

  Future<void> addProfile(String providerId, AgentProfile profile) async {
    final all = await _readAll();
    final entry = Map<String, dynamic>.from(
        all[providerId] as Map<String, dynamic>? ?? {});
    final profiles = ((entry['profiles'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .toList();
    profiles.removeWhere((p) => p['agentId'] == profile.agentId);
    profiles.add(profile.toJson());
    entry['profiles'] = profiles;
    all[providerId] = entry;
    await _writeAll(all);
  }

  Future<void> removeProfile(String providerId, String agentId) async {
    final all = await _readAll();
    final entry = all[providerId] as Map<String, dynamic>?;
    if (entry == null) return;
    final updated = Map<String, dynamic>.from(entry);
    final profiles = ((updated['profiles'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .where((p) => p['agentId'] != agentId)
        .toList();
    updated['profiles'] = profiles;
    if (updated['activeAgentId'] == agentId) updated['activeAgentId'] = null;
    all[providerId] = updated;
    await _writeAll(all);
  }
}
