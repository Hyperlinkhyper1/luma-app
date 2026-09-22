/// A reusable Markdown note in the AI Workbench library.
class AiMarkdownEntry {
  AiMarkdownEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
  });

  factory AiMarkdownEntry.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return AiMarkdownEntry(
      id: json['id']?.toString() ?? now.microsecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? 'Untitled note',
      body: json['body']?.toString() ?? '',
      tags: [
        for (final tag in (json['tags'] as List<dynamic>?) ?? const [])
          tag.toString(),
      ],
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? now,
    );
  }

  final String id;
  final String title;
  final String body;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'tags': tags,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// A reusable specialist definition that can be run in Luma's assistant or
/// exported as a Codex skill.
class AiAgentDefinition {
  AiAgentDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.instructions,
    required this.outputFormat,
    required this.updatedAt,
    this.libraryEntryIds = const [],
    this.preferredModel = '',
  });

  factory AiAgentDefinition.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return AiAgentDefinition(
      id: json['id']?.toString() ?? now.microsecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? 'Untitled agent',
      description: json['description']?.toString() ?? '',
      instructions: json['instructions']?.toString() ?? '',
      outputFormat: json['outputFormat']?.toString() ?? '',
      preferredModel: json['preferredModel']?.toString() ?? '',
      libraryEntryIds: [
        for (final id
            in (json['libraryEntryIds'] as List<dynamic>?) ?? const [])
          id.toString(),
      ],
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? now,
    );
  }

  final String id;
  final String name;
  final String description;
  final String instructions;
  final String outputFormat;
  final List<String> libraryEntryIds;
  final String preferredModel;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'instructions': instructions,
    'outputFormat': outputFormat,
    'libraryEntryIds': libraryEntryIds,
    'preferredModel': preferredModel,
    'updatedAt': updatedAt.toIso8601String(),
  };
}
