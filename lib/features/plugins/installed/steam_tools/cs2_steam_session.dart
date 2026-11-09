import 'cs2_inventory_api.dart';

/// A Steam Community session the user signed in to themselves, on Steam's
/// own page inside an embedded browser.
///
/// luma never sees the password or the session cookie: requests run inside
/// that browser, on steamcommunity.com, and only the response comes back.
/// Signed in as the inventory's owner, Steam lists trade-protected items
/// that the public listing leaves out.
abstract interface class Cs2SteamSession {
  /// The SteamID64 Steam reports for the signed-in account, or null when
  /// nobody is signed in.
  Future<String?> signedInSteamId();

  /// Fetches a steamcommunity.com URL with the session's cookies.
  Future<Cs2InventoryPage> load(Uri uri);

  /// Signs out of Steam in the embedded browser.
  Future<void> signOut();
}
