import 'package:flutter_test/flutter_test.dart';
import 'package:luma/pet/pet_window_lifecycle.dart';

void main() {
  test('child dismissal marks hidden before updating state', () async {
    var visible = true;
    var hidden = false;

    await dismissPetWindowFromChild(
      markHidden: () => visible = false,
      dismissPet: () async {
        expect(visible, isFalse);
        expect(hidden, isFalse);
      },
      hideWindow: () async => hidden = true,
    );

    expect(hidden, isTrue);
  });

  test('child window hides even when its state update throws', () async {
    var hidden = false;

    await expectLater(
      dismissPetWindowFromChild(
        markHidden: () {},
        dismissPet: () async => throw StateError('dismiss failed'),
        hideWindow: () async => hidden = true,
      ),
      throwsStateError,
    );
    expect(hidden, isTrue);
  });
}
