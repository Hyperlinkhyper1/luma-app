import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/chat/memory/assistant_memory_repository.dart';
import 'package:luma/sync/sync_state.dart';

void main() {
  late Directory directory;
  late AssistantMemoryRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('luma_assistant_memory_');
    repository = AssistantMemoryRepository(
      supportDirectoryProvider: () async => directory,
    );
    await repository.ready;
  });

  tearDown(() async {
    repository.dispose();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('remember appends facts to one page per title, without repeats',
      () async {
    await repository.remember(
      section: MemorySection.topics,
      title: 'Hardware',
      fact: 'Has an RTX 4070',
      description: "The user's PC hardware",
    );
    await repository.remember(
      section: MemorySection.topics,
      title: 'hardware',
      fact: 'Runs Windows 11',
    );
    await repository.remember(
      section: MemorySection.topics,
      title: 'Hardware',
      fact: 'has an rtx 4070',
    );

    final entry = repository.entries.single;
    expect(entry.title, 'Hardware');
    expect(entry.description, "The user's PC hardware");
    expect(entry.body, 'Has an RTX 4070\nRuns Windows 11');
  });

  test('persists across reloads and round-trips through sync', () async {
    await repository.saveEntry(
      section: MemorySection.you,
      title: 'Profile',
      description: 'Who the user is',
      body: 'Student and indie mod developer',
    );
    await repository.setProfile(
      const AssistantUserProfile(callMe: 'Ayden', instructions: 'Be brief'),
    );
    await repository.setLanguageCode('nl');
    await repository.setFont(ChatFont.mono);
    await repository.setTextSize(ChatTextSize.large);

    final reloaded = AssistantMemoryRepository(
      supportDirectoryProvider: () async => directory,
    );
    await reloaded.ready;
    expect(reloaded.entries.single.title, 'Profile');
    expect(reloaded.profile.callMe, 'Ayden');
    expect(reloaded.languageCode, 'nl');
    expect(reloaded.font, ChatFont.mono);
    expect(reloaded.textSize, ChatTextSize.large);

    final other = await Directory.systemTemp.createTemp('luma_memory_peer_');
    final peer = AssistantMemoryRepository(
      supportDirectoryProvider: () async => other,
    );
    await peer.importData(await repository.exportData());
    expect(peer.entriesIn(MemorySection.you).single.body,
        'Student and indie mod developer');
    expect(peer.profile.instructions, 'Be brief');
    reloaded.dispose();
    peer.dispose();
    await other.delete(recursive: true);
  });

  test('prompt context carries language, profile and memory', () async {
    expect(repository.promptContext(), contains('remember tool'));

    await repository.setLanguageCode('fr');
    await repository.setProfile(const AssistantUserProfile(callMe: 'Ayden'));
    await repository.saveEntry(
      section: MemorySection.topics,
      title: 'Gaming',
      body: 'Plays Minecraft',
    );
    final prompt = repository.promptContext();
    expect(prompt, contains('Always reply in French'));
    expect(prompt, contains('Call them: Ayden'));
    expect(prompt, contains('## Gaming\nPlays Minecraft'));

    await repository.setMemoryEnabled(false);
    final off = repository.promptContext();
    expect(off, isNot(contains('Plays Minecraft')));
    expect(off, isNot(contains('remember tool')));
    expect(off, contains('Call them: Ayden'));
  });

  test('prompt memory is capped so it cannot crowd the context', () async {
    for (var i = 0; i < 40; i++) {
      await repository.saveEntry(
        section: MemorySection.areas,
        title: 'Project $i',
        body: 'x' * 400,
      );
    }
    expect(
      repository.promptContext().length,
      lessThan(AssistantMemoryRepository.maxPromptMemoryChars + 1000),
    );
  });

  test('memory syncs automatically on every plan', () {
    expect(isAutomaticSyncCollection(kAssistantMemoryCollectionId), isTrue);
  });
}
