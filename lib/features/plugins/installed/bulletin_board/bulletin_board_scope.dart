import 'package:flutter/widgets.dart';

import 'bulletin_board_repository.dart';

class BulletinBoardScope extends InheritedWidget {
  const BulletinBoardScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final BulletinBoardRepository repository;

  static BulletinBoardRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BulletinBoardScope>();
    assert(scope != null, 'BulletinBoardScope was not found in the widget tree');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(BulletinBoardScope oldWidget) =>
      oldWidget.repository != repository;
}
