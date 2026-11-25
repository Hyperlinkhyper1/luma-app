import 'dart:convert';
import 'dart:io';

import 'package:cs2_dataset/cs2_dataset.dart';

import 'util.dart';

class Cs2DatasetStore {
  Cs2DatasetStore(String root) : _file = File('$root/cs2-datasets.json') {
    if (!_file.existsSync()) return;
    final json = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
    _staged = (json['staged'] as List)
        .map((entry) => (
              match: Cs2Match.fromJson(entry as Map<String, dynamic>),
              digest: entry['digest'] as String?,
            ))
        .toList();
    _published = Cs2Dataset.fromJson(json['published'] as Map<String, dynamic>);
    _publishedAt = json['publishedAt'] as String?;
  }

  static const maxCases = 250000;
  final File _file;
  final _lock = AsyncLock();
  var _staged = <({Cs2Match match, String? digest})>[];
  var _published = Cs2Dataset.empty();
  String? _publishedAt;

  Cs2Dataset get published => _published;

  Map<String, Object?> get status {
    final counts = <String, int>{};
    var total = 0;
    for (final entry in _staged) {
      final match = entry.match;
      final rounds = match.roundCount;
      counts.update(match.map, (value) => value + rounds,
          ifAbsent: () => rounds);
      total += rounds;
    }
    return {
      'staged': total,
      'published': _published.roundCount,
      'publishedAt': _publishedAt,
      'maps': [
        for (final id in (counts.keys.toList()..sort()))
          {
            'id': id,
            'name': cs2MapName(id),
            'staged': counts[id],
            'published': _published.predict(id).sampleSize,
          },
      ],
    };
  }

  Future<void> stage(Cs2Match match, {String? digest}) =>
      _lock.synchronized(() async {
        if (digest != null && _staged.any((entry) => entry.digest == digest)) {
          throw const FormatException('This replay has already been staged.');
        }
        final total =
            _staged.fold(0, (sum, entry) => sum + entry.match.roundCount);
        if (total + match.roundCount > maxCases) {
          throw const FormatException('The staged round limit was reached.');
        }
        final staged = [..._staged, (match: match, digest: digest)];
        await _save(staged, _published, _publishedAt);
        _staged = staged;
      });

  Future<void> publish(int count) => _lock.synchronized(() async {
        if (count < 1 || count > maxCases) {
          throw const FormatException('Enter a valid number of rounds.');
        }
        final compiled = Cs2Dataset.empty();
        var remaining = count;
        for (final entry in _staged.reversed) {
          final rounds = entry.match.roundCount;
          compiled.add(entry.match,
              skip: rounds > remaining ? rounds - remaining : 0);
          remaining -= rounds;
          if (remaining <= 0) break;
        }
        if (remaining > 0) {
          throw const FormatException(
              'There are fewer staged rounds than requested.');
        }
        final publishedAt = DateTime.now().toUtc().toIso8601String();
        await _save(_staged, compiled, publishedAt);
        _published = compiled;
        _publishedAt = publishedAt;
      });

  Future<void> _save(
    List<({Cs2Match match, String? digest})> staged,
    Cs2Dataset published,
    String? publishedAt,
  ) =>
      atomicWriteString(
          _file.path,
          jsonEncode({
            'staged': [
              for (final entry in staged)
                {
                  ...entry.match.toJson(),
                  if (entry.digest != null) 'digest': entry.digest,
                },
            ],
            'published': published.toJson(),
            'publishedAt': publishedAt,
          }));
}
