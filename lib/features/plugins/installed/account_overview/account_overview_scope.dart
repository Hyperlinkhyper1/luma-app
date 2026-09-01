import 'package:flutter/widgets.dart';

import 'account_overview_repository.dart';

/// Exposes the shared [AccountOverviewRepository] to the widget tree.
class AccountOverviewScope
    extends InheritedNotifier<AccountOverviewRepository> {
  const AccountOverviewScope({
    super.key,
    required AccountOverviewRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static AccountOverviewRepository of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AccountOverviewScope>();
    assert(scope != null, 'AccountOverviewScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
