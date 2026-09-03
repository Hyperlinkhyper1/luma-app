import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'gallery_media.dart';

/// A run of photos taken close together over more than a single sitting — a
/// weekend away, a week's holiday. Built from nothing but timestamps: no
/// model, no location, no Nova requirement. Every photo the gallery has
/// already carries a date, so this works for every device on day one.
@immutable
class GalleryMemory {
  const GalleryMemory({
    required this.id,
    required this.label,
    required this.items,
    required this.cover,
  });

  /// Derived from the start date, stable across rebuilds of the same trip.
  final String id;

  /// The date range, e.g. "31 Jul – 3 Aug 2026".
  final String label;

  /// In the order the trip happened — oldest first. Every other album in the
  /// gallery is newest-first because that matches how you look for a single
  /// recent photo; a memory is the opposite kind of browsing, reliving an
  /// event from its start, so it keeps its own chronology.
  final List<GalleryItem> items;

  /// The photo from roughly the middle of the trip. The first photo of a
  /// holiday is disproportionately likely to be "locking the front door" or
  /// "boarding the plane" — not what anyone would pick to represent it.
  final GalleryItem cover;

  int get count => items.length;
}

/// How long a gap between photos ends one memory and starts looking for the
/// next. Long enough that a photo taken the morning after a late night out
/// still counts as the same occasion.
const kMemoryMaxGap = Duration(hours: 36);

/// A run has to clear three floors to be a "memory" rather than ordinary use:
/// enough photos that flicking through it feels like something, enough date
/// span that it wasn't one sitting, and enough *density* that it reads as an
/// event rather than routine daily use.
///
/// Density is the one easy to miss: a gap-based rule alone means someone who
/// takes one photo every single day, with the gap never once crossing
/// [kMemoryMaxGap], would glom their entire year into a single "memory" —
/// there is never a pause big enough to split it, even though nothing about
/// it resembles a trip. Requiring a minimum rate of photos per day catches
/// that: a real trip runs several photos a day, not one.
const kMemoryMinItems = 12;
const kMemoryMinSpan = Duration(hours: 20);
const kMemoryMinDensity = 3.0;

/// Groups [items] into memories. [items] is left untouched; the result's
/// outer list is newest-trip-first, matching every other list in the
/// gallery, while each memory's own [GalleryMemory.items] runs oldest first.
List<GalleryMemory> buildMemories(
  List<GalleryItem> items, {
  int minItems = kMemoryMinItems,
  Duration maxGap = kMemoryMaxGap,
  Duration minSpan = kMemoryMinSpan,
  double minDensity = kMemoryMinDensity,
}) {
  if (items.isEmpty) return const [];

  final chronological = List<GalleryItem>.of(items)
    ..sort((a, b) => a.takenAt.compareTo(b.takenAt));

  final memories = <GalleryMemory>[];
  var bucket = <GalleryItem>[chronological.first];

  void closeBucket() {
    if (bucket.length < minItems) return;
    final span = bucket.last.takenAt.difference(bucket.first.takenAt);
    if (span < minSpan) return;
    final days = math.max(span.inMinutes / (24 * 60), 1 / 24);
    if (bucket.length / days < minDensity) return;
    memories.add(GalleryMemory(
      id: 'memory:${bucket.first.takenAt.toIso8601String()}',
      label: _formatRange(bucket.first.takenAt, bucket.last.takenAt),
      items: List.unmodifiable(bucket),
      cover: bucket[bucket.length ~/ 2],
    ));
  }

  for (var i = 1; i < chronological.length; i++) {
    final item = chronological[i];
    final gap = item.takenAt.difference(chronological[i - 1].takenAt);
    if (gap > maxGap) {
      closeBucket();
      bucket = [];
    }
    bucket.add(item);
  }
  closeBucket();

  return memories.reversed.toList();
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatRange(DateTime start, DateTime end) {
  final sameYear = start.year == end.year;
  final sameMonth = sameYear && start.month == end.month;
  final startStr = sameMonth
      ? '${start.day}'
      : '${start.day} ${_months[start.month - 1]}'
          '${sameYear ? '' : ' ${start.year}'}';
  final endStr = '${end.day} ${_months[end.month - 1]} ${end.year}';
  return '$startStr – $endStr';
}
