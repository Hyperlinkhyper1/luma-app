Future<void> dismissPetWindowFromChild({
  required void Function() markHidden,
  required Future<void> Function() dismissPet,
  required Future<void> Function() hideWindow,
}) async {
  // Keep the controller for the next summon, but prevent the repository's
  // synchronous notification from issuing a second hide request.
  markHidden();
  try {
    await dismissPet();
  } finally {
    await hideWindow();
  }
}
