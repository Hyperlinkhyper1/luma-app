import 'package:flutter/widgets.dart';

import 'spotify_repository.dart';

class SpotifyScope extends InheritedNotifier<SpotifyRepository> {
  const SpotifyScope({
    super.key,
    required SpotifyRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static SpotifyRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SpotifyScope>();
    assert(scope != null, 'SpotifyScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
