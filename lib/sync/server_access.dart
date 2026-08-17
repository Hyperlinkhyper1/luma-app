import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Thrown when something tries to reach a luma server while this device has
/// no approved account. `toString()` is already user-facing.
class ServerAccessDeniedException implements Exception {
  const ServerAccessDeniedException([this.message = _defaultMessage]);

  static const _defaultMessage =
      'This needs an approved luma account. Create one under '
      'Settings → Sync & account, confirm the link in your email, then sign in.';

  final String message;

  @override
  String toString() => message;
}

/// The one gate that decides whether this device may talk to a luma server.
///
/// It starts **closed** on every fresh install: until the user has created an
/// account *and* that account has been approved (email verified, or approved
/// by the operator from the admin dashboard), nothing in the app reaches the
/// server — not sync, not the plugins that need it, not even anonymous
/// stats pings. The only exception is the account handshake itself, which is
/// how an account gets created in the first place; see
/// [ServerAccessGate.accountSetupPaths].
///
/// [SyncService] owns the gate's state; everything else reads it, either
/// directly ([approved] / [ensureApproved]) or implicitly by sending its
/// requests through a [GatedServerClient].
class ServerAccessGate extends ChangeNotifier {
  ServerAccessGate._();

  /// App-wide instance — repositories and API clients without a
  /// `BuildContext` read it directly, mirroring `StorageGuard.instance`.
  static final ServerAccessGate instance = ServerAccessGate._();

  /// The only paths that may be called before an account is approved: the
  /// account handshake (look up KDF params, register, sign in, ask for
  /// another verification mail). Everything else is refused.
  static const accountSetupPaths = {
    '/api/v1/auth/params',
    '/api/v1/auth/register',
    '/api/v1/auth/login',
    '/api/v1/auth/resend-verification',
    // Signing in with Google or GitHub is the same handshake wearing a
    // different hat: it ends in a session token for an approved account, and
    // like the rest of this list it carries nothing but what the user just
    // typed or clicked. /complete is the one that issues the token.
    '/api/v1/auth/oauth/providers',
    '/api/v1/auth/oauth/start',
    '/api/v1/auth/oauth/poll',
    '/api/v1/auth/oauth/complete',
  };

  bool _approved = false;

  /// Whether this device currently holds a signed-in, approved account.
  bool get approved => _approved;

  /// Set by [SyncService] whenever the account state changes.
  void setApproved(bool value) {
    if (_approved == value) return;
    _approved = value;
    notifyListeners();
  }

  /// Throws [ServerAccessDeniedException] unless an approved account exists.
  void ensureApproved() {
    if (!_approved) throw const ServerAccessDeniedException();
  }
}

/// Short alias used at call sites (`ServerAccess.instance.approved`).
typedef ServerAccess = ServerAccessGate;

/// An [http.Client] that refuses to send anything to a luma server while
/// [ServerAccessGate.approved] is false.
///
/// This is the belt to the call sites' braces: every server-backed feature
/// already checks `SyncService.serverReady` before doing any work, but
/// routing their traffic through this client means a missed check can't turn
/// into a silent connection to the server.
class GatedServerClient extends http.BaseClient {
  GatedServerClient({
    http.Client? inner,
    this.allowBeforeApproval = const {},
  }) : _inner = inner ?? http.Client();

  final http.Client _inner;

  /// Paths that stay reachable while the gate is closed. Empty for
  /// everything except the sync API's account handshake.
  final Set<String> allowBeforeApproval;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!ServerAccessGate.instance.approved && !_isAllowed(request.url)) {
      throw const ServerAccessDeniedException();
    }
    return _inner.send(request);
  }

  /// Base URLs may carry a path prefix (`https://host/luma/api/v1/...`), so
  /// the allowlist matches on the suffix rather than the whole path.
  bool _isAllowed(Uri url) {
    return allowBeforeApproval.any((p) => url.path.endsWith(p));
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
