import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/sftp/file_times.dart';

/// The dates a transfer carries with a file, and how they are stamped back
/// onto the copy.
void main() {
  test('survive the wire unchanged', () {
    final times = FileTimes(
      modified: DateTime(2024, 3, 1, 9, 15),
      accessed: DateTime(2024, 3, 2),
      created: DateTime(2024, 2, 28, 23, 59),
    );
    final back = FileTimes.fromWire(times.toWire());
    expect(back.modified, times.modified);
    expect(back.accessed, times.accessed);
    expect(back.created, times.created);
  });

  test('ignore missing, malformed and absurd dates', () {
    expect(FileTimes.fromWire(null).isEmpty, isTrue);
    expect(FileTimes.fromWire('nope').isEmpty, isTrue);
    final far = DateTime.now().add(const Duration(days: 400));
    final times = FileTimes.fromWire({
      'm': 'yesterday',
      'a': DateTime(1970, 1, 2).millisecondsSinceEpoch,
      'c': far.millisecondsSinceEpoch,
    });
    expect(times.isEmpty, isTrue);
  });

  test('a copy without a known creation time is created when it was modified',
      () async {
    final dir = await Directory.systemTemp.createTemp('luma_file_times');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}clip.mp4')
      ..writeAsBytesSync(const [1, 2, 3]);
    // What a phone or an SFTP server sends: a modified time and nothing else.
    final recorded = DateTime(2023, 12, 24, 18);
    await FileTimes(modified: recorded).applyTo(file);

    final stat = file.statSync();
    expect(stat.modified, recorded);
    if (Platform.isWindows) expect(stat.changed, recorded);
  });

  test('a file that is not there is left alone', () async {
    final missing = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}luma_no_such_file',
    );
    expect((await FileTimes.of(missing)).isEmpty, isTrue);
    await FileTimes(modified: DateTime(2022)).applyTo(missing);
    expect(missing.existsSync(), isFalse);
  });
}
