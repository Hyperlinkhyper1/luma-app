import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/pet/pet_search.dart';

PetTarget _target(String label, {String? id, List<String> keywords = const []}) =>
    PetTarget(
      id: id ?? label.toLowerCase(),
      label: label,
      icon: Icons.circle,
      kind: PetTargetKind.plugin,
      keywords: keywords,
      open: () {},
    );

List<String> _labels(List<PetTarget> targets) =>
    [for (final t in targets) t.label];

void main() {
  group('scorePetLabel', () {
    test('ranks the tiers in order: exact, prefix, word start, contains', () {
      final exact = scorePetLabel('notes', 'notes')!;
      final prefix = scorePetLabel('notes plugin', 'notes')!;
      final wordStart = scorePetLabel('my notes', 'notes')!;
      final contains = scorePetLabel('endnotes', 'notes')!;
      expect(exact, greaterThan(prefix));
      expect(prefix, greaterThan(wordStart));
      expect(wordStart, greaterThan(contains));
    });

    test('prefers the shorter label inside a tier', () {
      expect(
        scorePetLabel('notes', 'note')!,
        greaterThan(scorePetLabel('note taking', 'note')!),
      );
    });

    test('matches a subsequence, below every literal tier', () {
      final subsequence = scorePetLabel('mind map', 'mnmp')!;
      expect(subsequence, lessThan(scorePetLabel('a mind map', 'mind')!));
      expect(scorePetLabel('mind map', 'zzz'), isNull);
    });

    test('scores a tighter subsequence higher than a scattered one', () {
      expect(
        scorePetLabel('mindmap', 'mind')!,
        greaterThan(scorePetLabel('m i n d', 'mind')!),
      );
    });

    test('an empty query matches everything equally', () {
      expect(scorePetLabel('anything', ''), 0);
    });
  });

  group('rankPetTargets', () {
    final targets = [
      _target('Home'),
      _target('Finance', keywords: ['money']),
      _target('Notes'),
      _target('Mind Map'),
      _target('Whiteboard'),
    ];

    test('with no query, recents come first in order', () {
      final ranked = rankPetTargets(
        targets,
        '',
        recentIds: const ['mind map', 'notes'],
      );
      expect(_labels(ranked).take(2), ['Mind Map', 'Notes']);
      // Everything else keeps its natural order behind them.
      expect(_labels(ranked).skip(2), ['Home', 'Finance', 'Whiteboard']);
    });

    test('with no query and no recents, nothing is reordered', () {
      expect(_labels(rankPetTargets(targets, '')), _labels(targets));
    });

    test('drops everything that does not match', () {
      expect(_labels(rankPetTargets(targets, 'note')), ['Notes']);
    });

    test('a hidden keyword matches but ranks below a real label match', () {
      final ranked = rankPetTargets([
        _target('Finance', id: 'finance', keywords: ['money']),
        _target('Money jar', id: 'jar'),
      ], 'money');
      expect(_labels(ranked), ['Money jar', 'Finance']);
    });

    test('recents break ties between equally good matches', () {
      final ranked = rankPetTargets(
        [_target('Notes A', id: 'a'), _target('Notes B', id: 'b')],
        'notes',
        recentIds: const ['b'],
      );
      expect(_labels(ranked), ['Notes B', 'Notes A']);
    });

    test('ignores case and surrounding whitespace', () {
      expect(_labels(rankPetTargets(targets, '  MIND  ')), ['Mind Map']);
    });
  });
}
