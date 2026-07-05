import 'package:flutter/widgets.dart';

import 'mood_journal_repository.dart';

class MoodJournalScope extends InheritedWidget {
  const MoodJournalScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final MoodJournalRepository repository;

  static MoodJournalRepository of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<MoodJournalScope>();
    assert(scope != null, 'MoodJournalScope was not found in the widget tree');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(MoodJournalScope oldWidget) =>
      oldWidget.repository != repository;
}
