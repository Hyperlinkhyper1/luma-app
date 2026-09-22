import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_workbench_models.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_workbench_repository.dart';

void main() {
  late Directory directory;
  late AiWorkbenchRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('luma_ai_workbench_');
    repository = AiWorkbenchRepository(
      supportDirectoryProvider: () async => directory,
    );
    await repository.ready;
  });

  tearDown(() async {
    repository.dispose();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('persists Markdown notes and agents locally', () async {
    await repository.saveMarkdown(
      title: 'Flutter conventions',
      body: '# Rules\n\nPrefer const widgets.',
      tags: ['flutter', 'project'],
    );
    final note = repository.markdownEntries.single;

    await repository.saveAgent(
      name: 'Code reviewer',
      description: 'Reviews Flutter changes.',
      instructions: 'Find correctness and maintainability issues.',
      outputFormat: 'Use severity headings.',
      libraryEntryIds: [note.id],
      preferredModel: 'gpt-5.6-terra',
    );

    final restored = AiWorkbenchRepository(
      supportDirectoryProvider: () async => directory,
    );
    await restored.ready;
    addTearDown(restored.dispose);

    expect(restored.markdownEntries.single.title, 'Flutter conventions');
    expect(restored.markdownEntries.single.tags, ['flutter', 'project']);
    expect(restored.agents.single.name, 'Code reviewer');
    expect(restored.agents.single.libraryEntryIds, [note.id]);
  });

  test('renders a self-contained Codex skill', () async {
    await repository.saveMarkdown(
      title: 'Project context',
      body: 'This project uses the Scope pattern.',
    );
    final note = repository.markdownEntries.single;
    final agent = AiAgentDefinition(
      id: 'reviewer',
      name: 'Flutter Code Reviewer',
      description: 'Reviews Flutter code safely.',
      instructions: 'Inspect code and report actionable findings.',
      outputFormat: 'Group findings by severity.',
      libraryEntryIds: [note.id],
      preferredModel: '',
      updatedAt: DateTime(2026),
    );

    final skill = repository.codexSkill(agent);

    expect(skill, startsWith('---\nname: flutter-code-reviewer\n'));
    expect(skill, contains('Inspect code and report actionable findings.'));
    expect(skill, contains('### Project context'));
    expect(skill, contains('This project uses the Scope pattern.'));
  });

  test('creates stable Codex slugs', () {
    expect(
      AiWorkbenchRepository.slugFor('Flutter Code Reviewer'),
      'flutter-code-reviewer',
    );
    expect(AiWorkbenchRepository.slugFor('  '), 'luma-agent');
  });
}
