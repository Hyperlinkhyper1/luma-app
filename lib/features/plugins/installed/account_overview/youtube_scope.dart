import 'package:flutter/widgets.dart';

import 'youtube_repository.dart';

/// Exposes the shared [YoutubeRepository] to the widget tree.
class YoutubeScope extends InheritedNotifier<YoutubeRepository> {
  const YoutubeScope({
    super.key,
    required YoutubeRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static YoutubeRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<YoutubeScope>();
    assert(scope != null, 'YoutubeScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
