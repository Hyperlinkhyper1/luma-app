import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_media.dart';
import 'package:luma/features/plugins/installed/gallery/gallery_memories.dart';

GalleryItem _at(DateTime when, [String name = 'a.jpg']) => GalleryItem(
      id: '$name@${when.microsecondsSinceEpoch}',
      name: name,
      type: GalleryMediaType.image,
      folder: 'DCIM/Camera',
      takenAt: when,
    );

/// [count] photos three hours apart, starting at [start] — dense enough to
/// read as an event, spread out enough to clear the minimum span.
List<GalleryItem> _burst(DateTime start, int count) => [
      for (var i = 0; i < count; i++)
        _at(start.add(Duration(hours: i * 3)), 'p$i.jpg'),
    ];

/// One photo per day for [count] days — ordinary use, never dense enough to
/// be a trip.
List<GalleryItem> _trickle(DateTime start, int count) => [
      for (var i = 0; i < count; i++)
        _at(start.add(Duration(days: i)), 'd$i.jpg'),
    ];

void main() {
  test('a busy single day is not a memory', () {
    // Twenty photos in one afternoon is a lot for a phone, not a trip: the
    // span floor is what tells these apart. Half-hour spacing keeps the
    // whole run inside one 9.5-hour afternoon.
    final items = [
      for (var i = 0; i < 20; i++)
        _at(DateTime(2026, 7, 1, 9).add(Duration(minutes: i * 30)), 'p$i.jpg'),
    ];
    expect(buildMemories(items), isEmpty);
  });

  test('a four-day holiday with enough photos is a memory', () {
    final items = [
      for (var day = 0; day < 4; day++)
        ..._burst(DateTime(2026, 7, 10 + day, 9), 5),
    ];
    final memories = buildMemories(items);
    expect(memories, hasLength(1));
    expect(memories.single.count, 20);
  });

  test('a long weekend with few photos does not qualify', () {
    // Enough span, not enough photos.
    final items = [
      _at(DateTime(2026, 7, 10, 9)),
      _at(DateTime(2026, 7, 11, 9)),
      _at(DateTime(2026, 7, 12, 9)),
    ];
    expect(buildMemories(items, minItems: 12), isEmpty);
  });

  test('a gap longer than the threshold splits one trip into two', () {
    final firstTrip = _burst(DateTime(2026, 6, 1, 9), 15);
    final secondTrip = _burst(DateTime(2026, 7, 1, 9), 15);
    final memories = buildMemories([...firstTrip, ...secondTrip]);
    expect(memories, hasLength(2));
  });

  test('one photo a day for two months is routine use, not a trip', () {
    // Never a gap over the threshold — a purely gap-based rule would glom
    // the whole stretch into one 60-day "memory". Density is what stops it:
    // a photo a day is ordinary life, not an event.
    final items = _trickle(DateTime(2026, 1, 1), 60);
    expect(buildMemories(items), isEmpty);
  });

  test('memories come back newest trip first', () {
    final older = _burst(DateTime(2025, 3, 1, 9), 15);
    final newer = _burst(DateTime(2026, 8, 1, 9), 15);
    final memories = buildMemories([...older, ...newer]);
    expect(memories.first.items.first.takenAt.year, 2026);
    expect(memories.last.items.first.takenAt.year, 2025);
  });

  test('inside a memory, photos run oldest to newest', () {
    // The whole point is reliving a trip from its start — the opposite
    // ordering to every other album in the app.
    final items = _burst(DateTime(2026, 7, 10, 9), 15);
    final memory = buildMemories(items).single;
    for (var i = 1; i < memory.items.length; i++) {
      expect(
        memory.items[i].takenAt.isAfter(memory.items[i - 1].takenAt),
        isTrue,
      );
    }
  });

  test('the cover is a photo from the middle, not the very first', () {
    final items = _burst(DateTime(2026, 7, 10, 9), 15);
    final memory = buildMemories(items).single;
    expect(memory.cover, isNot(memory.items.first));
    expect(memory.cover, isNot(memory.items.last));
  });

  test('the label reads as a date range', () {
    final items = _burst(DateTime(2026, 7, 10, 9), 20);
    final memory = buildMemories(items).single;
    expect(memory.label, contains('10'));
    expect(memory.label, contains('Jul'));
  });

  test('a trip crossing a year boundary shows both years', () {
    // One continuous run, not two: it has to stay under maxGap the whole
    // way through, or it splits into two too-small buckets either side of
    // the boundary and disappears rather than testing what its name says.
    final items = _burst(DateTime(2025, 12, 30, 9), 16);
    final memory = buildMemories(items).single;
    expect(memory.label, contains('2025'));
    expect(memory.label, contains('2026'));
  });

  test('an empty library produces no memories', () {
    expect(buildMemories(const []), isEmpty);
  });

  test('the input list is not mutated', () {
    final items = _burst(DateTime(2026, 7, 10, 9), 5);
    final originalOrder = List.of(items);
    buildMemories(items);
    expect(items, orderedEquals(originalOrder));
  });
}
