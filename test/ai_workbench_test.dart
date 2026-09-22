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

  test('renders Claude Code and opencode subagents', () {
    AiAgentDefinition agent(String model) => AiAgentDefinition(
      id: 'reviewer',
      name: 'Flutter Code Reviewer',
      description: 'Reviews Flutter code safely.',
      instructions: 'Inspect code and report actionable findings.',
      outputFormat: '',
      preferredModel: model,
      updatedAt: DateTime(2026),
    );

    final claude = repository.claudeCodeAgent(agent('sonnet'));
    expect(claude, startsWith('---\nname: flutter-code-reviewer\n'));
    expect(claude, contains('model: "sonnet"'));
    expect(claude, contains('Inspect code and report actionable findings.'));

    final opencode = repository.opencodeAgent(
      agent('anthropic/claude-sonnet-5'),
    );
    expect(opencode, contains('mode: subagent'));
    expect(opencode, contains('model: "anthropic/claude-sonnet-5"'));
    expect(opencode, isNot(contains('name:')));

    // opencode rejects a bare model id, so it stays out of the frontmatter.
    final bare = repository.opencodeAgent(agent('sonnet'));
    expect(bare, isNot(contains('model:')));
    expect(bare, contains('## Preferred model'));

    expect(
      AiWorkbenchRepository.projectPathFor(
        agent(''),
        AiAgentTarget.claudeCode,
      ),
      ['.claude', 'agents', 'flutter-code-reviewer.md'],
    );
    expect(
      AiWorkbenchRepository.projectPathFor(agent(''), AiAgentTarget.opencode),
      ['.opencode', 'agents', 'flutter-code-reviewer.md'],
    );
    expect(
      AiWorkbenchRepository.projectPathFor(agent(''), AiAgentTarget.codex),
      ['.agents', 'skills', 'flutter-code-reviewer', 'SKILL.md'],
    );
  });

  test('installs an agent where each tool looks for it', () async {
    final agent = AiAgentDefinition(
      id: 'a',
      name: 'Doc Writer',
      description: 'Writes docs.',
      instructions: 'Write clear docs.',
      outputFormat: '',
      updatedAt: DateTime(2026),
    );
    for (final target in AiAgentTarget.values) {
      final path = await repository.installAgent(
        agent,
        directory.path,
        target,
      );
      expect(await File(path).readAsString(), contains('Write clear docs.'));
    }
    expect(
      await File(
        '${directory.path}/.claude/agents/doc-writer.md',
      ).exists(),
      isTrue,
    );
  });

  test('exports and imports the library and agents for sync', () async {
    await repository.saveMarkdown(title: 'Context', body: 'Body');
    await repository.saveAgent(
      name: 'Helper',
      description: '',
      instructions: 'Help.',
      outputFormat: '',
      libraryEntryIds: [repository.markdownEntries.single.id],
      preferredModel: '',
    );
    final snapshot = await repository.exportData();

    final other = await Directory.systemTemp.createTemp('luma_ai_wb_other_');
    addTearDown(() => other.delete(recursive: true));
    final device = AiWorkbenchRepository(
      supportDirectoryProvider: () async => other,
    );
    addTearDown(device.dispose);
    await device.importData(snapshot);

    expect(device.markdownEntries.single.title, 'Context');
    expect(device.agents.single.name, 'Helper');

    final reloaded = AiWorkbenchRepository(
      supportDirectoryProvider: () async => other,
    );
    addTearDown(reloaded.dispose);
    await reloaded.ready;
    expect(reloaded.agents.single.libraryEntryIds, hasLength(1));
  });

  test('creates stable Codex slugs', () {
    expect(
      AiWorkbenchRepository.slugFor('Flutter Code Reviewer'),
      'flutter-code-reviewer',
    );
    expect(AiWorkbenchRepository.slugFor('  '), 'luma-agent');
  });
}
