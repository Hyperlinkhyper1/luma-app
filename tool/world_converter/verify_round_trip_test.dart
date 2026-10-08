import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'verify_round_trip.dart' as verifier;

/// Runs [verifier.main] under `flutter test`, because the converter code it
/// drives reads its messages from the app's localizations, which need
/// `dart:ui` — something a plain `dart run` can't load. Arguments come from
/// `LUMA_WORLD_VERIFY_ARGS`, space-separated, exactly as the script takes them.
void main() {
  test('world converter round trip', () async {
    final args = (Platform.environment['LUMA_WORLD_VERIFY_ARGS'] ?? '')
        .split(' ')
        .where((a) => a.isNotEmpty)
        .toList();
    await verifier.main(args);
  }, timeout: Timeout.none);
}
