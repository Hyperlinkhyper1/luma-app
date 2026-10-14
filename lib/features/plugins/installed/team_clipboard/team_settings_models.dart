/// What a lead can let a member do, one by one or through a tag. A lead
/// always has every one. The names are the server's keys.
enum TeamPermission {
  markAdded,
  editAny,
  closeAny,
  removeAny,
  library,
  botSettings,
  botToken;

  static Set<TeamPermission> parseAll(Object? raw) => {
    if (raw is List)
      for (final p in raw) ?TeamPermission.values.asNameMap()[p],
  };
}

List<String> teamPermissionKeys(Set<TeamPermission> permissions) => [
  for (final p in TeamPermission.values)
    if (permissions.contains(p)) p.name,
];

/// A label a lead puts on team members, like "Modeller" or "Tester", with
/// the permissions everyone wearing it gets. [color] picks from the app's
/// tag palette. A tag not saved yet has a null [id].
class TeamTag {
  const TeamTag({
    this.id,
    required this.name,
    this.color = 0,
    this.permissions = const {},
  });

  final String? id;
  final String name;
  final int color;
  final Set<TeamPermission> permissions;

  TeamTag copyWith({
    String? name,
    int? color,
    Set<TeamPermission>? permissions,
  }) => TeamTag(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
    permissions: permissions ?? this.permissions,
  );

  factory TeamTag.fromJson(Map<String, dynamic> j) => TeamTag(
    id: j['id'] as String?,
    name: j['name'] as String? ?? '',
    color: j['color'] as int? ?? 0,
    permissions: TeamPermission.parseAll(j['permissions']),
  );

  Map<String, dynamic> toJson() => {
    'id': ?id,
    'name': name,
    'color': color,
    'permissions': teamPermissionKeys(permissions),
  };
}

/// One teammate as the Settings tab shows them: what they were given
/// directly, which tags they wear, and everything that adds up to.
class TeamMemberAccess {
  const TeamMemberAccess({
    required this.id,
    required this.name,
    required this.email,
    required this.lead,
    this.permissions = const {},
    this.tags = const [],
    this.effective = const {},
  });

  final String id;
  final String name;
  final String email;
  final bool lead;
  final Set<TeamPermission> permissions;

  /// Tag ids, in the team's tag order.
  final List<String> tags;
  final Set<TeamPermission> effective;

  factory TeamMemberAccess.fromJson(Map<String, dynamic> j) => TeamMemberAccess(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    email: j['email'] as String? ?? '',
    lead: j['role'] == 'lead',
    permissions: TeamPermission.parseAll(j['permissions']),
    tags: [for (final t in j['tags'] as List? ?? const []) t as String],
    effective: TeamPermission.parseAll(j['effective']),
  );
}

/// What a lead's Settings tab works on: the team's tags and every member.
class TeamSettings {
  const TeamSettings({required this.tags, required this.members});

  final List<TeamTag> tags;
  final List<TeamMemberAccess> members;

  TeamTag? tag(String id) => tags.where((t) => t.id == id).firstOrNull;

  /// The members wearing tag [id].
  int wearing(String id) => members.where((m) => m.tags.contains(id)).length;

  factory TeamSettings.fromJson(Map<String, dynamic> j) => TeamSettings(
    tags: [
      for (final t in j['tags'] as List? ?? const [])
        TeamTag.fromJson(t as Map<String, dynamic>),
    ],
    members: [
      for (final m in j['members'] as List? ?? const [])
        TeamMemberAccess.fromJson(m as Map<String, dynamic>),
    ],
  );
}
