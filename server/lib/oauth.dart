import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as c;

import 'util.dart';

/// Sign in with Google / GitHub.
///
/// The luma server — not the app — drives the OAuth code exchange, so the
/// provider client *secrets* never ship inside a desktop or Android binary,
/// where they could not be kept secret in the first place. The app's part of
/// the dance is deliberately dumb:
///
///   1. POST /auth/oauth/start   -> { ticket, authUrl }
///   2. open authUrl in the system browser; the user signs in there
///   3. the provider redirects to /auth/oauth/callback/<provider>, which is
///      where this server swaps the code for a verified email address
///   4. POST /auth/oauth/poll    -> the verified email, once step 3 lands
///   5. POST /auth/oauth/complete with the locally derived auth key
///
/// Step 5 is what actually issues a session token, and it is not optional:
/// a provider can vouch for *who* you are, but it cannot hand over the key
/// that decrypts your data. That key is still derived on the device from a
/// passphrase only the user knows, exactly as with an email/password
/// account — see SyncCrypto in the app. OAuth replaces the "which account"
/// half of signing in, never the zero-knowledge half.
class OAuthProviderConfig {
  const OAuthProviderConfig({
    required this.id,
    required this.clientId,
    required this.clientSecret,
  });

  /// Stable identifier used in URLs and stored on the account ('google').
  final String id;

  final String clientId;
  final String clientSecret;

  bool get configured => clientId.isNotEmpty && clientSecret.isNotEmpty;
}

/// Everything the two supported providers differ on. Adding a third one is a
/// matter of another entry here plus its two env vars.
class OAuthProviderSpec {
  const OAuthProviderSpec({
    required this.id,
    required this.displayName,
    required this.authorizeUrl,
    required this.tokenUrl,
    required this.scope,
    required this.extraAuthorizeParams,
  });

  final String id;

  /// Shown in the app's sign-in button ("Continue with Google").
  final String displayName;

  final String authorizeUrl;
  final String tokenUrl;
  final String scope;
  final Map<String, String> extraAuthorizeParams;

  static const google = OAuthProviderSpec(
    id: 'google',
    displayName: 'Google',
    authorizeUrl: 'https://accounts.google.com/o/oauth2/v2/auth',
    tokenUrl: 'https://oauth2.googleapis.com/token',
    scope: 'openid email profile',
    // select_account so a shared machine does not silently reuse whoever
    // happens to be signed in to Google in that browser.
    extraAuthorizeParams: {'access_type': 'online', 'prompt': 'select_account'},
  );

  static const github = OAuthProviderSpec(
    id: 'github',
    displayName: 'GitHub',
    authorizeUrl: 'https://github.com/login/oauth/authorize',
    tokenUrl: 'https://github.com/login/oauth/access_token',
    scope: 'read:user user:email',
    extraAuthorizeParams: {},
  );

  static const all = [google, github];

  static OAuthProviderSpec? byId(String? id) {
    for (final spec in all) {
      if (spec.id == id) return spec;
    }
    return null;
  }
}

/// The verified identity a provider handed back.
class OAuthIdentity {
  const OAuthIdentity({
    required this.provider,
    required this.subject,
    required this.email,
    this.displayName,
  });

  final String provider;

  /// The provider's own immutable user id. Stored on the account so a later
  /// email change at the provider still resolves to the same luma account.
  final String subject;

  /// Lower-cased, provider-*verified* address. An unverified address is
  /// never returned — see [OAuthClient.fetchIdentity].
  final String email;

  final String? displayName;
}

class OAuthException implements Exception {
  OAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One in-flight browser sign-in.
///
/// Two independent secrets guard it. [state] travels through the browser and
/// the provider, so it shows up in address bars, history and Referer headers;
/// the ticket never leaves the app, and only its hash is held here. Polling
/// requires the ticket, so learning a state — the easy half to leak — buys an
/// attacker nothing.
class OAuthFlow {
  OAuthFlow({
    required this.provider,
    required this.state,
    required this.ticketHash,
    required this.createdAtMs,
  });

  final String provider;
  final String state;
  final String ticketHash;
  final int createdAtMs;

  /// Set once the callback has run: the verified identity, or the reason it
  /// failed. Both stay null while the user is still in the browser.
  OAuthIdentity? identity;
  String? error;

  /// Whether [identity]'s email already had a luma account when the callback
  /// ran, which is what tells the app to ask for the existing passphrase
  /// rather than to have the user choose a new one.
  bool existingAccount = false;

  /// KDF parameters of that existing account, so the app can derive the same
  /// keys it would have derived from a normal password sign-in.
  String? kdfSalt;
  int? kdfIterations;

  /// Failed passphrase attempts. A flow is burned after [maxAttempts] so a
  /// stolen ticket cannot be used to grind the passphrase.
  int attempts = 0;

  bool get ready => identity != null && error == null;

  static const maxAttempts = 5;
  static const ttl = Duration(minutes: 10);

  bool isExpired(int nowMs) => nowMs - createdAtMs > ttl.inMilliseconds;
}

/// In-memory registry of in-flight sign-ins. Deliberately not persisted: a
/// server restart mid-flow just means the user presses the button again.
class OAuthFlowStore {
  final Map<String, OAuthFlow> _byState = {};
  final Map<String, OAuthFlow> _byTicketHash = {};

  /// Cap on concurrent flows, so an unauthenticated endpoint cannot be used
  /// to grow this map without bound.
  static const maxFlows = 500;

  static String hashTicket(String ticket) =>
      c.sha256.convert(utf8.encode(ticket)).toString();

  /// Creates a flow and returns the app's private ticket for it.
  (OAuthFlow, String) create(String provider) {
    _prune();
    if (_byState.length >= maxFlows) {
      throw OAuthException('Too many sign-ins in progress. Try again shortly.');
    }
    final ticket = _token();
    final flow = OAuthFlow(
      provider: provider,
      state: _token(),
      ticketHash: hashTicket(ticket),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _byState[flow.state] = flow;
    _byTicketHash[flow.ticketHash] = flow;
    return (flow, ticket);
  }

  OAuthFlow? byState(String? state) {
    _prune();
    return state == null ? null : _byState[state];
  }

  OAuthFlow? byTicket(String? ticket) {
    _prune();
    if (ticket == null) return null;
    return _byTicketHash[hashTicket(ticket)];
  }

  void remove(OAuthFlow flow) {
    _byState.remove(flow.state);
    _byTicketHash.remove(flow.ticketHash);
  }

  void _prune() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dead = _byState.values.where((f) => f.isExpired(now)).toList();
    for (final flow in dead) {
      remove(flow);
    }
  }

  static String _token() =>
      base64UrlEncode(randomBytes(32)).replaceAll('=', '');
}

/// Talks to the providers. Split out from Api so the HTTP shape of each
/// provider is testable on its own and the request handlers stay readable.
class OAuthClient {
  OAuthClient({this.timeout = const Duration(seconds: 20)});

  final Duration timeout;

  /// Swaps an authorization code for a verified [OAuthIdentity].
  Future<OAuthIdentity> fetchIdentity({
    required OAuthProviderSpec spec,
    required OAuthProviderConfig config,
    required String code,
    required String redirectUri,
  }) async {
    final accessToken = await _exchangeCode(
      spec: spec,
      config: config,
      code: code,
      redirectUri: redirectUri,
    );
    return switch (spec.id) {
      'google' => await _googleIdentity(accessToken),
      'github' => await _githubIdentity(accessToken),
      _ => throw OAuthException('Unsupported provider.'),
    };
  }

  Future<String> _exchangeCode({
    required OAuthProviderSpec spec,
    required OAuthProviderConfig config,
    required String code,
    required String redirectUri,
  }) async {
    final json = await _request(
      'POST',
      Uri.parse(spec.tokenUrl),
      formBody: {
        'client_id': config.clientId,
        'client_secret': config.clientSecret,
        'code': code,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
      },
    );
    final token = json['access_token'];
    if (token is! String || token.isEmpty) {
      // GitHub reports a bad or expired code with HTTP 200 and an error body.
      final detail = json['error_description'] ?? json['error'];
      throw OAuthException(detail is String
          ? 'The provider rejected the sign-in ($detail).'
          : 'The provider did not return an access token.');
    }
    return token;
  }

  Future<OAuthIdentity> _googleIdentity(String accessToken) async {
    final json = await _request(
      'GET',
      Uri.parse('https://openidconnect.googleapis.com/v1/userinfo'),
      bearer: accessToken,
    );
    final email = json['email'];
    final subject = json['sub'];
    if (email is! String || subject is! String) {
      throw OAuthException('Google did not return an email address.');
    }
    // email_verified comes back as a bool from the OIDC endpoint, but has
    // historically been a string on some Google surfaces.
    final verified = json['email_verified'];
    if (verified == false || verified == 'false') {
      throw OAuthException(
          'That Google address is not verified. Verify it with Google first.');
    }
    return OAuthIdentity(
      provider: 'google',
      subject: subject,
      email: email.trim().toLowerCase(),
      displayName: json['name'] as String?,
    );
  }

  Future<OAuthIdentity> _githubIdentity(String accessToken) async {
    final user = await _request(
      'GET',
      Uri.parse('https://api.github.com/user'),
      bearer: accessToken,
      accept: 'application/vnd.github+json',
    );
    final subject = user['id'];
    if (subject == null) {
      throw OAuthException('GitHub did not return an account id.');
    }
    // The profile's `email` field is whatever the user made public, which is
    // often null and is never guaranteed verified. The addresses endpoint is
    // the only trustworthy source, so it is the only one used.
    final emails = await _requestList(
      Uri.parse('https://api.github.com/user/emails'),
      bearer: accessToken,
      accept: 'application/vnd.github+json',
    );
    final chosen = pickGithubEmail(emails);
    if (chosen == null) {
      throw OAuthException('Your GitHub account has no verified email '
          'address. Add and verify one on GitHub, then try again.');
    }
    return OAuthIdentity(
      provider: 'github',
      subject: '$subject',
      email: chosen,
      displayName: (user['name'] ?? user['login']) as String?,
    );
  }

  /// Picks the address to identify a GitHub user by: their verified primary
  /// one, or failing that any other verified one. Unverified addresses are
  /// skipped entirely — anyone can add an address they do not control to a
  /// GitHub account, and honouring one would hand them the luma account that
  /// already owns it.
  static String? pickGithubEmail(List<dynamic> entries) {
    String? fallback;
    for (final entry in entries) {
      if (entry is! Map) continue;
      if (entry['verified'] != true) continue;
      final address = entry['email'];
      if (address is! String || !address.contains('@')) continue;
      final normalized = address.trim().toLowerCase();
      if (entry['primary'] == true) return normalized;
      fallback ??= normalized;
    }
    return fallback;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    Uri url, {
    Map<String, String>? formBody,
    String? bearer,
    String accept = 'application/json',
  }) async {
    final decoded = await _send(method, url,
        formBody: formBody, bearer: bearer, accept: accept);
    if (decoded is! Map<String, dynamic>) {
      throw OAuthException('The provider returned an unexpected response.');
    }
    return decoded;
  }

  Future<List<dynamic>> _requestList(
    Uri url, {
    String? bearer,
    String accept = 'application/json',
  }) async {
    final decoded = await _send('GET', url, bearer: bearer, accept: accept);
    if (decoded is! List) {
      throw OAuthException('The provider returned an unexpected response.');
    }
    return decoded;
  }

  Future<Object?> _send(
    String method,
    Uri url, {
    Map<String, String>? formBody,
    String? bearer,
    String accept = 'application/json',
  }) async {
    final client = HttpClient();
    try {
      final request = method == 'POST'
          ? await client.postUrl(url)
          : await client.getUrl(url);
      request.headers.set(HttpHeaders.acceptHeader, accept);
      // GitHub rejects requests without one.
      request.headers.set(HttpHeaders.userAgentHeader, 'luma-sync-server');
      if (bearer != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearer');
      }
      if (formBody != null) {
        request.headers.contentType = ContentType(
            'application', 'x-www-form-urlencoded',
            charset: 'utf-8');
        request.write(formBody.entries
            .map((e) => '${Uri.encodeQueryComponent(e.key)}='
                '${Uri.encodeQueryComponent(e.value)}')
            .join('&'));
      }
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 400) {
        throw OAuthException(
            'The provider refused the request (HTTP ${response.statusCode}).');
      }
      try {
        return jsonDecode(body);
      } catch (_) {
        throw OAuthException('The provider returned a malformed response.');
      }
    } on OAuthException {
      rethrow;
    } catch (_) {
      throw OAuthException('Could not reach ${url.host}.');
    } finally {
      client.close();
    }
  }
}
