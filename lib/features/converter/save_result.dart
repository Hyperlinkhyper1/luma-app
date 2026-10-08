import '../../l10n/current_l.dart';

/// Outcome of attempting to persist a converted image.
class SaveResult {
  const SaveResult({
    required this.saved,
    this.location,
    required this.summary,
  });

  /// False when the user cancelled the save/download dialog.
  final bool saved;

  /// On desktop, the absolute path the file was written to. Null on web.
  final String? location;

  /// Human-readable description of what happened.
  final String summary;

  factory SaveResult.cancelled() =>
      SaveResult(saved: false, summary: currentL.converterSaveCancelled);
}
