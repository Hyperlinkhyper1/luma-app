import 'dart:async';

Future<void> dismissPetWindowFromChild({
  required void Function() detachWindow,
  required Future<void> Function() dismissPet,
  required Future<void> Function() closeWindow,
}) async {
  // The repository notifies the shell synchronously when it is dismissed.
  // Detach first so that notification cannot close the child engine mid-call.
  detachWindow();
  try {
    await dismissPet();
  } finally {
    closePetWindowAfterReply(closeWindow);
  }
}

void closePetWindowAfterReply(Future<void> Function() closeWindow) {
  // Method-channel replies run in microtasks. A timer lets that reply leave
  // the engine before its window and messenger are destroyed.
  Timer.run(() => unawaited(closeWindow()));
}
