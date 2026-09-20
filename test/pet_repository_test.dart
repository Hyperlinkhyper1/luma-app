import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:luma/pet/pet_repository.dart';

void main() {
  group('toggle', () {
    test('opens, then closes once the debounce window has passed', () async {
      final pet = PetRepository();
      await pet.toggle();
      expect(pet.visible, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 400));
      await pet.toggle();
      expect(pet.visible, isFalse);
    });

    test('ignores a second fire inside the debounce window', () async {
      // The chord is registered twice on purpose — once with the OS, once
      // in-app so it still works when the OS refuses — and a held key
      // repeats. Without this guard the pet would open and shut again in the
      // same breath, which looks exactly like the hotkey doing nothing.
      final pet = PetRepository();
      await pet.toggle();
      await pet.toggle();
      await pet.toggle();

      expect(pet.visible, isTrue);
    });
  });

  group('the summon chord', () {
    test('defaults to Ctrl+Shift+Alt+Space', () {
      final pet = PetRepository();
      expect(
        pet.hotKey.modifiers,
        [
          HotKeyModifier.control,
          HotKeyModifier.shift,
          HotKeyModifier.alt,
        ],
      );
      expect(pet.hotKey.physicalKey, PhysicalKeyboardKey.space);
      expect(pet.hotKeyLabel, 'Ctrl + Shift + Alt + Space');
    });

    test('carries a modifier, which Windows requires to register at all', () {
      // A chord of two ordinary keys (W+Space) cannot be a global hotkey:
      // RegisterHotKey takes modifiers plus exactly one key.
      final pet = PetRepository();
      expect(pet.hotKey.modifiers, isNotEmpty);
    });
  });

  group('mood', () {
    test('is sleepy late at night and idle during the day', () {
      final pet = PetRepository();
      expect(pet.moodAt(DateTime(2026, 9, 20, 23, 30)), PetMood.sleepy);
      expect(pet.moodAt(DateTime(2026, 9, 20, 3, 0)), PetMood.sleepy);
      expect(pet.moodAt(DateTime(2026, 9, 20, 14, 0)), PetMood.idle);
    });

    test('is curious while something is being typed, even at night', () {
      final pet = PetRepository()..setQuery('fin');
      expect(pet.moodAt(DateTime(2026, 9, 20, 23, 30)), PetMood.curious);
    });

    test('a pat wins over everything, and a streak delights it', () {
      final pet = PetRepository()..setQuery('fin');
      pet.pat();
      expect(pet.mood, PetMood.happy);
      pet.pat();
      pet.pat();
      expect(pet.mood, PetMood.delighted);
      expect(pet.pats, 3);
    });
  });

  group('recents', () {
    test('most recent first, no duplicates', () async {
      final pet = PetRepository();
      await pet.recordOpen('a');
      await pet.recordOpen('b');
      await pet.recordOpen('a');

      expect(pet.recentIds, ['a', 'b']);
    });

    test('keeps only the last few', () async {
      final pet = PetRepository();
      for (var i = 0; i < kPetRecentLimit + 3; i++) {
        await pet.recordOpen('id$i');
      }

      expect(pet.recentIds, hasLength(kPetRecentLimit));
      expect(pet.recentIds.first, 'id${kPetRecentLimit + 2}');
    });
  });
}
