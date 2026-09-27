import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/pet/pet_window_lifecycle.dart';

void main() {
  test('child dismissal releases both channel replies before closing', () async {
    var attached = true;
    var closed = false;
    final dismissalFinished = Completer<void>();

    final dismissal = dismissPetWindowFromChild(
      detachWindow: () => attached = false,
      dismissPet: () async {
        expect(attached, isFalse);
        dismissalFinished.complete();
      },
      closeWindow: () async => closed = true,
    );

    await dismissalFinished.future;
    await dismissal;
    expect(closed, isFalse);

    await Future<void>.delayed(Duration.zero);
    expect(closed, isTrue);
  });

  test('a close request replies before destroying its own engine', () async {
    var destroyed = false;
    closePetWindowAfterReply(() async => destroyed = true);
    expect(destroyed, isFalse);

    await Future<void>.delayed(Duration.zero);
    expect(destroyed, isTrue);
  });
}
