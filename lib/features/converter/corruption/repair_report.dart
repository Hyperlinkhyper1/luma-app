import 'dart:typed_data';

/// How much weight to give one line of a repair report.
enum RepairSeverity { info, fixed, warning, failed }

class RepairNote {
  const RepairNote(this.severity, this.message);

  const RepairNote.info(this.message) : severity = RepairSeverity.info;
  const RepairNote.fixed(this.message) : severity = RepairSeverity.fixed;
  const RepairNote.warning(this.message) : severity = RepairSeverity.warning;
  const RepairNote.failed(this.message) : severity = RepairSeverity.failed;

  final RepairSeverity severity;
  final String message;
}

/// Collects notes while a repairer works, so each repairer can just narrate
/// what it did.
class RepairLog {
  final List<RepairNote> notes = [];

  void info(String message) => notes.add(RepairNote.info(message));
  void fixed(String message) => notes.add(RepairNote.fixed(message));
  void warning(String message) => notes.add(RepairNote.warning(message));
  void failed(String message) => notes.add(RepairNote.failed(message));

  bool get anyFailed =>
      notes.any((note) => note.severity == RepairSeverity.failed);
}

/// What came out of a repair attempt.
class RepairResult {
  const RepairResult({
    required this.bytes,
    required this.notes,
    required this.formatLabel,
    required this.suggestedName,
    required this.changed,
    required this.restoredExactly,
  });

  final Uint8List bytes;
  final List<RepairNote> notes;

  /// What the file turned out to actually be, as far as the repairer could
  /// tell.
  final String formatLabel;

  final String suggestedName;

  /// False when nothing needed doing, or nothing could be done.
  final bool changed;

  /// True only for a sidecar restore that matched the recorded checksum.
  final bool restoredExactly;

  int get fixCount =>
      notes.where((note) => note.severity == RepairSeverity.fixed).length;

  bool get hasWarnings => notes.any(
    (note) =>
        note.severity == RepairSeverity.warning ||
        note.severity == RepairSeverity.failed,
  );
}
