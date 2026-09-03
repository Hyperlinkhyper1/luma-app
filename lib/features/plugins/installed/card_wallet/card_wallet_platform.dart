import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Where a wallet card may be captured. Adding a card means holding it to a
/// camera or an NFC reader, and only the phone builds have either, so Windows,
/// macOS and Linux keep the wallet read-only: cards are made on the phone and
/// arrive on the desktop through the `card_wallet` sync collection.
class CardWalletPlatform {
  const CardWalletPlatform._();

  /// Whether this build can create or edit cards.
  static bool get canManageCards =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Shown wherever the desktop hides an editing affordance.
  static const String readOnlyNotice =
      'Cards are added on your phone, where the camera and NFC reader are. '
      'Turn on Card wallet sync and they show up here to view and present.';
}
