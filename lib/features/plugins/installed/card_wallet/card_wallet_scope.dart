import 'package:flutter/widgets.dart';

import 'card_wallet_repository.dart';

/// Provides the shared [CardWalletRepository] to the Card Wallet plugin.
class CardWalletScope extends InheritedWidget {
  const CardWalletScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final CardWalletRepository repository;

  static CardWalletRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CardWalletScope>();
    assert(scope != null, 'CardWalletScope was not found in the widget tree');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(CardWalletScope oldWidget) =>
      oldWidget.repository != repository;
}
