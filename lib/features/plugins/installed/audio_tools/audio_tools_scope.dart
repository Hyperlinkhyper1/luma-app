import 'package:flutter/widgets.dart';

import 'audio_tools_repository.dart';

/// Exposes the app-wide [AudioToolsRepository] to the widget tree.
class AudioToolsScope extends InheritedNotifier<AudioToolsRepository> {
  const AudioToolsScope({
    super.key,
    required AudioToolsRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static AudioToolsRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AudioToolsScope>();
    assert(scope != null, 'AudioToolsScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
