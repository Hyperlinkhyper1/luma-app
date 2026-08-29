import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'ai_model_catalog.dart';
import 'ai_model_refresh.dart';
import 'ai_usage_store.dart';
import 'chat_store.dart';
import 'deploy_console.dart';
import 'update_check.dart';
import 'family_store.dart';
import 'mail.dart';
import 'metrics.dart';
import 'oauth.dart';
import 'rate_limit.dart';
import 'recipe_store.dart';
import 'store.dart';
import 'subway_relay.dart';
import 'subway_store.dart';
import 'util.dart';

/// How a newly registered account becomes usable.
enum ApprovalMode {
  /// The operator approves each account by hand from the admin dashboard.
  /// No email is sent and no verification link exists — the default, so a
  /// deployment works with no SMTP configured at all.
  manual,

  /// The user approves their own account by opening a link emailed to them.
  email,

  /// No approval step: accounts are active (and signed in) the moment they
  /// are created.
  open;

  static ApprovalMode parse(String? raw) => switch (raw?.trim().toLowerCase()) {
        'email' => ApprovalMode.email,
        'open' || 'none' || 'off' => ApprovalMode.open,
        _ => ApprovalMode.manual,
      };

  /// Whether new accounts start out waiting for approval.
  bool get holdsNewAccounts => this != ApprovalMode.open;
}

/// Server configuration, read from environment variables (see .env.example).
class ServerConfig {
  ServerConfig({
    required this.port,
    required this.dataDir,
    required this.allowRegistration,
    required this.maxBlobBytes,
    required this.tokenTtl,
    required this.corsOrigin,
    required this.trustProxy,
    required this.verificationTtl,
    required this.approvalMode,
    required this.adminKey,
    required this.mistralApiKey,
    required this.mistralAgentId,
    required this.googleApiKey,
    required this.itadApiKey,
    required this.groceriesUrl,
    required this.groceriesAdminKey,
    required this.artificialAnalysisKey,
    required this.repoPath,
    required this.wikiDir,
    required this.publicUrl,
    required this.oauthProviders,
  });

  final int port;
  final String dataDir;
  final bool allowRegistration;
  final int maxBlobBytes;
  final Duration tokenTtl;
  final String corsOrigin;
  final bool trustProxy;

  /// How long an email-verification link stays valid.
  final Duration verificationTtl;

  /// How a new account gets approved before it can sign in. Defaults to
  /// [ApprovalMode.manual] — the operator approves each one from the admin
  /// dashboard, so nobody waits on email and no SMTP setup is needed.
  final ApprovalMode approvalMode;

  /// Whether new accounts have to verify their own email address.
  bool get requireEmailVerification => approvalMode == ApprovalMode.email;

  /// Shared secret for the /admin/* endpoints. When unset, the admin
  /// dashboard is disabled entirely rather than left open.
  final String? adminKey;

  bool get adminEnabled => adminKey != null && adminKey!.isNotEmpty;

  /// A Mistral ("Luma" in the app's UI) API key configured once by the
  /// operator, so individual users don't each have to paste their own — see
  /// Api._mistralKey. Optional; when unset, the app falls back to its
  /// existing per-device key entry.
  final String? mistralApiKey;

  bool get mistralKeyConfigured =>
      mistralApiKey != null && mistralApiKey!.isNotEmpty;

  /// An optional Mistral Agents API agent id ("ag:...") configured by the
  /// operator alongside [mistralApiKey]. When set, proxied chats that don't
  /// pick their own agent are routed to this hosted agent instead of the
  /// plain chat-completions model — see Api._mistralChatProxy.
  final String? mistralAgentId;

  bool get mistralAgentConfigured =>
      mistralAgentId != null && mistralAgentId!.isNotEmpty;

  /// A Google AI Studio key configured once by the operator, powering the
  /// app's "Luma AI" modes (Aurora/Nebula/Pulsar → Gemini models). Same
  /// deal as [mistralApiKey]: used only server-side by Api._googleChatProxy,
  /// never sent to clients. Usage is token-metered per user — see
  /// [kAiTokens5h] / [kAiTokensWeek].
  final String? googleApiKey;

  bool get googleKeyConfigured =>
      googleApiKey != null && googleApiKey!.isNotEmpty;

  /// An IsThereAnyDeal key configured once by the operator, so individual
  /// users never register for one of their own. Same deal as [mistralApiKey]:
  /// used only server-side by Api._itadLookupProxy / _itadHistoryProxy /
  /// _itadOverviewProxy, never sent to clients. IsThereAnyDeal is where the
  /// Steam Tools plugin's price-history chart gets its data — Steam's own
  /// store API only ever answers with today's price. Without this key the
  /// plugin's library and store details still work; only the chart is
  /// unavailable.
  final String? itadApiKey;

  bool get itadKeyConfigured => itadApiKey != null && itadApiKey!.isNotEmpty;

  /// Where the supermarket-db API lives (see supermarket-db/ at the repo
  /// root) and its admin key, so the dashboard's Control panel tab can
  /// trigger database syncs by proxy — the groceries key never reaches the
  /// browser, only this server's own admin key does.
  final String groceriesUrl;
  final String? groceriesAdminKey;

  bool get groceriesAdminEnabled =>
      groceriesAdminKey != null && groceriesAdminKey!.isNotEmpty;

  /// Optional Artificial Analysis data-API key (free tier, 1000 requests a
  /// day) used only while refreshing the AI model leaderboard. Without it the
  /// catalogue still builds from OpenRouter and Hugging Face; the reasoning
  /// column, the speed figures and the per-effort measurements are what go
  /// missing. Like the other provider keys here it never reaches a client.
  final String? artificialAnalysisKey;

  bool get artificialAnalysisConfigured =>
      artificialAnalysisKey != null && artificialAnalysisKey!.isNotEmpty;

  /// Absolute path to this repo's checkout on the host, used only by
  /// [DeployConsole] to know where to `git pull` and re-run `docker compose`
  /// from. See LUMA_REPO_PATH in .env.example for why there is no default —
  /// a wrong guess here can create files in the wrong place on the host.
  final String? repoPath;

  bool get repoPathConfigured => repoPath != null && repoPath!.isNotEmpty;

  /// Root of the wiki checkout mounted into the container (contains
  /// `source/` with the Astro project and `site/` with the built output).
  /// When unset, the /admin/website editor is disabled.
  final String? wikiDir;

  bool get wikiEnabled => wikiDir != null && wikiDir!.isNotEmpty;

  /// Where this server is reachable from the public internet, without a
  /// trailing slash. Same value the verification mail uses; OAuth needs it
  /// too, because the redirect URI has to be an absolute URL the provider
  /// can send a browser back to.
  final String publicUrl;

  /// Client credentials per OAuth provider id, from
  /// LUMA_GOOGLE_OAUTH_CLIENT_ID / _SECRET and the GitHub pair. Providers
  /// with no credentials configured are simply absent, and the app hides
  /// their button — "Sign in with Google" is opt-in for the operator, not
  /// something a self-hosted deployment is forced to set up.
  final Map<String, OAuthProviderConfig> oauthProviders;

  /// The configured providers, in the order they are shown in the app.
  List<OAuthProviderSpec> get enabledOAuthProviders => OAuthProviderSpec.all
      .where((spec) => oauthProviders[spec.id]?.configured ?? false)
      .toList();

  bool get anyOAuthConfigured => enabledOAuthProviders.isNotEmpty;

  /// Where a provider sends the browser back to after the user approves.
  /// Must be registered verbatim in the provider's app settings.
  String oauthRedirectUri(String providerId) =>
      '$publicUrl/api/v1/auth/oauth/callback/$providerId';

  /// Whether new accounts may be created. Open by default; set
  /// LUMA_ALLOW_REGISTRATION=false to close it (existing accounts keep working).
  bool get registrationEnabled => allowRegistration;

  factory ServerConfig.fromEnvironment(Map<String, String> env) {
    int intOf(String key, int fallback) =>
        int.tryParse(env[key] ?? '') ?? fallback;
    return ServerConfig(
      port: intOf('LUMA_PORT', 8080),
      dataDir: env['LUMA_DATA_DIR'] ?? 'data',
      // Registration is open unless explicitly disabled.
      allowRegistration:
          (env['LUMA_ALLOW_REGISTRATION'] ?? 'true').toLowerCase() != 'false',
      // A single collection snapshot may not exceed this (protects disk/RAM).
      maxBlobBytes: intOf('LUMA_MAX_BLOB_BYTES', 256 * 1024 * 1024),
      tokenTtl: Duration(days: intOf('LUMA_TOKEN_TTL_DAYS', 90)),
      corsOrigin: env['LUMA_CORS_ORIGIN'] ?? '*',
      trustProxy: env['LUMA_TRUST_PROXY'] == 'true',
      verificationTtl:
          Duration(hours: intOf('LUMA_VERIFICATION_TTL_HOURS', 24)),
      // LUMA_APPROVAL_MODE wins; the older LUMA_REQUIRE_EMAIL_VERIFICATION
      // is still honoured so existing .env files keep their behaviour
      // (true → email, false → no approval at all).
      approvalMode: env['LUMA_APPROVAL_MODE'] != null
          ? ApprovalMode.parse(env['LUMA_APPROVAL_MODE'])
          : switch (env['LUMA_REQUIRE_EMAIL_VERIFICATION']?.toLowerCase()) {
              'true' => ApprovalMode.email,
              'false' => ApprovalMode.open,
              _ => ApprovalMode.manual,
            },
      adminKey: env['LUMA_ADMIN_KEY'],
      mistralApiKey: env['LUMA_MISTRAL_API_KEY'],
      mistralAgentId: env['LUMA_MISTRAL_AGENT_ID'],
      googleApiKey: env['LUMA_GOOGLE_API_KEY'],
      itadApiKey: env['LUMA_ITAD_API_KEY'],
      groceriesUrl:
          env['LUMA_GROCERIES_URL'] ?? 'https://groceries.luma-app.cc',
      groceriesAdminKey: env['LUMA_GROCERIES_ADMIN_KEY'],
      artificialAnalysisKey: env['LUMA_AA_API_KEY'],
      repoPath: env['LUMA_REPO_PATH'],
      wikiDir: env['LUMA_WIKI_DIR'],
      publicUrl: (env['LUMA_PUBLIC_URL'] ?? 'http://localhost:8080')
          .replaceAll(RegExp(r'/+$'), ''),
      oauthProviders: {
        for (final spec in OAuthProviderSpec.all)
          spec.id: OAuthProviderConfig(
            id: spec.id,
            clientId:
                env['LUMA_${spec.id.toUpperCase()}_OAUTH_CLIENT_ID'] ?? '',
            clientSecret:
                env['LUMA_${spec.id.toUpperCase()}_OAUTH_CLIENT_SECRET'] ?? '',
          ),
      },
    );
  }
}

/// Iterations for the *server-side* hash of the client's auth key. The auth
/// key is already a 256-bit output of a slow client-side KDF, so this only
/// needs to make a leaked database non-trivially reusable, not resist
/// password guessing.
const int _serverHashIterations = 20000;

/// Default KDF params advertised for unknown emails so the params endpoint
/// looks identical for existing and non-existing accounts.
const int _defaultClientIterations = 200000;

const int _maxJsonBody = 64 * 1024;

/// Rolling per-user token budgets for the shared Google key's "Luma AI"
/// modes. Clients only ever see these as percentages (Api._aiStatus).
const int kAiTokens5h = 7500;
const int kAiTokensWeek = 40000;

/// Luma Support (Mistral) messages per rolling day, counted separately
/// from the token budgets above.
const int kSupportMessagesPerDay = 15;

class Api {
  /// [oauthClient] is only passed by tests, which substitute one that
  /// resolves an identity without a round trip to Google or GitHub.
  Api(this.store, this.config, this.mailer, this.familyStore, this.chatStore,
      this.aiUsage, this.subwayStore, this.recipeStore, this.aiCatalog,
      {OAuthClient? oauthClient})
      : _oauthClient = oauthClient ?? OAuthClient(),
        _authLimiter = RateLimiter(
            maxRequests: 15, window: const Duration(minutes: 10)),
        _generalLimiter = RateLimiter(
            maxRequests: 300, window: const Duration(minutes: 1)),
        _resendLimiter = RateLimiter(
            maxRequests: 3, window: const Duration(minutes: 15)),
        _adminFailLimiter = RateLimiter(
            maxRequests: 1, window: const Duration(minutes: 1)),
        _inviteLimiter = RateLimiter(
            maxRequests: 10, window: const Duration(hours: 1)),
        _aiChatLimiter = RateLimiter(
            maxRequests: 20, window: const Duration(minutes: 1)),
        _itadLimiter = RateLimiter(
            maxRequests: 60, window: const Duration(minutes: 1)),
        _syncWriteLimiter = RateLimiter(
            maxRequests: 60, window: const Duration(minutes: 1)),
        _uploadLimiter = RateLimiter(
            maxRequests: 30, window: const Duration(minutes: 10)),
        _socketLimiter = RateLimiter(
            maxRequests: 30, window: const Duration(minutes: 1)),
        _adminLimiter = RateLimiter(
            maxRequests: 240, window: const Duration(minutes: 1)),
        _loginFailLimiter = RateLimiter(
            maxRequests: 10, window: const Duration(minutes: 15)) {
    _adminSessionExpiryByTokenHash.addAll(_adminSessions.load());
  }

  final Store store;
  final ServerConfig config;
  final Mailer mailer;
  final FamilyStore familyStore;
  final ChatStore chatStore;
  final AiUsageStore aiUsage;
  final SubwayStore subwayStore;
  final RecipeStore recipeStore;
  final AiModelCatalogStore aiCatalog;
  final SubwayRelay _subwayRelay = SubwayRelay();
  final SubwayTicketStore _subwayTickets = SubwayTicketStore();

  /// Browser sign-ins currently in flight, and the client that talks to
  /// Google/GitHub on their behalf. See oauth.dart for the whole dance.
  final OAuthFlowStore _oauthFlows = OAuthFlowStore();
  final OAuthClient _oauthClient;
  final RateLimiter _authLimiter;
  final RateLimiter _generalLimiter;

  /// Extra, per-email limit on top of [_authLimiter] so someone can't spam
  /// verification mail to one address from many IPs.
  final RateLimiter _resendLimiter;

  /// Per-IP limit on *failed* admin-key attempts: one wrong guess per
  /// minute, so the admin key cannot be brute-forced by a bot. Successful
  /// logins never count against it.
  final RateLimiter _adminFailLimiter;

  /// Per-user limit on family/chat invites, each of which sends an email to
  /// an arbitrary address — without this, any account could use the server
  /// as a spam relay at the general limiter's speed.
  final RateLimiter _inviteLimiter;

  /// Tighter per-IP budgets for the expensive endpoint classes, layered into
  /// [_rateLimit] by [_limiterFor]. The general 300/min budget is fine for
  /// small JSON calls but far too generous for endpoints that burn upstream
  /// AI quota, accept multi-megabyte bodies, or hold a socket open.
  final RateLimiter _aiChatLimiter;
  final RateLimiter _itadLimiter;
  final RateLimiter _syncWriteLimiter;
  final RateLimiter _uploadLimiter;
  final RateLimiter _socketLimiter;

  /// Per-IP budget for /admin/* — high enough for the dashboard's live
  /// polling, low enough that the admin surface can't be hammered.
  final RateLimiter _adminLimiter;

  /// Per-*email* limit on failed logins, so one account's password can't be
  /// brute-forced from many IPs (the per-IP [_authLimiter] alone doesn't
  /// stop a distributed guesser). Only failures count — successful logins
  /// never lock anyone out.
  final RateLimiter _loginFailLimiter;

  /// Admin dashboard login sessions, keyed by SHA-256 of the session cookie
  /// token (mirrors [Store.sessionsByTokenHash] for regular users), so the
  /// admin key no longer has to travel in every dashboard URL/log line/Referer
  /// header.
  ///
  /// Kept on disk as well as in memory, by [AdminSessionStore] — see there
  /// for why a restart must not sign the operator out.
  final Map<String, int> _adminSessionExpiryByTokenHash = {};
  static const _adminSessionTtl = Duration(hours: 12);
  static const _adminCookieName = 'luma_admin';

  Handler get handler {
    final router = Router()
      ..get('/', _root)
      ..get('/health', _health)
      ..post('/api/v1/auth/params', _authParams)
      ..post('/api/v1/auth/register', _register)
      ..get('/api/v1/auth/verify', _verify)
      ..post('/api/v1/auth/resend-verification', _resendVerification)
      ..post('/api/v1/auth/login', _login)
      ..get('/api/v1/auth/oauth/providers', _oauthProviders)
      ..post('/api/v1/auth/oauth/start', _oauthStart)
      ..get('/api/v1/auth/oauth/callback/<provider>', _oauthCallback)
      ..post('/api/v1/auth/oauth/poll', _oauthPoll)
      ..post('/api/v1/auth/oauth/complete', _oauthComplete)
      ..post('/api/v1/auth/logout', _requireAuth(_logout))
      ..post('/api/v1/auth/change', _requireAuth(_changePassword))
      ..get('/api/v1/auth/sessions', _requireAuth(_listSessions))
      ..post('/api/v1/auth/sessions/<id>/revoke', _requireAuth(_revokeSession))
      ..get('/api/v1/account', _requireAuth(_accountInfo))
      ..post('/api/v1/account/delete', _requireAuth(_deleteAccount))
      ..get('/api/v1/ai/mistral-key-configured', _requireAuth(_mistralKeyStatus))
      ..get('/api/v1/ai/status', _requireAuth(_aiStatus))
      ..post('/api/v1/ai/mistral/chat', _requireAuth(_mistralChatProxy))
      ..post('/api/v1/ai/google/chat', _requireAuth(_googleChatProxy))
      ..get('/api/v1/steam/itad/status', _requireAuth(_itadStatus))
      ..get('/api/v1/steam/itad/lookup', _requireAuth(_itadLookupProxy))
      ..get('/api/v1/steam/itad/history', _requireAuth(_itadHistoryProxy))
      ..post('/api/v1/steam/itad/overview', _requireAuth(_itadOverviewProxy))
      ..get('/api/v1/sync/<collection>', _requireAuth(_getBlob))
      ..put('/api/v1/sync/<collection>', _requireAuth(_putBlob))
      ..delete('/api/v1/sync/<collection>', _requireAuth(_deleteBlobHandler))
      ..post('/api/v1/family', _requireAuth(_createFamily))
      ..get('/api/v1/family', _requireAuth(_getMyFamily))
      ..post('/api/v1/family/<id>/invite', _requireAuth(_inviteFamilyMember))
      ..get('/api/v1/family/invites', _requireAuth(_listMyInvites))
      ..post('/api/v1/family/invites/<inviteId>/accept',
          _requireAuth(_acceptFamilyInvite))
      ..post('/api/v1/family/invites/<inviteId>/decline',
          _requireAuth(_declineFamilyInvite))
      ..post('/api/v1/family/<id>/members/<userId>/remove',
          _requireAuth(_removeFamilyMember))
      ..post('/api/v1/family/<id>/delete', _requireAuth(_deleteFamily))
      ..post('/api/v1/family/<id>/events', _requireAuth(_addSharedEvent))
      ..get('/api/v1/family/<id>/events', _requireAuth(_listSharedEvents))
      ..put('/api/v1/family/<id>/events/<eventId>',
          _requireAuth(_updateSharedEvent))
      ..delete('/api/v1/family/<id>/events/<eventId>',
          _requireAuth(_deleteSharedEvent))
      ..put('/api/v1/chat/key', _requireAuth(_putChatKey))
      ..get('/api/v1/chat/key/<userId>', _requireAuth(_getChatKey))
      ..post('/api/v1/chat/invite', _requireAuth(_sendChatInvite))
      ..get('/api/v1/chat/invites', _requireAuth(_listChatInvites))
      ..post('/api/v1/chat/invites/<inviteId>/accept',
          _requireAuth(_acceptChatInvite))
      ..post('/api/v1/chat/invites/<inviteId>/decline',
          _requireAuth(_declineChatInvite))
      ..get('/api/v1/chat/conversations', _requireAuth(_listChatConversations))
      ..get('/api/v1/chat/conversations/<id>/messages',
          _requireAuth(_listChatMessages))
      ..post('/api/v1/chat/conversations/<id>/messages',
          _requireAuth(_sendChatMessage))
      ..get('/api/v1/ai-models', _requireAuth(_listAiModels))
      ..get('/api/v1/recipes', _requireAuth(_listPublicRecipes))
      ..post('/api/v1/recipes', _requireAuth(_publishRecipe))
      ..get('/api/v1/recipes/media/<photoId>', _requireAuth(_getRecipeMedia))
      ..get('/api/v1/recipes/<id>', _requireAuth(_getPublicRecipe))
      ..put('/api/v1/recipes/<id>', _requireAuth(_updatePublicRecipe))
      ..delete('/api/v1/recipes/<id>', _requireAuth(_deletePublicRecipe))
      ..post('/api/v1/recipes/<id>/photo', _requireAuth(_uploadRecipePhoto))
      ..get('/api/v1/recipes/<id>/reviews', _requireAuth(_listRecipeReviews))
      ..post('/api/v1/recipes/<id>/reviews', _requireAuth(_putRecipeReview))
      ..post('/api/v1/recipes/<id>/reviews/photo',
          _requireAuth(_uploadReviewPhoto))
      ..delete('/api/v1/recipes/<id>/reviews', _requireAuth(_deleteRecipeReview))
      ..post('/api/v1/plugins/download', _requireAuth(_reportPluginDownload))
      ..post('/api/v1/subway/rooms', _requireAuth(_createSubwayRoom))
      ..get('/api/v1/subway/rooms', _requireAuth(_listSubwayRooms))
      ..post('/api/v1/subway/rooms/<code>/invite', _requireAuth(_inviteToSubwayRoom))
      ..post('/api/v1/subway/rooms/<code>/join', _requireAuth(_joinSubwayRoom))
      ..put('/api/v1/subway/rooms/<code>/state', _requireAuth(_putSubwayState))
      ..get('/api/v1/subway/rooms/<code>/state', _requireAuth(_getSubwayState))
      ..post('/api/v1/subway/rooms/<code>/clock/claim', _requireAuth(_claimSubwayClock))
      ..post('/api/v1/subway/rooms/<code>/clock/release', _requireAuth(_releaseSubwayClock))
      ..post('/api/v1/subway/rooms/<code>/ticket', _requireAuth(_mintSubwayTicket))
      ..get('/api/v1/subway/room/<room>', _subwayRoomSocket)
      ..get('/admin/login', _adminLoginPage)
      ..post('/admin/login', _adminLoginSubmit)
      ..post('/admin/logout', _adminLogout)
      ..get('/admin', _requireAdmin(_adminDashboard))
      ..get('/admin/users', _requireAdmin(_adminUsers))
      ..get('/admin/stats', _requireAdmin(_adminStats))
      ..get('/admin/metrics', _requireAdmin(_adminMetrics))
      ..get('/admin/metrics/history', _requireAdmin(_adminMetricsHistory))
      ..get('/admin/storage', _requireAdmin(_adminStorage))
      ..get('/admin/activity', _requireAdmin(_adminActivity))
      ..post('/admin/verify', _requireAdmin(_adminVerifyUser))
      ..post('/admin/revoke', _requireAdmin(_adminRevokeUser))
      ..post('/admin/plan', _requireAdmin(_adminSetPlan))
      ..post('/admin/groceries/sync', _requireAdmin(_adminGroceriesSync))
      ..post('/admin/groceries/reload', _requireAdmin(_adminGroceriesReload))
      ..get('/admin/groceries/status', _requireAdmin(_adminGroceriesStatus))
      ..post('/admin/ai-models/refresh', _requireAdmin(_adminAiModelsRefresh))
      ..get('/admin/ai-models/status', _requireAdmin(_adminAiModelsStatus))
      ..post('/admin/deploy', _requireAdmin(_deploy.requestDeploy))
      ..get('/admin/deploy/status', _requireAdmin(_deploy.deployStatus))
      ..post('/admin/system/check-updates',
          _requireAdmin(_updateCheck.requestCheck))
      ..get('/admin/system/check-updates/status',
          _requireAdmin(_updateCheck.checkStatus))
      ..get('/admin/website', _requireAdmin(_adminWebsiteIndex))
      ..post('/admin/website/build', _requireAdmin(_adminWebsiteBuild))
      ..get('/admin/website/build/status',
          _requireAdmin(_adminWebsiteBuildStatus))
      // Preview assets + upload must be registered before the <page|.*>
      // catch-alls or those would swallow them.
      ..get('/admin/website/preview/page.css', _requireAdmin(_wikiPreviewCss))
      ..get('/admin/website/preview/astro/<file>',
          _requireAdmin(_wikiPreviewAstroAsset))
      ..get('/admin/website/preview/public/<path|.*>',
          _requireAdmin(_wikiPreviewPublicAsset))
      ..post('/admin/website/upload', _requireAdmin(_adminWebsiteUpload))
      ..get('/admin/website/new-devlog', _requireAdmin(_adminNewDevlogForm))
      ..post('/admin/website/new-devlog', _requireAdmin(_adminNewDevlogCreate))
      // Registered before the <page|.*> catch-all, which would otherwise
      // treat "team" as a Markdown page at the content root rather than the
      // roster form.
      ..get('/admin/website/team', _requireAdmin(_adminTeamEditor))
      ..post('/admin/website/team', _requireAdmin(_adminTeamSave))
      ..post('/admin/website/<page|.*>/delete', _requireAdmin(_adminWebsiteDelete))
      ..get('/admin/website/<page|.*>', _requireAdmin(_adminWebsiteEditor))
      ..post('/admin/website/<page|.*>', _requireAdmin(_adminWebsiteSave));

    return const Pipeline()
        .addMiddleware(_recover)
        .addMiddleware(_cors)
        .addMiddleware(_rateLimit)
        .addHandler(router.call);
  }

  // ---- Middleware ---------------------------------------------------------

  /// Turns unexpected exceptions into a clean 500 without leaking internals.
  Handler _recover(Handler inner) => (request) async {
        try {
          return await inner(request);
        } on HijackException {
          // WebSocket upgrades (subway co-op) hijack the connection instead
          // of returning a Response — this must propagate untouched, never
          // get converted into a 500.
          rethrow;
        } on FormatException {
          return errorResponse(400, 'bad_request', 'Malformed request.');
        } catch (e, st) {
          stderr.writeln('[luma] unhandled error: $e\n$st');
          return errorResponse(500, 'internal', 'Internal server error.');
        }
      };

  Handler _cors(Handler inner) => (request) async {
        final headers = {
          'Access-Control-Allow-Origin': config.corsOrigin,
          'Access-Control-Allow-Methods': 'GET, PUT, POST, DELETE, OPTIONS',
          'Access-Control-Allow-Headers':
              'Authorization, Content-Type, X-Base-Version, X-Payload-Saved-At',
          'Access-Control-Expose-Headers': 'X-Version, X-Payload-Saved-At',
          'X-Content-Type-Options': 'nosniff',
          // Nothing this server serves should ever render inside a frame on
          // someone else's site (clickjacking the admin dashboard, mainly).
          // SAMEORIGIN, not DENY: the website editor's live preview frames
          // its own /admin/website/preview pages.
          'X-Frame-Options': 'SAMEORIGIN',
        };
        if (request.method == 'OPTIONS') {
          return Response(204, headers: headers);
        }
        final response = await inner(request);
        return response.change(headers: headers);
      };

  Handler _rateLimit(Handler inner) => (request) async {
        final key = _clientKey(request);
        final (tag, limiter) = _limiterFor(request.method, request.url.path);
        if (!limiter.allow('$tag:$key')) {
          return errorResponse(429, 'rate_limited', 'Too many requests. Slow down.');
        }
        return inner(request);
      };

  /// Buckets every request into the limiter matching how expensive it is.
  /// Each bucket keys separately (the tag), so e.g. hammering uploads can't
  /// starve the same IP's ordinary API calls or vice versa.
  (String, RateLimiter) _limiterFor(String method, String path) {
    // The app polls this one every couple of seconds for as long as the user
    // is in their browser, so it cannot share the 15-per-10-minutes auth
    // budget — a single sign-in would exhaust it. It does no work beyond a
    // map lookup and reveals nothing without the ticket.
    if (path == 'api/v1/auth/oauth/poll') {
      return ('op', _generalLimiter);
    }
    if (path.startsWith('api/v1/auth/') && !path.endsWith('/logout')) {
      return ('a', _authLimiter);
    }
    if (path.startsWith('api/v1/ai/') && path.endsWith('/chat')) {
      return ('ai', _aiChatLimiter);
    }
    if (path.startsWith('api/v1/steam/itad/')) {
      return ('itad', _itadLimiter);
    }
    if (path.startsWith('api/v1/sync/') &&
        (method == 'PUT' || method == 'DELETE')) {
      return ('w', _syncWriteLimiter);
    }
    if (method == 'POST' &&
        (path.endsWith('/photo') ||
            path.endsWith('/reviews/photo') ||
            path == 'admin/website/upload')) {
      return ('u', _uploadLimiter);
    }
    if (path.startsWith('api/v1/subway/room/')) {
      return ('ws', _socketLimiter);
    }
    if (path == 'admin' || path.startsWith('admin/')) {
      return ('adm', _adminLimiter);
    }
    return ('g', _generalLimiter);
  }

  String _clientKey(Request request) {
    if (config.trustProxy) {
      final forwarded = request.headers['x-forwarded-for'];
      if (forwarded != null && forwarded.isNotEmpty) {
        // Take the LAST entry — that's the one appended by our own trusted
        // proxy. Earlier entries are client-supplied and trivially spoofed,
        // which would let an attacker rotate fake IPs past the rate limiter.
        return forwarded.split(',').last.trim();
      }
    }
    final conn = request.context['shelf.io.connection_info'];
    if (conn is HttpConnectionInfo) return conn.remoteAddress.address;
    return 'unknown';
  }

  /// Wraps a handler so it only runs with a valid bearer token; the session's
  /// user is passed along. Also slides the token expiry forward.
  Handler _requireAuth(
      FutureOr<Response> Function(Request, StoredUser) handler) {
    return (request) async {
      final auth = request.headers['authorization'] ?? '';
      if (!auth.startsWith('Bearer ') || auth.length < 20) {
        return errorResponse(401, 'unauthorized', 'Missing or invalid token.');
      }
      final token = auth.substring(7).trim();
      final tokenHash = c.sha256.convert(utf8.encode(token)).toString();
      final session = store.sessionsByTokenHash[tokenHash];
      final now = DateTime.now().millisecondsSinceEpoch;
      if (session == null || session.expiresAtMs <= now) {
        return errorResponse(401, 'unauthorized', 'Session expired. Sign in again.');
      }
      final user = store.usersById[session.userId];
      if (user == null) {
        return errorResponse(401, 'unauthorized', 'Account no longer exists.');
      }
      // An account that is (back to) waiting for approval gets nothing but
      // the account handshake — the app mirrors this by shutting its own
      // server-access gate when it sees this code.
      if (user.isPending) {
        return errorResponse(403, 'account_not_approved',
            'This account is waiting to be approved.');
      }
      // Sliding expiry: refresh when past the halfway point.
      final half = config.tokenTtl.inMilliseconds ~/ 2;
      if (session.expiresAtMs - now < half) {
        await store.lock.synchronized(() async {
          session.expiresAtMs = now + config.tokenTtl.inMilliseconds;
          await store.saveSessions();
        });
      }
      return handler(request, user);
    };
  }

  /// Wraps a handler so it only runs for an authenticated admin. If no admin
  /// key is configured, the route behaves as if it doesn't exist (404)
  /// rather than being left open.
  ///
  /// Primary path: a session cookie set by [_adminLoginSubmit] after the
  /// operator enters the key once at /admin/login — this is what the
  /// dashboard itself uses, so the key never appears in a URL, browser
  /// history, or a reverse-proxy access log line. Fallback path, for
  /// non-browser callers (curl, scripts): the raw key via the `X-Admin-Key`
  /// header or a `?key=` query parameter — visiting /admin this way still
  /// works but also opportunistically establishes a session, so only the
  /// first request needs the key.
  Handler _requireAdmin(FutureOr<Response> Function(Request) handler) {
    return (request) async {
      if (!config.adminEnabled) {
        return errorResponse(404, 'not_found', 'Not found.');
      }
      final clientKey = _clientKey(request);
      // Refuse outright while this IP is over its failed-attempt budget —
      // only *failed* attempts count, so the dashboard's own polling never
      // locks a legitimate operator out.
      if (_adminFailLimiter.isLimited(clientKey)) {
        return errorResponse(429, 'rate_limited',
                'Too many failed admin attempts. Try again later.')
            .change(headers: {
          'Retry-After': '${_adminFailLimiter.retryAfterSeconds(clientKey)}',
        });
      }

      if (_hasValidAdminSession(request)) {
        return _withAdminHeaders(await handler(request));
      }

      // Fall back to the raw key, for non-browser/API callers (curl, scripts)
      // that don't hold a session cookie.
      final provided =
          request.headers['x-admin-key'] ?? request.url.queryParameters['key'];
      if (provided == null) {
        // No credential of any kind — most likely a browser navigating here
        // directly, so send it to the login form rather than a bare 401.
        return Response.found('/admin/login');
      }
      final expected = config.adminKey!;
      final match = constantTimeEquals(
          utf8.encode(provided), utf8.encode(expected));
      if (!match) {
        _adminFailLimiter.allow(clientKey);
        return errorResponse(401, 'unauthorized', 'Invalid or missing admin key.');
      }
      final response = _withAdminHeaders(await handler(request));
      // Loading the dashboard itself via an old `?key=` bookmark: piggyback a
      // session cookie on the response so every subsequent click/poll from
      // this browser goes through the cookie instead of repeating the key.
      return request.url.path == 'admin'
          ? _establishAdminSession(response, request)
          : response;
    };
  }

  Response _establishAdminSession(Response response, Request request) {
    final token = base64UrlEncode(randomBytes(32)).replaceAll('=', '');
    final tokenHash = c.sha256.convert(utf8.encode(token)).toString();
    _pruneAdminSessions();
    _adminSessionExpiryByTokenHash[tokenHash] =
        DateTime.now().millisecondsSinceEpoch + _adminSessionTtl.inMilliseconds;
    _adminSessions.save(_adminSessionExpiryByTokenHash);
    final secure = _isSecureRequest(request);
    return response.change(headers: {
      'Set-Cookie': '$_adminCookieName=$token; Path=/admin; HttpOnly; '
          'SameSite=Strict${secure ? '; Secure' : ''}; '
          'Max-Age=${_adminSessionTtl.inSeconds}',
    });
  }

  /// The dashboard used to carry the admin key in its URL (every link, form
  /// action, and fetch call) — that leaks into reverse-proxy access logs,
  /// browser history, and the Referer header. These headers close that off
  /// for the cookie-authenticated path; `no-store` also keeps a shared/public
  /// machine from caching a page full of account data.
  Response _withAdminHeaders(Response response) => response.change(headers: {
        'Referrer-Policy': 'no-referrer',
        'Cache-Control': 'no-store',
        // The dashboard is self-contained (inline styles/scripts, same-origin
        // fetches) — everything external is refused, so even an HTML-injection
        // slip could not load or exfiltrate to an outside host.
        // 'self' in style-src is what lets the wiki editor's preview iframe
        // load /admin/website/preview/page.css — a srcdoc iframe inherits this
        // policy, and 'unsafe-inline' alone covers <style> blocks but refuses
        // <link rel=stylesheet>, which left the live preview unstyled.
        'Content-Security-Policy': "default-src 'none'; "
            "style-src 'self' 'unsafe-inline'; script-src 'unsafe-inline'; "
            "img-src 'self' data:; connect-src 'self'; form-action 'self'; "
            "frame-src 'self'; frame-ancestors 'self'; base-uri 'none'; "
            "font-src 'self'",
      });

  String? _adminSessionToken(Request request) {
    final cookieHeader = request.headers['cookie'];
    if (cookieHeader == null) return null;
    for (final part in cookieHeader.split(';')) {
      final eq = part.indexOf('=');
      if (eq < 0) continue;
      final name = part.substring(0, eq).trim();
      if (name == _adminCookieName) return part.substring(eq + 1).trim();
    }
    return null;
  }

  bool _hasValidAdminSession(Request request) {
    final token = _adminSessionToken(request);
    if (token == null) return false;
    final tokenHash = c.sha256.convert(utf8.encode(token)).toString();
    final expiresAt = _adminSessionExpiryByTokenHash[tokenHash];
    if (expiresAt == null) return false;
    if (expiresAt <= DateTime.now().millisecondsSinceEpoch) {
      _adminSessionExpiryByTokenHash.remove(tokenHash);
      return false;
    }
    return true;
  }

  void _pruneAdminSessions() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _adminSessionExpiryByTokenHash.removeWhere((_, exp) => exp <= now);
  }

  late final AdminSessionStore _adminSessions =
      AdminSessionStore(config.dataDir);


  /// Whether to mark the session cookie `Secure` (HTTPS-only). Mirrors the
  /// scheme-detection [_originHint] already uses for the landing page: trust
  /// the proxy's forwarded-proto header, and otherwise assume plain HTTP only
  /// on localhost.
  bool _isSecureRequest(Request request) {
    final proto = request.headers['x-forwarded-proto'];
    if (proto != null) return proto == 'https';
    final host = request.headers['host'] ?? '';
    return !(host.startsWith('localhost') || host.startsWith('127.'));
  }

  static String _fmtWait(int seconds) {
    if (seconds < 60) return '$seconds second${seconds == 1 ? '' : 's'}';
    final minutes = (seconds / 60).ceil();
    return '$minutes minute${minutes == 1 ? '' : 's'}';
  }

  String _adminLoginFormHtml({bool failed = false, int? lockedSeconds}) {
    final message = lockedSeconds != null
        ? 'Too many failed attempts — try again in ${_fmtWait(lockedSeconds)}.'
        : (failed ? 'Invalid admin key.' : null);
    return '<!doctype html><html><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<title>luma admin — sign in</title>'
        '<style>$_adminCss</style></head><body><div class="wrap" '
        'style="max-width:360px;padding-top:15vh">'
        '<header class="top"><h1>luma<span class="dot">.</span> admin</h1></header>'
        '<div class="card">'
        '${message != null ? '<p class="hint" style="color:#e07e7e">${_htmlEscape(message)}</p>' : ''}'
        '<form method="post" action="/admin/login">'
        '<div class="product-form" style="flex-direction:column;align-items:stretch">'
        '<input type="password" name="key" placeholder="Admin key" autofocus required '
        '${lockedSeconds != null ? 'disabled' : ''} style="width:100%">'
        '<button type="submit" class="btn btn-primary" '
        '${lockedSeconds != null ? 'disabled' : ''}>Sign in</button>'
        '</div></form></div></div></body></html>';
  }

  Response _adminLoginPage(Request request) {
    if (!config.adminEnabled) return errorResponse(404, 'not_found', 'Not found.');
    final locked = int.tryParse(request.url.queryParameters['locked'] ?? '');
    return Response(200,
        body: _adminLoginFormHtml(
            failed: request.url.queryParameters.containsKey('failed'),
            lockedSeconds: locked),
        headers: {
          'Content-Type': 'text/html; charset=utf-8',
          'Cache-Control': 'no-store',
        });
  }

  Future<Response> _adminLoginSubmit(Request request) async {
    if (!config.adminEnabled) return errorResponse(404, 'not_found', 'Not found.');
    final clientKey = _clientKey(request);
    if (_adminFailLimiter.isLimited(clientKey)) {
      final wait = _adminFailLimiter.retryAfterSeconds(clientKey);
      return Response.found('/admin/login?locked=$wait');
    }
    Map<String, String> form = const {};
    try {
      form = Uri.splitQueryString(await request.readAsString());
    } catch (_) {}
    final provided = form['key'] ?? '';
    final match = constantTimeEquals(
        utf8.encode(provided), utf8.encode(config.adminKey!));
    if (!match) {
      _adminFailLimiter.allow(clientKey);
      return Response.found('/admin/login?failed=1');
    }

    return _establishAdminSession(Response.found('/admin'), request);
  }

  Response _adminLogout(Request request) {
    final token = _adminSessionToken(request);
    if (token != null) {
      _adminSessionExpiryByTokenHash
          .remove(c.sha256.convert(utf8.encode(token)).toString());
      _adminSessions.save(_adminSessionExpiryByTokenHash);
    }
    return Response.found('/admin/login', headers: {
      'Set-Cookie': '$_adminCookieName=; Path=/admin; HttpOnly; '
          'SameSite=Strict; Max-Age=0',
    });
  }

  // ---- Handlers: misc -----------------------------------------------------

  /// A friendly landing page. This server is an API, not a website — there is
  /// nothing to browse here; the luma app connects to it directly.
  Response _root(Request request) => Response.ok(
        '<!doctype html><html><head><meta charset="utf-8">'
        '<title>luma sync server</title>'
        '<style>body{background:#161320;color:#e8e4f3;font-family:system-ui,'
        'sans-serif;display:flex;min-height:100vh;margin:0;align-items:center;'
        'justify-content:center}main{max-width:420px;padding:32px;text-align:'
        'center}h1{font-size:20px;margin:0 0 8px}p{color:#a49fb8;line-height:'
        '1.5;font-size:14px}code{background:#241f33;padding:2px 6px;border-radius'
        ':6px}</style></head><body><main>'
        '<h1>luma sync server</h1>'
        '<p>It\'s running. This is an API for the luma app, not a website — '
        'open luma and add <code>${_originHint(request)}</code> as your server '
        'address under <b>Settings &rarr; Sync &amp; account</b>.</p>'
        '<p>Status: <code>/health</code></p>'
        '</main></body></html>',
        headers: {'Content-Type': 'text/html; charset=utf-8'},
      );

  /// Best-effort reconstruction of the URL the user reached us on, for the
  /// landing page hint.
  static String _originHint(Request request) {
    final host = request.headers['host'];
    if (host == null || host.isEmpty) return 'http://localhost:8080';
    // Behind Caddy the original scheme arrives here; default to http locally.
    final scheme = request.headers['x-forwarded-proto'] ??
        (host.startsWith('localhost') || host.startsWith('127.')
            ? 'http'
            : 'https');
    return '$scheme://$host';
  }

  Response _health(Request request) => jsonResponse(200, {
        'ok': true,
        'name': 'luma-sync-server',
        'registration': config.registrationEnabled ? 'open' : 'closed',
        'approval': config.approvalMode.name,
      });

  // ---- Handlers: auth -----------------------------------------------------

  /// Returns the client-side KDF parameters for an email. For unknown emails
  /// a stable fake salt is fabricated so accounts cannot be enumerated.
  Future<Response> _authParams(Request request) async {
    final body = await _readJson(request);
    final email = _normalizeEmail(body['email']);
    if (email == null) return errorResponse(400, 'bad_email', 'Invalid email.');

    final userId = store.userIdByEmail[email];
    final user = userId == null ? null : store.usersById[userId];
    if (user != null) {
      return jsonResponse(200, {
        'kdfSalt': user.kdfSalt,
        'kdfIterations': user.kdfIterations,
      });
    }
    final fake = c.Hmac(c.sha256, store.serverSecret)
        .convert(utf8.encode('kdf-salt:$email'))
        .bytes
        .sublist(0, 16);
    return jsonResponse(200, {
      'kdfSalt': base64Encode(fake),
      'kdfIterations': _defaultClientIterations,
    });
  }

  Future<Response> _register(Request request) async {
    if (!config.registrationEnabled) {
      return errorResponse(403, 'registration_closed',
          'This server does not accept new accounts.');
    }
    final body = await _readJson(request);

    final email = _normalizeEmail(body['email']);
    if (email == null) return errorResponse(400, 'bad_email', 'Invalid email.');

    final authKey = _decodeB64(body['authKey'], minLen: 32, maxLen: 64);
    if (authKey == null) {
      return errorResponse(400, 'bad_auth_key', 'Invalid auth key.');
    }
    final kdfSalt = _decodeB64(body['kdfSalt'], minLen: 16, maxLen: 64);
    if (kdfSalt == null) {
      return errorResponse(400, 'bad_kdf_salt', 'Invalid KDF salt.');
    }
    final iterations = body['kdfIterations'];
    if (iterations is! int || iterations < 50000 || iterations > 5000000) {
      return errorResponse(400, 'bad_kdf_iterations', 'Invalid KDF iterations.');
    }
    final deviceLabel = body['deviceLabel'] as String?;

    return store.lock.synchronized(() async {
      if (store.userIdByEmail.containsKey(email)) {
        return errorResponse(409, 'email_taken', 'An account already exists for this email.');
      }
      final authSalt = randomBytes(16);
      final authHash = await _hashAuthKey(authKey, authSalt);
      final mode = config.approvalMode;
      final user = StoredUser(
        id: base64UrlEncode(randomBytes(12)).replaceAll('=', ''),
        email: email,
        authHash: base64Encode(authHash),
        authSalt: base64Encode(authSalt),
        kdfSalt: base64Encode(kdfSalt),
        kdfIterations: iterations,
        // New accounts start on the free 'core' plan; quota comes from the
        // plan map, not LUMA_QUOTA_BYTES — see kPlanQuotaBytes.
        quotaBytes: kPlanQuotaBytes[kDefaultPlanId]!,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        status: mode.holdsNewAccounts ? 'pending' : 'active',
      );
      store.usersById[user.id] = user;
      store.userIdByEmail[email] = user.id;

      if (!mode.holdsNewAccounts) {
        await store.saveUsers();
        await store.logActivity('account_registered', '$email registered');
        final token = await _createSession(user, deviceLabel: deviceLabel);
        return jsonResponse(201, {
          'token': token.$1,
          'expiresAtMs': token.$2,
          'quotaBytes': user.quotaBytes,
          'approval': mode.name,
        });
      }

      if (mode == ApprovalMode.manual) {
        // Nothing to send and nothing for the user to do: the account sits
        // in 'pending' until the operator approves it from /admin.
        await store.saveUsers();
        await store.logActivity(
            'account_registered', '$email registered (awaiting approval)');
        return jsonResponse(201, {
          'status': 'pending_approval',
          'approval': mode.name,
          'message': 'Account created. It has to be approved by the server '
              'operator before you can sign in — no email needed, just try '
              'signing in once they have approved it.',
        });
      }

      final verificationToken = await _issueVerificationToken(user);
      await store.saveUsers();
      await store.logActivity(
          'account_registered', '$email registered (pending verification)');
      await _sendVerificationEmail(user, verificationToken);
      return jsonResponse(201, {
        'status': 'pending_approval',
        'approval': mode.name,
        'message':
            'Check your email to verify your account before signing in.',
      });
    });
  }

  Future<Response> _login(Request request) async {
    final body = await _readJson(request);
    final email = _normalizeEmail(body['email']);
    final authKey = _decodeB64(body['authKey'], minLen: 32, maxLen: 64);
    final deviceLabel = body['deviceLabel'] as String?;
    if (email == null || authKey == null) {
      return errorResponse(400, 'bad_request', 'Invalid email or auth key.');
    }

    // Refuse before doing any hashing work while this address is over its
    // failed-attempt budget. Keyed by email, not IP, so rotating IPs doesn't
    // buy an attacker more guesses at the same account.
    if (_loginFailLimiter.isLimited(email)) {
      return errorResponse(429, 'rate_limited',
          'Too many failed sign-in attempts for this account. Try again later.');
    }

    final userId = store.userIdByEmail[email];
    final user = userId == null ? null : store.usersById[userId];

    // Always burn the same hashing work so response timing does not reveal
    // whether the account exists.
    final salt = user != null
        ? Uint8List.fromList(base64Decode(user.authSalt))
        : randomBytes(16);
    final hash = await _hashAuthKey(authKey, salt);

    if (user == null ||
        !constantTimeEquals(hash, base64Decode(user.authHash))) {
      _loginFailLimiter.allow(email);
      return errorResponse(401, 'invalid_credentials', 'Wrong email or password.');
    }

    if (user.isPending) {
      return errorResponse(
          403,
          'account_pending_approval',
          config.approvalMode == ApprovalMode.email
              ? 'Please verify your email address before signing in.'
              : 'This account is waiting to be approved by the server '
                  'operator.');
    }

    return store.lock.synchronized(() async {
      final token = await _createSession(user, deviceLabel: deviceLabel);
      user.lastLoginAtMs = DateTime.now().millisecondsSinceEpoch;
      await store.saveUsers();
      await store.logActivity('login', '${user.email} logged in');
      return jsonResponse(200, {
        'token': token.$1,
        'expiresAtMs': token.$2,
        'quotaBytes': user.quotaBytes,
      });
    });
  }

  // ---- Handlers: sign in with Google / GitHub -----------------------------

  /// Which providers this deployment has credentials for. Called before the
  /// sign-in screen is drawn, so an operator who configured neither simply
  /// never sees the buttons.
  Response _oauthProviders(Request request) => jsonResponse(200, {
        'providers': config.enabledOAuthProviders
            .map((spec) => {'id': spec.id, 'name': spec.displayName})
            .toList(),
      });

  /// Opens a flow: returns the provider URL for the app to hand to the
  /// system browser, plus the private ticket it polls with.
  Future<Response> _oauthStart(Request request) async {
    final body = await _readJson(request);
    final spec = OAuthProviderSpec.byId(body['provider'] as String?);
    final providerConfig =
        spec == null ? null : config.oauthProviders[spec.id];
    if (spec == null || providerConfig == null || !providerConfig.configured) {
      return errorResponse(400, 'unknown_provider',
          'This server is not set up for that sign-in method.');
    }
    final OAuthFlow flow;
    final String ticket;
    try {
      (flow, ticket) = _oauthFlows.create(spec.id);
    } on OAuthException catch (e) {
      return errorResponse(503, 'oauth_busy', e.message);
    }
    final authUrl = Uri.parse(spec.authorizeUrl).replace(queryParameters: {
      'client_id': providerConfig.clientId,
      'redirect_uri': config.oauthRedirectUri(spec.id),
      'response_type': 'code',
      'scope': spec.scope,
      'state': flow.state,
      ...spec.extraAuthorizeParams,
    });
    return jsonResponse(200, {
      'ticket': ticket,
      'authUrl': authUrl.toString(),
      'expiresInSeconds': OAuthFlow.ttl.inSeconds,
    });
  }

  /// Where the provider sends the browser back. Swaps the code for a
  /// verified email, parks the result on the flow, and renders a page the
  /// user can close — the app is polling and picks it up from there.
  Future<Response> _oauthCallback(Request request) async {
    final spec = OAuthProviderSpec.byId(request.params['provider']);
    final providerConfig =
        spec == null ? null : config.oauthProviders[spec.id];
    if (spec == null || providerConfig == null || !providerConfig.configured) {
      return _verifyPage(404, 'Unknown sign-in provider.');
    }
    final query = request.url.queryParameters;
    final flow = _oauthFlows.byState(query['state']);
    if (flow == null || flow.provider != spec.id) {
      return _verifyPage(400,
          'This sign-in link has expired. Start again from the luma app.');
    }
    if (query['error'] != null) {
      flow.error = 'Sign-in was cancelled at ${spec.displayName}.';
      return _verifyPage(400, flow.error!);
    }
    final code = query['code'];
    if (code == null || code.isEmpty) {
      flow.error = '${spec.displayName} did not return an authorization code.';
      return _verifyPage(400, flow.error!);
    }

    final OAuthIdentity identity;
    try {
      identity = await _oauthClient.fetchIdentity(
        spec: spec,
        config: providerConfig,
        code: code,
        redirectUri: config.oauthRedirectUri(spec.id),
      );
    } on OAuthException catch (e) {
      flow.error = e.message;
      return _verifyPage(502, e.message);
    } catch (_) {
      flow.error = 'Could not complete sign-in with ${spec.displayName}.';
      return _verifyPage(502, flow.error!);
    }

    return store.lock.synchronized(() async {
      // A previously linked identity wins over the address: someone who
      // changed their email at the provider still lands on their own
      // account rather than creating a second one (or, worse, being handed
      // whoever now owns the old address).
      final linkedId =
          store.userIdByOAuth[Store.oauthKey(spec.id, identity.subject)];
      final user = store.usersById[linkedId] ??
          store.usersById[store.userIdByEmail[identity.email]];

      if (user == null && !config.registrationEnabled) {
        flow.error = 'This server does not accept new accounts.';
        return _verifyPage(403, flow.error!);
      }

      flow.identity = identity;
      if (user != null) {
        // Matching an existing account by verified email is exactly what
        // links the provider to it, so an account made with an email and
        // password can be signed into with the button from then on.
        store.linkOAuthIdentity(user, spec.id, identity.subject);
        await store.saveUsers();
        flow
          ..existingAccount = true
          ..kdfSalt = user.kdfSalt
          ..kdfIterations = user.kdfIterations;
      }
      return _verifyPage(
        200,
        'Signed in as ${identity.email}. You can close this window and go '
        'back to luma.',
      );
    });
  }

  /// Tells the app whether the browser half has landed yet. Requires the
  /// ticket, so knowing a state (which is visible in the browser) is not
  /// enough to learn the email address behind a flow.
  Future<Response> _oauthPoll(Request request) async {
    final body = await _readJson(request);
    final flow = _oauthFlows.byTicket(body['ticket'] as String?);
    if (flow == null) {
      return jsonResponse(200, {
        'status': 'error',
        'message': 'This sign-in attempt expired. Please try again.',
      });
    }
    if (flow.error != null) {
      _oauthFlows.remove(flow);
      return jsonResponse(200, {'status': 'error', 'message': flow.error});
    }
    if (!flow.ready) return jsonResponse(200, {'status': 'pending'});
    return jsonResponse(200, {
      'status': 'ready',
      'provider': flow.provider,
      'email': flow.identity!.email,
      'displayName': flow.identity!.displayName,
      'existingAccount': flow.existingAccount,
      if (flow.kdfSalt != null) 'kdfSalt': flow.kdfSalt,
      if (flow.kdfIterations != null) 'kdfIterations': flow.kdfIterations,
    });
  }

  /// Finishes the sign-in. The provider settled *who* the user is; this is
  /// where they prove they hold the passphrase that decrypts their data —
  /// the server never learns it, only the derived auth key, exactly as with
  /// [_login]. For a brand new account the supplied key and KDF parameters
  /// become the account's, which is what makes the passphrase step on first
  /// sign-in unskippable.
  Future<Response> _oauthComplete(Request request) async {
    final body = await _readJson(request);
    final flow = _oauthFlows.byTicket(body['ticket'] as String?);
    if (flow == null || !flow.ready) {
      return errorResponse(400, 'oauth_expired',
          'This sign-in attempt expired. Please try again.');
    }
    final authKey = _decodeB64(body['authKey'], minLen: 32, maxLen: 64);
    if (authKey == null) {
      return errorResponse(400, 'bad_auth_key', 'Invalid auth key.');
    }
    final identity = flow.identity!;
    final deviceLabel = body['deviceLabel'] as String?;
    final spec = OAuthProviderSpec.byId(flow.provider)!;

    return store.lock.synchronized(() async {
      final linkedId =
          store.userIdByOAuth[Store.oauthKey(flow.provider, identity.subject)];
      final existing = store.usersById[linkedId] ??
          store.usersById[store.userIdByEmail[identity.email]];

      if (existing != null) {
        final hash = await _hashAuthKey(
            authKey, Uint8List.fromList(base64Decode(existing.authSalt)));
        if (!constantTimeEquals(hash, base64Decode(existing.authHash))) {
          flow.attempts++;
          if (flow.attempts >= OAuthFlow.maxAttempts) {
            _oauthFlows.remove(flow);
            return errorResponse(429, 'too_many_attempts',
                'Too many wrong passphrases. Start the sign-in again.');
          }
          return errorResponse(401, 'invalid_credentials',
              'That passphrase does not match this account.');
        }
        if (existing.isPending) {
          // The provider vouched for the address, which is precisely what an
          // email-verification link was there to establish — so accept it in
          // that mode. Under manual approval the operator's decision is the
          // gate, and no provider substitutes for it.
          if (config.approvalMode == ApprovalMode.email) {
            existing.status = 'active';
            existing.verificationTokenHash = null;
            existing.verificationExpiresAtMs = null;
            await store.logActivity('account_verified',
                '${existing.email} verified via ${spec.displayName}');
          } else {
            return errorResponse(
                403,
                'account_pending_approval',
                'This account is waiting to be approved by the server '
                    'operator.');
          }
        }
        store.linkOAuthIdentity(existing, flow.provider, identity.subject);
        _oauthFlows.remove(flow);
        final token = await _createSession(existing, deviceLabel: deviceLabel);
        existing.lastLoginAtMs = DateTime.now().millisecondsSinceEpoch;
        await store.saveUsers();
        await store.logActivity('login',
            '${existing.email} logged in with ${spec.displayName}');
        return jsonResponse(200, {
          'token': token.$1,
          'expiresAtMs': token.$2,
          'quotaBytes': existing.quotaBytes,
          'email': existing.email,
        });
      }

      // ---- New account ----------------------------------------------------
      if (!config.registrationEnabled) {
        return errorResponse(403, 'registration_closed',
            'This server does not accept new accounts.');
      }
      final kdfSalt = _decodeB64(body['kdfSalt'], minLen: 16, maxLen: 64);
      if (kdfSalt == null) {
        return errorResponse(400, 'bad_kdf_salt', 'Invalid KDF salt.');
      }
      final iterations = body['kdfIterations'];
      if (iterations is! int || iterations < 50000 || iterations > 5000000) {
        return errorResponse(400, 'bad_kdf_iterations', 'Invalid KDF iterations.');
      }
      final authSalt = randomBytes(16);
      // Under manual approval a new account still waits for the operator;
      // the provider only proves the address is real, not that this
      // deployment wants the person behind it.
      final pending = config.approvalMode == ApprovalMode.manual;
      final user = StoredUser(
        id: base64UrlEncode(randomBytes(12)).replaceAll('=', ''),
        email: identity.email,
        authHash: base64Encode(await _hashAuthKey(authKey, authSalt)),
        authSalt: base64Encode(authSalt),
        kdfSalt: base64Encode(kdfSalt),
        kdfIterations: iterations,
        quotaBytes: kPlanQuotaBytes[kDefaultPlanId]!,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        status: pending ? 'pending' : 'active',
      );
      store.usersById[user.id] = user;
      store.userIdByEmail[user.email] = user.id;
      store.linkOAuthIdentity(user, flow.provider, identity.subject);
      await store.saveUsers();

      if (pending) {
        // The account exists now, so this flow can never complete — a retry
        // on it would only fail the pending check.
        _oauthFlows.remove(flow);
        await store.logActivity('account_registered',
            '${user.email} registered with ${spec.displayName} '
            '(awaiting approval)');
        return jsonResponse(201, {
          'status': 'pending_approval',
          'approval': config.approvalMode.name,
          'message': 'Account created with ${spec.displayName}. It has to be '
              'approved by the server operator before you can sign in.',
        });
      }
      _oauthFlows.remove(flow);
      await store.logActivity('account_registered',
          '${user.email} registered with ${spec.displayName}');
      final token = await _createSession(user, deviceLabel: deviceLabel);
      return jsonResponse(201, {
        'token': token.$1,
        'expiresAtMs': token.$2,
        'quotaBytes': user.quotaBytes,
        'email': user.email,
      });
    });
  }

  /// Lists this account's active (non-expired) sessions, newest first, with
  /// the caller's own session flagged via `isCurrent` so the UI can show
  /// "This device" and disable revoking it (use Sign out for that instead).
  Response _listSessions(Request request, StoredUser user) {
    final auth = request.headers['authorization']!;
    final currentTokenHash =
        c.sha256.convert(utf8.encode(auth.substring(7).trim())).toString();
    final now = DateTime.now().millisecondsSinceEpoch;
    final sessions = store.sessionsByTokenHash.values
        .where((s) => s.userId == user.id && s.expiresAtMs > now)
        .toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return jsonResponse(200, {
      'sessions': sessions
          .map((s) => {
                'id': s.tokenHash,
                'deviceLabel': s.deviceLabel,
                'createdAtMs': s.createdAtMs,
                'expiresAtMs': s.expiresAtMs,
                'isCurrent': s.tokenHash == currentTokenHash,
              })
          .toList(),
    });
  }

  /// Revokes one of the caller's own sessions by id (its tokenHash). Revoking
  /// the current session is rejected — use /auth/logout for that, which also
  /// clears the client's local token.
  Future<Response> _revokeSession(Request request, StoredUser user) async {
    final id = request.params['id']!;
    final auth = request.headers['authorization']!;
    final currentTokenHash =
        c.sha256.convert(utf8.encode(auth.substring(7).trim())).toString();
    if (id == currentTokenHash) {
      return errorResponse(400, 'cannot_revoke_current',
          'Cannot revoke the session you are currently using — sign out instead.');
    }
    return store.lock.synchronized(() async {
      final session = store.sessionsByTokenHash[id];
      if (session == null || session.userId != user.id) {
        return errorResponse(404, 'not_found', 'Session not found.');
      }
      store.sessionsByTokenHash.remove(id);
      await store.saveSessions();
      return jsonResponse(200, {'ok': true});
    });
  }

  /// Confirms a pending account from the link sent by [_sendVerificationEmail].
  /// Returns a small HTML page (the user opens this in a browser from their
  /// email client, not the app) mirroring the style of [_root].
  Future<Response> _verify(Request request) async {
    // In manual (or open) mode no verification links are ever issued, so
    // this endpoint must be inert — it is the only path that could flip an
    // account to 'active' without the operator pressing Approve.
    if (config.approvalMode != ApprovalMode.email) {
      return _verifyPage(403,
          'This server approves accounts by hand from the admin dashboard — '
          'email verification links are not used here.');
    }
    final token = request.url.queryParameters['token'];
    if (token == null || token.isEmpty) {
      return _verifyPage(400, 'Missing verification token.');
    }
    final tokenHash = c.sha256.convert(utf8.encode(token)).toString();

    return store.lock.synchronized(() async {
      StoredUser? user;
      for (final u in store.usersById.values) {
        final candidate = u.verificationTokenHash;
        if (candidate != null &&
            constantTimeEquals(
                utf8.encode(candidate), utf8.encode(tokenHash))) {
          user = u;
          break;
        }
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      if (user == null) {
        return _verifyPage(
            400, 'This verification link is invalid or has already been used.');
      }
      if ((user.verificationExpiresAtMs ?? 0) <= now) {
        return _verifyPage(400,
            'This verification link has expired. Request a new one from the app.');
      }
      user.status = 'active';
      user.verificationTokenHash = null;
      user.verificationExpiresAtMs = null;
      await store.saveUsers();
      await store.logActivity('account_verified', '${user.email} verified their email');
      return _verifyPage(
          200, 'Your email is verified. You can return to the app and sign in.');
    });
  }

  /// Re-sends the verification email. Responds identically whether or not
  /// the address is registered, so this cannot be used to enumerate accounts.
  Future<Response> _resendVerification(Request request) async {
    final body = await _readJson(request);
    final email = _normalizeEmail(body['email']);
    if (email == null) return errorResponse(400, 'bad_email', 'Invalid email.');

    if (config.approvalMode != ApprovalMode.email) {
      // No link exists to resend. Answered the same way for every address,
      // so this still says nothing about whether the account exists.
      return jsonResponse(200, {
        'status': 'pending_approval',
        'approval': config.approvalMode.name,
        'message': config.approvalMode == ApprovalMode.manual
            ? 'This server approves accounts by hand — there is no email to '
                'resend. The operator will approve it.'
            : 'This server does not require approval; just sign in.',
      });
    }

    if (!_resendLimiter.allow(email)) {
      return errorResponse(429, 'rate_limited',
          'Too many verification requests for this address. Try again later.');
    }

    const genericResponse = {
      'status': 'pending_verification',
      'message':
          'If that email has an unverified account, we just sent a new '
              'verification link.',
    };

    return store.lock.synchronized(() async {
      final userId = store.userIdByEmail[email];
      final user = userId == null ? null : store.usersById[userId];
      if (user == null || !user.isPending) {
        return jsonResponse(200, genericResponse);
      }
      final verificationToken = await _issueVerificationToken(user);
      await store.saveUsers();
      await _sendVerificationEmail(user, verificationToken);
      return jsonResponse(200, genericResponse);
    });
  }

  Response _verifyPage(int status, String message) => Response(
        status,
        body: '<!doctype html><html><head><meta charset="utf-8">'
            '<title>luma sync server</title>'
            '<style>body{background:#161320;color:#e8e4f3;font-family:system-ui,'
            'sans-serif;display:flex;min-height:100vh;margin:0;align-items:center;'
            'justify-content:center}main{max-width:420px;padding:32px;text-align:'
            'center}h1{font-size:20px;margin:0 0 8px}p{color:#a49fb8;line-height:'
            '1.5;font-size:14px}</style></head><body><main>'
            '<h1>luma sync server</h1>'
            '<p>${_htmlEscape(message)}</p>'
            '</main></body></html>',
        headers: {'Content-Type': 'text/html; charset=utf-8'},
      );

  static String _htmlEscape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  Future<Response> _logout(Request request, StoredUser user) async {
    final auth = request.headers['authorization']!;
    final tokenHash =
        c.sha256.convert(utf8.encode(auth.substring(7).trim())).toString();
    return store.lock.synchronized(() async {
      store.sessionsByTokenHash.remove(tokenHash);
      await store.saveSessions();
      return jsonResponse(200, {'ok': true});
    });
  }

  /// Rotates the account credentials. The client is expected to re-upload
  /// its blobs afterwards (they are encrypted under a key derived from the
  /// old password). All other sessions are revoked.
  Future<Response> _changePassword(Request request, StoredUser user) async {
    final body = await _readJson(request);
    final current = _decodeB64(body['currentAuthKey'], minLen: 32, maxLen: 64);
    final next = _decodeB64(body['newAuthKey'], minLen: 32, maxLen: 64);
    final newSalt = _decodeB64(body['newKdfSalt'], minLen: 16, maxLen: 64);
    final iterations = body['newKdfIterations'];
    if (current == null ||
        next == null ||
        newSalt == null ||
        iterations is! int ||
        iterations < 50000 ||
        iterations > 5000000) {
      return errorResponse(400, 'bad_request', 'Invalid change-password payload.');
    }

    final currentHash =
        await _hashAuthKey(current, Uint8List.fromList(base64Decode(user.authSalt)));
    if (!constantTimeEquals(currentHash, base64Decode(user.authHash))) {
      return errorResponse(401, 'invalid_credentials', 'Current password is wrong.');
    }

    final auth = request.headers['authorization']!;
    final keepTokenHash =
        c.sha256.convert(utf8.encode(auth.substring(7).trim())).toString();

    return store.lock.synchronized(() async {
      final authSalt = randomBytes(16);
      user.authSalt = base64Encode(authSalt);
      user.authHash = base64Encode(await _hashAuthKey(next, authSalt));
      user.kdfSalt = base64Encode(newSalt);
      user.kdfIterations = iterations;
      store.sessionsByTokenHash.removeWhere(
          (hash, s) => s.userId == user.id && hash != keepTokenHash);
      await store.saveUsers();
      await store.saveSessions();
      return jsonResponse(200, {'ok': true});
    });
  }

  Future<Response> _deleteAccount(Request request, StoredUser user) async {
    final body = await _readJson(request);
    final authKey = _decodeB64(body['authKey'], minLen: 32, maxLen: 64);
    if (authKey == null) {
      return errorResponse(400, 'bad_request', 'Auth key required to delete account.');
    }
    final hash = await _hashAuthKey(
        authKey, Uint8List.fromList(base64Decode(user.authSalt)));
    if (!constantTimeEquals(hash, base64Decode(user.authHash))) {
      return errorResponse(401, 'invalid_credentials', 'Wrong password.');
    }
    return store.lock.synchronized(() async {
      final email = user.email;
      store.usersById.remove(user.id);
      store.userIdByEmail.remove(user.email.toLowerCase());
      store.unlinkAllOAuthIdentities(user);
      store.sessionsByTokenHash.removeWhere((_, s) => s.userId == user.id);
      store.collectionsByUser.remove(user.id);
      await store.deleteUserData(user.id);
      await store.saveUsers();
      await store.saveSessions();
      await store.saveCollections();
      await store.logActivity('account_deleted', '$email deleted their account');
      return jsonResponse(200, {'ok': true});
    });
  }

  // ---- Handlers: AI ---------------------------------------------------------

  /// Whether the operator has configured a shared Mistral key
  /// (LUMA_MISTRAL_API_KEY) — status only, never the key itself. Lets the
  /// app show "a key is available" in Settings without exposing the secret;
  /// the actual key is only ever used server-side, by [_mistralChatProxy].
  Response _mistralKeyStatus(Request request, StoredUser user) =>
      jsonResponse(200, {'configured': config.mistralKeyConfigured});

  /// Which shared AI keys the operator has configured, plus this user's
  /// usage — expressed only as percentages / message counts, never raw
  /// token numbers (the budgets are a server-side implementation detail).
  Response _aiStatus(Request request, StoredUser user) {
    int pct(int used, int limit) =>
        ((used * 100) / limit).clamp(0, 100).round();
    return jsonResponse(200, {
      'mistralConfigured': config.mistralKeyConfigured,
      'googleConfigured': config.googleKeyConfigured,
      'usage': {
        'fiveHourPct':
            pct(aiUsage.tokensUsed(user.id, const Duration(hours: 5)), kAiTokens5h),
        'weeklyPct':
            pct(aiUsage.tokensUsed(user.id, const Duration(days: 7)), kAiTokensWeek),
        'supportUsed': aiUsage.supportMessagesUsed(user.id),
        'supportLimit': kSupportMessagesPerDay,
      },
    });
  }

  /// The app's user-facing "Luma AI" modes and the Gemini model each maps
  /// to. Clients only ever send the mode name; the real model names stay
  /// server-side so they can be upgraded without an app release.
  ///
  /// Uses Google's rolling "-latest" aliases, not a pinned version like
  /// "gemini-2.5-flash" — pinned versions get retired for newer API
  /// keys/projects (404 "no longer available to new users") even while
  /// still listed in /v1beta/openai/models. The aliases always resolve to
  /// whatever Google currently serves for that tier.
  ///
  /// Pulsar shares Nebula's Flash model rather than a Pro one — free-tier
  /// API keys get a hard `limit: 0` quota on every Pro-tier model
  /// (confirmed directly against the API), so Pro isn't usable without
  /// billing enabled on the key's project. Pulsar's "smartest" distinction
  /// instead comes from the client sending `reasoning_effort: "high"`
  /// (see AiMode.reasoningEffort), which this proxy forwards unchanged —
  /// it only overrides `model`/`max_tokens` below, everything else in the
  /// client's request body passes straight through to Google.
  static const _googleModeModels = {
    'normal': 'gemini-flash-lite-latest', // Aurora 1.0
    'smarter': 'gemini-flash-latest', // Nebula 1.0
    'smartest': 'gemini-flash-latest', // Pulsar 1.0 — same model, forced high reasoning effort
  };

  /// Proxies a chat-completion request to Google AI Studio's
  /// OpenAI-compatible endpoint using the operator-configured
  /// LUMA_GOOGLE_API_KEY — same trust model as [_mistralChatProxy]: the key
  /// never leaves this server. Each user is token-metered against rolling
  /// 5-hour and weekly budgets ([kAiTokens5h]/[kAiTokensWeek]) using the
  /// exact `usage.total_tokens` Google reports per call.
  Future<Response> _googleChatProxy(Request request, StoredUser user) async {
    if (!config.googleKeyConfigured) {
      return errorResponse(404, 'not_configured',
          'No server-wide Google AI key is configured.');
    }
    Map<String, dynamic> body;
    try {
      body = await _readJson(request);
    } on FormatException {
      return errorResponse(400, 'bad_request', 'Malformed request.');
    }
    if (body['messages'] is! List) {
      return errorResponse(400, 'bad_request', 'messages is required.');
    }
    if (aiUsage.tokensUsed(user.id, const Duration(hours: 5)) >= kAiTokens5h) {
      return errorResponse(429, 'usage_limit',
          "You've hit your assistant usage limit for now — it frees up again "
          'over the next few hours.');
    }
    if (aiUsage.tokensUsed(user.id, const Duration(days: 7)) >= kAiTokensWeek) {
      return errorResponse(429, 'usage_limit',
          "You've hit your weekly assistant usage limit — it frees up again "
          'over the coming days.');
    }

    final model = _googleModeModels[body['model']] ??
        _googleModeModels['normal']!;
    final maxTokensRaw = body['max_tokens'];
    final upstreamBody = {
      ...body,
      'model': model,
      'max_tokens': (maxTokensRaw is int ? maxTokensRaw : 1024).clamp(1, 4096),
    }..remove('agent_id');

    final httpClient = HttpClient();
    try {
      final upstreamRequest = await httpClient.postUrl(Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions'));
      upstreamRequest.headers
          .set(HttpHeaders.authorizationHeader, 'Bearer ${config.googleApiKey}');
      upstreamRequest.headers.contentType = ContentType.json;
      upstreamRequest.write(jsonEncode(upstreamBody));
      final upstreamResponse =
          await upstreamRequest.close().timeout(const Duration(seconds: 60));
      final responseBody =
          await upstreamResponse.transform(utf8.decoder).join();
      if (upstreamResponse.statusCode == 200) {
        var tokens = 0;
        try {
          final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
          tokens = (decoded['usage']?['total_tokens'] as num?)?.toInt() ?? 0;
        } catch (_) {}
        // If Google somehow omits usage, charge a conservative flat amount
        // so metering can't be sidestepped by malformed responses.
        await aiUsage.recordTokens(user.id, tokens > 0 ? tokens : 500);
      }
      return Response(upstreamResponse.statusCode,
          body: responseBody, headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return errorResponse(502, 'upstream_error', 'Could not reach the AI service.');
    } finally {
      httpClient.close();
    }
  }

  Response _itadStatus(Request request, StoredUser user) =>
      jsonResponse(200, {'configured': config.itadKeyConfigured});

  /// A Steam app id has no meaning to IsThereAnyDeal — it identifies games by
  /// its own id, resolved once here and then cached client-side.
  Future<Response> _itadLookupProxy(Request request, StoredUser user) async {
    if (!config.itadKeyConfigured) {
      return errorResponse(404, 'not_configured',
          'No server-wide IsThereAnyDeal key is configured.');
    }
    final appId = int.tryParse(request.url.queryParameters['appid'] ?? '');
    if (appId == null) {
      return errorResponse(
          400, 'bad_request', 'appid must be a Steam app id.');
    }
    return _forwardToItad(
      Uri.https('api.isthereanydeal.com', '/games/lookup/v1', {
        'key': config.itadApiKey,
        'appid': '$appId',
      }),
    );
  }

  /// Every Steam price change IsThereAnyDeal has on file for one game.
  Future<Response> _itadHistoryProxy(Request request, StoredUser user) async {
    if (!config.itadKeyConfigured) {
      return errorResponse(404, 'not_configured',
          'No server-wide IsThereAnyDeal key is configured.');
    }
    final id = request.url.queryParameters['id'] ?? '';
    if (!_itadIdPattern.hasMatch(id)) {
      return errorResponse(
          400, 'bad_request', 'id must be an IsThereAnyDeal game id.');
    }
    return _forwardToItad(
      Uri.https('api.isthereanydeal.com', '/games/history/v2', {
        'key': config.itadApiKey,
        'id': id,
        'country': _sanitizeCountry(request.url.queryParameters['country']),
      }),
    );
  }

  /// Current price and all-time low for up to a handful of games at once.
  Future<Response> _itadOverviewProxy(Request request, StoredUser user) async {
    if (!config.itadKeyConfigured) {
      return errorResponse(404, 'not_configured',
          'No server-wide IsThereAnyDeal key is configured.');
    }
    Object? body;
    try {
      body = jsonDecode(await request.readAsString());
    } catch (_) {
      return errorResponse(400, 'bad_request', 'Malformed request body.');
    }
    // Kept narrow on purpose: this exists to answer "what does this one game
    // cost", not to become a general-purpose batch passthrough to ITAD.
    if (body is! List ||
        body.isEmpty ||
        body.length > 5 ||
        body.any((e) => e is! String || !_itadIdPattern.hasMatch(e))) {
      return errorResponse(400, 'bad_request',
          'Body must be a JSON array of 1-5 IsThereAnyDeal game ids.');
    }
    return _forwardToItad(
      Uri.https('api.isthereanydeal.com', '/games/overview/v2', {
        'key': config.itadApiKey,
        'country': _sanitizeCountry(request.url.queryParameters['country']),
      }),
      body: jsonEncode(body),
    );
  }

  static final _itadIdPattern = RegExp(r'^[0-9a-fA-F-]{8,40}$');

  String _sanitizeCountry(String? raw) {
    final upper = (raw ?? 'US').toUpperCase();
    return RegExp(r'^[A-Z]{2}$').hasMatch(upper) ? upper : 'US';
  }

  /// Shared GET/POST forwarder for the three ITAD proxy endpoints above:
  /// same upstream host, same timeout, same "pass the status and body
  /// straight through" behaviour as the AI chat proxies. IsThereAnyDeal's
  /// response shape is untouched, so the client's existing parsing keeps
  /// working unchanged — only the URL and the (now server-held) key moved.
  Future<Response> _forwardToItad(Uri upstream, {String? body}) async {
    final httpClient = HttpClient();
    try {
      final upstreamRequest = body == null
          ? await httpClient.getUrl(upstream)
          : await httpClient.postUrl(upstream);
      if (body != null) {
        upstreamRequest.headers.contentType = ContentType.json;
        upstreamRequest.write(body);
      }
      final upstreamResponse =
          await upstreamRequest.close().timeout(const Duration(seconds: 30));
      final responseBody =
          await upstreamResponse.transform(utf8.decoder).join();
      return Response(upstreamResponse.statusCode,
          body: responseBody, headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return errorResponse(
          502, 'upstream_error', 'Could not reach IsThereAnyDeal.');
    } finally {
      httpClient.close();
    }
  }

  /// Proxies a chat-completion request to Mistral using the
  /// operator-configured LUMA_MISTRAL_API_KEY, so signed-in users can chat
  /// through the shared key without it ever being sent to any client — only
  /// the caller's own bearer token (already required by [_requireAuth])
  /// leaves their device. The request body is forwarded to Mistral almost
  /// unchanged (same shape [OpenAiCompatibleClient] sends for a direct call:
  /// `model`/`agent_id`, `messages`, `max_tokens`, `tools`); only
  /// `max_tokens` is clamped, since callers no longer hold the key that
  /// would otherwise cap their own spend.
  Future<Response> _mistralChatProxy(Request request, StoredUser user) async {
    if (!config.mistralKeyConfigured) {
      return errorResponse(404, 'not_configured',
          'No server-wide Mistral API key is configured.');
    }
    Map<String, dynamic> body;
    try {
      body = await _readJson(request);
    } on FormatException {
      return errorResponse(400, 'bad_request', 'Malformed request.');
    }
    if (body['messages'] is! List) {
      return errorResponse(400, 'bad_request', 'messages is required.');
    }
    // One "support message" = one user turn. A single turn can trigger
    // several upstream calls when the model uses tools (the follow-up calls
    // end with a 'tool' role message), so only count calls that end with a
    // fresh user message.
    final messages = body['messages'] as List;
    final lastMessage = messages.isNotEmpty && messages.last is Map
        ? messages.last as Map
        : null;
    final isNewUserTurn = lastMessage?['role'] == 'user';
    if (isNewUserTurn &&
        aiUsage.supportMessagesUsed(user.id) >= kSupportMessagesPerDay) {
      return errorResponse(429, 'usage_limit',
          "You've used all $kSupportMessagesPerDay Luma Support messages for "
          'today — more tomorrow.');
    }
    final maxTokensRaw = body['max_tokens'];
    final upstreamBody = {
      ...body,
      'max_tokens': (maxTokensRaw is int ? maxTokensRaw : 1024).clamp(1, 4096),
    };
    // When the operator configured a hosted agent (LUMA_MISTRAL_AGENT_ID)
    // and the caller didn't pick their own, route through that agent. The
    // agents endpoint derives the model from the agent, so `model` must go.
    if (upstreamBody['agent_id'] is! String && config.mistralAgentConfigured) {
      upstreamBody['agent_id'] = config.mistralAgentId;
      upstreamBody.remove('model');
    }
    final url = upstreamBody['agent_id'] is String
        ? 'https://api.mistral.ai/v1/agents/completions'
        : 'https://api.mistral.ai/v1/chat/completions';

    final httpClient = HttpClient();
    try {
      final upstreamRequest = await httpClient.postUrl(Uri.parse(url));
      upstreamRequest.headers
          .set(HttpHeaders.authorizationHeader, 'Bearer ${config.mistralApiKey}');
      upstreamRequest.headers.contentType = ContentType.json;
      upstreamRequest.write(jsonEncode(upstreamBody));
      final upstreamResponse =
          await upstreamRequest.close().timeout(const Duration(seconds: 30));
      final responseBody =
          await upstreamResponse.transform(utf8.decoder).join();
      if (upstreamResponse.statusCode == 200 && isNewUserTurn) {
        await aiUsage.recordSupportMessage(user.id);
      }
      return Response(upstreamResponse.statusCode,
          body: responseBody, headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return errorResponse(502, 'upstream_error', 'Could not reach Mistral.');
    } finally {
      httpClient.close();
    }
  }

  // ---- Handlers: account & sync -------------------------------------------

  Response _accountInfo(Request request, StoredUser user) {
    final collections = store.collectionsByUser[user.id] ?? const {};
    return jsonResponse(200, {
      'email': user.email,
      'usedBytes': store.usedBytes(user.id),
      'quotaBytes': user.quotaBytes,
      'planId': user.planId,
      // Ids only ('google', 'github') — never the provider-side subject.
      'linkedProviders': user.oauthSubjects.keys.toList()..sort(),
      // The client mirrors this into its own server-access gate: an account
      // that is back to 'pending' stops talking to the server until it is
      // approved again (see ServerAccessGate in the app).
      'status': user.status,
      'collections': collections.values.map((m) => m.toJson()).toList(),
    });
  }

  Future<Response> _getBlob(Request request, StoredUser user) async {
    final name = request.params['collection']!;
    if (!collectionPattern.hasMatch(name)) {
      return errorResponse(400, 'bad_collection', 'Invalid collection name.');
    }
    final meta = store.collectionsByUser[user.id]?[name];
    final bytes = meta == null ? null : await store.readBlob(user.id, name);
    if (meta == null || bytes == null) {
      return errorResponse(404, 'not_found', 'No data for this collection.');
    }
    return Response(200, body: bytes, headers: {
      'Content-Type': 'application/octet-stream',
      'X-Version': '${meta.version}',
      'X-Payload-Saved-At': '${meta.payloadSavedAtMs}',
    });
  }

  Future<Response> _putBlob(Request request, StoredUser user) async {
    final name = request.params['collection']!;
    if (!collectionPattern.hasMatch(name)) {
      return errorResponse(400, 'bad_collection', 'Invalid collection name.');
    }
    final baseVersion =
        int.tryParse(request.headers['x-base-version'] ?? '') ?? -1;
    final savedAtMs =
        int.tryParse(request.headers['x-payload-saved-at'] ?? '') ??
            DateTime.now().millisecondsSinceEpoch;
    if (baseVersion < 0) {
      return errorResponse(400, 'bad_version', 'X-Base-Version header required.');
    }

    // Read the body with a hard cap so oversized uploads cannot exhaust RAM.
    // The cap is the smaller of the global per-upload limit and what this
    // user's quota could possibly accept (replacing their existing blob), so
    // a 5 MB-quota account can't buffer 256 MB into memory per request. The
    // authoritative quota check still happens under the lock below.
    final existingSize =
        store.collectionsByUser[user.id]?[name]?.size ?? 0;
    final quotaHeadroom =
        user.quotaBytes - store.usedBytes(user.id) + existingSize;
    final cap = quotaHeadroom < config.maxBlobBytes
        ? quotaHeadroom
        : config.maxBlobBytes;
    if (cap <= 0) {
      return errorResponse(413, 'quota_exceeded',
          'Storage quota exceeded (${user.quotaBytes} bytes).');
    }
    final declared = request.contentLength ?? -1;
    if (declared > cap) {
      return errorResponse(413, 'blob_too_large',
          'Snapshot exceeds the allowed upload size of $cap bytes.');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request.read()) {
      builder.add(chunk);
      if (builder.length > cap) {
        return errorResponse(413, 'blob_too_large',
            'Snapshot exceeds the allowed upload size of $cap bytes.');
      }
    }
    final bytes = builder.takeBytes();
    if (bytes.isEmpty) {
      return errorResponse(400, 'empty_body', 'Empty snapshot rejected.');
    }

    return store.lock.synchronized(() async {
      final perUser =
          store.collectionsByUser.putIfAbsent(user.id, () => {});
      final existing = perUser[name];
      final currentVersion = existing?.version ?? 0;

      if (baseVersion != currentVersion) {
        return errorResponse(409, 'version_conflict', 'Server has a newer snapshot.',
            extra: {
              'version': currentVersion,
              'payloadSavedAtMs': existing?.payloadSavedAtMs ?? 0,
            });
      }

      final newUsed =
          store.usedBytes(user.id) - (existing?.size ?? 0) + bytes.length;
      if (newUsed > user.quotaBytes) {
        return errorResponse(413, 'quota_exceeded',
            'Storage quota exceeded (${user.quotaBytes} bytes).',
            extra: {
              'usedBytes': store.usedBytes(user.id),
              'quotaBytes': user.quotaBytes,
            });
      }

      await store.writeBlob(user.id, name, bytes);
      final now = DateTime.now().millisecondsSinceEpoch;
      final meta = existing ??
          CollectionMeta(
              name: name,
              version: 0,
              size: 0,
              payloadSavedAtMs: 0,
              updatedAtMs: 0);
      meta
        ..version = currentVersion + 1
        ..size = bytes.length
        ..payloadSavedAtMs = savedAtMs
        ..updatedAtMs = now;
      perUser[name] = meta;
      await store.saveCollections();

      return jsonResponse(200, {
        'version': meta.version,
        'usedBytes': store.usedBytes(user.id),
        'quotaBytes': user.quotaBytes,
      });
    });
  }

  Future<Response> _deleteBlobHandler(Request request, StoredUser user) async {
    final name = request.params['collection']!;
    if (!collectionPattern.hasMatch(name)) {
      return errorResponse(400, 'bad_collection', 'Invalid collection name.');
    }
    return store.lock.synchronized(() async {
      store.collectionsByUser[user.id]?.remove(name);
      await store.deleteBlob(user.id, name);
      await store.saveCollections();
      return jsonResponse(200, {
        'ok': true,
        'usedBytes': store.usedBytes(user.id),
        'quotaBytes': user.quotaBytes,
      });
    });
  }

  // ---- Handlers: AI model leaderboard --------------------------------------

  /// The whole model catalogue plus the news rail, in one response.
  ///
  /// Public data — identical for every account and carrying nothing a user
  /// typed — so unlike the sync collections it is served in the clear, the
  /// same way the recipe catalogue is. It is still behind [_requireAuth]: the
  /// app may not talk to a luma server at all before its account is approved
  /// (see lib/sync/server_access.dart), and this endpoint is no exception.
  ///
  /// The payload is a few hundred kilobytes and changes only when the
  /// operator refreshes it, so it is served with an ETag and the app sends it
  /// back as `If-None-Match` — a client that is already current pays for a
  /// 304 and nothing else.
  Response _listAiModels(Request request, StoredUser user) {
    final etag = aiCatalog.etag;
    if (request.headers['if-none-match'] == etag) {
      return Response.notModified(headers: {'ETag': etag});
    }
    return Response(
      200,
      body: jsonEncode(aiCatalog.toJson()),
      headers: {
        'Content-Type': 'application/json',
        'ETag': etag,
        // Must revalidate rather than sit in a cache: a refresh should reach
        // devices on their next launch, not whenever a TTL happens to lapse.
        'Cache-Control': 'no-cache',
      },
    );
  }

  /// Rebuilds the catalogue from OpenRouter, Artificial Analysis and Hugging
  /// Face, and re-polls the news feeds.
  ///
  /// A full refresh takes a minute or two — far longer than a dashboard
  /// request should hold a connection open — so this starts the job and
  /// returns immediately; the dashboard follows it through
  /// [_adminAiModelsStatus]. Only one may run at a time, since two concurrent
  /// refreshes would interleave writes to the same store.
  Future<Response> _adminAiModelsRefresh(Request request) async {
    if (aiCatalog.status.running) {
      return errorResponse(409, 'refresh_running',
          'A catalogue refresh is already in progress.');
    }
    unawaited(refreshAiCatalog(
      aiCatalog,
      artificialAnalysisKey: config.artificialAnalysisKey,
    ));
    return jsonResponse(202, {'started': true});
  }

  Response _adminAiModelsStatus(Request request) => jsonResponse(200, {
        'status': aiCatalog.status.toJson(),
        'modelCount': aiCatalog.modelCount,
        'newsCount': aiCatalog.news.length,
        'refreshedAtMs': aiCatalog.refreshedAtMs,
        // Drives the dashboard's "reasoning column needs a key" hint, so an
        // operator can tell a missing key from a broken upstream.
        'artificialAnalysisConfigured': config.artificialAnalysisConfigured,
      });

  // ---- Handlers: recipes ---------------------------------------------------

  static final RegExp _photoIdPattern = RegExp(r'^[a-z0-9_]{1,80}$');

  String _newRecipeId() =>
      randomBytes(12).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// A public recipe's author display name: the local-part of their email,
  /// so the whole address isn't broadcast to everyone browsing the catalogue.
  static String _authorDisplay(String email) {
    final at = email.indexOf('@');
    return at > 0 ? email.substring(0, at) : email;
  }

  Map<String, dynamic> _recipeJson(PublicRecipe r, StoredUser viewer,
      {bool includeReviews = false}) {
    final summary = recipeStore.ratingSummary(r.id);
    final mine = recipeStore.reviewBy(r.id, viewer.id);
    return {
      'id': r.id,
      'authorName': _authorDisplay(r.authorEmail),
      'mine': r.authorId == viewer.id,
      'title': r.title,
      'description': r.description,
      'category': r.category,
      'servings': r.servings,
      'prepMinutes': r.prepMinutes,
      'cookMinutes': r.cookMinutes,
      'ingredients': jsonDecode(r.ingredients),
      'steps': jsonDecode(r.steps),
      'photoId': r.photoId,
      'createdAtMs': r.createdAtMs,
      'ratingCount': summary.count,
      'ratingAvg': summary.avg,
      'myRating': mine?.rating,
      if (includeReviews)
        'reviews':
            recipeStore.reviewsFor(r.id).map((rv) => _reviewJson(rv, viewer)).toList(),
    };
  }

  Map<String, dynamic> _reviewJson(RecipeReview r, StoredUser viewer) => {
        'id': r.id,
        'authorName': _authorDisplay(r.userEmail),
        'mine': r.userId == viewer.id,
        'rating': r.rating,
        'text': r.text,
        'photoId': r.photoId,
        'createdAtMs': r.createdAtMs,
      };

  Response _listPublicRecipes(Request request, StoredUser user) => jsonResponse(200, {
        'recipes':
            recipeStore.browse().map((r) => _recipeJson(r, user)).toList(),
      });

  Response _getPublicRecipe(Request request, StoredUser user) {
    final recipe = recipeStore.recipesById[request.params['id']];
    if (recipe == null) return errorResponse(404, 'not_found', 'Recipe not found.');
    return jsonResponse(200, _recipeJson(recipe, user, includeReviews: true));
  }

  /// Validates the shared recipe body used by publish + update. Returns either
  /// a normalised field record or a validation error.
  ({
    String title,
    String? description,
    String category,
    int servings,
    int prep,
    int cook,
    String ingredients,
    String steps
  })? _parseRecipeBody(Map<String, dynamic> body, {required void Function(Response) fail}) {
    final title = (body['title'] as String? ?? '').trim();
    if (title.isEmpty || title.length > 200) {
      fail(errorResponse(400, 'bad_title', 'A title of up to 200 characters is required.'));
      return null;
    }
    final descRaw = (body['description'] as String?)?.trim();
    if (descRaw != null && descRaw.length > 2000) {
      fail(errorResponse(400, 'bad_description', 'Description is too long.'));
      return null;
    }
    final category = (body['category'] as String? ?? 'Other').trim();
    if (category.length > 40) {
      fail(errorResponse(400, 'bad_category', 'Category is too long.'));
      return null;
    }
    int clampInt(dynamic v, int lo, int hi, int fallback) {
      final n = v is int ? v : (v is num ? v.toInt() : fallback);
      return n < lo ? lo : (n > hi ? hi : n);
    }
    final ingredientsRaw = body['ingredients'];
    final stepsRaw = body['steps'];
    if (ingredientsRaw is! List || stepsRaw is! List) {
      fail(errorResponse(400, 'bad_body', 'ingredients and steps must be lists.'));
      return null;
    }
    if (ingredientsRaw.length > 100 || stepsRaw.length > 100) {
      fail(errorResponse(400, 'too_many', 'Too many ingredients or steps.'));
      return null;
    }
    final ingredients = <Map<String, dynamic>>[];
    for (final i in ingredientsRaw) {
      if (i is! Map) continue;
      final name = (i['name'] as String? ?? '').trim();
      if (name.isEmpty || name.length > 120) continue;
      ingredients.add({
        'name': name,
        'amount': (i['amount'] as String? ?? '').trim(),
        'unit': (i['unit'] as String? ?? '').trim(),
      });
    }
    final steps = <String>[];
    for (final s in stepsRaw) {
      final text = (s is String ? s : '').trim();
      if (text.isEmpty || text.length > 1000) continue;
      steps.add(text);
    }
    final ingredientsJson = jsonEncode(ingredients);
    final stepsJson = jsonEncode(steps);
    if (ingredientsJson.length + stepsJson.length > 32 * 1024) {
      fail(errorResponse(400, 'too_large', 'Recipe body is too large.'));
      return null;
    }
    return (
      title: title,
      description: (descRaw == null || descRaw.isEmpty) ? null : descRaw,
      category: category.isEmpty ? 'Other' : category,
      servings: clampInt(body['servings'], 1, 999, 2),
      prep: clampInt(body['prepMinutes'], 0, 100000, 0),
      cook: clampInt(body['cookMinutes'], 0, 100000, 0),
      ingredients: ingredientsJson,
      steps: stepsJson,
    );
  }

  Future<Response> _publishRecipe(Request request, StoredUser user) async {
    final body = await _readJson(request);
    Response? error;
    final fields = _parseRecipeBody(body, fail: (r) => error = r);
    if (fields == null) return error!;
    return store.lock.synchronized(() async {
      final recipe = PublicRecipe(
        id: _newRecipeId(),
        authorId: user.id,
        authorEmail: user.email,
        title: fields.title,
        description: fields.description,
        category: fields.category,
        servings: fields.servings,
        prepMinutes: fields.prep,
        cookMinutes: fields.cook,
        ingredients: fields.ingredients,
        steps: fields.steps,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      recipeStore.recipesById[recipe.id] = recipe;
      await recipeStore.saveRecipes();
      return jsonResponse(201, _recipeJson(recipe, user));
    });
  }

  Future<Response> _updatePublicRecipe(Request request, StoredUser user) async {
    final recipe = recipeStore.recipesById[request.params['id']];
    if (recipe == null) return errorResponse(404, 'not_found', 'Recipe not found.');
    if (recipe.authorId != user.id) {
      return errorResponse(403, 'forbidden', 'You can only edit your own recipes.');
    }
    final body = await _readJson(request);
    Response? error;
    final fields = _parseRecipeBody(body, fail: (r) => error = r);
    if (fields == null) return error!;
    return store.lock.synchronized(() async {
      recipe
        ..title = fields.title
        ..description = fields.description
        ..category = fields.category
        ..servings = fields.servings
        ..prepMinutes = fields.prep
        ..cookMinutes = fields.cook
        ..ingredients = fields.ingredients
        ..steps = fields.steps
        ..updatedAtMs = DateTime.now().millisecondsSinceEpoch;
      await recipeStore.saveRecipes();
      return jsonResponse(200, _recipeJson(recipe, user, includeReviews: true));
    });
  }

  Future<Response> _deletePublicRecipe(Request request, StoredUser user) async {
    final recipe = recipeStore.recipesById[request.params['id']];
    if (recipe == null) return errorResponse(404, 'not_found', 'Recipe not found.');
    if (recipe.authorId != user.id) {
      return errorResponse(403, 'forbidden', 'You can only delete your own recipes.');
    }
    return store.lock.synchronized(() async {
      await recipeStore.deleteRecipe(recipe.id);
      return jsonResponse(200, {'ok': true});
    });
  }

  Response _listRecipeReviews(Request request, StoredUser user) {
    final recipe = recipeStore.recipesById[request.params['id']];
    if (recipe == null) return errorResponse(404, 'not_found', 'Recipe not found.');
    return jsonResponse(200, {
      'reviews': recipeStore
          .reviewsFor(recipe.id)
          .map((r) => _reviewJson(r, user))
          .toList(),
    });
  }

  /// Adds or updates the caller's review (one per recipe). Rating is required
  /// (1..5); text is optional.
  Future<Response> _putRecipeReview(Request request, StoredUser user) async {
    final recipe = recipeStore.recipesById[request.params['id']];
    if (recipe == null) return errorResponse(404, 'not_found', 'Recipe not found.');
    final body = await _readJson(request);
    final rating = body['rating'];
    if (rating is! int || rating < 1 || rating > 5) {
      return errorResponse(400, 'bad_rating', 'A rating from 1 to 5 is required.');
    }
    final text = (body['text'] as String? ?? '').trim();
    if (text.length > 2000) {
      return errorResponse(400, 'bad_text', 'Review text is too long.');
    }
    return store.lock.synchronized(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final existing = recipeStore.reviewBy(recipe.id, user.id);
      if (existing != null) {
        existing
          ..rating = rating
          ..text = text
          ..updatedAtMs = now;
      } else {
        recipeStore.reviewsByRecipeId
            .putIfAbsent(recipe.id, () => [])
            .insert(
                0,
                RecipeReview(
                  id: _newRecipeId(),
                  recipeId: recipe.id,
                  userId: user.id,
                  userEmail: user.email,
                  rating: rating,
                  text: text,
                  createdAtMs: now,
                ));
      }
      await recipeStore.saveReviews();
      return jsonResponse(200, _recipeJson(recipe, user, includeReviews: true));
    });
  }

  Future<Response> _deleteRecipeReview(Request request, StoredUser user) async {
    final recipe = recipeStore.recipesById[request.params['id']];
    if (recipe == null) return errorResponse(404, 'not_found', 'Recipe not found.');
    return store.lock.synchronized(() async {
      final list = recipeStore.reviewsByRecipeId[recipe.id];
      if (list != null) {
        final mine = list.where((r) => r.userId == user.id).toList();
        for (final r in mine) {
          await recipeStore.deleteMedia(r.photoId);
        }
        list.removeWhere((r) => r.userId == user.id);
        await recipeStore.saveReviews();
      }
      return jsonResponse(200, _recipeJson(recipe, user, includeReviews: true));
    });
  }

  Future<Response> _uploadRecipePhoto(Request request, StoredUser user) async {
    final recipe = recipeStore.recipesById[request.params['id']];
    if (recipe == null) return errorResponse(404, 'not_found', 'Recipe not found.');
    if (recipe.authorId != user.id) {
      return errorResponse(403, 'forbidden', 'You can only edit your own recipes.');
    }
    final bytes = await _readCappedBytes(request, RecipeStore.maxPhotoBytes);
    if (bytes == null) {
      return errorResponse(413, 'photo_too_large', 'That image is too large.');
    }
    return store.lock.synchronized(() async {
      final photoId = 'r_${recipe.id}';
      await recipeStore.writeMedia(photoId, bytes);
      recipe
        ..photoId = photoId
        ..updatedAtMs = DateTime.now().millisecondsSinceEpoch;
      await recipeStore.saveRecipes();
      return jsonResponse(200, {'photoId': photoId});
    });
  }

  Future<Response> _uploadReviewPhoto(Request request, StoredUser user) async {
    final recipe = recipeStore.recipesById[request.params['id']];
    if (recipe == null) return errorResponse(404, 'not_found', 'Recipe not found.');
    final review = recipeStore.reviewBy(recipe.id, user.id);
    if (review == null) {
      return errorResponse(404, 'no_review', 'Post your review before adding a photo.');
    }
    final bytes = await _readCappedBytes(request, RecipeStore.maxPhotoBytes);
    if (bytes == null) {
      return errorResponse(413, 'photo_too_large', 'That image is too large.');
    }
    return store.lock.synchronized(() async {
      final photoId = 'v_${review.id}';
      await recipeStore.writeMedia(photoId, bytes);
      review.photoId = photoId;
      await recipeStore.saveReviews();
      return jsonResponse(200, {'photoId': photoId});
    });
  }

  Future<Response> _getRecipeMedia(Request request, StoredUser user) async {
    final photoId = request.params['photoId']!;
    if (!_photoIdPattern.hasMatch(photoId)) {
      return errorResponse(400, 'bad_photo_id', 'Invalid photo id.');
    }
    final bytes = await recipeStore.readMedia(photoId);
    if (bytes == null) return errorResponse(404, 'not_found', 'No such photo.');
    return Response(200, body: bytes, headers: {
      'Content-Type': 'image/jpeg',
      'Cache-Control': 'private, max-age=86400',
    });
  }

  /// Streams a request body into memory with a hard cap, returning null if it
  /// exceeds [cap] (mirrors the streaming guard in [_putBlob]).
  Future<Uint8List?> _readCappedBytes(Request request, int cap) async {
    if ((request.contentLength ?? 0) > cap) return null;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request.read()) {
      builder.add(chunk);
      if (builder.length > cap) return null;
    }
    final bytes = builder.takeBytes();
    return bytes.isEmpty ? null : bytes;
  }

  // ---- Handlers: plugins ---------------------------------------------------

  /// Records one plugin install for the admin dashboard's "Plugins" tab (see
  /// Api._adminDashboard). Deliberately unauthenticated — plugins can be
  /// installed without a sync account — and just a best-effort counter, so a
  /// malformed or missing body is ignored rather than erroring the client's
  /// install flow.
  /// Records a plugin install for the dashboard's aggregate counter.
  /// Authenticated: the app only ever reaches a luma server once its account
  /// is approved, so anonymous stats pings no longer exist.
  Future<Response> _reportPluginDownload(Request request, StoredUser user) async {
    Map<String, dynamic> body;
    try {
      body = await _readJson(request);
    } on FormatException {
      return errorResponse(400, 'bad_request', 'Malformed request.');
    }
    final pluginId = body['pluginId'];
    if (pluginId is! String || !pluginIdPattern.hasMatch(pluginId)) {
      return errorResponse(400, 'bad_plugin_id', 'Invalid plugin id.');
    }
    final name = (body['name'] as String?)?.trim();
    final safeName =
        (name == null || name.isEmpty || name.length > 80) ? pluginId : name;

    return store.lock.synchronized(() async {
      await store.recordPluginDownload(pluginId, safeName);
      return jsonResponse(200, {'ok': true});
    });
  }

  // ---- Handlers: subway co-op ------------------------------------------------
  //
  // The server never simulates the game — it holds room membership and
  // whatever full-state JSON snapshot a member last pushed, so a room stays
  // joinable without its creator's client needing to stay online. See
  // subway_store.dart and subway_relay.dart for the persistence/relay split.

  static const _maxSubwayStateBytes = 4 * 1024 * 1024;
  static const _clockLeaseTtl = Duration(seconds: 12);

  Future<Response> _createSubwayRoom(Request request, StoredUser user) async {
    return store.lock.synchronized(() async {
      final code = subwayStore.newRoomCode();
      final room = SubwayRoom(
        code: code,
        ownerId: user.id,
        createdAtMs: _nowMs,
        memberIds: {user.id},
      );
      subwayStore.roomsByCode[code] = room;
      await subwayStore.saveRooms();
      return jsonResponse(201, {'code': code, 'createdAtMs': room.createdAtMs});
    });
  }

  Response _listSubwayRooms(Request request, StoredUser user) {
    final rooms = subwayStore.roomsForUser(user.id);
    return jsonResponse(200, {
      'rooms': rooms
          .map((r) => {
                'code': r.code,
                'ownerId': r.ownerId,
                'isOwner': r.ownerId == user.id,
                'memberCount': r.memberIds.length,
                'updatedAtMs': r.updatedAtMs,
              })
          .toList(),
    });
  }

  /// Owner-only. [contactUserId] must already be someone the caller has an
  /// accepted chat conversation with — this is the "existing chat contacts
  /// only" invite scope. Does not itself send anything; the client is
  /// responsible for actually notifying the invitee via a real chat message
  /// (the server cannot compose one — chat messages are end-to-end
  /// encrypted client-side, see chat_store.dart).
  Future<Response> _inviteToSubwayRoom(Request request, StoredUser user) async {
    final code = (request.params['code'] ?? '').toUpperCase();
    final body = await _readJson(request);
    final contactUserId = body['contactUserId'];
    if (contactUserId is! String || contactUserId.isEmpty) {
      return errorResponse(400, 'bad_request', 'Missing contactUserId.');
    }
    return store.lock.synchronized(() async {
      final room = subwayStore.roomsByCode[code];
      if (room == null) return errorResponse(404, 'not_found', 'Room not found.');
      if (room.ownerId != user.id) {
        return errorResponse(403, 'forbidden', 'Only the room owner can invite.');
      }
      if (chatStore.conversationBetween(user.id, contactUserId) == null) {
        return errorResponse(403, 'not_a_contact',
            'You can only invite people you already chat with.');
      }
      room.memberIds.add(contactUserId);
      room.updatedAtMs = _nowMs;
      await subwayStore.saveRooms();
      return jsonResponse(200, {'ok': true});
    });
  }

  /// Presenting a valid code is itself an invite path (alongside the
  /// chat-contact invite above) — any signed-in account holding the code
  /// can join. There's no public room listing/discovery, so this only works
  /// for someone who was actually given the code.
  Future<Response> _joinSubwayRoom(Request request, StoredUser user) async {
    final code = (request.params['code'] ?? '').toUpperCase();
    return store.lock.synchronized(() async {
      final room = subwayStore.roomsByCode[code];
      if (room == null) return errorResponse(404, 'not_found', 'Room not found.');
      if (room.memberIds.add(user.id)) {
        room.updatedAtMs = _nowMs;
        await subwayStore.saveRooms();
      }
      final stateJson = await subwayStore.readState(code);
      return jsonResponse(200, {
        'ok': true,
        'code': room.code,
        'ownerId': room.ownerId,
        'memberIds': room.memberIds.toList(),
        'state': stateJson == null ? null : jsonDecode(stateJson),
      });
    });
  }

  Future<Response> _putSubwayState(Request request, StoredUser user) async {
    final code = (request.params['code'] ?? '').toUpperCase();
    final room = subwayStore.roomsByCode[code];
    if (room == null) return errorResponse(404, 'not_found', 'Room not found.');
    if (!room.isMember(user.id)) {
      return errorResponse(403, 'forbidden', 'Not a member of this room.');
    }
    final raw = await request.readAsString();
    if (raw.length > _maxSubwayStateBytes) {
      return errorResponse(413, 'too_large', 'Room state too large.');
    }
    try {
      jsonDecode(raw); // shape-validate without needing to understand it
    } on FormatException {
      return errorResponse(400, 'bad_request', 'Malformed state.');
    }
    return store.lock.synchronized(() async {
      await subwayStore.writeState(code, raw);
      room.stateVersion++;
      room.updatedAtMs = _nowMs;
      await subwayStore.saveRooms();
      return jsonResponse(200, {'ok': true, 'version': room.stateVersion});
    });
  }

  Future<Response> _getSubwayState(Request request, StoredUser user) async {
    final code = (request.params['code'] ?? '').toUpperCase();
    final room = subwayStore.roomsByCode[code];
    if (room == null) return errorResponse(404, 'not_found', 'Room not found.');
    if (!room.isMember(user.id)) {
      return errorResponse(403, 'forbidden', 'Not a member of this room.');
    }
    final stateJson = await subwayStore.readState(code);
    if (stateJson == null) return errorResponse(404, 'no_state', 'Room has no state yet.');
    return Response.ok(stateJson, headers: {'Content-Type': 'application/json'});
  }

  /// A lease on "who runs the world clock right now" (see world.js/mp.js on
  /// the client) — floats to whichever member claims it first, renewed
  /// every few seconds while held, expires on its own if that client goes
  /// away so someone else can pick it up. Not who "owns" the room.
  Future<Response> _claimSubwayClock(Request request, StoredUser user) async {
    final code = (request.params['code'] ?? '').toUpperCase();
    return store.lock.synchronized(() async {
      final room = subwayStore.roomsByCode[code];
      if (room == null) return errorResponse(404, 'not_found', 'Room not found.');
      if (!room.isMember(user.id)) {
        return errorResponse(403, 'forbidden', 'Not a member of this room.');
      }
      final now = _nowMs;
      final held = room.clockHolderId != null &&
          room.clockLeaseExpiresAtMs != null &&
          room.clockLeaseExpiresAtMs! > now;
      if (held && room.clockHolderId != user.id) {
        return jsonResponse(200, {'granted': false, 'holderId': room.clockHolderId});
      }
      room.clockHolderId = user.id;
      room.clockLeaseExpiresAtMs = now + _clockLeaseTtl.inMilliseconds;
      await subwayStore.saveRooms();
      return jsonResponse(200, {
        'granted': true,
        'leaseExpiresAtMs': room.clockLeaseExpiresAtMs,
      });
    });
  }

  Future<Response> _releaseSubwayClock(Request request, StoredUser user) async {
    final code = (request.params['code'] ?? '').toUpperCase();
    return store.lock.synchronized(() async {
      final room = subwayStore.roomsByCode[code];
      if (room == null) return errorResponse(404, 'not_found', 'Room not found.');
      if (room.clockHolderId == user.id) {
        room.clockHolderId = null;
        room.clockLeaseExpiresAtMs = null;
        await subwayStore.saveRooms();
      }
      return jsonResponse(200, {'ok': true});
    });
  }

  /// Mints a short-lived, single-use ticket that authorizes exactly one
  /// WebSocket upgrade for this room (see SubwayTicketStore's doc comment
  /// for why — browsers can't attach an Authorization header to a WS
  /// handshake, so this keeps the real session token out of the connection
  /// URL / any proxy log line).
  Future<Response> _mintSubwayTicket(Request request, StoredUser user) async {
    final code = (request.params['code'] ?? '').toUpperCase();
    final room = subwayStore.roomsByCode[code];
    if (room == null) return errorResponse(404, 'not_found', 'Room not found.');
    if (!room.isMember(user.id)) {
      return errorResponse(403, 'forbidden', 'Not a member of this room.');
    }
    final ticket = _subwayTickets.mint(user.id, code);
    return jsonResponse(200, {
      'ticket': ticket,
      'ttlSeconds': SubwayTicketStore.ttl.inSeconds,
    });
  }

  /// The WebSocket upgrade itself is unauthenticated at the shelf_router
  /// level (routes can't run `_requireAuth`'s bearer-token check against a
  /// WS handshake the same way) — this wrapper enforces the ticket instead,
  /// then falls through to the unchanged dumb-relay handler.
  FutureOr<Response> _subwayRoomSocket(Request request) {
    final code = (request.params['room'] ?? '').toUpperCase();
    final ticket = request.url.queryParameters['ticket'];
    if (ticket == null) {
      return errorResponse(401, 'unauthorized', 'Missing ticket.');
    }
    final redeemed = _subwayTickets.redeem(ticket, code);
    if (redeemed == null) {
      return errorResponse(401, 'unauthorized', 'Invalid or expired ticket.');
    }
    final room = subwayStore.roomsByCode[code];
    if (room == null || !room.isMember(redeemed.userId)) {
      return errorResponse(403, 'forbidden', 'Not a member of this room.');
    }
    return _subwayRelay.subwayRoomHandler(request);
  }

  // ---- Handlers: family -----------------------------------------------------
  //
  // Unlike /api/v1/sync/<collection>, this data is deliberately readable by
  // the server in the clear — sharing across accounts is incompatible with
  // the per-account zero-knowledge key derivation used for everything else,
  // and the user chose plain server-side storage (secured the same way the
  // rest of the API is: bearer-token auth + explicit membership checks) over
  // building a per-family encryption/key-distribution scheme. Every handler
  // below must verify the caller is a current member before returning or
  // mutating anything for a family.

  static const _familyInviteTtl = Duration(days: 7);

  int get _nowMs => DateTime.now().millisecondsSinceEpoch;

  String _genId() => base64UrlEncode(randomBytes(12)).replaceAll('=', '');

  int _familyMemberLimitFor(StoredUser owner) =>
      kFamilyMemberLimit[owner.planId] ?? kFamilyMemberLimit[kDefaultPlanId]!;

  Map<String, dynamic> _familyJson(Family family, StoredUser requester,
      {required bool includeInvites}) {
    final owner = store.usersById[family.ownerUserId];
    final members = familyStore.membersOf(family.id);
    final now = _nowMs;
    final json = {
      'id': family.id,
      'name': family.name,
      'ownerUserId': family.ownerUserId,
      'createdAtMs': family.createdAtMs,
      'slotLimit': owner == null ? null : _familyMemberLimitFor(owner),
      'slotsUsed': familyStore.slotsUsed(family.id, now),
      'members': members
          .map((m) => {
                'userId': m.userId,
                'email': store.usersById[m.userId]?.email ?? '',
                'role': m.role,
                'joinedAtMs': m.joinedAtMs,
              })
          .toList(),
    };
    if (includeInvites && requester.id == family.ownerUserId) {
      json['pendingInvites'] = familyStore
          .pendingInvitesForFamily(family.id, now)
          .map((i) => {
                'id': i.id,
                'email': i.inviteeEmail,
                'createdAtMs': i.createdAtMs,
                'expiresAtMs': i.expiresAtMs,
              })
          .toList();
    }
    return json;
  }

  Map<String, dynamic> _sharedEventJson(FamilySharedEvent e) => {
        'id': e.id,
        'familyId': e.familyId,
        'authorUserId': e.authorUserId,
        'title': e.title,
        'description': e.description,
        'location': e.location,
        'startMs': e.startMs,
        'endMs': e.endMs,
        'allDay': e.allDay,
        'color': e.color,
        'recurrence': e.recurrence,
        'recurrenceEndMs': e.recurrenceEndMs,
        'reminderMinutes': e.reminderMinutes,
        'visibility': e.visibility,
        'visibleMemberUserIds': e.visibleMemberUserIds,
        'createdAtMs': e.createdAtMs,
        'updatedAtMs': e.updatedAtMs,
      };

  Future<Response> _createFamily(Request request, StoredUser user) async {
    if (familyStore.familyIdByUserId.containsKey(user.id)) {
      return errorResponse(409, 'already_in_family',
          'You already belong to a family. Leave it before creating another.');
    }
    final body = await _readJson(request);
    final name = (body['name'] as String?)?.trim() ?? '';
    if (name.isEmpty || name.length > 60) {
      return errorResponse(400, 'bad_name', 'Family name must be 1–60 characters.');
    }
    // No control characters: the name is later interpolated into an email
    // Subject header (see Mailer.sendFamilyInviteEmail), where a CR/LF would
    // be an SMTP header-injection vector.
    if (name.codeUnits.any((c) => c < 0x20 || c == 0x7f)) {
      return errorResponse(400, 'bad_name', 'Family name contains invalid characters.');
    }

    return store.lock.synchronized(() async {
      if (familyStore.familyIdByUserId.containsKey(user.id)) {
        return errorResponse(409, 'already_in_family',
            'You already belong to a family. Leave it before creating another.');
      }
      final now = _nowMs;
      final family =
          Family(id: _genId(), name: name, ownerUserId: user.id, createdAtMs: now);
      familyStore.familiesById[family.id] = family;
      familyStore.membersByFamilyId[family.id] = {
        user.id: FamilyMember(
            familyId: family.id,
            userId: user.id,
            role: 'owner',
            joinedAtMs: now),
      };
      familyStore.familyIdByUserId[user.id] = family.id;
      await familyStore.saveFamilies();
      await familyStore.saveMembers();
      return jsonResponse(
          201, _familyJson(family, user, includeInvites: true));
    });
  }

  Response _getMyFamily(Request request, StoredUser user) {
    final family = familyStore.familyForUser(user.id);
    if (family == null) {
      return errorResponse(404, 'no_family', 'You are not in a family yet.');
    }
    return jsonResponse(200, _familyJson(family, user, includeInvites: true));
  }

  Future<Response> _inviteFamilyMember(Request request, StoredUser user) async {
    final familyId = request.params['id']!;
    final family = familyStore.familiesById[familyId];
    if (family == null) return errorResponse(404, 'not_found', 'Family not found.');
    if (family.ownerUserId != user.id) {
      return errorResponse(403, 'forbidden', 'Only the family owner can invite members.');
    }
    final body = await _readJson(request);
    final email = _normalizeEmail(body['email']);
    if (email == null) return errorResponse(400, 'bad_email', 'Invalid email.');
    if (!_inviteLimiter.allow(user.id)) {
      return errorResponse(429, 'rate_limited',
          'Too many invites sent recently. Try again later.');
    }

    return store.lock.synchronized(() async {
      final now = _nowMs;
      final existingUserId = store.userIdByEmail[email];
      if (existingUserId != null && familyStore.isMember(familyId, existingUserId)) {
        return errorResponse(409, 'already_member', 'That person is already in the family.');
      }
      final alreadyPending = familyStore.invitesById.values.any((i) =>
          i.familyId == familyId && i.inviteeEmail == email && i.isPendingAt(now));
      if (alreadyPending) {
        return errorResponse(409, 'invite_pending', 'An invite is already pending for that email.');
      }

      final owner = store.usersById[user.id]!;
      final limit = _familyMemberLimitFor(owner);
      if (familyStore.slotsUsed(familyId, now) >= limit) {
        return errorResponse(403, 'family_limit_exceeded',
            'Your plan allows up to $limit family members. Upgrade your plan to invite more.');
      }

      final invite = FamilyInvite(
        id: _genId(),
        familyId: familyId,
        inviteeEmail: email,
        invitedByUserId: user.id,
        createdAtMs: now,
        expiresAtMs: now + _familyInviteTtl.inMilliseconds,
      );
      familyStore.invitesById[invite.id] = invite;
      await familyStore.saveInvites();
      await _sendFamilyInviteEmail(
          toEmail: email, inviterEmail: user.email, familyName: family.name);
      return jsonResponse(201, {
        'id': invite.id,
        'email': invite.inviteeEmail,
        'expiresAtMs': invite.expiresAtMs,
      });
    });
  }

  Response _listMyInvites(Request request, StoredUser user) {
    final now = _nowMs;
    final invites =
        familyStore.pendingInvitesForEmail(user.email.toLowerCase(), now);
    return jsonResponse(200, {
      'invites': invites.map((i) {
        final family = familyStore.familiesById[i.familyId];
        final inviter = store.usersById[i.invitedByUserId];
        return {
          'id': i.id,
          'familyId': i.familyId,
          'familyName': family?.name ?? 'Family',
          'inviterEmail': inviter?.email ?? '',
          'createdAtMs': i.createdAtMs,
          'expiresAtMs': i.expiresAtMs,
        };
      }).toList(),
    });
  }

  Future<Response> _acceptFamilyInvite(Request request, StoredUser user) async {
    final inviteId = request.params['inviteId']!;
    return store.lock.synchronized(() async {
      final now = _nowMs;
      final invite = familyStore.invitesById[inviteId];
      if (invite == null || invite.inviteeEmail != user.email.toLowerCase()) {
        return errorResponse(404, 'not_found', 'Invite not found.');
      }
      if (!invite.isPendingAt(now)) {
        return errorResponse(410, 'invite_not_pending', 'This invite is no longer available.');
      }
      final family = familyStore.familiesById[invite.familyId];
      if (family == null) {
        return errorResponse(404, 'not_found', 'This family no longer exists.');
      }
      if (familyStore.familyIdByUserId.containsKey(user.id)) {
        return errorResponse(409, 'already_in_family',
            'You already belong to a family. Leave it before accepting a new invite.');
      }
      final owner = store.usersById[family.ownerUserId];
      final limit = owner == null
          ? kFamilyMemberLimit[kDefaultPlanId]!
          : _familyMemberLimitFor(owner);
      if (familyStore.membersOf(family.id).length >= limit) {
        return errorResponse(403, 'family_limit_exceeded',
            'This family is full.');
      }

      familyStore.membersByFamilyId.putIfAbsent(family.id, () => {})[user.id] =
          FamilyMember(
              familyId: family.id,
              userId: user.id,
              role: 'member',
              joinedAtMs: now);
      familyStore.familyIdByUserId[user.id] = family.id;
      invite.status = 'accepted';
      invite.respondedAtMs = now;
      await familyStore.saveMembers();
      await familyStore.saveInvites();
      return jsonResponse(200, _familyJson(family, user, includeInvites: false));
    });
  }

  Future<Response> _declineFamilyInvite(Request request, StoredUser user) async {
    final inviteId = request.params['inviteId']!;
    return store.lock.synchronized(() async {
      final now = _nowMs;
      final invite = familyStore.invitesById[inviteId];
      if (invite == null || invite.inviteeEmail != user.email.toLowerCase()) {
        return errorResponse(404, 'not_found', 'Invite not found.');
      }
      if (!invite.isPendingAt(now)) {
        return errorResponse(410, 'invite_not_pending', 'This invite is no longer available.');
      }
      invite.status = 'declined';
      invite.respondedAtMs = now;
      await familyStore.saveInvites();
      return jsonResponse(200, {'ok': true});
    });
  }

  Future<Response> _removeFamilyMember(Request request, StoredUser user) async {
    final familyId = request.params['id']!;
    final targetUserId = request.params['userId']!;
    final family = familyStore.familiesById[familyId];
    if (family == null) return errorResponse(404, 'not_found', 'Family not found.');
    final isOwner = family.ownerUserId == user.id;
    final isSelf = targetUserId == user.id;
    if (!isOwner && !isSelf) {
      return errorResponse(403, 'forbidden', 'Only the family owner can remove other members.');
    }
    if (targetUserId == family.ownerUserId) {
      return errorResponse(409, 'owner_cannot_leave',
          'The owner cannot leave the family. Delete the family instead.');
    }
    return store.lock.synchronized(() async {
      familyStore.membersByFamilyId[familyId]?.remove(targetUserId);
      if (familyStore.familyIdByUserId[targetUserId] == familyId) {
        familyStore.familyIdByUserId.remove(targetUserId);
      }
      await familyStore.saveMembers();
      return jsonResponse(200, {'ok': true});
    });
  }

  Future<Response> _deleteFamily(Request request, StoredUser user) async {
    final familyId = request.params['id']!;
    final family = familyStore.familiesById[familyId];
    if (family == null) return errorResponse(404, 'not_found', 'Family not found.');
    if (family.ownerUserId != user.id) {
      return errorResponse(403, 'forbidden', 'Only the family owner can delete the family.');
    }
    return store.lock.synchronized(() async {
      familyStore.deleteFamilyData(familyId);
      await familyStore.saveFamilies();
      await familyStore.saveMembers();
      await familyStore.saveInvites();
      await familyStore.saveEvents();
      return jsonResponse(200, {'ok': true});
    });
  }

  Future<Response> _addSharedEvent(Request request, StoredUser user) async {
    final familyId = request.params['id']!;
    final family = familyStore.familiesById[familyId];
    if (family == null) return errorResponse(404, 'not_found', 'Family not found.');
    if (!familyStore.isMember(familyId, user.id)) {
      return errorResponse(403, 'forbidden', 'You are not a member of this family.');
    }
    final body = await _readJson(request);
    final parsed = _parseSharedEventBody(body, familyId);
    if (parsed is _ParseError) {
      return errorResponse(400, parsed.code, parsed.message);
    }
    final fields = parsed as _ParsedSharedEvent;
    if (fields.visibility == 'subset') {
      for (final id in fields.visibleMemberUserIds) {
        if (!familyStore.isMember(familyId, id)) {
          return errorResponse(400, 'bad_member', 'One of the chosen members is not in this family.');
        }
      }
    }

    return store.lock.synchronized(() async {
      final now = _nowMs;
      final event = FamilySharedEvent(
        id: _genId(),
        familyId: familyId,
        authorUserId: user.id,
        title: fields.title,
        description: fields.description,
        location: fields.location,
        startMs: fields.startMs,
        endMs: fields.endMs,
        allDay: fields.allDay,
        color: fields.color,
        recurrence: fields.recurrence,
        recurrenceEndMs: fields.recurrenceEndMs,
        reminderMinutes: fields.reminderMinutes,
        visibility: fields.visibility,
        visibleMemberUserIds: fields.visibleMemberUserIds,
        createdAtMs: now,
        updatedAtMs: now,
      );
      familyStore.sharedEventsByFamilyId
          .putIfAbsent(familyId, () => {})[event.id] = event;
      await familyStore.saveEvents();
      return jsonResponse(201, _sharedEventJson(event));
    });
  }

  Response _listSharedEvents(Request request, StoredUser user) {
    final familyId = request.params['id']!;
    if (familyStore.familiesById[familyId] == null) {
      return errorResponse(404, 'not_found', 'Family not found.');
    }
    if (!familyStore.isMember(familyId, user.id)) {
      return errorResponse(403, 'forbidden', 'You are not a member of this family.');
    }
    final events = familyStore.visibleEvents(familyId, user.id);
    return jsonResponse(200, {'events': events.map(_sharedEventJson).toList()});
  }

  Future<Response> _updateSharedEvent(Request request, StoredUser user) async {
    final familyId = request.params['id']!;
    final eventId = request.params['eventId']!;
    final family = familyStore.familiesById[familyId];
    if (family == null) return errorResponse(404, 'not_found', 'Family not found.');
    final event = familyStore.sharedEventsByFamilyId[familyId]?[eventId];
    if (event == null) return errorResponse(404, 'not_found', 'Event not found.');
    if (event.authorUserId != user.id && family.ownerUserId != user.id) {
      return errorResponse(403, 'forbidden', 'Only the author or family owner can edit this event.');
    }
    final body = await _readJson(request);
    final parsed = _parseSharedEventBody(body, familyId);
    if (parsed is _ParseError) {
      return errorResponse(400, parsed.code, parsed.message);
    }
    final fields = parsed as _ParsedSharedEvent;
    if (fields.visibility == 'subset') {
      for (final id in fields.visibleMemberUserIds) {
        if (!familyStore.isMember(familyId, id)) {
          return errorResponse(400, 'bad_member', 'One of the chosen members is not in this family.');
        }
      }
    }

    return store.lock.synchronized(() async {
      event
        ..title = fields.title
        ..description = fields.description
        ..location = fields.location
        ..startMs = fields.startMs
        ..endMs = fields.endMs
        ..allDay = fields.allDay
        ..color = fields.color
        ..recurrence = fields.recurrence
        ..recurrenceEndMs = fields.recurrenceEndMs
        ..reminderMinutes = fields.reminderMinutes
        ..visibility = fields.visibility
        ..visibleMemberUserIds = fields.visibleMemberUserIds
        ..updatedAtMs = _nowMs;
      await familyStore.saveEvents();
      return jsonResponse(200, _sharedEventJson(event));
    });
  }

  Future<Response> _deleteSharedEvent(Request request, StoredUser user) async {
    final familyId = request.params['id']!;
    final eventId = request.params['eventId']!;
    final family = familyStore.familiesById[familyId];
    if (family == null) return errorResponse(404, 'not_found', 'Family not found.');
    final event = familyStore.sharedEventsByFamilyId[familyId]?[eventId];
    if (event == null) return errorResponse(404, 'not_found', 'Event not found.');
    if (event.authorUserId != user.id && family.ownerUserId != user.id) {
      return errorResponse(403, 'forbidden', 'Only the author or family owner can delete this event.');
    }
    return store.lock.synchronized(() async {
      familyStore.sharedEventsByFamilyId[familyId]?.remove(eventId);
      await familyStore.saveEvents();
      return jsonResponse(200, {'ok': true});
    });
  }

  Object _parseSharedEventBody(Map<String, dynamic> body, String familyId) {
    final title = (body['title'] as String?)?.trim() ?? '';
    if (title.isEmpty || title.length > 200) {
      return const _ParseError('bad_title', 'Title must be 1–200 characters.');
    }
    final startMs = body['startMs'];
    final endMs = body['endMs'];
    if (startMs is! int || endMs is! int) {
      return const _ParseError('bad_dates', 'startMs and endMs are required.');
    }
    final visibility = body['visibility'] as String? ?? 'all';
    if (visibility != 'all' && visibility != 'subset') {
      return const _ParseError('bad_visibility', "visibility must be 'all' or 'subset'.");
    }
    final memberIds = (body['memberUserIds'] as List?)
            ?.map((e) => e as String)
            .toList() ??
        const <String>[];
    if (visibility == 'subset' && memberIds.isEmpty) {
      return const _ParseError(
          'bad_members', 'Choose at least one member when sharing with specific people.');
    }
    return _ParsedSharedEvent(
      title: title,
      description: _nullIfBlank(body['description'] as String?),
      location: _nullIfBlank(body['location'] as String?),
      startMs: startMs,
      endMs: endMs,
      allDay: body['allDay'] as bool? ?? false,
      color: body['color'] as int? ?? 0xFF7C5AD9,
      recurrence: body['recurrence'] as String? ?? 'none',
      recurrenceEndMs: body['recurrenceEndMs'] as int?,
      reminderMinutes: body['reminderMinutes'] as int?,
      visibility: visibility,
      visibleMemberUserIds: visibility == 'subset' ? memberIds : const [],
    );
  }

  /// Best-effort send; a mail outage should not block invites outright since
  /// the invite still shows up in-app the next time the invitee's client
  /// polls /api/v1/family/invites.
  Future<void> _sendFamilyInviteEmail({
    required String toEmail,
    required String inviterEmail,
    required String familyName,
  }) async {
    try {
      await mailer.sendFamilyInviteEmail(
          toEmail: toEmail, inviterEmail: inviterEmail, familyName: familyName);
    } catch (e) {
      stderr.writeln('[luma] could not send family invite email to $toEmail: $e');
    }
  }

  // ---- Handlers: chat --------------------------------------------------------
  //
  // The server here is a dumb, opaque relay: it stores each user's X25519
  // public key (needed so others can encrypt *to* them) and, once two users
  // are connected, opaque ciphertext blobs per message. It never sees a
  // plaintext message, a private key, or has any way to decrypt what it
  // stores — see chat_crypto.dart on the client for the sealed-box scheme.

  static const _chatInviteTtl = Duration(days: 14);
  // A message body carries *two* blobs (one sealed to the recipient, one to
  // the sender) plus JSON overhead, and the whole request must still fit
  // under `_maxJsonBody` (64KB) — so each blob gets well under half of that.
  static const _maxChatBlobLength = 28000; // base64 chars (~20KB plaintext)

  /// Hard cap on stored messages per conversation; the oldest are dropped
  /// once it's exceeded, so one user can't grow the messages file (and the
  /// full rewrite each save does) without bound.
  static const _maxChatMessagesPerConversation = 2000;

  Future<Response> _putChatKey(Request request, StoredUser user) async {
    final body = await _readJson(request);
    final key = body['publicKey'];
    // Must be exactly a base64-encoded 32-byte X25519 public key — anything
    // else would silently break every peer that tries to encrypt to it.
    if (key is! String || key.isEmpty || key.length > 200) {
      return errorResponse(400, 'bad_key', 'Invalid public key.');
    }
    try {
      if (base64Decode(key).length != 32) {
        return errorResponse(400, 'bad_key', 'Invalid public key.');
      }
    } on FormatException {
      return errorResponse(400, 'bad_key', 'Invalid public key.');
    }
    return store.lock.synchronized(() async {
      chatStore.publicKeyByUserId[user.id] = key;
      await chatStore.saveKeys();
      return jsonResponse(200, {'ok': true});
    });
  }

  Response _getChatKey(Request request, StoredUser user) {
    final userId = request.params['userId']!;
    final key = chatStore.publicKeyByUserId[userId];
    if (key == null) return errorResponse(404, 'not_found', 'No public key for that user.');
    return jsonResponse(200, {'userId': userId, 'publicKey': key});
  }

  Future<Response> _sendChatInvite(Request request, StoredUser user) async {
    if (!chatStore.publicKeyByUserId.containsKey(user.id)) {
      return errorResponse(400, 'no_key',
          'Set up chat encryption on this device first.');
    }
    final body = await _readJson(request);
    final email = _normalizeEmail(body['email']);
    if (email == null) return errorResponse(400, 'bad_email', 'Invalid email.');
    if (email == user.email.toLowerCase()) {
      return errorResponse(400, 'bad_email', 'You cannot invite yourself.');
    }
    if (!_inviteLimiter.allow(user.id)) {
      return errorResponse(429, 'rate_limited',
          'Too many invites sent recently. Try again later.');
    }

    return store.lock.synchronized(() async {
      final now = _nowMs;
      final existingUserId = store.userIdByEmail[email];
      if (existingUserId != null &&
          chatStore.conversationBetween(user.id, existingUserId) != null) {
        return errorResponse(409, 'already_chatting', 'You already have a chat with that person.');
      }
      final alreadyPending = chatStore.invitesById.values.any((i) =>
          i.fromUserId == user.id && i.toEmail == email && i.isPendingAt(now));
      if (alreadyPending) {
        return errorResponse(409, 'invite_pending', 'An invite is already pending for that email.');
      }

      final invite = ChatInvite(
        id: _genId(),
        fromUserId: user.id,
        toEmail: email,
        createdAtMs: now,
        expiresAtMs: now + _chatInviteTtl.inMilliseconds,
      );
      chatStore.invitesById[invite.id] = invite;
      await chatStore.saveInvites();
      await _sendChatInviteEmail(toEmail: email, inviterEmail: user.email);
      return jsonResponse(201, {
        'id': invite.id,
        'email': invite.toEmail,
        'expiresAtMs': invite.expiresAtMs,
      });
    });
  }

  Response _listChatInvites(Request request, StoredUser user) {
    final now = _nowMs;
    final invites = chatStore.pendingInvitesForEmail(user.email.toLowerCase(), now);
    return jsonResponse(200, {
      'invites': invites.map((i) {
        final inviter = store.usersById[i.fromUserId];
        return {
          'id': i.id,
          'inviterEmail': inviter?.email ?? '',
          'createdAtMs': i.createdAtMs,
          'expiresAtMs': i.expiresAtMs,
        };
      }).toList(),
    });
  }

  Future<Response> _acceptChatInvite(Request request, StoredUser user) async {
    if (!chatStore.publicKeyByUserId.containsKey(user.id)) {
      return errorResponse(400, 'no_key',
          'Set up chat encryption on this device first.');
    }
    final inviteId = request.params['inviteId']!;
    return store.lock.synchronized(() async {
      final now = _nowMs;
      final invite = chatStore.invitesById[inviteId];
      if (invite == null || invite.toEmail != user.email.toLowerCase()) {
        return errorResponse(404, 'not_found', 'Invite not found.');
      }
      if (!invite.isPendingAt(now)) {
        return errorResponse(410, 'invite_not_pending', 'This invite is no longer available.');
      }

      var conversation = chatStore.conversationBetween(invite.fromUserId, user.id);
      conversation ??= ChatConversation(
        id: _genId(),
        userAId: invite.fromUserId,
        userBId: user.id,
        createdAtMs: now,
      );
      chatStore.conversationsById[conversation.id] = conversation;
      invite.status = 'accepted';
      invite.respondedAtMs = now;
      await chatStore.saveConversations();
      await chatStore.saveInvites();

      final peer = store.usersById[invite.fromUserId];
      return jsonResponse(200, _conversationJson(conversation, user.id, peer));
    });
  }

  Future<Response> _declineChatInvite(Request request, StoredUser user) async {
    final inviteId = request.params['inviteId']!;
    return store.lock.synchronized(() async {
      final now = _nowMs;
      final invite = chatStore.invitesById[inviteId];
      if (invite == null || invite.toEmail != user.email.toLowerCase()) {
        return errorResponse(404, 'not_found', 'Invite not found.');
      }
      invite.status = 'declined';
      invite.respondedAtMs = now;
      await chatStore.saveInvites();
      return jsonResponse(200, {'ok': true});
    });
  }

  Map<String, dynamic> _conversationJson(
      ChatConversation c, String meUserId, StoredUser? peer) {
    final peerId = c.otherUser(meUserId);
    return {
      'id': c.id,
      'peerUserId': peerId,
      'peerEmail': peer?.email ?? '',
      'peerPublicKey': chatStore.publicKeyByUserId[peerId],
      'createdAtMs': c.createdAtMs,
    };
  }

  Response _listChatConversations(Request request, StoredUser user) {
    final conversations = chatStore.conversationsForUser(user.id);
    return jsonResponse(200, {
      'conversations': conversations.map((c) {
        final peer = store.usersById[c.otherUser(user.id)];
        return _conversationJson(c, user.id, peer);
      }).toList(),
    });
  }

  Response _listChatMessages(Request request, StoredUser user) {
    final conversationId = request.params['id']!;
    final conversation = chatStore.conversationsById[conversationId];
    if (conversation == null || !conversation.hasUser(user.id)) {
      return errorResponse(404, 'not_found', 'Conversation not found.');
    }
    final sinceMs = int.tryParse(request.url.queryParameters['since'] ?? '');
    final messages = chatStore.messagesFor(conversationId, sinceMs: sinceMs);
    return jsonResponse(200, {
      'messages': messages.map((m) => {
            'id': m.id,
            'senderUserId': m.senderUserId,
            'createdAtMs': m.createdAtMs,
            'blob': m.senderUserId == user.id ? m.blobForSender : m.blobForRecipient,
          }).toList(),
    });
  }

  Future<Response> _sendChatMessage(Request request, StoredUser user) async {
    final conversationId = request.params['id']!;
    final conversation = chatStore.conversationsById[conversationId];
    if (conversation == null || !conversation.hasUser(user.id)) {
      return errorResponse(404, 'not_found', 'Conversation not found.');
    }
    final body = await _readJson(request);
    final forRecipient = body['blobForRecipient'];
    final forSender = body['blobForSender'];
    if (forRecipient is! String ||
        forSender is! String ||
        forRecipient.isEmpty ||
        forSender.isEmpty ||
        forRecipient.length > _maxChatBlobLength ||
        forSender.length > _maxChatBlobLength) {
      return errorResponse(400, 'bad_message', 'Invalid message payload.');
    }

    return store.lock.synchronized(() async {
      final message = ChatMessage(
        id: _genId(),
        conversationId: conversationId,
        senderUserId: user.id,
        createdAtMs: _nowMs,
        blobForRecipient: forRecipient,
        blobForSender: forSender,
      );
      final messages = chatStore.messagesByConversationId
          .putIfAbsent(conversationId, () => [])
        ..add(message);
      if (messages.length > _maxChatMessagesPerConversation) {
        messages.removeRange(
            0, messages.length - _maxChatMessagesPerConversation);
      }
      await chatStore.saveMessages();
      return jsonResponse(201, {'id': message.id, 'createdAtMs': message.createdAtMs});
    });
  }

  /// Best-effort send; a mail outage should not block invites outright since
  /// the invite still shows up in-app the next time the invitee's client
  /// polls /api/v1/chat/invites.
  Future<void> _sendChatInviteEmail({
    required String toEmail,
    required String inviterEmail,
  }) async {
    try {
      await mailer.sendChatInviteEmail(toEmail: toEmail, inviterEmail: inviterEmail);
    } catch (e) {
      stderr.writeln('[luma] could not send chat invite email to $toEmail: $e');
    }
  }

  // ---- Handlers: admin ------------------------------------------------------

  /// Metadata-only view of one account for the admin endpoints. Never
  /// includes anything that could help decrypt a user's blobs (authHash,
  /// authSalt, kdfSalt, session tokens, etc. are all withheld).
  Map<String, dynamic> _adminUserJson(StoredUser user) => {
        'email': user.email,
        'status': user.status,
        'planId': user.planId,
        'createdAtMs': user.createdAtMs,
        'usedBytes': store.usedBytes(user.id),
        'quotaBytes': user.quotaBytes,
        'lastLoginAtMs': user.lastLoginAtMs,
      };

  Response _adminUsers(Request request) {
    final users = store.usersById.values.toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return jsonResponse(200, {'users': users.map(_adminUserJson).toList()});
  }

  Map<String, dynamic> _adminStatsJson() {
    final users = store.usersById.values;
    var active = 0;
    var pending = 0;
    var usedTotal = 0;
    var quotaTotal = 0;
    final planCounts = <String, int>{for (final id in kPlanQuotaBytes.keys) id: 0};
    for (final u in users) {
      if (u.isPending) {
        pending++;
      } else {
        active++;
      }
      usedTotal += store.usedBytes(u.id);
      quotaTotal += u.quotaBytes;
      planCounts[u.planId] = (planCounts[u.planId] ?? 0) + 1;
    }
    return {
      'totalAccounts': users.length,
      'activeAccounts': active,
      'pendingAccounts': pending,
      'usedBytesTotal': usedTotal,
      'quotaBytesTotal': quotaTotal,
      'planCounts': planCounts,
    };
  }

  Response _adminStats(Request request) => jsonResponse(200, _adminStatsJson());

  Future<Response> _adminMetrics(Request request) async {
    final metrics = await SystemMetrics.sample();
    await store.metricsHistory.addSample(metrics);
    return jsonResponse(200, metrics.toJson());
  }

  /// Persisted graph history for the admin dashboard's range selector —
  /// range is one of 'minute' / 'hour' / 'day' / 'week' (default 'minute').
  /// Backed by [MetricsHistory], which downsamples raw /admin/metrics
  /// samples into minute/hour buckets so this survives page reloads and
  /// server restarts, unlike the old client-only rolling window.
  Response _adminMetricsHistory(Request request) {
    final range = request.url.queryParameters['range'] ?? 'minute';
    final points = store.metricsHistory.pointsForRange(range);
    return jsonResponse(200, {
      'range': range,
      'points': points.map((p) => p.toJson()).toList(),
    });
  }

  /// Storage breakdown for the admin dashboard's metrics tab: how many bytes
  /// each logical "database" (JSON store file or blob/media directory) is
  /// using on disk. Enables the doughnut chart in the metrics panel.
  Future<Response> _adminStorage(Request request) async {
    final root = config.dataDir;

    Future<int> fileBytes(String name) async {
      try {
        final f = File('$root/$name');
        if (!await f.exists()) return 0;
        return await f.length();
      } catch (_) {
        return 0;
      }
    }

    Future<int> dirBytes(String name) async {
      try {
        final d = Directory('$root/$name');
        if (!await d.exists()) return 0;
        var total = 0;
        await for (final e in d.list(recursive: true, followLinks: false)) {
          if (e is File) {
            try {
              total += await e.length();
            } catch (_) {}
          }
        }
        return total;
      } catch (_) {
        return 0;
      }
    }

    final raw = <Map<String, dynamic>>[
      {'id': 'blobs', 'label': 'Sync blobs', 'bytes': await dirBytes('blobs')},
      {'id': 'users', 'label': 'Users', 'bytes': await fileBytes('users.json')},
      {
        'id': 'sessions',
        'label': 'Sessions',
        'bytes': await fileBytes('sessions.json')
      },
      {
        'id': 'collections',
        'label': 'Collections',
        'bytes': await fileBytes('collections.json')
      },
      {'id': 'activity', 'label': 'Activity', 'bytes': await fileBytes('activity.json')},
      {
        'id': 'plugin_downloads',
        'label': 'Plugin stats',
        'bytes': await fileBytes('plugin_downloads.json')
      },
      {
        'id': 'metrics_history',
        'label': 'Metrics history',
        'bytes': await fileBytes('metrics_history.json')
      },
      {'id': 'families', 'label': 'Families', 'bytes': await fileBytes('families.json')},
      {
        'id': 'family_members',
        'label': 'Family members',
        'bytes': await fileBytes('family_members.json')
      },
      {
        'id': 'family_invites',
        'label': 'Family invites',
        'bytes': await fileBytes('family_invites.json')
      },
      {
        'id': 'family_events',
        'label': 'Shared events',
        'bytes': await fileBytes('family_shared_events.json')
      },
      {'id': 'chat_keys', 'label': 'Chat keys', 'bytes': await fileBytes('chat_keys.json')},
      {
        'id': 'chat_invites',
        'label': 'Chat invites',
        'bytes': await fileBytes('chat_invites.json')
      },
      {
        'id': 'chat_conversations',
        'label': 'Chat conversations',
        'bytes': await fileBytes('chat_conversations.json')
      },
      {
        'id': 'chat_messages',
        'label': 'Chat messages',
        'bytes': await fileBytes('chat_messages.json')
      },
      {'id': 'recipes', 'label': 'Recipes', 'bytes': await fileBytes('recipes.json')},
      {
        'id': 'recipe_reviews',
        'label': 'Recipe reviews',
        'bytes': await fileBytes('recipe_reviews.json')
      },
      {
        'id': 'recipe_media',
        'label': 'Recipe media',
        'bytes': await dirBytes('recipe_media')
      },
      {
        'id': 'subway_rooms',
        'label': 'Subway rooms',
        'bytes': await fileBytes('subway_rooms.json')
      },
      {
        'id': 'subway_state',
        'label': 'Subway states',
        'bytes': await dirBytes('subway_state')
      },
      {'id': 'ai_models', 'label': 'AI models', 'bytes': await fileBytes('ai_models.json')},
      {'id': 'ai_usage', 'label': 'AI usage', 'bytes': await fileBytes('ai_usage.json')},
      {
        'id': 'admin_sessions',
        'label': 'Admin sessions',
        'bytes': await fileBytes('admin_sessions.json')
      },
    ];

    // Drop empty stores so the chart doesn't render 20 zero-width slices;
    // keep at least one entry so the total is still reported.
    final entries = raw.where((e) => (e['bytes'] as int) > 0).toList()
      ..sort((a, b) => (b['bytes'] as int).compareTo(a['bytes'] as int));

    final total = raw.fold<int>(0, (s, e) => s + (e['bytes'] as int));

    // If every store is empty (fresh install) report zeros without filtering.
    final payloadEntries = entries.isEmpty && total == 0 ? raw : entries;

    return jsonResponse(200, {
      'totalBytes': total,
      'entries': payloadEntries,
    });
  }

  /// Persisted activity feed (see Store.logActivity), filtered to the last
  /// [hours] (default 24) and newest first — unlike /admin/metrics this
  /// survives a server restart.
  Response _adminActivity(Request request) {
    final hours =
        int.tryParse(request.url.queryParameters['hours'] ?? '') ?? 24;
    final cutoff = DateTime.now().millisecondsSinceEpoch -
        Duration(hours: hours).inMilliseconds;
    final events = store.activity.where((a) => a.createdAtMs >= cutoff).toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return jsonResponse(200, {'events': events.map((e) => e.toJson()).toList()});
  }

  /// Approves a pending account, which is how accounts normally become
  /// usable: [ApprovalMode.manual] (the default) has every sign-up wait here
  /// until the operator presses Approve in the dashboard. It doubles as the
  /// escape hatch under [ApprovalMode.email] when the mail never arrived.
  Future<Response> _adminVerifyUser(Request request) async {
    final raw = await request.readAsString();
    String? email;
    try {
      email = Uri.splitQueryString(raw)['email'];
    } catch (_) {}
    email = email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      return errorResponse(400, 'bad_request', 'email is required.');
    }
    return store.lock.synchronized(() async {
      final userId = store.userIdByEmail[email];
      final user = userId == null ? null : store.usersById[userId];
      if (user == null) {
        return errorResponse(404, 'not_found', 'No account with that email.');
      }
      user.status = 'active';
      user.verificationTokenHash = null;
      user.verificationExpiresAtMs = null;
      await store.saveUsers();
      await store.logActivity(
          'admin_verified', '$email was approved by an admin');
      return _adminFormResponse(request, '/admin');
    });
  }

  /// The opposite of [_adminVerifyUser]: puts an account back to 'pending'
  /// and revokes every one of its sessions, so its devices are cut off on
  /// their very next request — [_requireAuth] rejects pending accounts, and
  /// the app shuts its own server-access gate when it sees
  /// `account_not_approved`.
  Future<Response> _adminRevokeUser(Request request) async {
    final raw = await request.readAsString();
    String? email;
    try {
      email = Uri.splitQueryString(raw)['email'];
    } catch (_) {}
    email = email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      return errorResponse(400, 'bad_request', 'email is required.');
    }
    return store.lock.synchronized(() async {
      final userId = store.userIdByEmail[email];
      final user = userId == null ? null : store.usersById[userId];
      if (user == null) {
        return errorResponse(404, 'not_found', 'No account with that email.');
      }
      user.status = 'pending';
      user.verificationTokenHash = null;
      user.verificationExpiresAtMs = null;
      store.sessionsByTokenHash.removeWhere((_, s) => s.userId == user.id);
      await store.saveUsers();
      await store.saveSessions();
      await store.logActivity(
          'admin_revoked', '$email had their approval revoked by an admin');
      return _adminFormResponse(request, '/admin');
    });
  }

  /// The dashboard's forms POST here directly (cookie-authenticated) and
  /// expect an HTML redirect back to the page; a script/API caller
  /// authenticates with the `X-Admin-Key` header instead and expects JSON.
  /// `?key=` is preserved on the redirect for old bookmarked dashboard links
  /// still authenticating that way.
  Response _adminFormResponse(Request request, String path,
      {Map<String, dynamic>? json, String? fragment}) {
    if (request.headers['x-admin-key'] != null) {
      return jsonResponse(200, json ?? {'ok': true});
    }
    final key = request.url.queryParameters['key'];
    final withKey = key != null ? '$path?key=${Uri.encodeQueryComponent(key)}' : path;
    return Response.found(fragment != null ? '$withKey#$fragment' : withKey);
  }

  /// Grants (or revokes, by setting planId='core') a plan for an account —
  /// the "Products" tab on the dashboard. Storage quota is updated to match
  /// the plan immediately (see kPlanQuotaBytes).
  Future<Response> _adminSetPlan(Request request) async {
    final raw = await request.readAsString();
    Map<String, String> form = const {};
    try {
      form = Uri.splitQueryString(raw);
    } catch (_) {}
    final email = form['email']?.trim().toLowerCase();
    final planId = form['planId'];
    if (email == null || email.isEmpty) {
      return errorResponse(400, 'bad_request', 'email is required.');
    }
    if (planId == null || !kPlanQuotaBytes.containsKey(planId)) {
      return errorResponse(400, 'bad_plan',
          'planId must be one of: ${kPlanQuotaBytes.keys.join(', ')}.');
    }
    return store.lock.synchronized(() async {
      final userId = store.userIdByEmail[email];
      final user = userId == null ? null : store.usersById[userId];
      if (user == null) {
        return errorResponse(404, 'not_found', 'No account with that email.');
      }
      user.planId = planId;
      user.quotaBytes = kPlanQuotaBytes[planId]!;
      await store.saveUsers();
      await store.logActivity(
          'plan_granted', '$email was granted the $planId plan');
      return _adminFormResponse(request, '/admin', fragment: 'products',
          json: {'ok': true, 'planId': planId, 'quotaBytes': user.quotaBytes});
    });
  }

  /// Proxies a "reload the groceries database" click to the supermarket-db
  /// API's own admin endpoint. Keeping this server in the middle means the
  /// groceries admin key stays in this process's environment — the dashboard
  /// page only ever carries this server's admin key.
  Future<Response> _adminGroceriesSync(Request request) async {
    if (!config.groceriesAdminEnabled) {
      return errorResponse(404, 'not_configured',
          'LUMA_GROCERIES_ADMIN_KEY is not set on this server.');
    }
    Map<String, String> form = const {};
    try {
      form = Uri.splitQueryString(await request.readAsString());
    } catch (_) {}
    final market = form['market'];

    final httpClient = HttpClient();
    try {
      final upstream = await httpClient
          .postUrl(Uri.parse('${config.groceriesUrl}/admin/sync'));
      upstream.headers.set('x-admin-key', config.groceriesAdminKey!);
      upstream.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded');
      if (market != null && market.isNotEmpty) {
        upstream.write('market=${Uri.encodeQueryComponent(market)}');
      }
      final response =
          await upstream.close().timeout(const Duration(seconds: 30));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 400) {
        return Response(response.statusCode,
            body: body, headers: {'Content-Type': 'application/json'});
      }
      if (request.headers['x-admin-key'] != null) {
        return Response(200,
            body: body, headers: {'Content-Type': 'application/json'});
      }
      final key = request.url.queryParameters['key'];
      final withKey =
          key != null ? '/admin?key=${Uri.encodeQueryComponent(key)}' : '/admin';
      return Response.found('$withKey#control');
    } catch (_) {
      return errorResponse(
          502, 'upstream_error', 'Could not reach the groceries server.');
    } finally {
      httpClient.close();
    }
  }

  /// Wipes and re-fetches the groceries catalog. Unlike [_adminGroceriesSync]
  /// (incremental), this deletes existing rows for the chosen scope first, so
  /// stale unavailable products don't linger. Proxied so the groceries admin
  /// key never leaves this process.
  Future<Response> _adminGroceriesReload(Request request) async {
    if (!config.groceriesAdminEnabled) {
      return errorResponse(404, 'not_configured',
          'LUMA_GROCERIES_ADMIN_KEY is not set on this server.');
    }
    Map<String, String> form = const {};
    try {
      form = Uri.splitQueryString(await request.readAsString());
    } catch (_) {}
    final market = form['market'];

    final httpClient = HttpClient();
    try {
      final upstream = await httpClient
          .postUrl(Uri.parse('${config.groceriesUrl}/admin/database/reload'));
      upstream.headers.set('x-admin-key', config.groceriesAdminKey!);
      upstream.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded');
      if (market != null && market.isNotEmpty) {
        upstream.write('market=${Uri.encodeQueryComponent(market)}');
      }
      final response =
          await upstream.close().timeout(const Duration(seconds: 30));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 400) {
        return Response(response.statusCode,
            body: body, headers: {'Content-Type': 'application/json'});
      }
      if (request.headers['x-admin-key'] != null) {
        return Response(200,
            body: body, headers: {'Content-Type': 'application/json'});
      }
      final key = request.url.queryParameters['key'];
      final withKey =
          key != null ? '/admin?key=${Uri.encodeQueryComponent(key)}' : '/admin';
      return Response.found('$withKey#control');
    } catch (_) {
      return errorResponse(
          502, 'upstream_error', 'Could not reach the groceries server.');
    } finally {
      httpClient.close();
    }
  }

  /// Fetches the groceries server's sync status (product counts + recent
  /// sync runs) for the Control panel tab, again by proxy so the key stays
  /// server-side. Reports `configured: false` instead of erroring when the
  /// operator hasn't wired the groceries server up.
  Future<Response> _adminGroceriesStatus(Request request) async {
    if (!config.groceriesAdminEnabled) {
      return jsonResponse(200, {'configured': false});
    }
    final httpClient = HttpClient();
    try {
      final upstream = await httpClient
          .getUrl(Uri.parse('${config.groceriesUrl}/admin/sync/status'));
      upstream.headers.set('x-admin-key', config.groceriesAdminKey!);
      final response =
          await upstream.close().timeout(const Duration(seconds: 15));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        return errorResponse(502, 'upstream_error',
            'Groceries server returned ${response.statusCode}.');
      }
      return Response(200,
          body: '{"configured":true,"status":$body}',
          headers: {'Content-Type': 'application/json'});
    } catch (_) {
      return errorResponse(
          502, 'upstream_error', 'Could not reach the groceries server.');
    } finally {
      httpClient.close();
    }
  }

  /// The "Update & restart server" button. All of it — the phase model, the
  /// request handling and the dashboard's script — lives in
  /// deploy_console.dart; see [DeployConsole] for why a deploy can't run
  /// inside this container.
  late final DeployConsole _deploy = DeployConsole(
    dataDir: config.dataDir,
    repoPathConfigured: config.repoPathConfigured,
  );

  /// The "System updates" button. Lives in update_check.dart for the same
  /// reason as [_deploy]: it needs deploy-watcher.sh on the host to run
  /// `apt`/`ubuntu-drivers` against the actual Ubuntu Desktop install and
  /// restart the server and wiki, not this container's own filesystem.
  late final UpdateCheckConsole _updateCheck = UpdateCheckConsole(
    dataDir: config.dataDir,
    repoPathConfigured: config.repoPathConfigured,
  );


  // ---------------------------------------------------------------------
  // Website (wiki) editor — /admin/website
  //
  // Edits only Markdown files under source/src/content in the mounted wiki
  // checkout; the served static output is never written directly. Publishing
  // drops a .build-request flag that a separate builder container picks up
  // (git commit → astro build → rsync into site/), so this process needs no
  // node, docker, or shell access to publish.
  // ---------------------------------------------------------------------

  /// One or more lowercase slug segments: `wiki/simply-cozy`, `blog/luma-1-1`.
  static final _wikiPageRe =
      RegExp(r'^[a-z0-9][a-z0-9._-]*(/[a-z0-9][a-z0-9._-]*)*$');

  String get _wikiContentPath => '${config.wikiDir}/source/src/content';

  /// Resolves a page name to its Markdown file, or null if the name is
  /// invalid. The regex already forbids `..`, empty segments, and leading
  /// dots, but the canonical-path containment check is kept as a second
  /// line of defense.
  File? _wikiPageFile(String page) {
    if (page.length > 200 || !_wikiPageRe.hasMatch(page)) return null;
    if (page.contains('..')) return null;
    final root = Directory(_wikiContentPath).absolute.path;
    final file = File('$_wikiContentPath/$page.md');
    if (!file.absolute.path.replaceAll('\\', '/').startsWith('$root/')) {
      return null;
    }
    return file;
  }

  /// CSRF guard for the state-changing website endpoints: the session cookie
  /// is SameSite=Strict, and on top of that the Origin header must match the
  /// Host we were reached on. Browser form posts always send Origin.
  bool _sameOrigin(Request request) {
    final origin = request.headers['origin'];
    final host = request.headers['host'];
    if (origin == null || host == null) return false;
    final uri = Uri.tryParse(origin);
    return uri != null && uri.authority == host;
  }

  Response? _wikiUnavailable() {
    if (!config.wikiEnabled) {
      return errorResponse(404, 'not_found',
          'Website editing is not configured (LUMA_WIKI_DIR unset).');
    }
    if (!Directory(_wikiContentPath).existsSync()) {
      return errorResponse(500, 'wiki_missing',
          'Wiki source not found at $_wikiContentPath — run deploy.sh once '
          'to upload it.');
    }
    return null;
  }

  Future<Response> _adminWebsiteIndex(Request request) async {
    final unavailable = _wikiUnavailable();
    if (unavailable != null) return unavailable;

    final root = Directory(_wikiContentPath);
    final prefix = '${root.path}/';
    final pages = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.md')) continue;
      final normalized = entity.path.replaceAll('\\', '/');
      if (!normalized.startsWith(prefix)) continue;
      pages.add(normalized
          .substring(prefix.length)
          .replaceFirst(RegExp(r'\.md$'), ''));
    }
    pages.sort();
    final pageSet = pages.toSet();

    // Scan every page's body for links to a wiki/blog/admin-editor page that
    // doesn't exist yet, so a page like simply-cozy can reference
    // "coffee-machine" before that page is created and the tree shows it as
    // a pending stub instead of the link silently going nowhere.
    final referencedMissing = <String>{};
    final linkRe = RegExp(r'\]\(([^)\s]+)\)');
    for (final p in pages) {
      final file = _wikiPageFile(p);
      if (file == null) continue;
      String content;
      try {
        content = await file.readAsString();
      } catch (_) {
        continue;
      }
      for (final m in linkRe.allMatches(content)) {
        final uri = Uri.tryParse(m[1]!);
        if (uri == null) continue;
        final path = uri.path;
        String? target;
        if (path.startsWith('/admin/website/')) {
          target = path.substring('/admin/website/'.length);
        } else if (path.startsWith('/wiki/') || path.startsWith('/blog/')) {
          target = path.substring(1);
        }
        if (target == null) continue;
        target = target.replaceAll(RegExp(r'/+$'), '');
        if (target.isEmpty || !_wikiPageRe.hasMatch(target)) continue;
        if (pageSet.contains(target)) continue; // already a real page
        referencedMissing.add(target);
      }
    }

    // Group by top-level folder — each is a content collection (wiki, blog…).
    final byCollection = <String, List<String>>{};
    for (final p in pages) {
      final slash = p.indexOf('/');
      final collection = slash > 0 ? p.substring(0, slash) : p;
      (byCollection[collection] ??= []).add(p);
    }
    for (final target in referencedMissing) {
      final slash = target.indexOf('/');
      final collection = slash > 0 ? target.substring(0, slash) : target;
      // A link to a collection with no real pages yet still gets its own
      // section (empty count, all-phantom tree) — that's a useful signal
      // too, e.g. a typo'd collection name in a link.
      byCollection.putIfAbsent(collection, () => []);
    }
    final collectionNames = {'wiki': 'Wiki', 'blog': 'Devlog'};

    // The team roster is data, not a Markdown page, so it never shows up in
    // the tree above — surface it here with its own count instead.
    var teamCount = 0;
    if (await _wikiTeamFile.exists()) {
      try {
        final decoded = jsonDecode(await _wikiTeamFile.readAsString());
        if (decoded is Map && decoded['members'] is List) {
          teamCount = (decoded['members'] as List).length;
        }
      } catch (_) {}
    }

    final sections = byCollection.entries.map((entry) {
      final collection = entry.key;
      final name = collectionNames[collection] ?? collection;
      final tree = _WikiTreeNode();
      for (final p in entry.value) {
        final rel = p.contains('/') ? p.substring(p.indexOf('/') + 1) : p;
        var node = tree;
        for (final segment in rel.split('/')) {
          node = node.children.putIfAbsent(segment, () => _WikiTreeNode());
        }
        node.pagePath = p;
      }
      for (final target
          in referencedMissing.where((t) => t.startsWith('$collection/'))) {
        final rel = target.substring(collection.length + 1);
        var node = tree;
        for (final segment in rel.split('/')) {
          node = node.children.putIfAbsent(segment, () => _WikiTreeNode());
        }
        if (node.pagePath == null) node.phantomPath = target;
      }
      final newDevlogBtn = collection == 'blog'
          ? '<a href="/admin/website/new-devlog" class="btn btn-primary btn-sm">'
              '+ New devlog</a>'
          : '';
      final newPageHint = collection == 'wiki'
          ? '<p class="hint tree-hint">New page: open '
              '<code>/admin/website/wiki/&lt;name&gt;</code> — nest it under an '
              'existing page the same way, e.g. '
              '<code>wiki/simply-cozy/&lt;name&gt;</code>. Link to a page that '
              'doesn\'t exist yet and it shows up below as '
              '<span class="tree-phantom-badge">not created</span> with a '
              'shortcut to make it.</p>'
          : '';
      return '<div class="card table-card">'
          '<div class="tree-head">'
          '<h2><span>$name</span><span class="count-pill">${entry.value.length}</span></h2>'
          '$newDevlogBtn'
          '</div>'
          '<div class="tree" role="tree">${_renderWikiTree(tree.children, collection: collection)}</div>'
          '$newPageHint'
          '</div>';
    }).join();

    return Response(200,
        body: '<!doctype html><html><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width, initial-scale=1">'
            '<title>luma admin — website</title>'
            '<style>$_adminCss$_wikiTreeCss</style></head>'
            '<body><div class="wrap">'
            '<header class="top"><h1>luma<span class="dot">.</span> website</h1>'
            '<span class="sub">page editor</span>'
            '<nav style="margin-left:auto">'
            '<a href="/admin" class="btn btn-ghost btn-sm">← dashboard</a>'
            '</nav></header>'
            '<div class="stats">'
            '<div class="stat"><div class="n">${pages.length}</div>'
            '<div class="l">Pages</div></div>'
            '<div class="stat"><div class="n">${byCollection.length}</div>'
            '<div class="l">Collections</div></div>'
            '<div class="stat"><div class="n">$teamCount</div>'
            '<div class="l">Team members</div></div>'
            '</div>'
            '$sections'
            '<div class="card table-card">'
            '<div class="tree-head">'
            '<h2><span>Team</span><span class="count-pill">$teamCount</span></h2>'
            '<a href="/admin/website/team" class="btn btn-primary btn-sm">'
            'Edit roster</a>'
            '</div>'
            '<p class="hint tree-hint">The cards on '
            '<code>/wiki/team</code> — name, role, description, icon and '
            'avatar per person. Stored as <code>team.json</code> rather than a '
            'Markdown page, so it has its own form instead of appearing in the '
            'tree above.</p>'
            '</div>'
            '<div class="card">'
            '<h2>Publish</h2>'
            '<p class="hint">Saved edits stay in draft on the server until you '
            'publish — this commits them to git, rebuilds the site with '
            'Astro, and rsyncs the result live.</p>'
            '<div class="product-form">'
            '<form method="post" action="/admin/website/build" style="margin:0">'
            '<button type="submit" class="btn btn-primary">Publish site '
            '(rebuild)</button></form>'
            '<span id="buildbadge" class="badge" style="display:none"></span>'
            '</div>'
            '<pre id="buildlog" class="log" style="display:none;margin-top:12px"></pre>'
            '</div>'
            '<script>$_wikiBuildScript</script>'
            '</div></body></html>',
        headers: {'Content-Type': 'text/html; charset=utf-8'});
  }

  /// Renders one level of the page tree. A node with children becomes an
  /// expandable `<details>` (native disclosure semantics — keyboard and
  /// screen-reader accessible with zero extra JS). A childless node is
  /// either a real page (only created while walking toward one) or a
  /// "phantom" — a page some other page links to that doesn't exist yet.
  String _renderWikiTree(Map<String, _WikiTreeNode> nodes,
      {int depth = 0, required String collection}) {
    final keys = nodes.keys.toList()..sort();
    final buf = StringBuffer();
    for (final key in keys) {
      final node = nodes[key]!;
      final label = _htmlEscape(key);
      final isPhantom = node.pagePath == null && node.phantomPath != null;
      if (node.children.isNotEmpty) {
        final selfRow = node.pagePath != null
            ? '<div class="tree-row tree-self">'
                '<a href="/admin/website/${_htmlEscape(node.pagePath!)}">'
                'This page<span class="tree-self-name"> — $label</span></a></div>'
            : (isPhantom ? _phantomRow(label, node.phantomPath!) : '');
        buf.write('<details class="tree-node">'
            '<summary><span class="tree-toggle" aria-hidden="true"></span>'
            '<span class="tree-label">$label</span></summary>'
            '<div class="tree-children">'
            '$selfRow'
            '${_renderWikiTree(node.children, depth: depth + 1, collection: collection)}'
            '</div></details>');
      } else if (isPhantom) {
        buf.write(_phantomRow(label, node.phantomPath!));
      } else {
        final deleteBtn = collection == 'blog'
            ? '<form class="tree-delete-form" method="post" '
                'action="/admin/website/${_htmlEscape(node.pagePath!)}/delete" '
                'onsubmit="return confirm(\'Delete this devlog post? This '
                'cannot be undone.\')">'
                '<button class="tree-delete" type="submit">Delete</button>'
                '</form>'
            : '';
        buf.write('<div class="tree-row tree-leaf">'
            '<a href="/admin/website/${_htmlEscape(node.pagePath!)}">$label</a>'
            '<a class="tree-edit" href="/admin/website/${_htmlEscape(node.pagePath!)}">Edit</a>'
            '$deleteBtn'
            '</div>');
      }
    }
    return buf.toString();
  }

  /// A page some other page links to, that doesn't have a file yet —
  /// dimmed, dashed, with a shortcut straight into a blank editor for it.
  String _phantomRow(String label, String phantomPath) =>
      '<div class="tree-row tree-leaf tree-phantom">'
      '<a class="tree-phantom-link" href="/admin/website/${_htmlEscape(phantomPath)}">'
      '$label</a>'
      '<span class="tree-phantom-badge">not created</span>'
      '<a class="tree-edit" href="/admin/website/${_htmlEscape(phantomPath)}">Create</a>'
      '</div>';

  static const _wikiTreeCss = r'''
.tree-head{display:flex;align-items:center;justify-content:space-between;
gap:12px;padding:6px 6px 2px;margin-bottom:2px}
.tree-head h2{display:flex;align-items:center;gap:8px;margin:0;padding:0}
.count-pill{display:inline-flex;align-items:center;justify-content:center;
min-width:20px;height:20px;padding:0 6px;border-radius:999px;background:#241e3c;
color:#a89fd6;font-size:11px;font-weight:700;font-variant-numeric:tabular-nums}
.tree{padding:2px 6px 8px}
.tree-row{display:flex;align-items:center;justify-content:space-between;gap:10px;
min-height:40px;padding:0 10px 0 30px;border-radius:8px}
.tree-row:hover{background:#1a1530}
.tree-row a{color:#d3cef0;text-decoration:none;font-size:13.5px;
padding:8px 0;flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;
white-space:nowrap}
.tree-row a:hover{color:#ece8f7;text-decoration:underline}
.tree-row a:focus-visible{outline:2px solid #8a7ee0;outline-offset:2px;
border-radius:4px}
.tree-edit{flex:none!important;font-size:11px!important;font-weight:600;
color:#8d86a8!important;text-decoration:none!important;padding:4px 10px!important;
border-radius:999px;border:1px solid #262038;opacity:0;transition:opacity .12s}
.tree-row:hover .tree-edit,.tree-row:focus-within .tree-edit{opacity:1}
.tree-edit:hover{border-color:#463d6b;color:#ece8f7!important}
.tree-delete-form{flex:none;margin:0}
.tree-delete{flex:none;font:inherit;font-size:11px!important;font-weight:600;
color:#b08d8d!important;background:none;cursor:pointer;padding:4px 10px!important;
border-radius:999px;border:1px solid #262038;opacity:0;transition:opacity .12s,
border-color .12s,color .12s}
.tree-row:hover .tree-delete,.tree-row:focus-within .tree-delete{opacity:1}
.tree-delete:hover{border-color:#7a3d3d;color:#e08d8d!important}
.tree-node{position:relative}
.tree-node > summary{list-style:none;display:flex;align-items:center;gap:8px;
min-height:40px;padding:0 10px;border-radius:8px;cursor:pointer;user-select:none;
font-size:13.5px;font-weight:600;color:#c7c1e6}
.tree-node > summary::-webkit-details-marker{display:none}
.tree-node > summary:hover{background:#1a1530}
.tree-node > summary:focus-visible{outline:2px solid #8a7ee0;outline-offset:-2px}
.tree-toggle{flex:none;width:16px;height:16px;position:relative}
.tree-toggle::before{content:'';position:absolute;left:3px;top:6px;
border:4px solid transparent;border-left-color:#7f7898;border-right:none;
transition:transform .15s var(--ease-out,ease)}
.tree-node[open] > summary .tree-toggle::before{transform:rotate(90deg)
translate(2px,-2px)}
.tree-children{position:relative;margin-left:19px;padding-left:12px;
border-left:1px solid #262038}
.tree-children .tree-row,.tree-children .tree-node>summary{padding-left:11px}
.tree-self{opacity:.85}
.tree-self a{font-style:italic}
.tree-self-name{font-style:normal}
.tree-hint{margin:8px 6px 0;padding-top:10px;border-top:1px solid #1d1830}
.tree-hint code{background:#1a1530;border:1px solid #262038;border-radius:5px;
padding:1px 6px;font-size:11.5px;color:#c7c1e6}
.tree-hint .tree-phantom-badge{position:relative;top:-1px}
.tree-phantom-link{color:#9089b0!important;font-style:italic}
.tree-phantom-link:hover{color:#c7c1e6!important}
.tree-phantom-badge{flex:none;font-size:10px;font-weight:700;
letter-spacing:.03em;text-transform:uppercase;color:#e0c87e;
background:rgba(224,200,126,.12);border:1px dashed rgba(224,200,126,.4);
border-radius:999px;padding:2px 8px}
''';

  /// Page name from the request path, e.g. /admin/website/wiki/simply-cozy
  /// → "wiki/simply-cozy". The single-arg [_requireAdmin] wrapper hides the
  /// router's path parameter, so it is re-derived here.
  static String _wikiPageOf(Request request) {
    const prefix = 'admin/website/';
    final path = request.url.path;
    return path.startsWith(prefix) ? path.substring(prefix.length) : '';
  }

  Future<Response> _adminWebsiteEditor(Request request) async {
    final unavailable = _wikiUnavailable();
    if (unavailable != null) return unavailable;
    final page = _wikiPageOf(request);
    final file = _wikiPageFile(page);
    if (file == null) {
      return errorResponse(400, 'bad_page',
          'Invalid page name. Use lowercase letters, digits, dashes, and "/".');
    }
    final exists = await file.exists();
    final content = exists ? await file.readAsString() : '';
    // JSON-embedded into a <script>; <-escape closes the XSS door of a
    // literal "</script>" inside page content.
    final initial = jsonEncode({'page': page, 'content': content, 'isNew': !exists})
        .replaceAll('<', '\\u003c');

    return Response(200,
        body: '<!doctype html><html><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width, initial-scale=1">'
            '<title>edit — ${_htmlEscape(page)}</title>'
            '<style>$_wikiEditorCss</style></head>'
            '<body>'
            '<header class="ed-top">'
            '<a class="ed-back" href="/admin/website" aria-label="All pages">←</a>'
            '<h1 class="ed-name">${_htmlEscape(page)}</h1>'
            '<span id="status" class="ed-status" role="status" aria-live="polite"></span>'
            '<div class="ed-actions">'
            '<button id="savebtn" class="ed-btn" type="button">Save</button>'
            '<button id="pubbtn" class="ed-btn ed-primary" type="button">'
            'Save &amp; publish</button>'
            '</div></header>'
            '<div class="ed-format" role="toolbar" aria-label="Formatting">'
            '<button id="fmt-bold" class="ed-fmt" type="button" '
            'title="Bold (Ctrl+B)"><strong>B</strong></button>'
            '<button id="fmt-italic" class="ed-fmt" type="button" '
            'title="Italic (Ctrl+I)"><em>i</em></button>'
            '<button id="fmt-h2" class="ed-fmt" type="button" '
            'title="Heading">H2</button>'
            '<button id="fmt-list" class="ed-fmt" type="button" '
            'title="Bullet list">•⁠ ⁠list</button>'
            '<span class="ed-fmt-sep"></span>'
            '<button id="linkbtn" class="ed-fmt" type="button" '
            'title="Insert link — turns a name into a clickable link '
            'instead of a bare URL" aria-expanded="false">Link</button>'
            '<button id="imgbtn" class="ed-fmt" type="button" '
            'title="Insert image">Image</button>'
            '<input id="imgfile" type="file" accept="image/*" hidden>'
            '<div id="linkpop" class="ed-linkpop" hidden>'
            '<input id="linktext" type="text" placeholder="Text readers see" '
            'aria-label="Link text">'
            '<input id="linkurl" type="url" placeholder="https://…" '
            'aria-label="Link URL">'
            '<button id="linkgo" type="button" class="ed-btn ed-primary">Add</button>'
            '</div>'
            '</div>'
            '<div class="ed-tabs" role="tablist">'
            '<button class="ed-tab is-on" data-pane="write" role="tab">Write</button>'
            '<button class="ed-tab" data-pane="preview" role="tab">Preview</button>'
            '</div>'
            '<main class="ed-split">'
            '<section class="ed-pane" id="pane-write">'
            '<details class="ed-fm"><summary>Page settings (frontmatter)</summary>'
            '<textarea id="fm" spellcheck="false" rows="8" '
            'aria-label="Frontmatter"></textarea></details>'
            '<textarea id="src" spellcheck="false" '
            'aria-label="Page content (Markdown)" '
            'placeholder="Write Markdown here…"></textarea>'
            '</section>'
            '<section class="ed-pane" id="pane-preview">'
            '<iframe id="pv" title="Live preview"></iframe>'
            '</section>'
            '</main>'
            '<script>window.__initial=$initial;</script>'
            '<script>$_wikiEditorJs</script>'
            '</body></html>',
        headers: {'Content-Type': 'text/html; charset=utf-8'});
  }

  // ---- Preview assets: the editor iframe uses the *built site's* own CSS
  // and fonts so the preview is pixel-identical to wiki.luma-app.cc. ----

  static const _assetTypes = {
    'css': 'text/css; charset=utf-8',
    'woff2': 'font/woff2',
    'woff': 'font/woff',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'svg': 'image/svg+xml',
    'avif': 'image/avif',
    'ico': 'image/x-icon',
  };

  static final _assetNameRe = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');

  Response _serveFile(File file, String name, {String cache = 'no-store'}) {
    if (!file.existsSync()) return errorResponse(404, 'not_found', 'Not found.');
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final type = _assetTypes[ext];
    if (type == null) return errorResponse(404, 'not_found', 'Not found.');
    return Response(200, body: file.openRead(), headers: {
      'Content-Type': type,
      'Content-Length': '${file.lengthSync()}',
      'Cache-Control': cache,
    });
  }

  /// Built wiki pages worth sampling the preview's CSS from, best first:
  /// top-level articles, then one level of nesting (simply-cozy/trellis),
  /// then the wiki landing page as a last resort.
  List<File> _wikiPreviewSamples() {
    final root = Directory('${config.wikiDir}/site/wiki');
    if (!root.existsSync()) return const [];
    final dirs = root.listSync().whereType<Directory>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final out = <File>[];
    for (final d in dirs) {
      final f = File('${d.path}/index.html');
      if (f.existsSync()) out.add(f);
    }
    for (final d in dirs) {
      final subs = d.listSync().whereType<Directory>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final s in subs) {
        final f = File('${s.path}/index.html');
        if (f.existsSync()) out.add(f);
      }
    }
    final landing = File('${root.path}/index.html');
    if (landing.existsSync()) out.add(landing);
    return out;
  }

  /// All of the built site's stylesheets concatenated, with asset URLs
  /// rewritten to our authed proxy so fonts/images resolve too.
  Future<Response> _wikiPreviewCss(Request request) async {
    final unavailable = _wikiUnavailable();
    if (unavailable != null) return unavailable;
    final dir = Directory('${config.wikiDir}/site/_astro');
    if (!dir.existsSync()) {
      return errorResponse(404, 'not_found', 'No built site yet — publish once.');
    }
    // Use exactly the stylesheets a built wiki page links, in order —
    // concatenating every page's CSS lets unrelated pages override the
    // wiki's own rules. Fall back to all of them if no page qualifies.
    var files = <File>[];
    // Astro inlines the page-specific CSS (the prose/wiki rules that
    // actually style an article) as <style> blocks and links only the
    // shared bundles, so the preview needs both halves.
    var inline = '';
    // Sample a real *article* page — the exact template the preview mirrors.
    // The wiki landing page and /wiki/changelog link different bundles, and a
    // page retired through Astro's `redirects:` is left as a bare meta-refresh
    // stub carrying no CSS at all. Sampling one of those (/wiki/about-
    // hyperlinkhyper, first alphabetically, did exactly that) drops every
    // inlined prose rule and the preview falls back to browser defaults, so
    // hold out for a page that renders `class="prose"`; settle for any page
    // with the wiki chrome only if none does.
    for (final strict in [true, false]) {
      for (final sample in _wikiPreviewSamples()) {
        final html = sample.readAsStringSync();
        if (html.contains('http-equiv="refresh"')) continue;
        if (!html.contains(strict ? 'class="prose"' : 'wiki-card')) continue;
        final links = RegExp(r'<link rel="stylesheet" href="/_astro/([^"]+)"')
            .allMatches(html)
            .map((m) => File('${dir.path}/${m[1]}'))
            .where((f) => f.existsSync())
            .toList();
        if (links.isEmpty) continue;
        files = links;
        inline = RegExp(r'<style>(.*?)</style>', dotAll: true)
            .allMatches(html)
            .map((m) => m[1]!)
            .join('\n');
        break;
      }
      if (files.isNotEmpty) break;
    }
    if (files.isEmpty) {
      files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.css'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
    }
    final buf = StringBuffer();
    for (final f in files) {
      buf.writeln(f.readAsStringSync()
          .replaceAll('url(/_astro/', 'url(/admin/website/preview/astro/')
          .replaceAll('url("/_astro/', 'url("/admin/website/preview/astro/')
          .replaceAll("url('/_astro/", "url('/admin/website/preview/astro/"));
    }
    if (inline.isNotEmpty) {
      // Placeholder keeps the second (broader) rewrite from re-prefixing
      // URLs the first one already handled.
      buf.writeln(inline
          .replaceAll('url(/_astro/', 'url(@astro@')
          .replaceAll('url(/', 'url(/admin/website/preview/public/')
          .replaceAll('url(@astro@', 'url(/admin/website/preview/astro/'));
    }
    return Response(200, body: buf.toString(), headers: {
      'Content-Type': 'text/css; charset=utf-8',
      'Cache-Control': 'private, max-age=300',
    });
  }

  Future<Response> _wikiPreviewAstroAsset(Request request) async {
    final unavailable = _wikiUnavailable();
    if (unavailable != null) return unavailable;
    final name = request.url.pathSegments.last;
    if (!_assetNameRe.hasMatch(name) || name.contains('..')) {
      return errorResponse(404, 'not_found', 'Not found.');
    }
    return _serveFile(File('${config.wikiDir}/site/_astro/$name'), name,
        cache: 'private, max-age=3600');
  }

  /// Serves files from the editable source's public/ dir, so images that are
  /// uploaded but not yet published still show up in the preview.
  Future<Response> _wikiPreviewPublicAsset(Request request) async {
    final unavailable = _wikiUnavailable();
    if (unavailable != null) return unavailable;
    const prefix = 'admin/website/preview/public/';
    final rel = request.url.path.startsWith(prefix)
        ? request.url.path.substring(prefix.length)
        : '';
    if (rel.isEmpty ||
        rel.contains('..') ||
        !RegExp(r'^[A-Za-z0-9._/-]+$').hasMatch(rel)) {
      return errorResponse(404, 'not_found', 'Not found.');
    }
    final root = '${config.wikiDir}/source/public';
    final file = File('$root/$rel');
    if (!file.absolute.path.replaceAll('\\', '/')
        .startsWith(Directory(root).absolute.path.replaceAll('\\', '/'))) {
      return errorResponse(404, 'not_found', 'Not found.');
    }
    // Fall back to the built site (already-published assets like wiki-bg.jpg).
    final fallback = File('${config.wikiDir}/site/$rel');
    return _serveFile(file.existsSync() ? file : fallback, rel.split('/').last);
  }

  static const _wikiUploadMax = 8 * 1024 * 1024;

  /// Raw-body image upload (no multipart): the filename travels in ?name=,
  /// the bytes in the body. Saved under source/public/images/uploads/.
  Future<Response> _adminWebsiteUpload(Request request) async {
    final unavailable = _wikiUnavailable();
    if (unavailable != null) return unavailable;
    if (!_sameOrigin(request)) {
      return errorResponse(403, 'bad_origin', 'Cross-origin request rejected.');
    }
    final rawName = request.url.queryParameters['name'] ?? '';
    final dot = rawName.lastIndexOf('.');
    if (dot <= 0) return errorResponse(400, 'bad_name', 'Filename needs an extension.');
    final ext = rawName.substring(dot + 1).toLowerCase();
    if (!{'png', 'jpg', 'jpeg', 'webp', 'gif', 'svg', 'avif'}.contains(ext)) {
      return errorResponse(400, 'bad_type',
          'Only png, jpg, webp, gif, svg, and avif images are allowed.');
    }
    var stem = rawName
        .substring(0, dot)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    if (stem.isEmpty) stem = 'image';

    final bytes = BytesBuilder();
    await for (final chunk in request.read()) {
      bytes.add(chunk);
      if (bytes.length > _wikiUploadMax) {
        return errorResponse(413, 'too_large', 'Image too large (max 8 MB).');
      }
    }
    if (bytes.length == 0) return errorResponse(400, 'empty', 'Empty upload.');

    final dir = Directory('${config.wikiDir}/source/public/images/uploads');
    await dir.create(recursive: true);
    var name = '$stem.$ext';
    var n = 1;
    while (File('${dir.path}/$name').existsSync()) {
      name = '$stem-${++n}.$ext';
    }
    await File('${dir.path}/$name').writeAsBytes(bytes.takeBytes(), flush: true);
    return jsonResponse(200, {'url': '/images/uploads/$name'});
  }

  // ---------------------------------------------------------------------
  // Team roster editor — /admin/website/team
  //
  // The wiki's Team page renders src/content/team.json rather than Markdown,
  // because a roster is a list of records and not prose. This is the form for
  // that file: it writes into the same mounted source tree the page editor
  // uses, and publishes through the same .build-request flag, so a member
  // added here shows up on /wiki/team after the next build.
  // ---------------------------------------------------------------------

  /// Icons offered for a member, kept in step with TEAM_ICONS in the site's
  /// `src/data/team.ts`. A name outside the site's icon set renders as
  /// nothing at all, so anything unrecognised is replaced with the fallback
  /// on save rather than trusted through.
  static const _teamIcons = [
    'user', 'users', 'star', 'sparkles', 'leaf', 'coffee', 'moon', 'rocket',
    'brush', 'palette', 'wrench', 'braces', 'bot', 'book', 'shield', 'zap',
    'globe', 'compass', 'gamepad', 'package', 'server', 'key', 'image',
    'message', 'pencil', 'activity', 'smile', 'puzzle', 'cloud', 'mail',
    'github', 'discord',
  ];

  File get _wikiTeamFile => File('$_wikiContentPath/team.json');

  static String _teamStr(Object? v, {int max = 200}) {
    if (v is! String) return '';
    final s = v.trim();
    return s.length > max ? s.substring(0, max) : s;
  }

  static String _teamIcon(Object? v, String fallback) {
    final s = v is String ? v.trim() : '';
    return _teamIcons.contains(s) ? s : fallback;
  }

  /// Site-relative paths and http(s)/mailto only. These end up as `href`s and
  /// image sources on a public page, so `javascript:` and protocol-relative
  /// URLs are dropped rather than escaped.
  static String _teamHref(Object? v) {
    final s = _teamStr(v, max: 500);
    if (s.isEmpty) return '';
    if (s.startsWith('//')) return '';
    if (s.startsWith('/')) return s;
    return RegExp(r'^(https?:|mailto:)', caseSensitive: false).hasMatch(s)
        ? s
        : '';
  }

  Future<Response> _adminTeamEditor(Request request) async {
    final unavailable = _wikiUnavailable();
    if (unavailable != null) return unavailable;

    var members = const <dynamic>[];
    if (await _wikiTeamFile.exists()) {
      try {
        final decoded = jsonDecode(await _wikiTeamFile.readAsString());
        if (decoded is Map && decoded['members'] is List) {
          members = decoded['members'] as List;
        }
      } catch (_) {
        // A corrupt or hand-edited file must not lock the operator out of the
        // only UI that can fix it — start empty and let a save overwrite it.
      }
    }
    // JSON in a <script>; escaping "<" closes the door on a literal
    // "</script>" arriving through a member's description.
    final initial = jsonEncode({'members': members, 'icons': _teamIcons})
        .replaceAll('<', '\\u003c');

    return Response(200,
        body: '<!doctype html><html><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width, initial-scale=1">'
            '<title>luma admin — team</title>'
            '<style>$_adminCss$_teamEditorCss</style></head>'
            '<body><div class="wrap">'
            '<header class="top"><h1>luma<span class="dot">.</span> team</h1>'
            '<span class="sub">wiki roster</span>'
            '<nav style="margin-left:auto">'
            '<a href="/admin/website" class="btn btn-ghost btn-sm">← all pages</a>'
            '</nav></header>'
            '<div class="card">'
            '<h2>Members</h2>'
            '<p class="hint">One card each on <code>/wiki/team</code>, shown in '
            'this order. Only the name is required — a member with no avatar '
            'falls back to the icon you pick.</p>'
            '<div id="tmlist" class="tm-list"></div>'
            '<button type="button" class="btn btn-ghost tm-addbtn" id="tmadd">'
            '+ Add member</button>'
            '</div>'
            '<div class="card">'
            '<h2>Save</h2>'
            '<p class="hint"><strong>Save</strong> writes the roster to '
            '<code>src/content/team.json</code> on the server and leaves it as '
            'a draft. <strong>Save &amp; publish</strong> also rebuilds the '
            'site, which is when the page actually changes.</p>'
            '<div class="product-form">'
            '<button type="button" class="btn btn-primary" id="tmsave">Save</button>'
            '<button type="button" class="btn btn-ghost" id="tmpub">Save &amp; publish</button>'
            '<span id="tmstatus" class="tm-status" role="status" aria-live="polite"></span>'
            '<span id="buildbadge" class="badge" style="display:none"></span>'
            '</div>'
            '<pre id="buildlog" class="log" style="display:none;margin-top:12px"></pre>'
            '</div>'
            '</div>'
            '<script type="application/json" id="teamdata">$initial</script>'
            '<script>$_teamEditorScript</script>'
            '</body></html>',
        headers: {'Content-Type': 'text/html; charset=utf-8'});
  }

  Future<Response> _adminTeamSave(Request request) async {
    final unavailable = _wikiUnavailable();
    if (unavailable != null) return unavailable;
    if (!_sameOrigin(request)) {
      return errorResponse(403, 'bad_origin', 'Cross-origin request rejected.');
    }
    Map<String, String> form = const {};
    try {
      form = Uri.splitQueryString(await request.readAsString());
    } catch (_) {}
    final data = form['data'];
    if (data == null) {
      return errorResponse(400, 'bad_request', 'Missing data field.');
    }
    if (data.length > 512 * 1024) {
      return errorResponse(413, 'too_large', 'Roster too large.');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(data);
    } catch (_) {
      return errorResponse(400, 'bad_json', 'Roster is not valid JSON.');
    }
    if (decoded is! Map || decoded['members'] is! List) {
      return errorResponse(
          400, 'bad_shape', 'Expected an object with a "members" list.');
    }

    // Normalised here as well as in the browser: the form is convenience, the
    // server is the thing that decides what lands in the file.
    final members = <Map<String, Object?>>[];
    for (final raw in decoded['members'] as List) {
      if (raw is! Map) continue;
      final name = _teamStr(raw['name'], max: 120);
      // A nameless row is a half-filled form, not a person.
      if (name.isEmpty) continue;
      final links = <Map<String, String>>[];
      final rawLinks = raw['links'];
      if (rawLinks is List) {
        for (final rl in rawLinks.take(8)) {
          if (rl is! Map) continue;
          final href = _teamHref(rl['href']);
          if (href.isEmpty) continue;
          links.add({
            'label': _teamStr(rl['label'], max: 60),
            'href': href,
            'icon': _teamIcon(rl['icon'], 'globe'),
          });
        }
      }
      members.add({
        'name': name,
        'role': _teamStr(raw['role'], max: 120),
        'description': _teamStr(raw['description'], max: 2000),
        'icon': _teamIcon(raw['icon'], 'user'),
        'avatar': _teamHref(raw['avatar']),
        'links': links,
      });
      if (members.length >= 100) break;
    }

    final file = _wikiTeamFile;
    await file.parent.create(recursive: true);
    // Indented so the file stays readable to anyone who opens it in the repo,
    // and write-then-rename so a build never reads a half-written roster.
    final encoded =
        const JsonEncoder.withIndent('  ').convert({'members': members});
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString('$encoded\n', flush: true);
    await tmp.rename(file.path);

    final publish = form['publish'] == '1';
    if (publish) _requestWikiBuild();
    return jsonResponse(
        200, {'ok': true, 'count': members.length, 'publishing': publish});
  }

  // ---- Quick devlog creation: a small form instead of hand-writing
  // frontmatter YAML in the raw editor. Writes the post as a draft by
  // default and hands off to the full split editor for everything else. ----

  static String _slugify(String s) {
    final slug = s
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r"[^a-z0-9\s-]"), '')
        .replaceAll(RegExp(r'[\s_-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'post' : slug;
  }

  static String _yamlStr(String s) =>
      '"${s.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';

  Response _adminNewDevlogForm(Request request) {
    final unavailable = _wikiUnavailable();
    if (unavailable != null) return unavailable;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return Response(200,
        body: '<!doctype html><html><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width, initial-scale=1">'
            '<title>luma admin — new devlog</title>'
            '<style>$_adminCss'
            '.product-form{flex-direction:column;align-items:stretch;gap:6px}'
            '.product-form label{font-size:11px;letter-spacing:.05em;'
            'text-transform:uppercase;color:#8d86a8;margin:10px 0 -2px}'
            '.product-form label:first-child{margin-top:0}'
            '.product-form input,.product-form select{width:100%}'
            '.product-form textarea{background:#1a1530;color:#ece8f7;'
            'border:1px solid #2d2645;border-radius:9px;padding:10px 12px;'
            'font-size:13px;font-family:inherit;outline:none;width:100%;'
            'min-height:220px;resize:vertical}'
            '.product-form textarea:focus{border-color:#8a7ee0}'
            '.devlog-row{display:flex;gap:10px}'
            '.devlog-row > div{flex:1}'
            '.devlog-check{flex-direction:row!important;align-items:center;'
            'gap:8px;text-transform:none!important;letter-spacing:0!important;'
            'font-size:13px!important;color:#ece8f7!important}'
            '.devlog-check input{width:auto!important}'
            '</style></head><body><div class="wrap">'
            '<header class="top"><h1>luma<span class="dot">.</span> new devlog</h1>'
            '<nav style="margin-left:auto">'
            '<a href="/admin/website" class="btn btn-ghost btn-sm">← all pages</a>'
            '</nav></header>'
            '<div class="card" style="max-width:640px">'
            '<h2>New devlog post</h2>'
            '<form method="post" action="/admin/website/new-devlog">'
            '<div class="product-form">'
            '<label for="title">Title</label>'
            '<input id="title" name="title" type="text" required autofocus '
            'placeholder="What happened this week">'
            '<label for="description">Description</label>'
            '<input id="description" name="description" type="text" required '
            'placeholder="One line for the devlog list">'
            '<div class="devlog-row">'
            '<div><label for="topic">Topic</label>'
            '<select id="topic" name="topic">'
            '<option value="site">Site</option>'
            '<option value="luma">Luma</option>'
            '<option value="minecraft">Minecraft</option>'
            '</select></div>'
            '<div><label for="date">Date</label>'
            '<input id="date" name="date" type="date" value="$today"></div>'
            '</div>'
            '<label for="tags">Tags (comma separated)</label>'
            '<input id="tags" name="tags" type="text" placeholder="update, mods">'
            '<label for="body">Body (Markdown)</label>'
            '<textarea id="body" name="body" '
            'placeholder="Write the devlog here — you can keep editing after '
            'it is created."></textarea>'
            '<label class="devlog-check">'
            '<input type="checkbox" name="draft" value="1" checked>'
            'Save as draft (hidden from the site until you publish it)</label>'
            '<button type="submit" class="btn btn-primary" '
            'style="align-self:flex-start;margin-top:6px">Create devlog</button>'
            '</div></form></div></div></body></html>',
        headers: {'Content-Type': 'text/html; charset=utf-8'});
  }

  Future<Response> _adminNewDevlogCreate(Request request) async {
    final unavailable = _wikiUnavailable();
    if (unavailable != null) return unavailable;
    if (!_sameOrigin(request)) {
      return errorResponse(403, 'bad_origin', 'Cross-origin request rejected.');
    }
    Map<String, String> form = const {};
    try {
      form = Uri.splitQueryString(await request.readAsString());
    } catch (_) {}
    final title = (form['title'] ?? '').trim();
    final description = (form['description'] ?? '').trim();
    if (title.isEmpty || description.isEmpty) {
      return errorResponse(
          400, 'bad_request', 'Title and description are required.');
    }
    final topic = {'luma', 'minecraft', 'site'}.contains(form['topic'])
        ? form['topic']!
        : 'site';
    final date = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(form['date'] ?? '')
        ? form['date']!
        : DateTime.now().toIso8601String().substring(0, 10);
    final tags = (form['tags'] ?? '')
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final draft = form['draft'] == '1';
    final body = (form['body'] ?? '').trim();

    final dir = Directory('$_wikiContentPath/blog');
    await dir.create(recursive: true);
    final baseSlug = _slugify(title);
    var file = File('${dir.path}/$baseSlug.md');
    var n = 2;
    while (await file.exists()) {
      file = File('${dir.path}/$baseSlug-${n++}.md');
    }
    final slug =
        file.path.replaceAll('\\', '/').split('/').last.replaceFirst(RegExp(r'\.md$'), '');

    final tagsYaml = tags.map(_yamlStr).join(', ');
    final frontmatter = 'title: ${_yamlStr(title)}\n'
        'description: ${_yamlStr(description)}\n'
        'date: $date\n'
        'tags: [$tagsYaml]\n'
        'topic: $topic\n'
        'draft: $draft\n';
    await file.writeAsString('---\n$frontmatter---\n\n$body\n', flush: true);

    return Response.found('/admin/website/blog/$slug?saved=1');
  }

  /// A frontmatter line like `description:` with nothing after the colon
  /// parses as YAML `null` — which a schema field like
  /// `z.string().optional()` rejects (optional allows the key to be
  /// *missing*, not present-but-null), and fails the whole site build with
  /// an opaque schema error. Dropping such lines makes the key genuinely
  /// absent instead, which every `.optional()` field accepts. Only drops a
  /// line when the next line isn't more indented — a real block sequence
  /// (`links:` followed by `  - ...`) is left alone.
  static String _dropEmptyFrontmatterKeys(String content) {
    if (!content.startsWith('---\n')) return content;
    final close = content.indexOf('\n---', 4);
    if (close < 0) return content;
    final lines = content.substring(4, close).split('\n');
    final kept = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (RegExp(r'^[A-Za-z0-9_-]+:\s*$').hasMatch(line)) {
        final next = i + 1 < lines.length ? lines[i + 1] : '';
        final isBlockContinuation =
            next.isNotEmpty && RegExp(r'^\s').hasMatch(next);
        if (!isBlockContinuation) continue;
      }
      kept.add(line);
    }
    return '---\n${kept.join('\n')}${content.substring(close)}';
  }

  Future<Response> _adminWebsiteSave(Request request) async {
    final unavailable = _wikiUnavailable();
    if (unavailable != null) return unavailable;
    if (!_sameOrigin(request)) {
      return errorResponse(403, 'bad_origin', 'Cross-origin request rejected.');
    }
    final page = _wikiPageOf(request);
    final file = _wikiPageFile(page);
    if (file == null) {
      return errorResponse(400, 'bad_page', 'Invalid page name.');
    }
    Map<String, String> form = const {};
    try {
      form = Uri.splitQueryString(await request.readAsString());
    } catch (_) {}
    final content = form['content'];
    if (content == null) {
      return errorResponse(400, 'bad_request', 'Missing content field.');
    }
    if (content.length > 2 * 1024 * 1024) {
      return errorResponse(413, 'too_large', 'Page content too large.');
    }
    await file.parent.create(recursive: true);
    // Write-then-rename so the builder never sees a half-written file.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
        _dropEmptyFrontmatterKeys(content.replaceAll('\r\n', '\n')),
        flush: true);
    await tmp.rename(file.path);

    if (form['publish'] == '1') {
      _requestWikiBuild();
      return Response.found('/admin/website/$page?saved=1');
    }
    return Response.found('/admin/website/$page?saved=1');
  }

  Future<Response> _adminWebsiteDelete(Request request) async {
    final unavailable = _wikiUnavailable();
    if (unavailable != null) return unavailable;
    if (!_sameOrigin(request)) {
      return errorResponse(403, 'bad_origin', 'Cross-origin request rejected.');
    }
    var page = _wikiPageOf(request);
    if (page.endsWith('/delete')) {
      page = page.substring(0, page.length - '/delete'.length);
    }
    final file = _wikiPageFile(page);
    if (file == null) {
      return errorResponse(400, 'bad_page', 'Invalid page name.');
    }
    if (await file.exists()) {
      await file.delete();
    }
    _requestWikiBuild();
    return Response.found('/admin/website');
  }

  void _requestWikiBuild() {
    File('${config.wikiDir}/.build-request')
        .writeAsStringSync(DateTime.now().toIso8601String());
  }

  Future<Response> _adminWebsiteBuild(Request request) async {
    final unavailable = _wikiUnavailable();
    if (unavailable != null) return unavailable;
    if (!_sameOrigin(request)) {
      return errorResponse(403, 'bad_origin', 'Cross-origin request rejected.');
    }
    _requestWikiBuild();
    return Response.found('/admin/website');
  }

  Future<Response> _adminWebsiteBuildStatus(Request request) async {
    final unavailable = _wikiUnavailable();
    if (unavailable != null) return unavailable;
    String status = '{}';
    final statusFile = File('${config.wikiDir}/.build-status.json');
    if (await statusFile.exists()) {
      try {
        status = await statusFile.readAsString();
        jsonDecode(status); // validate before embedding
      } catch (_) {
        status = '{}';
      }
    }
    String log = '';
    final logFile = File('${config.wikiDir}/.build-log');
    if (await logFile.exists()) {
      try {
        log = await logFile.readAsString();
        if (log.length > 20000) log = log.substring(log.length - 20000);
      } catch (_) {}
    }
    final pending = File('${config.wikiDir}/.build-request').existsSync();
    return jsonResponse(200, {
      'pending': pending,
      'status': jsonDecode(status),
      'log': log,
    });
  }

  /// Polls build status after a publish and shows the tail of the build log.
  static const _wikiBuildScript = r'''
(function () {
  var el = document.getElementById('buildlog');
  if (!el) return;
  var badge = document.getElementById('buildbadge');
  var timer = null, idle = 0;
  function setBadge(text, cls) {
    if (!badge) return;
    badge.style.display = 'inline-block';
    badge.textContent = text;
    badge.className = 'badge' + (cls ? ' ' + cls : '');
  }
  function poll() {
    fetch('/admin/website/build/status', {credentials: 'same-origin'})
      .then(function (r) { return r.json(); })
      .then(function (s) {
        var state = (s.status && s.status.state) || '';
        var busy = s.pending || state === 'building';
        if (busy) setBadge('Building…', 'warn');
        else if (state === 'ok') setBadge('Live', 'ok');
        else if (state === 'error') setBadge('Build failed', 'err');
        if (busy || state === 'error') {
          el.style.display = 'block';
          el.textContent = s.log || '(no output yet)';
          el.scrollTop = el.scrollHeight;
        } else if (state === 'ok' && el.style.display !== 'none') {
          el.style.display = 'none';
        }
        idle = busy ? 0 : idle + 1;
        if (idle > 4 && timer) { clearInterval(timer); timer = null; }
      }).catch(function () {});
  }
  document.querySelectorAll('form').forEach(function (f) {
    f.addEventListener('submit', function () {
      idle = 0;
      if (!timer) timer = setInterval(poll, 2000);
    });
  });
  // If a build is already running when the page loads, start polling.
  poll(); timer = setInterval(poll, 2000);
})();
''';

  /// Roster editor. Layered on top of _adminCss so it inherits the
  /// dashboard's buttons, cards and spacing — this is one more panel of the
  /// admin, not a second design.
  static const _teamEditorCss = r'''
.tm-list{display:grid;gap:14px;margin-bottom:16px}
.tm-card{background:#191430;border:1px solid #262038;border-radius:12px;
padding:14px 16px 16px}
.tm-head{display:flex;align-items:center;gap:10px;padding-bottom:12px;
margin-bottom:14px;border-bottom:1px solid #241e36}
.tm-avatar{flex:none;display:grid;place-items:center;width:38px;height:38px;
overflow:hidden;border-radius:9px;border:1px solid #322a52;background:#221b3d}
.tm-avatar img{width:100%;height:100%;object-fit:cover}
.tm-avatar-icon{font-size:9px;line-height:1.1;text-align:center;padding:2px;
color:#9089b0;word-break:break-all}
.tm-title{flex:1;min-width:0;margin:0;font-size:14px;font-weight:600;
line-height:1.4;letter-spacing:0;text-transform:none;color:#ece8f7;
overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.tm-pos{flex:none;font-size:11px;color:#7f7898;font-variant-numeric:tabular-nums}
.tm-icon-btn{flex:none;width:32px;height:32px;display:grid;place-items:center;
background:#1c1730;color:#b4addc;border:1px solid #2d2645;border-radius:8px;
font:inherit;font-size:14px;line-height:1;cursor:pointer;
transition:border-color .15s,color .15s,opacity .15s}
.tm-icon-btn:hover:not(:disabled){border-color:#463d6b;color:#ece8f7}
.tm-icon-btn:disabled{opacity:.35;cursor:not-allowed}
.tm-icon-btn:focus-visible{outline:2px solid #8a7ee0;outline-offset:2px}
.tm-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));
gap:14px 16px}
.tm-field{display:flex;flex-direction:column;gap:6px;min-width:0}
.tm-field.tm-wide{grid-column:1/-1}
.tm-label{font-size:11px;font-weight:600;letter-spacing:.05em;
text-transform:uppercase;color:#8d86a8}
.tm-input{width:100%;background:#1a1530;color:#ece8f7;border:1px solid #2d2645;
border-radius:9px;padding:9px 12px;font-size:13px;font-family:inherit;
outline:none;transition:border-color .15s}
.tm-input:focus{border-color:#8a7ee0}
.tm-input:focus-visible{outline:2px solid #8a7ee0;outline-offset:1px}
.tm-area{resize:vertical;line-height:1.55;min-height:74px}
.tm-help{margin:0;font-size:11.5px;line-height:1.45;color:#8d86a8}
.tm-file{display:flex;gap:8px;align-items:center}
.tm-file .tm-input{flex:1;min-width:0}
.tm-file .btn{flex:none}
.tm-links{margin-top:16px;padding-top:14px;border-top:1px solid #241e36;
display:flex;flex-direction:column;gap:8px;align-items:flex-start}
.tm-links .tm-label{margin-bottom:2px}
.tm-link-row{display:flex;gap:8px;width:100%}
.tm-link-row .tm-input:nth-child(1){flex:0 1 30%}
.tm-link-row .tm-input:nth-child(2){flex:1 1 45%;min-width:0}
.tm-link-row select.tm-input{flex:0 1 25%}
.tm-none{font-style:italic}
.tm-addbtn{width:100%}
.tm-status{font-size:12.5px;color:#9b94b3}
.tm-status.ok{color:#7ee08a}
.tm-status.err{color:#e07e7e}
@media (max-width:720px){
.tm-grid{grid-template-columns:1fr}
.tm-link-row{flex-wrap:wrap}
.tm-link-row .tm-input{flex:1 1 100%}
}
''';

  /// The roster form itself. State lives in one array; text edits mutate it
  /// in place and only structural changes (add / remove / reorder) re-render,
  /// so typing never loses the caret.
  static const _teamEditorScript = r'''
(function () {
  var data = {};
  try { data = JSON.parse(document.getElementById('teamdata').textContent); }
  catch (e) { data = {}; }
  var ICONS = (Array.isArray(data.icons) && data.icons.length)
    ? data.icons : ['user'];
  var list = document.getElementById('tmlist');
  var statusEl = document.getElementById('tmstatus');
  var badge = document.getElementById('buildbadge');
  var logEl = document.getElementById('buildlog');
  var dirty = false, saving = false, buildTimer = null, buildIdle = 0;

  function esc(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;',
               "'": '&#39;' }[c];
    });
  }
  function str(v) { return typeof v === 'string' ? v : ''; }
  function icon(v, fallback) {
    return ICONS.indexOf(v) >= 0 ? v : fallback;
  }
  function normalise(m) {
    if (!m || typeof m !== 'object') m = {};
    return {
      name: str(m.name), role: str(m.role), description: str(m.description),
      icon: icon(m.icon, 'user'), avatar: str(m.avatar),
      links: (Array.isArray(m.links) ? m.links : []).map(function (l) {
        if (!l || typeof l !== 'object') l = {};
        return { label: str(l.label), href: str(l.href),
                 icon: icon(l.icon, 'globe') };
      })
    };
  }
  var members = (Array.isArray(data.members) ? data.members : []).map(normalise);

  function setStatus(msg, cls) {
    statusEl.textContent = msg || '';
    statusEl.className = 'tm-status' + (cls ? ' ' + cls : '');
  }
  function markDirty() { dirty = true; setStatus('Unsaved changes'); }

  /* ---------- markup ---------- */
  function field(id, label, control, help, wide) {
    return '<div class="tm-field' + (wide ? ' tm-wide' : '') + '">' +
      '<label class="tm-label" for="' + id + '">' + esc(label) + '</label>' +
      control +
      '<p class="tm-help" id="' + id + '-h">' + esc(help) + '</p></div>';
  }
  function iconSelect(id, selected, i, li) {
    var attrs = 'data-i="' + i + '" data-f="icon"' +
      (li == null ? '' : ' data-li="' + li + '"');
    var opts = ICONS.map(function (n) {
      return '<option value="' + esc(n) + '"' +
        (n === selected ? ' selected' : '') + '>' + esc(n) + '</option>';
    }).join('');
    return '<select class="tm-input" id="' + id + '" ' + attrs +
      (li == null ? ' aria-describedby="' + id + '-h"'
                  : ' aria-label="Link icon"') + '>' + opts + '</select>';
  }
  function avatarPreview(m) {
    return m.avatar
      ? '<img src="' + esc(m.avatar) + '" alt="">'
      : '<span class="tm-avatar-icon">' + esc(m.icon) + '</span>';
  }
  function linksBlock(m, i) {
    var rows = m.links.map(function (l, j) {
      var n = j + 1;
      return '<div class="tm-link-row">' +
        '<input class="tm-input" type="text" data-i="' + i + '" data-li="' + j +
          '" data-f="label" value="' + esc(l.label) +
          '" placeholder="Modrinth" aria-label="Link ' + n + ' label">' +
        '<input class="tm-input" type="url" data-i="' + i + '" data-li="' + j +
          '" data-f="href" value="' + esc(l.href) +
          '" placeholder="https://..." aria-label="Link ' + n + ' address">' +
        iconSelect('f' + i + 'l' + j + '-icon', l.icon, i, j) +
        '<button type="button" class="tm-icon-btn" data-act="dellink" data-i="' +
          i + '" data-li="' + j + '" aria-label="Remove link ' + n +
          '">&times;</button>' +
        '</div>';
    }).join('');
    return '<div class="tm-links"><span class="tm-label">Links</span>' +
      (rows || '<p class="tm-help tm-none">No links yet.</p>') +
      '<button type="button" class="btn btn-ghost btn-sm" data-act="addlink" ' +
      'data-i="' + i + '">+ Add link</button></div>';
  }
  function card(m, i) {
    var total = members.length;
    // Button names are positional, not the person's — the name changes as you
    // type and only the visible heading is refreshed, so a name in here would
    // go stale for screen readers.
    var n = i + 1;
    var p = 'f' + i + '-';
    return '<section class="tm-card" aria-labelledby="' + p + 'title">' +
      '<div class="tm-head">' +
        '<span class="tm-avatar" data-avatar="' + i + '">' +
          avatarPreview(m) + '</span>' +
        '<h3 class="tm-title" id="' + p + 'title" data-title="' + i + '">' +
          esc(m.name || 'New member') + '</h3>' +
        '<span class="tm-pos">' + n + ' / ' + total + '</span>' +
        '<button type="button" class="tm-icon-btn" data-act="up" data-i="' + i +
          '" aria-label="Move member ' + n + ' up"' +
          (i === 0 ? ' disabled' : '') + '>&uarr;</button>' +
        '<button type="button" class="tm-icon-btn" data-act="down" data-i="' + i +
          '" aria-label="Move member ' + n + ' down"' +
          (i === total - 1 ? ' disabled' : '') + '>&darr;</button>' +
        '<button type="button" class="btn btn-danger btn-sm" data-act="del" ' +
          'data-i="' + i + '" aria-label="Remove member ' + n + '">Remove</button>' +
      '</div><div class="tm-grid">' +
        field(p + 'name', 'Name',
          '<input class="tm-input" type="text" id="' + p + 'name" data-i="' + i +
          '" data-f="name" value="' + esc(m.name) + '" placeholder="Ada" ' +
          'aria-describedby="' + p + 'name-h">',
          'Required. A row left without a name is dropped when you save.') +
        field(p + 'role', 'Role',
          '<input class="tm-input" type="text" id="' + p + 'role" data-i="' + i +
          '" data-f="role" value="' + esc(m.role) + '" placeholder="Textures" ' +
          'aria-describedby="' + p + 'role-h">',
          'Short line under the name. Job, area, anything.') +
        field(p + 'icon', 'Icon', iconSelect(p + 'icon', m.icon, i, null),
          'Shown in place of an avatar when there is no image.') +
        field(p + 'avatar', 'Avatar',
          '<div class="tm-file"><input class="tm-input" type="url" id="' + p +
          'avatar" data-i="' + i + '" data-f="avatar" value="' + esc(m.avatar) +
          '" placeholder="/images/uploads/ada.png" aria-describedby="' + p +
          'avatar-h">' +
          '<button type="button" class="btn btn-ghost btn-sm" data-act="pick" ' +
          'data-i="' + i + '">Upload...</button>' +
          '<input type="file" accept="image/*" hidden data-up="' + i + '"></div>',
          'Square images look best. Uploading files it under the site uploads ' +
          'folder and fills this in for you.') +
        field(p + 'desc', 'Description',
          '<textarea class="tm-input tm-area" rows="3" id="' + p + 'desc" ' +
          'data-i="' + i + '" data-f="description" placeholder="What they work ' +
          'on." aria-describedby="' + p + 'desc-h">' + esc(m.description) +
          '</textarea>',
          'A sentence or two. Plain text, not Markdown.', true) +
      '</div>' + linksBlock(m, i) + '</section>';
  }
  function render(focusId) {
    list.innerHTML = members.length
      ? members.map(card).join('')
      : '<p class="tm-help tm-none">Nobody on the roster yet. Add the first ' +
        'member below.</p>';
    if (focusId) {
      var el = document.getElementById(focusId);
      if (el) el.focus();
    }
  }

  /* ---------- edits ---------- */
  list.addEventListener('input', function (e) {
    var t = e.target;
    var i = t.getAttribute('data-i'), f = t.getAttribute('data-f');
    if (i === null || !f) return;
    i = +i;
    var li = t.getAttribute('data-li');
    if (li !== null) { members[i].links[+li][f] = t.value; markDirty(); return; }
    members[i][f] = t.value;
    if (f === 'name') {
      var title = list.querySelector('[data-title="' + i + '"]');
      if (title) title.textContent = t.value || 'New member';
    }
    if (f === 'avatar' || f === 'icon') {
      var av = list.querySelector('[data-avatar="' + i + '"]');
      if (av) av.innerHTML = avatarPreview(members[i]);
    }
    markDirty();
  });

  list.addEventListener('change', function (e) {
    var t = e.target;
    if (t.type !== 'file' || !t.hasAttribute('data-up')) return;
    var i = +t.getAttribute('data-up');
    if (t.files && t.files[0]) upload(t.files[0], i);
    t.value = '';
  });

  list.addEventListener('click', function (e) {
    var btn = e.target.closest('[data-act]');
    if (!btn) return;
    var i = +btn.getAttribute('data-i');
    var act = btn.getAttribute('data-act');
    if (act === 'up' && i > 0) swap(i, i - 1);
    else if (act === 'down' && i < members.length - 1) swap(i, i + 1);
    else if (act === 'del') {
      var who = members[i].name || 'this member';
      if (!confirm('Remove ' + who + ' from the team page?')) return;
      members.splice(i, 1);
      markDirty(); render();
    } else if (act === 'addlink') {
      members[i].links.push({ label: '', href: '', icon: 'globe' });
      markDirty();
      render('f' + i + 'l' + (members[i].links.length - 1) + '-icon');
    } else if (act === 'dellink') {
      members[i].links.splice(+btn.getAttribute('data-li'), 1);
      markDirty(); render();
    } else if (act === 'pick') {
      var f = list.querySelector('input[type=file][data-up="' + i + '"]');
      if (f) f.click();
    }
  });

  function swap(a, b) {
    var tmp = members[a]; members[a] = members[b]; members[b] = tmp;
    markDirty();
    render('f' + b + '-name');
  }

  document.getElementById('tmadd').addEventListener('click', function () {
    members.push(normalise({}));
    markDirty();
    render('f' + (members.length - 1) + '-name');
  });

  /* ---------- avatar upload ---------- */
  function upload(file, i) {
    setStatus('Uploading ' + file.name + '...');
    fetch('/admin/website/upload?name=' + encodeURIComponent(file.name), {
      method: 'POST', body: file, credentials: 'same-origin'
    }).then(function (r) {
      return r.json().then(function (j) {
        if (!r.ok) throw new Error(j.message || 'HTTP ' + r.status);
        return j;
      });
    }).then(function (j) {
      members[i].avatar = j.url;
      var input = document.getElementById('f' + i + '-avatar');
      if (input) input.value = j.url;
      var av = list.querySelector('[data-avatar="' + i + '"]');
      if (av) av.innerHTML = avatarPreview(members[i]);
      markDirty();
      setStatus('Image uploaded', 'ok');
    }).catch(function (err) {
      setStatus('Upload failed: ' + err.message, 'err');
    });
  }

  /* ---------- save & publish ---------- */
  function setBadge(text, cls) {
    badge.style.display = 'inline-block';
    badge.textContent = text;
    badge.className = 'badge' + (cls ? ' ' + cls : '');
  }
  function pollBuild() {
    fetch('/admin/website/build/status', { credentials: 'same-origin' })
      .then(function (r) { return r.json(); })
      .then(function (s) {
        var st = (s.status && s.status.state) || '';
        var busy = s.pending || st === 'building';
        if (busy) setBadge('Building...', 'warn');
        else if (st === 'ok') setBadge('Live', 'ok');
        else if (st === 'error') setBadge('Build failed', 'err');
        if (busy || st === 'error') {
          logEl.style.display = 'block';
          logEl.textContent = s.log || '(no output yet)';
          logEl.scrollTop = logEl.scrollHeight;
        } else if (st === 'ok') {
          logEl.style.display = 'none';
        }
        buildIdle = busy ? 0 : buildIdle + 1;
        if (buildIdle > 4 && buildTimer) {
          clearInterval(buildTimer); buildTimer = null;
        }
      }).catch(function () {});
  }
  function save(publish) {
    if (saving) return;
    saving = true;
    var btn = document.getElementById(publish ? 'tmpub' : 'tmsave');
    btn.disabled = true;
    setStatus('Saving...');
    var body = new URLSearchParams();
    body.set('data', JSON.stringify({ members: members }));
    if (publish) body.set('publish', '1');
    fetch(location.pathname, {
      method: 'POST', body: body, credentials: 'same-origin'
    }).then(function (r) {
      return r.json().then(function (j) {
        if (!r.ok) throw new Error(j.message || 'HTTP ' + r.status);
        return j;
      });
    }).then(function (j) {
      dirty = false;
      var kept = j.count;
      var dropped = members.length - kept;
      var msg = 'Saved ' + kept + (kept === 1 ? ' member' : ' members');
      if (dropped > 0) {
        msg += ' - ' + dropped + (dropped === 1 ? ' row' : ' rows') +
          ' skipped (no name)';
      }
      setStatus(msg, 'ok');
      if (publish) {
        buildIdle = 0;
        if (!buildTimer) buildTimer = setInterval(pollBuild, 2000);
        pollBuild();
      }
    }).catch(function (err) {
      setStatus('Save failed: ' + err.message, 'err');
    }).finally(function () { saving = false; btn.disabled = false; });
  }
  document.getElementById('tmsave')
    .addEventListener('click', function () { save(false); });
  document.getElementById('tmpub')
    .addEventListener('click', function () { save(true); });
  document.addEventListener('keydown', function (e) {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') {
      e.preventDefault(); save(false);
    }
  });
  window.addEventListener('beforeunload', function (e) {
    if (!dirty) return;
    e.preventDefault();
    e.returnValue = '';
  });

  render();
})();
''';

  /// Chrome for the split-view page editor. Dark, warm-neutral, amber accent
  /// to sit visually alongside the wiki itself; the preview pane's inside is
  /// styled entirely by the built site's own CSS.
  static const _wikiEditorCss = '''
:root{--bg:#131110;--bg2:#1b1917;--line:#2c2825;--tx:#ece7e1;--tx2:#a89f94;
--accent:#e8a44e;--accent-tx:#241a0c;--ok:#8fc98f;--err:#e07e7e;--focus:#7db3e8}
*{box-sizing:border-box}
html,body{height:100%}
body{margin:0;background:var(--bg);color:var(--tx);
font:15px/1.5 system-ui,-apple-system,"Segoe UI",sans-serif;
display:flex;flex-direction:column}
.ed-top{display:flex;align-items:center;gap:12px;padding:8px 14px;
background:var(--bg2);border-bottom:1px solid var(--line);flex:0 0 auto}
.ed-back{color:var(--tx2);text-decoration:none;font-size:19px;padding:8px 10px;
border-radius:8px;min-width:40px;text-align:center}
.ed-back:hover{background:var(--line);color:var(--tx)}
.ed-name{font-size:15px;font-weight:600;margin:0;white-space:nowrap;
overflow:hidden;text-overflow:ellipsis}
.ed-status{margin-left:auto;font-size:13px;color:var(--tx2);white-space:nowrap}
.ed-status.ok{color:var(--ok)}.ed-status.err{color:var(--err)}
.ed-actions{display:flex;gap:8px}
.ed-btn{min-height:40px;padding:0 16px;border-radius:9px;cursor:pointer;
border:1px solid var(--line);background:var(--bg);color:var(--tx);
font:inherit;font-weight:500}
.ed-btn:hover{background:var(--line)}
.ed-btn:focus-visible,.ed-tab:focus-visible,.ed-back:focus-visible{
outline:2px solid var(--focus);outline-offset:2px}
.ed-btn:disabled{opacity:.45;cursor:default}
.ed-primary{background:var(--accent);border-color:var(--accent);
color:var(--accent-tx);font-weight:600}
.ed-primary:hover{background:#f2b465}
.ed-format{position:relative;display:flex;align-items:center;gap:4px;
padding:6px 10px;background:var(--bg2);border-bottom:1px solid var(--line);
flex:0 0 auto;flex-wrap:wrap}
.ed-fmt{min-height:32px;min-width:32px;padding:0 10px;border-radius:7px;
border:1px solid transparent;background:none;color:var(--tx2);cursor:pointer;
font:13px/1 inherit}
.ed-fmt:hover{background:var(--line);color:var(--tx)}
.ed-fmt:focus-visible{outline:2px solid var(--focus);outline-offset:1px}
.ed-fmt[aria-expanded="true"]{background:var(--line);color:var(--tx);
border-color:var(--accent)}
.ed-fmt-sep{width:1px;align-self:stretch;margin:4px 4px;background:var(--line)}
/* In normal flow (not an overlay) — a floating popover here would sit right
   on top of the frontmatter panel below and swallow clicks meant for it. */
.ed-linkpop{width:100%;display:flex;flex-wrap:wrap;gap:6px;margin-top:6px;
padding:10px;background:var(--bg2);border:1px solid var(--line);
border-radius:10px}
.ed-linkpop input{min-height:36px;padding:0 10px;border-radius:7px;
border:1px solid var(--line);background:var(--bg);color:var(--tx);
font:13px inherit;flex:1;min-width:140px}
.ed-linkpop input:focus{outline:2px solid var(--focus);outline-offset:1px}
.ed-linkpop .ed-btn{min-height:36px;padding:0 14px}
.ed-tabs{display:none;flex:0 0 auto;border-bottom:1px solid var(--line)}
.ed-tab{flex:1;min-height:44px;background:none;border:0;color:var(--tx2);
font:inherit;cursor:pointer;border-bottom:2px solid transparent}
.ed-tab.is-on{color:var(--tx);border-bottom-color:var(--accent)}
.ed-split{flex:1;display:grid;grid-template-columns:1fr 1fr;min-height:0}
.ed-pane{display:flex;flex-direction:column;min-width:0;min-height:0}
#pane-write{border-right:1px solid var(--line)}
.ed-fm{flex:0 0 auto;border-bottom:1px solid var(--line);background:var(--bg2)}
.ed-fm summary{padding:9px 14px;font-size:13px;color:var(--tx2);cursor:pointer;
user-select:none}
.ed-fm summary:hover{color:var(--tx)}
.ed-fm textarea{width:100%;border:0;background:var(--bg2);color:var(--tx);
resize:vertical;padding:4px 14px 12px;
font:13px/1.6 ui-monospace,SFMono-Regular,Consolas,monospace}
#src{flex:1;width:100%;border:0;resize:none;background:var(--bg);
color:var(--tx);padding:18px 16px 40vh;
font:14.5px/1.65 ui-monospace,SFMono-Regular,Consolas,monospace}
#src:focus,.ed-fm textarea:focus{outline:none}
#src.dragover{box-shadow:inset 0 0 0 2px var(--accent)}
#pv{flex:1;width:100%;border:0;background:#161311}
@media(max-width:900px){
.ed-tabs{display:flex}
.ed-split{grid-template-columns:1fr}
.ed-pane{display:none}
.ed-pane.is-on{display:flex}
#pane-write{border-right:0}
.ed-name{display:none}
}
@media(prefers-reduced-motion:no-preference){
.ed-btn{transition:background .15s ease-out}
}''';

  /// The whole client side of the editor: a small Markdown renderer, the
  /// live preview iframe (styled by the site's real CSS), image upload
  /// (button, paste, or drag a file in), and drag-to-reposition for image
  /// blocks inside the preview.
  static const _wikiEditorJs = r'''
(function () {
'use strict';
var page = window.__initial.page;
var src = document.getElementById('src');
var fm = document.getElementById('fm');
var pv = document.getElementById('pv');
var statusEl = document.getElementById('status');
var dirty = false, saving = false, pollTimer = null;

/* ---------- frontmatter split ---------- */
function splitFM(text) {
  if (text.slice(0, 4) === '---\n' || text === '---') {
    var end = text.indexOf('\n---', 3);
    if (end > 0) {
      // Drop the newline that closes the "---" line plus any blank lines
      // after it: fullContent() always re-adds exactly one, so keeping them
      // grew the empty gap above the first paragraph by a line on every save.
      var rest = text.slice(end + 4).replace(/^(?:[ \t]*\n)+/, '');
      return { fm: text.slice(4, end), body: rest };
    }
  }
  return { fm: '', body: text };
}
var parts = splitFM(window.__initial.content);
fm.value = parts.fm;
src.value = parts.body;
if (!parts.fm && window.__initial.isNew) {
  fm.value = 'title: New page\ndescription: ';
  document.querySelector('.ed-fm').open = true;
}

/* ---------- tiny markdown renderer (block-level, for preview only) ------ */
function esc(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}
function mapSrc(u) {
  // site-absolute assets go through the authed preview proxy so unpublished
  // uploads render too
  return u.charAt(0) === '/' ? '/admin/website/preview/public' + u : u;
}
function inline(s) {
  s = esc(s);
  s = s.replace(/`([^`]+)`/g, function (_, c) { return '<code>' + c + '</code>'; });
  s = s.replace(/!\[([^\]]*)\]\(([^)\s]+)\)/g, function (_, alt, u) {
    return '<img src="' + mapSrc(u) + '" alt="' + alt + '" style="max-width:100%">';
  });
  s = s.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, '<a href="$2">$1</a>');
  s = s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  s = s.replace(/(^|[^*])\*([^*\n]+)\*/g, '$1<em>$2</em>');
  return s;
}
function blockHtml(b) {
  var m;
  if ((m = b.match(/^```(\w*)\n?([\s\S]*?)\n?```\s*$/)))
    return { h: '<pre><code>' + esc(m[2]) + '</code></pre>' };
  if ((m = b.match(/^(#{1,6})\s+(.*)$/m))) {
    var lvl = m[1].length; // same mapping as the site's markdown renderer
    return { h: '<h' + lvl + '>' + inline(m[2]) + '</h' + lvl + '>' };
  }
  if (/^(-{3,}|\*{3,})\s*$/.test(b)) return { h: '<hr>' };
  var lines = b.split('\n');
  if (lines.every(function (l) { return /^\s*([-*]|\d+\.)\s+/.test(l); })) {
    var ordered = /^\s*\d+\./.test(lines[0]);
    var items = lines.map(function (l) {
      return '<li>' + inline(l.replace(/^\s*([-*]|\d+\.)\s+/, '')) + '</li>';
    }).join('');
    return { h: (ordered ? '<ol>' : '<ul>') + items + (ordered ? '</ol>' : '</ul>') };
  }
  if (lines.every(function (l) { return /^\s*>/.test(l); })) {
    return { h: '<blockquote><p>' + lines.map(function (l) {
      return inline(l.replace(/^\s*>\s?/, ''));
    }).join('<br>') + '</p></blockquote>' };
  }
  if (lines.length > 1 && lines[0].indexOf('|') >= 0 &&
      /^[\s|:-]+$/.test(lines[1] || '')) {
    var row = function (l, tag) {
      var cells = l.replace(/^\s*\|/, '').replace(/\|\s*$/, '').split('|');
      return '<tr>' + cells.map(function (c) {
        return '<' + tag + '>' + inline(c.trim()) + '</' + tag + '>';
      }).join('') + '</tr>';
    };
    return { h: '<table><thead>' + row(lines[0], 'th') + '</thead><tbody>' +
      lines.slice(2).map(function (l) { return row(l, 'td'); }).join('') +
      '</tbody></table>' };
  }
  var onlyImg = b.match(/^\s*!\[([^\]]*)\]\(([^)\s]+)\)\s*$/);
  if (onlyImg) return { h: '<p>' + inline(b.trim()) + '</p>', img: true };
  return { h: '<p>' + inline(lines.join('\n')) + '</p>' };
}
function blocksOf(body) {
  var out = [], cur = [], inFence = false;
  body.split('\n').forEach(function (line) {
    if (/^```/.test(line)) inFence = !inFence;
    if (!inFence && /^\s*$/.test(line)) {
      if (cur.length) { out.push(cur.join('\n')); cur = []; }
    } else {
      cur.push(line);
    }
  });
  if (cur.length) out.push(cur.join('\n'));
  return out;
}
function titleOf() {
  var m = fm.value.match(/^title:\s*["']?(.+?)["']?\s*$/m);
  return m ? m[1] : page;
}

/* ---------- preview iframe (uses the built site's real CSS) ---------- */
pv.srcdoc = '<!doctype html><html data-theme="wiki"><head>' +
  '<meta charset="utf-8">' +
  '<link rel="stylesheet" href="/admin/website/preview/page.css">' +
  '<style>' +
  'html{scrollbar-color:#3a352f transparent}' +
  '.wiki-shell{display:block!important;max-width:900px;margin:0 auto}' +
  'body{padding:2rem 1.25rem 40vh}' +
  '.blk.drag-img{cursor:grab}' +
  '.blk.drag-img:hover{outline:2px dashed rgba(232,164,78,.55);outline-offset:4px;border-radius:6px}' +
  '.blk.dragging{opacity:.35}' +
  '.blk.drop-before{box-shadow:0 -3px 0 0 #e8a44e}' +
  '.blk.drop-after{box-shadow:0 3px 0 0 #e8a44e}' +
  '.prose:empty:before{content:"Start typing on the left…";color:#8d8375}' +
  '</style></head><body>' +
  '<main id="main"><div class="wiki-shell"><article class="wiki-card">' +
  '<div class="wiki-title-row"><h1 class="wiki-title" id="_top"></h1></div>' +
  '<div class="prose" style="margin-top:2rem" id="prose"></div>' +
  '</article></div></main></body></html>';

var doc = null, prose = null, blocks = blocksOf(src.value);

function render() {
  if (!prose) return;
  blocks = blocksOf(src.value);
  doc.querySelector('.wiki-title').textContent = titleOf();
  prose.innerHTML = blocks.map(function (b, i) {
    var r = blockHtml(b);
    return '<div class="blk' + (r.img ? ' drag-img' : '') + '" data-i="' + i +
      '"' + (r.img ? ' draggable="true"' : '') + '>' + r.h + '</div>';
  }).join('');
}

/* ---------- drag to reposition image blocks ---------- */
var dragFrom = -1;
function clearDrop() {
  prose.querySelectorAll('.drop-before,.drop-after').forEach(function (el) {
    el.classList.remove('drop-before', 'drop-after');
  });
}
function moveBlock(from, to) {
  if (from < 0 || from === to || from + 1 === to) return;
  var b = blocks.splice(from, 1)[0];
  blocks.splice(from < to ? to - 1 : to, 0, b);
  src.value = blocks.join('\n\n');
  markDirty();
  render();
}
function bindPreview() {
  doc = pv.contentDocument;
  prose = doc.getElementById('prose');
  render();
  doc.addEventListener('dragstart', function (e) {
    var blk = e.target.closest && e.target.closest('.blk.drag-img');
    if (!blk) return;
    dragFrom = +blk.dataset.i;
    blk.classList.add('dragging');
    e.dataTransfer.effectAllowed = 'move';
    try { e.dataTransfer.setData('text/plain', 'blk'); } catch (_) {}
  });
  doc.addEventListener('dragend', function () {
    dragFrom = -1; clearDrop();
    prose.querySelectorAll('.dragging').forEach(function (el) {
      el.classList.remove('dragging');
    });
  });
  doc.addEventListener('dragover', function (e) {
    e.preventDefault(); // allow drop (both block moves and OS files)
    var blk = e.target.closest && e.target.closest('.blk');
    clearDrop();
    if (!blk) return;
    var r = blk.getBoundingClientRect();
    blk.classList.add(e.clientY < r.top + r.height / 2 ? 'drop-before' : 'drop-after');
  });
  doc.addEventListener('drop', function (e) {
    e.preventDefault();
    var blk = e.target.closest && e.target.closest('.blk');
    var idx = blocks.length;
    if (blk) {
      var r = blk.getBoundingClientRect();
      idx = +blk.dataset.i + (e.clientY < r.top + r.height / 2 ? 0 : 1);
    }
    clearDrop();
    if (e.dataTransfer.files && e.dataTransfer.files.length) {
      uploadFiles(e.dataTransfer.files, idx);
    } else if (dragFrom >= 0) {
      moveBlock(dragFrom, idx);
    }
    dragFrom = -1;
  });
}
pv.addEventListener('load', bindPreview);

/* ---------- editing ---------- */
var renderT = null;
function markDirty() { dirty = true; setStatus(''); }
src.addEventListener('input', function () {
  markDirty();
  clearTimeout(renderT); renderT = setTimeout(render, 120);
});
fm.addEventListener('input', function () {
  markDirty();
  clearTimeout(renderT); renderT = setTimeout(render, 120);
});
// rough scroll sync: keep preview at the same relative position
src.addEventListener('scroll', function () {
  if (!doc) return;
  var p = src.scrollTop / Math.max(1, src.scrollHeight - src.clientHeight);
  var d = doc.scrollingElement;
  d.scrollTop = p * Math.max(0, d.scrollHeight - d.clientHeight);
});

/* ---------- image upload ---------- */
function setStatus(msg, cls) {
  statusEl.textContent = msg;
  statusEl.className = 'ed-status' + (cls ? ' ' + cls : '');
}
function insertBlockAt(text, idx) {
  blocks = blocksOf(src.value);
  if (idx == null || idx > blocks.length) idx = blocks.length;
  blocks.splice(idx, 0, text);
  src.value = blocks.join('\n\n');
  markDirty();
  render();
}
function uploadFiles(files, atIdx) {
  Array.prototype.forEach.call(files, function (file) {
    if (!/^image\//.test(file.type)) return;
    setStatus('Uploading ' + file.name + '…');
    fetch('/admin/website/upload?name=' + encodeURIComponent(file.name), {
      method: 'POST', body: file, credentials: 'same-origin'
    }).then(function (r) { return r.json().then(function (j) { return { ok: r.ok, j: j }; }); })
      .then(function (res) {
        if (!res.ok) throw new Error(res.j.message || 'upload failed');
        insertBlockAt('![' + file.name.replace(/\.[^.]+$/, '') + '](' + res.j.url + ')', atIdx);
        setStatus('Image added — drag it in the preview to move it', 'ok');
      })
      .catch(function (e) { setStatus('Upload failed: ' + e.message, 'err'); });
  });
}
document.getElementById('imgbtn').addEventListener('click', function () {
  document.getElementById('imgfile').click();
});
document.getElementById('imgfile').addEventListener('change', function () {
  if (this.files.length) uploadFiles(this.files, null);
  this.value = '';
});

/* ---------- formatting toolbar ---------- */
function wrapSelection(before, after, placeholder) {
  var s = src.selectionStart, e = src.selectionEnd;
  var sel = src.value.slice(s, e) || placeholder || '';
  src.value = src.value.slice(0, s) + before + sel + after + src.value.slice(e);
  var caretStart = s + before.length;
  src.focus();
  src.setSelectionRange(caretStart, caretStart + sel.length);
  markDirty();
  render();
}
function prefixLines(marker) {
  var s = src.selectionStart, e = src.selectionEnd;
  var lineStart = src.value.lastIndexOf('\n', s - 1) + 1;
  var lineEnd = src.value.indexOf('\n', e);
  if (lineEnd === -1) lineEnd = src.value.length;
  var chunk = src.value.slice(lineStart, lineEnd);
  var out = chunk.split('\n').map(function (l) {
    return /^\s*[-#]/.test(l) ? l : marker + l;
  }).join('\n');
  src.value = src.value.slice(0, lineStart) + out + src.value.slice(lineEnd);
  src.focus();
  markDirty();
  render();
}
document.getElementById('fmt-bold').addEventListener('click', function () {
  wrapSelection('**', '**', 'bold text');
});
document.getElementById('fmt-italic').addEventListener('click', function () {
  wrapSelection('*', '*', 'italic text');
});
document.getElementById('fmt-h2').addEventListener('click', function () {
  prefixLines('## ');
});
document.getElementById('fmt-list').addEventListener('click', function () {
  prefixLines('- ');
});

/* ---------- link insert: turns a name/sentence into a clickable link
   instead of a bare URL sitting in the text ---------- */
var linkbtn = document.getElementById('linkbtn');
var linkpop = document.getElementById('linkpop');
var linktext = document.getElementById('linktext');
var linkurl = document.getElementById('linkurl');
var linkSelRange = null;
function openLinkPop() {
  linkSelRange = [src.selectionStart, src.selectionEnd];
  linktext.value = src.value.slice(linkSelRange[0], linkSelRange[1]);
  linkurl.value = '';
  linkpop.hidden = false;
  linkbtn.setAttribute('aria-expanded', 'true');
  (linktext.value ? linkurl : linktext).focus();
}
function closeLinkPop() {
  linkpop.hidden = true;
  linkbtn.setAttribute('aria-expanded', 'false');
}
linkbtn.addEventListener('click', function () {
  if (linkpop.hidden) openLinkPop(); else closeLinkPop();
});
document.getElementById('linkgo').addEventListener('click', function () {
  var url = linkurl.value.trim();
  if (!url) { linkurl.focus(); return; }
  var text = linktext.value.trim() || url;
  var r = linkSelRange || [src.selectionStart, src.selectionEnd];
  src.value = src.value.slice(0, r[0]) + '[' + text + '](' + url + ')' + src.value.slice(r[1]);
  closeLinkPop();
  src.focus();
  markDirty();
  render();
});
linkurl.addEventListener('keydown', function (e) {
  if (e.key === 'Enter') { e.preventDefault(); document.getElementById('linkgo').click(); }
  if (e.key === 'Escape') closeLinkPop();
});
document.addEventListener('click', function (e) {
  if (!linkpop.hidden && !linkpop.contains(e.target) && e.target !== linkbtn) closeLinkPop();
});
document.addEventListener('keydown', function (e) {
  if ((e.ctrlKey || e.metaKey) && !e.shiftKey && e.key.toLowerCase() === 'b' &&
      document.activeElement === src) { e.preventDefault(); wrapSelection('**', '**', 'bold text'); }
  if ((e.ctrlKey || e.metaKey) && !e.shiftKey && e.key.toLowerCase() === 'i' &&
      document.activeElement === src) { e.preventDefault(); wrapSelection('*', '*', 'italic text'); }
});
src.addEventListener('dragover', function (e) {
  e.preventDefault(); src.classList.add('dragover');
});
src.addEventListener('dragleave', function () { src.classList.remove('dragover'); });
src.addEventListener('drop', function (e) {
  e.preventDefault(); src.classList.remove('dragover');
  if (e.dataTransfer.files.length) uploadFiles(e.dataTransfer.files, null);
});
src.addEventListener('paste', function (e) {
  var files = e.clipboardData && e.clipboardData.files;
  if (files && files.length) { e.preventDefault(); uploadFiles(files, null); }
});

/* ---------- save & publish ---------- */
function fullContent() {
  var f = fm.value.replace(/\s+$/, '');
  var b = src.value.replace(/^(?:[ \t]*\n)+/, '').replace(/\s+$/, '') + '\n';
  return f ? '---\n' + f + '\n---\n\n' + b : b;
}
function save(publish) {
  if (saving) return;
  saving = true;
  var btn = document.getElementById(publish ? 'pubbtn' : 'savebtn');
  btn.disabled = true;
  setStatus(publish ? 'Saving…' : 'Saving…');
  var body = new URLSearchParams();
  body.set('content', fullContent());
  if (publish) body.set('publish', '1');
  fetch(location.pathname, {
    method: 'POST', body: body, credentials: 'same-origin', redirect: 'manual'
  }).then(function (r) {
    if (r.status >= 400) throw new Error('HTTP ' + r.status);
    dirty = false;
    if (publish) { setStatus('Building…'); pollBuild(); }
    else setStatus('Saved ✓', 'ok');
  }).catch(function (e) {
    setStatus('Save failed: ' + e.message, 'err');
  }).finally(function () { saving = false; btn.disabled = false; });
}
function pollBuild() {
  clearInterval(pollTimer);
  pollTimer = setInterval(function () {
    fetch('/admin/website/build/status', { credentials: 'same-origin' })
      .then(function (r) { return r.json(); })
      .then(function (s) {
        var st = (s.status && s.status.state) || '';
        if (s.pending || st === 'building') { setStatus('Building…'); return; }
        clearInterval(pollTimer);
        if (st === 'ok') setStatus('Published ✓ — live on the wiki', 'ok');
        else if (st === 'error') setStatus('Build failed — check /admin/website log', 'err');
      }).catch(function () {});
  }, 2000);
}
document.getElementById('savebtn').addEventListener('click', function () { save(false); });
document.getElementById('pubbtn').addEventListener('click', function () { save(true); });
document.addEventListener('keydown', function (e) {
  if ((e.ctrlKey || e.metaKey) && e.key === 's') { e.preventDefault(); save(false); }
});
window.addEventListener('beforeunload', function (e) {
  if (dirty) { e.preventDefault(); e.returnValue = ''; }
});

/* ---------- mobile tabs ---------- */
document.querySelectorAll('.ed-tab').forEach(function (t) {
  t.addEventListener('click', function () {
    document.querySelectorAll('.ed-tab').forEach(function (x) {
      x.classList.toggle('is-on', x === t);
    });
    document.querySelectorAll('.ed-pane').forEach(function (p) {
      p.classList.toggle('is-on', p.id === 'pane-' + t.dataset.pane);
    });
  });
});
if (window.innerWidth <= 900) document.getElementById('pane-write').classList.add('is-on');
})();
''';

  Response _adminDashboard(Request request) {
    final stats = _adminStatsJson();
    // Accounts waiting for approval float to the top: with the default
    // manual approval mode, working through them is the operator's routine
    // job here, and they'd otherwise be scattered through the list.
    final users = store.usersById.values.toList()
      ..sort((a, b) {
        if (a.isPending != b.isPending) return a.isPending ? -1 : 1;
        return b.createdAtMs.compareTo(a.createdAtMs);
      });

    String fmtBytes(int bytes) {
      const units = ['B', 'KB', 'MB', 'GB', 'TB'];
      var value = bytes.toDouble();
      var unit = 0;
      while (value >= 1024 && unit < units.length - 1) {
        value /= 1024;
        unit++;
      }
      return '${value.toStringAsFixed(value >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
    }

    String fmtDate(int? ms) {
      if (ms == null) return '—';
      final d = DateTime.fromMillisecondsSinceEpoch(ms).toUtc();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)} UTC';
    }

    const planLabels = {
      'core': 'Core (Free)',
      'orbit': 'Orbit (\$2/mo)',
      'nova': 'Nova (\$5/mo)',
    };

    final rows = users.map((u) {
      final used = store.usedBytes(u.id);
      final pct = u.quotaBytes > 0
          ? (used / u.quotaBytes * 100).clamp(0, 100)
          : 0.0;
      final statusClass = u.status == 'active' ? 'ok' : 'warn';
      final action = u.isPending
          ? '<form method="post" action="/admin/verify" '
              'style="margin:0" onsubmit="return confirm(\'Approve '
              '${_htmlEscape(u.email)}? They can sign in straight after.\')">'
              '<input type="hidden" name="email" value="${_htmlEscape(u.email)}">'
              '<button type="submit" class="btn btn-primary btn-sm">Approve</button>'
              '</form>'
          : '<form method="post" action="/admin/revoke" '
              'style="margin:0" onsubmit="return confirm(\'Revoke '
              '${_htmlEscape(u.email)}? All their devices are signed out '
              'immediately and blocked until you approve them again.\')">'
              '<input type="hidden" name="email" value="${_htmlEscape(u.email)}">'
              '<button type="submit" class="btn btn-danger btn-sm">Revoke</button>'
              '</form>';
      return '<tr>'
          '<td>${_htmlEscape(u.email)}</td>'
          '<td><span class="badge $statusClass">${_htmlEscape(u.status)}</span></td>'
          '<td>${_htmlEscape(planLabels[u.planId] ?? u.planId)}</td>'
          '<td>'
          '<div class="meter"><div style="width:${pct.toStringAsFixed(0)}%"></div></div>'
          '<span class="muted" style="font-size:12px">${fmtBytes(used)} / ${fmtBytes(u.quotaBytes)} (${pct.toStringAsFixed(0)}%)</span>'
          '</td>'
          '<td>${fmtDate(u.createdAtMs)}</td>'
          '<td>${fmtDate(u.lastLoginAtMs)}</td>'
          '<td>$action</td>'
          '</tr>';
    }).join();

    final subscriptionRows = users.where((u) => u.planId != kDefaultPlanId).map((u) {
      final label = planLabels[u.planId] ?? u.planId;
      return '<tr>'
          '<td>${_htmlEscape(u.email)}</td>'
          '<td>${_htmlEscape(label)}</td>'
          '<td><form method="post" action="/admin/plan" '
          'style="margin:0" onsubmit="return confirm(\'Remove '
          '${_htmlEscape(u.email)}\\\'s $label plan? They revert to Core.\')">'
          '<input type="hidden" name="email" value="${_htmlEscape(u.email)}">'
          '<input type="hidden" name="planId" value="$kDefaultPlanId">'
          '<button type="submit" class="btn btn-danger btn-sm">Remove</button>'
          '</form></td>'
          '</tr>';
    }).join();

    final planOptions = kPlanQuotaBytes.keys.map((id) {
      final selected = id == 'orbit' ? ' selected' : '';
      return '<option value="$id"$selected>${_htmlEscape(planLabels[id] ?? id)}</option>';
    }).join();

    final activityCutoff = DateTime.now().millisecondsSinceEpoch -
        const Duration(hours: 24).inMilliseconds;
    final recentActivity = store.activity
        .where((a) => a.createdAtMs >= activityCutoff)
        .toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

    const activityLabels = {
      'account_registered': 'Registered',
      'account_verified': 'Verified',
      'login': 'Login',
      'account_deleted': 'Account deleted',
      'admin_verified': 'Admin verified',
      'plan_granted': 'Plan granted',
    };

    final activityRows = recentActivity.map((a) {
      return '<tr>'
          '<td>${fmtDate(a.createdAtMs)}</td>'
          '<td>${_htmlEscape(activityLabels[a.type] ?? a.type)}</td>'
          '<td>${_htmlEscape(a.message)}</td>'
          '</tr>';
    }).join();

    final pluginStats = store.pluginDownloadsById.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    final pluginDownloadsTotal =
        pluginStats.fold<int>(0, (sum, p) => sum + p.count);
    final pluginRows = pluginStats.map((p) {
      return '<tr>'
          '<td>${_htmlEscape(p.name)}</td>'
          '<td>${_htmlEscape(p.pluginId)}</td>'
          '<td>${p.count}</td>'
          '<td>${fmtDate(p.lastDownloadedAtMs)}</td>'
          '</tr>';
    }).join();

    final body = '<!doctype html><html><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<title>luma admin</title>'
        '<style>$_adminCss</style>'
        '</head><body><div class="wrap">'
        '<header class="top"><h1>luma<span class="dot">.</span> admin</h1>'
        '<span class="sub">server console</span>'
        '<div style="margin-left:auto;display:flex;gap:8px;align-items:center">'
        '<a href="/admin/website" class="btn btn-ghost btn-sm">Website</a>'
        '<form method="post" action="/admin/logout" style="margin:0">'
        '<button type="submit" class="btn btn-ghost btn-sm">Sign out</button>'
        '</form>'
        '</div></header>'
        '<div class="stats">'
        '<div class="stat"><div class="n">${stats['totalAccounts']}</div><div class="l">Total accounts</div></div>'
        '<div class="stat"><div class="n">${stats['activeAccounts']}</div><div class="l">Active</div></div>'
        '<div class="stat"><div class="n">${stats['pendingAccounts']}</div><div class="l">Pending</div></div>'
        '<div class="stat"><div class="n">${fmtBytes(stats['usedBytesTotal'] as int)}</div><div class="l">Storage used</div></div>'
        '<div class="stat"><div class="n">${fmtBytes(stats['quotaBytesTotal'] as int)}</div><div class="l">Storage capacity</div></div>'
        '<div class="stat"><div class="n">${recentActivity.length}</div><div class="l">Activity (24h)</div></div>'
        '</div>'
        '<div class="tabs">'
        '<button class="tab-btn" data-tab="users">Users</button>'
        '<button class="tab-btn" data-tab="products">Products</button>'
        '<button class="tab-btn" data-tab="activity">Activity</button>'
        '<button class="tab-btn" data-tab="plugins">Plugins</button>'
        '<button class="tab-btn" data-tab="metrics">Metrics</button>'
        '<button class="tab-btn" data-tab="control">Maintenance</button>'
        '</div>'
        '<div class="tab-panel" id="panel-users">'
        '<div class="card table-card">'
        '<table><thead><tr><th>Email</th><th>Status</th><th>Plan</th>'
        '<th>Storage</th><th>Created</th><th>Last login</th><th></th></tr></thead>'
        '<tbody>$rows</tbody></table>'
        '</div>'
        '</div>'
        '<div class="tab-panel" id="panel-products">'
        '<div class="card">'
        '<h2>Grant a plan</h2>'
        '<form class="product-form" method="post" action="/admin/plan">'
        '<select name="planId">$planOptions</select>'
        '<input type="email" name="email" placeholder="user@example.com" required>'
        '<button type="submit" class="btn btn-primary">Grant</button>'
        '</form>'
        '</div>'
        '<div class="card table-card">'
        '<h2>Active subscriptions</h2>'
        '<table><thead><tr><th>Email</th><th>Plan</th><th></th></tr></thead>'
        '<tbody>${subscriptionRows.isEmpty ? '<tr><td colspan="3" class="muted">No paid subscriptions yet.</td></tr>' : subscriptionRows}</tbody></table>'
        '</div>'
        '</div>'
        '<div class="tab-panel" id="panel-activity">'
        '<div class="card table-card">'
        '<h2>Last 24 hours</h2>'
        '<table><thead><tr><th>Time</th><th>Type</th><th>Detail</th></tr></thead>'
        '<tbody>${activityRows.isEmpty ? '<tr><td colspan="3" class="muted">No activity in the last 24 hours.</td></tr>' : activityRows}</tbody></table>'
        '</div>'
        '</div>'
        '<div class="tab-panel" id="panel-plugins">'
        '<div class="stats" style="margin-bottom:20px">'
        '<div class="stat"><div class="n">$pluginDownloadsTotal</div><div class="l">Total downloads</div></div>'
        '<div class="stat"><div class="n">${pluginStats.length}</div><div class="l">Plugins tracked</div></div>'
        '</div>'
        '<div class="card table-card">'
        '<table><thead><tr><th>Plugin</th><th>ID</th><th>Downloads</th><th>Last downloaded</th></tr></thead>'
        '<tbody>${pluginRows.isEmpty ? '<tr><td colspan="4" class="muted">No plugin downloads reported yet.</td></tr>' : pluginRows}</tbody></table>'
        '</div>'
        '</div>'
        '<div class="tab-panel" id="panel-metrics">'
        '<div id="metricsUnsupported" class="hint" style="display:none">'
        'Live metrics aren\'t available on this server\'s OS/platform.</div>'
        '<div class="range-tabs" id="rangeTabs">'
        '<button class="range-btn" data-range="minute">1 minute</button>'
        '<button class="range-btn" data-range="hour">1 hour</button>'
        '<button class="range-btn" data-range="day">24 hours</button>'
        '<button class="range-btn" data-range="week">1 week</button>'
        '</div>'
        '<div class="metrics-grid" id="metricsGrid">'
        '<div class="metric-card"><div class="metric-title">CPU</div>'
        '<canvas id="cpuGraph" width="280" height="120"></canvas>'
        '<div class="metric-value" id="cpuValue">–</div></div>'
        '<div class="metric-card"><div class="metric-title">RAM</div>'
        '<canvas id="ramGraph" width="280" height="120"></canvas>'
        '<div class="metric-value" id="ramValue">–</div></div>'
        '<div class="metric-card"><div class="metric-title">Network '
        '<span class="legend"><span class="k accent">&#8595; down</span>'
        '<span class="k green">&#8593; up</span></span></div>'
        '<canvas id="netGraph" width="280" height="120"></canvas>'
        '<div class="metric-value" id="netValue">–</div></div>'
        '<div class="metric-card"><div class="metric-title">SSD '
        '<span class="legend"><span class="k accent">&#8595; read</span>'
        '<span class="k green">&#8593; write</span></span></div>'
        '<canvas id="diskGraph" width="280" height="120"></canvas>'
        '<div class="metric-value" id="diskValue">–</div></div>'
        '</div>'
        '<div class="card" style="margin-top:18px">'
        '<h2>Storage by database</h2>'
        '<div class="storage-wrap">'
        '<div class="storage-chart-box"><canvas id="storageChart" width="220" height="220"></canvas></div>'
        '<div id="storageLegend" class="storage-legend"></div>'
        '</div>'
        '<div class="muted" id="storageTotal" style="margin-top:14px;font-size:12px"></div>'
        '<div class="muted" id="storageHint" style="margin-top:4px;font-size:11px;color:#6f688a">Each slice is one store file or directory on disk. Zero-byte stores are hidden.</div>'
        '</div>'
        '</div>'
        '<div class="tab-panel" id="panel-control">'
        '<div class="maint-grid">'
        '<div class="card">'
        '<h2>Groceries database</h2>'
        '<div class="maint-desc">Pulls the latest products and prices from '
        'each supermarket, records price changes, and marks products that '
        'disappeared as unavailable.</div>'
        '<div style="display:flex;flex-direction:column;gap:8px">'
        '<div class="maint-actions" style="align-items:flex-start;gap:8px">'
        '<form method="post" action="/admin/groceries/sync" style="margin:0">'
        '<button type="submit" class="btn btn-primary">Sync all markets</button></form>'
        '<form method="post" action="/admin/groceries/sync" style="margin:0">'
        '<input type="hidden" name="market" value="jumbo">'
        '<button type="submit" class="btn btn-ghost">Jumbo</button></form>'
        '<form method="post" action="/admin/groceries/sync" style="margin:0">'
        '<input type="hidden" name="market" value="ah">'
        '<button type="submit" class="btn btn-ghost">Albert Heijn</button></form>'
        '<form method="post" action="/admin/groceries/sync" style="margin:0">'
        '<input type="hidden" name="market" value="hoogvliet">'
        '<button type="submit" class="btn btn-ghost">Hoogvliet</button></form>'
        '</div>'
        '<div style="display:flex;gap:6px">'
        '<button id="groceriesLogBtn" type="button" class="btn btn-ghost btn-sm">'
        'Show sync log</button>'
        '<form method="post" action="/admin/groceries/reload" style="margin:0" onsubmit="return confirm(\'Reload the entire groceries database — this deletes all products and re-fetches every market. Continue?\')">'
        '<button type="submit" class="btn btn-ghost btn-sm" style="color:#e0a0a0;border-color:#4a2a3a">Reload DB</button></form>'
        '</div>'
        '</div>'
        '<div id="groceriesSummary" class="maint-status">Loading groceries '
        'status…</div>'
        '<div id="groceriesLog" class="maint-out" style="display:none">'
        '<table><thead><tr><th>Market</th><th>Status</th><th>Started</th>'
        '<th>Finished</th><th>Checked</th><th>Added</th><th>Updated</th>'
        '<th>Failed</th><th>Error</th></tr></thead>'
        '<tbody id="groceriesSyncRows">'
        '<tr><td colspan="9" class="muted">Loading…</td></tr>'
        '</tbody></table>'
        '</div>'
        '</div>'
        '<div class="card">'
        '<h2>AI model leaderboard</h2>'
        '<div class="maint-desc">Re-fetches the model catalogue and news '
        'that back the AI Usage plugin\'s leaderboard.</div>'
        '<div class="maint-actions">'
        '<button id="aiModelsBtn" type="button" class="btn btn-primary">'
        'Refresh model data</button>'
        '</div>'
        '<div id="aiModelsSummary" class="maint-status">Loading catalogue '
        'status…</div>'
        '<div id="aiModelsLog" class="maint-out" style="display:none">'
        '<table><thead><tr><th>Source</th><th>Status</th><th>Fetched</th>'
        '<th>Applied</th><th>Detail</th></tr></thead>'
        '<tbody id="aiModelsRows"></tbody></table>'
        '</div>'
        '</div>'
        '<div class="card">'
        '<h2>Server update</h2>'
        '<div class="maint-desc">Pulls the latest code, rebuilds the image '
        'and recreates the container. <strong>The server restarts and is '
        'briefly unavailable.</strong></div>'
        '<div class="maint-actions">'
        '<button id="deployBtn" type="button" class="btn btn-primary">'
        'Update &amp; restart server</button>'
        '</div>'
        '<div id="deployStatus" class="maint-status"></div>'
        '<pre id="deployLog" class="log maint-out" style="display:none"></pre>'
        '</div>'
        '<div class="card">'
        '<h2>System updates</h2>'
        '<div class="maint-desc">Installs apt package upgrades and graphics '
        'driver updates on the host (Ubuntu Desktop), then immediately '
        'restarts the server and wiki. <strong>The server is briefly '
        'unavailable during the restart.</strong></div>'
        '<div class="maint-actions">'
        '<button id="updateCheckBtn" type="button" class="btn btn-primary">'
        'Install updates &amp; restart</button>'
        '</div>'
        '<div id="updateCheckStatus" class="maint-status"></div>'
        '<pre id="updateCheckLog" class="log maint-out" style="display:none"></pre>'
        '</div>'
        '</div>'
        '</div>'
        '<script>$_adminTabScript</script>'
        '<script>$_adminMetricsScript</script>'
        '<script>$_adminGroceriesScript</script>'
        '<script>$_adminAiModelsScript</script>'
        '<script>${DeployConsole.deployScript}</script>'
        '<script>${UpdateCheckConsole.updateCheckScript}</script>'
        '</body></html>';

    return Response(200,
        body: body, headers: {'Content-Type': 'text/html; charset=utf-8'});
  }

  /// Embedded stylesheet for the admin dashboard. Self-contained (no external
  /// fonts or CDNs), dark-only, built around the app's purple accent.
  static const _adminCss = r'''
*{box-sizing:border-box}
body{background:#0f0d17;color:#ece8f7;margin:0;-webkit-font-smoothing:antialiased;
  font-family:ui-sans-serif,system-ui,"Segoe UI",Roboto,sans-serif;font-size:14px;line-height:1.5}
.wrap{max-width:1180px;margin:0 auto;padding:36px 28px 64px}
header.top{display:flex;align-items:baseline;gap:12px;margin-bottom:26px}
h1{font-size:19px;font-weight:700;letter-spacing:-.01em;margin:0}
h1 .dot{color:#8a7ee0}
.sub{font-size:12px;color:#6f688a}
h2{font-size:12px;font-weight:600;letter-spacing:.06em;text-transform:uppercase;color:#8d86a8;margin:0 0 14px}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;margin-bottom:28px}
.stat{background:linear-gradient(180deg,#1a1628,#151122);border:1px solid #262038;border-radius:12px;padding:16px 18px}
.stat .n{font-size:24px;font-weight:700;letter-spacing:-.02em;font-variant-numeric:tabular-nums}
.stat .l{font-size:11px;letter-spacing:.05em;text-transform:uppercase;color:#8d86a8;margin-top:6px}
.tabs{display:inline-flex;gap:4px;background:#161225;border:1px solid #262038;border-radius:12px;padding:4px;margin-bottom:24px;flex-wrap:wrap}
.tab-btn{background:transparent;color:#9b94b3;border:0;border-radius:8px;padding:8px 16px;font-size:13px;font-weight:500;cursor:pointer;font-family:inherit;transition:color .15s,background .15s}
.tab-btn:hover{color:#ece8f7}
.tab-btn.active{background:#8a7ee0;color:#14111f;font-weight:600}
.tab-panel{display:none}.tab-panel.active{display:block}
.card{background:#151122;border:1px solid #241e36;border-radius:14px;padding:20px 22px;margin-bottom:18px}
.card.table-card{padding:14px 16px}
.card.table-card h2{padding:6px 6px 0}
table{border-collapse:collapse;width:100%;font-size:13px}
th{text-align:left;color:#7f7898;font-weight:600;font-size:11px;letter-spacing:.05em;text-transform:uppercase;padding:10px 12px;border-bottom:1px solid #262038;white-space:nowrap}
td{padding:10px 12px;border-bottom:1px solid #1d1830;font-variant-numeric:tabular-nums}
tbody tr:last-child td{border-bottom:0}
tbody tr:hover td{background:#181330}
.muted{color:#9b94b3}
.hint{color:#9b94b3;font-size:13px;margin-bottom:16px}
.badge{display:inline-block;padding:2px 9px;border-radius:999px;font-size:11px;font-weight:600;letter-spacing:.02em}
.badge.ok{background:rgba(126,224,138,.12);color:#7ee08a}
.badge.warn{background:rgba(224,200,126,.12);color:#e0c87e}
.badge.err{background:rgba(224,126,126,.12);color:#e07e7e}
.meter{background:#241f38;border-radius:99px;overflow:hidden;width:120px;height:6px;display:inline-block;vertical-align:middle;margin-right:8px}
.meter>div{background:linear-gradient(90deg,#8a7ee0,#a89bf0);height:100%}
.btn{display:inline-flex;align-items:center;justify-content:center;border-radius:9px;padding:8px 16px;font-size:13px;font-weight:600;cursor:pointer;font-family:inherit;border:1px solid transparent;transition:background .15s,border-color .15s,color .15s}
.btn-primary{background:#8a7ee0;color:#14111f}
.btn-primary:hover{background:#9c91ec}
.btn-primary:disabled{opacity:.5;cursor:not-allowed}
.btn-ghost{background:#1c1730;color:#b4addc;border-color:#2d2645;font-weight:500}
.btn-ghost:hover{border-color:#463d6b;color:#ece8f7}
.btn-danger{background:transparent;color:#e07e7e;border-color:#443030}
.btn-danger:hover{background:rgba(224,126,126,.08)}
.btn-sm{padding:4px 12px;font-size:12px;border-radius:7px}
.btn:focus-visible,.tab-btn:focus-visible,.range-btn:focus-visible{outline:2px solid #8a7ee0;outline-offset:2px}
.product-form{display:flex;gap:10px;flex-wrap:wrap;align-items:center;margin-bottom:18px}
.product-form select,.product-form input{background:#1a1530;color:#ece8f7;border:1px solid #2d2645;border-radius:9px;padding:8px 12px;font-size:13px;font-family:inherit;outline:none}
.product-form select:focus,.product-form input:focus{border-color:#8a7ee0}
.range-tabs{display:inline-flex;gap:4px;background:#161225;border:1px solid #262038;border-radius:10px;padding:4px;margin-bottom:18px}
.range-btn{background:transparent;color:#9b94b3;border:0;border-radius:7px;padding:6px 12px;font-size:12px;font-weight:500;cursor:pointer;font-family:inherit;transition:color .15s,background .15s}
.range-btn:hover{color:#ece8f7}
.range-btn.active{background:#8a7ee0;color:#14111f;font-weight:600}
.metrics-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(440px,1fr));gap:14px}
@media (max-width:960px){.metrics-grid{grid-template-columns:1fr}}
/* Four maintenance cards, each "button + status + output". Their natural
   heights differ wildly (a deploy log is 20x a one-line status), so this is
   a 2-col grid of equal-height cards with every output box capped and
   scrolling internally — an auto-fit 3-col grid left one card stranded on a
   second row and the tall deploy log punched a hole through the first. */
.maint-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(400px,1fr));gap:18px}
.maint-grid .card{margin-bottom:0;display:flex;flex-direction:column;min-width:0}
.maint-grid .card h2{margin-bottom:8px}
.maint-desc{color:#8d86a8;font-size:12.5px;line-height:1.55;margin:0 0 16px;max-width:62ch}
.maint-desc strong{color:#b4addc;font-weight:600}
.maint-actions{display:flex;gap:10px;flex-wrap:wrap;align-items:center;margin-bottom:14px}
/* Reserves its line so an arriving status message doesn't shift the card. */
.maint-status{font-size:13px;color:#9b94b3;line-height:1.5;min-height:20px}
/* Both output kinds — the sync tables and the deploy/update logs — render as
   the same inset panel, so the four cards read as one family. */
.maint-out{margin-top:14px;max-height:220px;overflow:auto;background:#12101e;border:1px solid #241e36;border-radius:10px}
.maint-grid pre.log{margin-top:14px;max-height:220px}
@media (max-width:900px){.maint-grid{grid-template-columns:1fr}}
.metric-card{background:#151122;border:1px solid #241e36;border-radius:14px;padding:16px 18px}
.metric-title{font-size:11px;letter-spacing:.05em;text-transform:uppercase;color:#8d86a8;margin-bottom:10px;display:flex;align-items:center;justify-content:space-between;gap:8px}
.metric-title .legend{display:inline-flex;gap:10px;text-transform:none;letter-spacing:0}
.metric-title .k.accent{color:#8a7ee0}
.metric-title .k.green{color:#7ee08a}
.metric-value{font-size:15px;font-weight:600;margin-top:10px;font-variant-numeric:tabular-nums}
canvas{display:block;width:100%;height:170px;cursor:crosshair}
.chart-tip{position:fixed;pointer-events:none;background:#1e1834;border:1px solid #352c55;border-radius:8px;padding:6px 10px;font-size:12px;line-height:1.6;color:#ece8f7;z-index:100;display:none;box-shadow:0 6px 20px rgba(0,0,0,.45);font-variant-numeric:tabular-nums;white-space:nowrap}
.chart-tip .t{color:#8d86a8;font-size:11px}
.storage-wrap{display:flex;gap:24px;align-items:center;flex-wrap:wrap}
.storage-chart-box{flex:0 0 220px;width:220px;height:220px;display:flex;align-items:center;justify-content:center}
#storageChart{width:220px;height:220px;max-width:220px;max-height:220px;cursor:default}
.storage-legend{display:flex;flex-direction:column;gap:7px;min-width:220px;flex:1}
.storage-legend-item{display:flex;align-items:center;gap:8px;font-size:13px;line-height:1.4}
.storage-legend-swatch{width:12px;height:12px;border-radius:3px;flex-shrink:0;display:inline-block}
.storage-legend-label{flex:1;color:#ece8f7}
.storage-legend-value{color:#9b94b3;font-variant-numeric:tabular-nums;white-space:nowrap}
.storage-legend-pct{color:#6f688a;font-size:11px;min-width:38px;text-align:right}
@media (max-width:640px){.storage-wrap{flex-direction:column;align-items:flex-start}.storage-legend{width:100%}}
pre.log{background:#12101e;border:1px solid #241e36;border-radius:12px;padding:16px;font-size:12px;line-height:1.55;max-height:400px;overflow:auto;white-space:pre-wrap;word-break:break-all;color:#b9b2d4;margin:0}
@media (max-width:640px){.wrap{padding:24px 16px 48px}.card{padding:16px}}
''';

  /// Tiny vanilla-JS tab switcher for the Users / Products / Metrics panels,
  /// keeping the selected tab in the URL hash so it survives a form POST's
  /// redirect back to the page (see _adminSetPlan/_adminVerifyUser).
  static const _adminTabScript = r'''
(function () {
  const buttons = document.querySelectorAll('.tab-btn');
  const panels = {
    users: document.getElementById('panel-users'),
    products: document.getElementById('panel-products'),
    activity: document.getElementById('panel-activity'),
    plugins: document.getElementById('panel-plugins'),
    metrics: document.getElementById('panel-metrics'),
    control: document.getElementById('panel-control'),
  };
  function activate(tab) {
    if (!panels[tab]) tab = 'users';
    buttons.forEach((b) => b.classList.toggle('active', b.dataset.tab === tab));
    Object.entries(panels).forEach(([k, el]) => el.classList.toggle('active', k === tab));
  }
  buttons.forEach((b) => b.addEventListener('click', () => {
    activate(b.dataset.tab);
    history.replaceState(null, '', '#' + b.dataset.tab);
  }));
  activate((location.hash || '#users').slice(1));
})();
''';

  /// Control panel tab: loads the groceries server's sync status through
  /// this server's /admin/groceries/status proxy and renders it; refreshes
  /// every 3 seconds while a sync is running so the counters fill in live.
  static const _adminGroceriesScript = r'''
(function () {
  const summary = document.getElementById('groceriesSummary');
  const rows = document.getElementById('groceriesSyncRows');
  if (!summary || !rows) return;

  const logBtn = document.getElementById('groceriesLogBtn');
  const logBox = document.getElementById('groceriesLog');
  if (logBtn && logBox) {
    logBtn.addEventListener('click', () => {
      const open = logBox.style.display !== 'none';
      logBox.style.display = open ? 'none' : 'block';
      logBtn.textContent = open ? 'Show sync log' : 'Hide sync log';
    });
  }

  function esc(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    })[c]);
  }

  function render(data) {
    if (data.error) {
      summary.textContent = 'Could not reach the groceries server ('
        + (data.message || data.error) + ')';
      rows.innerHTML = '<tr><td colspan="9" class="muted">—</td></tr>';
      return false;
    }
    if (!data.configured) {
      summary.textContent = 'Not connected: set LUMA_GROCERIES_ADMIN_KEY '
        + '(and optionally LUMA_GROCERIES_URL) in this server\'s .env, '
        + 'then restart.';
      rows.innerHTML = '<tr><td colspan="9" class="muted">—</td></tr>';
      return false;
    }
    const s = data.status;
    summary.innerHTML = '<strong>' + s.products.total + '</strong> products ('
      + s.products.available + ' available), '
      + s.priceSnapshots + ' price snapshots'
      + (s.running ? ' — <strong>sync running…</strong>' : '');
    rows.innerHTML = s.syncs.length === 0
      ? '<tr><td colspan="9" class="muted">No syncs yet.</td></tr>'
      : s.syncs.map((r) => {
          const cls = r.status === 'success' ? 'ok'
            : r.status === 'running' ? 'warn' : 'err';
          return '<tr><td>' + esc(r.marketName) + '</td>'
            + '<td><span class="badge ' + cls + '">' + esc(r.status) + '</span></td>'
            + '<td>' + esc(r.startedAt) + '</td>'
            + '<td>' + esc(r.finishedAt || '—') + '</td>'
            + '<td>' + r.checked + '</td><td>' + r.added + '</td>'
            + '<td>' + r.updated + '</td><td>' + r.failed + '</td>'
            + '<td>' + esc(r.error) + '</td></tr>';
        }).join('');
    return s.running;
  }

  let timer = null;
  function load() {
    fetch('/admin/groceries/status')
      .then((r) => r.json())
      .then((data) => {
        const running = render(data);
        clearTimeout(timer);
        if (running) timer = setTimeout(load, 3000);
      })
      .catch(() => {
        summary.textContent = 'Could not reach the groceries server.';
      });
  }
  load();
})();
''';

  /// Control panel tab: "Refresh model data" POSTs to
  /// /admin/ai-models/refresh and then polls /admin/ai-models/status every
  /// 2s until the job reports it has stopped running, rendering one row per
  /// upstream. The job outlives the request that started it, so the poll —
  /// not the POST response — is what reports the outcome; reloading the
  /// dashboard mid-refresh picks the same poll back up.
  static const _adminAiModelsScript = r'''
(function () {
  const btn = document.getElementById('aiModelsBtn');
  const summary = document.getElementById('aiModelsSummary');
  const logBox = document.getElementById('aiModelsLog');
  const rows = document.getElementById('aiModelsRows');
  if (!btn || !summary || !logBox || !rows) return;

  function esc(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    })[c]);
  }

  function when(ms) {
    if (!ms) return 'never';
    return new Date(ms).toLocaleString();
  }

  let timer = null;

  function render(data) {
    const s = data.status || {};
    const running = !!s.running;
    btn.disabled = running;
    btn.textContent = running ? 'Refreshing…' : 'Refresh model data';

    let text = '<strong>' + data.modelCount + '</strong> models · '
      + data.newsCount + ' news items · last refreshed ' + when(data.refreshedAtMs);
    if (running) {
      text += ' — <strong>refresh running…</strong>';
    } else if (s.error) {
      text += ' — <span class="badge err">failed</span> ' + esc(s.error);
    } else if (s.finishedAtMs) {
      const added = (s.modelsAdded || []).length;
      text += added > 0
        ? ' — <span class="badge ok">' + added + ' new model'
          + (added === 1 ? '' : 's') + '</span> '
          + esc((s.modelsAdded || []).slice(0, 6).join(', '))
          + (added > 6 ? ' …' : '')
        : ' — <span class="badge ok">no new models</span>';
    }
    if (!data.artificialAnalysisConfigured) {
      text += '<br><span class="muted">Reasoning, speed and effort-level data '
        + 'need LUMA_AA_API_KEY (free key from artificialanalysis.ai) in this '
        + "server's .env. Every other column works without it.</span>";
    }
    summary.innerHTML = text;

    const results = s.results || [];
    logBox.style.display = results.length ? 'block' : 'none';
    rows.innerHTML = results.map((r) => {
      const cls = r.ok ? 'ok' : 'err';
      return '<tr><td>' + esc(r.source) + '</td>'
        + '<td><span class="badge ' + cls + '">'
        + (r.ok ? 'ok' : 'failed') + '</span></td>'
        + '<td>' + esc(r.fetched) + '</td>'
        + '<td>' + esc(r.applied) + '</td>'
        + '<td>' + esc(r.error || '—') + '</td></tr>';
    }).join('');
    return running;
  }

  function load() {
    fetch('/admin/ai-models/status')
      .then((r) => r.json())
      .then((data) => {
        clearTimeout(timer);
        if (render(data)) timer = setTimeout(load, 2000);
      })
      .catch(() => {
        summary.textContent = 'Could not read the catalogue status.';
      });
  }

  btn.addEventListener('click', () => {
    btn.disabled = true;
    btn.textContent = 'Refreshing…';
    fetch('/admin/ai-models/refresh', { method: 'POST' })
      .then(() => setTimeout(load, 500))
      .catch(() => {
        btn.disabled = false;
        btn.textContent = 'Refresh model data';
        summary.textContent = 'Could not start the refresh.';
      });
  });

  load();
})();
''';


  /// Vanilla JS (no external deps, per the self-contained-dashboard style):
  /// polls /admin/metrics every 2s for a live reading, and separately loads
  /// persisted history from /admin/metrics/history for whichever range is
  /// selected (1 minute / 1 hour / 24 hours / 1 week) so the graphs survive
  /// a page reload or server restart instead of starting blank every time.
  static const _adminMetricsScript = r'''
(function () {
  const RANGE_CAPS = { minute: 45, hour: 60, day: 24, week: 24 * 7 };
  let currentRange = 'minute';
  let cap = RANGE_CAPS[currentRange];
  const history = { cpu: [], ram: [], rx: [], tx: [], diskRead: [], diskWrite: [] };

  function push(arr, v) {
    arr.push(v);
    if (arr.length > cap) arr.shift();
  }

  function fmtBytes(v) {
    if (v == null) return '–';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    let i = 0, val = v;
    while (val >= 1024 && i < units.length - 1) { val /= 1024; i++; }
    return val.toFixed(val >= 10 || i === 0 ? 0 : 1) + ' ' + units[i];
  }

  function fmtRate(v) {
    return v == null ? '–' : fmtBytes(v) + '/s';
  }

  // Backs each canvas with a devicePixelRatio-scaled bitmap (drawn in CSS
  // pixel coordinates via ctx.scale) so lines stay crisp instead of being
  // upscaled/blurred by the browser. Returns null while the canvas isn't
  // visible (e.g. its tab isn't active — panels start display:none, but
  // polling runs in the background regardless): getBoundingClientRect is
  // 0×0 there, and there's no CSS size to size the bitmap to yet. Skipping
  // the draw in that case (rather than falling back to some other size) is
  // what makes this self-correcting — the very first draw AFTER the tab
  // becomes visible sizes the bitmap correctly, once, with no stale cache
  // or compounding resize to work around.
  function ensureHiDPI(canvas) {
    const rect = canvas.getBoundingClientRect();
    if (rect.width < 1 || rect.height < 1) return null;
    if (canvas._ctx && canvas._cssW === rect.width && canvas._cssH === rect.height) {
      return canvas._ctx;
    }
    const dpr = window.devicePixelRatio || 1;
    canvas.width = Math.round(rect.width * dpr);
    canvas.height = Math.round(rect.height * dpr);
    const ctx = canvas.getContext('2d');
    ctx.scale(dpr, dpr);
    canvas._cssW = rect.width;
    canvas._cssH = rect.height;
    canvas._ctx = ctx;
    return ctx;
  }

  // Shared tooltip element for chart hover (one for all four graphs).
  const tip = document.createElement('div');
  tip.className = 'chart-tip';
  document.body.appendChild(tip);

  function drawGraph(canvas, series, maxValue) {
    if (!canvas) return;
    canvas._series = series;
    const ctx = ensureHiDPI(canvas);
    if (!ctx) return; // hidden right now — history keeps accumulating either way
    const w = canvas._cssW, h = canvas._cssH;
    ctx.clearRect(0, 0, w, h);
    ctx.strokeStyle = '#2c2640';
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (let i = 1; i <= 3; i++) {
      const y = Math.round(h * i / 4) + 0.5;
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
    }
    ctx.stroke();

    let max = maxValue;
    if (max == null) {
      max = 1;
      for (const s of series) {
        for (const v of s.values) max = Math.max(max, v);
      }
    }

    for (const s of series) {
      const values = s.values;
      if (values.length < 2) continue;
      const pts = values.map((v, i) => ({
        x: (w * i) / (values.length - 1),
        y: h - (Math.min(v, max) / max) * h,
      }));
      ctx.strokeStyle = s.color;
      ctx.lineWidth = 2;
      ctx.lineJoin = 'round';
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(pts[0].x, pts[0].y);
      // Smooth the polyline into a curve by drawing a quadratic segment
      // through the midpoint of each pair of points — avoids the jagged,
      // "low-res" look of a raw point-to-point line with no extra libs.
      // The very first hop goes to mid(0,1) (a tiny straight nub) instead of
      // curving straight from pts[0], so every quadratic segment afterward
      // is symmetric — control point pts[i] sits at t=0.5 between two
      // midpoints. Without this, the first segment was the odd one out
      // (start = pts[0] exactly, not a midpoint), so the on-curve point
      // near pts[1] landed off to the side of where a hover marker placed
      // at pts[1] expected it to be.
      if (pts.length > 2) {
        ctx.lineTo((pts[0].x + pts[1].x) / 2, (pts[0].y + pts[1].y) / 2);
      }
      for (let i = 1; i < pts.length - 1; i++) {
        const mx = (pts[i].x + pts[i + 1].x) / 2;
        const my = (pts[i].y + pts[i + 1].y) / 2;
        ctx.quadraticCurveTo(pts[i].x, pts[i].y, mx, my);
      }
      ctx.lineTo(pts[pts.length - 1].x, pts[pts.length - 1].y);
      ctx.stroke();
    }

    // Hover crosshair + markers at the sample nearest the cursor.
    if (canvas._hoverFrac != null) {
      const x = canvas._hoverFrac * w;
      ctx.strokeStyle = 'rgba(236,232,247,0.25)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(x + 0.5, 0);
      ctx.lineTo(x + 0.5, h);
      ctx.stroke();
      for (const s of series) {
        const values = s.values;
        if (!values.length) continue;
        const i = Math.round(canvas._hoverFrac * (values.length - 1));
        const px = values.length > 1 ? (w * i) / (values.length - 1) : 0;
        const yOf = (v) => h - (Math.min(v, max) / max) * h;
        // The line itself is smoothed (quadratic through segment midpoints),
        // so at interior samples the rendered curve sits at
        // (prev + 6*this + next) / 8, not at the raw sample — put the marker
        // on the curve so it never floats off the line at sharp peaks.
        const py = (i > 0 && i < values.length - 1)
            ? (yOf(values[i - 1]) + 6 * yOf(values[i]) + yOf(values[i + 1])) / 8
            : yOf(values[i]);
        ctx.fillStyle = s.color;
        ctx.beginPath();
        ctx.arc(px, py, 3.5, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }

  function redrawAll() {
    drawGraph(document.getElementById('cpuGraph'),
        [{ values: history.cpu, color: '#8a7ee0', label: 'CPU' }], 100);
    drawGraph(document.getElementById('ramGraph'),
        [{ values: history.ram, color: '#8a7ee0', label: 'RAM' }], 100);
    drawGraph(document.getElementById('netGraph'), [
      { values: history.rx, color: '#8a7ee0', label: '↓ down' },
      { values: history.tx, color: '#7ee08a', label: '↑ up' },
    ], null);
    drawGraph(document.getElementById('diskGraph'), [
      { values: history.diskRead, color: '#8a7ee0', label: '↓ read' },
      { values: history.diskWrite, color: '#7ee08a', label: '↑ write' },
    ], null);
  }

  function esc(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    })[c]);
  }

  // Shows the exact value(s) at the hovered sample in a floating tooltip
  // and redraws the chart with a crosshair. `fmt` formats one raw value
  // (percent for CPU/RAM, bytes/s for network and disk).
  function attachHover(canvas, fmt) {
    if (!canvas) return;
    canvas.addEventListener('mousemove', (e) => {
      const rect = canvas.getBoundingClientRect();
      if (rect.width < 1) return;
      canvas._hoverFrac =
          Math.min(1, Math.max(0, (e.clientX - rect.left) / rect.width));
      redrawAll();
      let html = '';
      for (const s of canvas._series || []) {
        const values = s.values;
        if (!values.length) continue;
        const i = Math.round(canvas._hoverFrac * (values.length - 1));
        html += '<div><span style="color:' + s.color + '">●</span> '
            + esc(s.label) + ' <strong>' + esc(fmt(values[i])) + '</strong></div>';
      }
      if (!html) { tip.style.display = 'none'; return; }
      tip.innerHTML = html;
      tip.style.display = 'block';
      const tw = tip.offsetWidth;
      const left = e.clientX + 14 + tw > window.innerWidth
          ? e.clientX - 14 - tw : e.clientX + 14;
      tip.style.left = left + 'px';
      tip.style.top = (e.clientY - 12) + 'px';
    });
    canvas.addEventListener('mouseleave', () => {
      canvas._hoverFrac = null;
      tip.style.display = 'none';
      redrawAll();
    });
  }

  attachHover(document.getElementById('cpuGraph'), (v) => v.toFixed(1) + '%');
  attachHover(document.getElementById('ramGraph'), (v) => v.toFixed(1) + '%');
  attachHover(document.getElementById('netGraph'), fmtRate);
  attachHover(document.getElementById('diskGraph'), fmtRate);

  // Rebuilds the `history` arrays (as drawn on the graphs) from a server
  // history payload — same derived fields poll() computes per live sample
  // (RAM as a percentage, etc.), just applied to a whole point list at once.
  function seedHistory(points) {
    history.cpu = points.map((p) => p.cpuPercent).filter((v) => v != null);
    history.ram = points
        .filter((p) => p.ramUsedBytes != null && p.ramTotalBytes)
        .map((p) => (p.ramUsedBytes / p.ramTotalBytes) * 100);
    history.rx = points.map((p) => p.netRxBytesPerSec).filter((v) => v != null);
    history.tx = points.map((p) => p.netTxBytesPerSec).filter((v) => v != null);
    history.diskRead =
        points.map((p) => p.diskReadBytesPerSec).filter((v) => v != null);
    history.diskWrite =
        points.map((p) => p.diskWriteBytesPerSec).filter((v) => v != null);
  }

  async function loadRange(range) {
    currentRange = range;
    cap = RANGE_CAPS[range];
    document.querySelectorAll('.range-btn').forEach((b) =>
        b.classList.toggle('active', b.dataset.range === range));
    try {
      const res = await fetch('/admin/metrics/history?range=' + range);
      if (res.ok) {
        const data = await res.json();
        seedHistory(data.points || []);
        redrawAll();
      }
    } catch (e) {}
  }

  document.querySelectorAll('.range-btn').forEach((b) =>
      b.addEventListener('click', () => loadRange(b.dataset.range)));

  async function poll() {
    let res;
    try {
      res = await fetch('/admin/metrics');
    } catch (e) {
      return;
    }
    if (!res.ok) return;
    const m = await res.json();

    if (!m.platformSupported) {
      document.getElementById('metricsUnsupported').style.display = 'block';
      document.getElementById('metricsGrid').style.display = 'none';
      return;
    }

    if (m.cpuPercent != null) {
      document.getElementById('cpuValue').textContent = m.cpuPercent.toFixed(1) + '%';
    }
    if (m.ramUsedBytes != null && m.ramTotalBytes) {
      document.getElementById('ramValue').textContent =
          fmtBytes(m.ramUsedBytes) + ' / ' + fmtBytes(m.ramTotalBytes);
    }
    if (m.netRxBytesPerSec != null && m.netTxBytesPerSec != null) {
      document.getElementById('netValue').textContent =
          '↓ ' + fmtRate(m.netRxBytesPerSec) + '   ↑ ' + fmtRate(m.netTxBytesPerSec);
    }
    document.getElementById('diskValue').textContent =
        (m.diskReadBytesPerSec != null && m.diskWriteBytesPerSec != null)
            ? '↓ ' + fmtRate(m.diskReadBytesPerSec) + '   ↑ ' + fmtRate(m.diskWriteBytesPerSec)
            : 'Not available on this host';

    // The server records this same poll into its own history (see
    // Api._adminMetrics), so the finest ("1 minute") view can just append
    // the live reading locally. Coarser ranges are re-fetched wholesale
    // instead, since a single new sample barely moves a minute/hour bucket.
    if (currentRange === 'minute') {
      if (m.cpuPercent != null) push(history.cpu, m.cpuPercent);
      if (m.ramUsedBytes != null && m.ramTotalBytes) {
        push(history.ram, (m.ramUsedBytes / m.ramTotalBytes) * 100);
      }
      if (m.netRxBytesPerSec != null && m.netTxBytesPerSec != null) {
        push(history.rx, m.netRxBytesPerSec);
        push(history.tx, m.netTxBytesPerSec);
      }
      if (m.diskReadBytesPerSec != null && m.diskWriteBytesPerSec != null) {
        push(history.diskRead, m.diskReadBytesPerSec);
        push(history.diskWrite, m.diskWriteBytesPerSec);
      }
      redrawAll();
    }
  }

  // ---- Storage doughnut (bytes per database) ---------------------------
  const STORAGE_COLORS = [
    '#8a7ee0','#7ee08a','#e0c87e','#e07e7e','#7ec8e0','#c87ee0',
    '#7ee0c8','#e0a07e','#a07ee0','#e07ea0','#a0c8e0','#c8e07e',
    '#e0c8a0','#8ae0a0','#a0a0e0','#e08a7e','#8ac87e','#c8a0e0',
    '#7ea0e0','#e0c87e','#8ae0c8','#a0e0c8',
  ];

  function drawStorageChart(entries, totalBytes) {
    const canvas = document.getElementById('storageChart');
    const legend = document.getElementById('storageLegend');
    const totalEl = document.getElementById('storageTotal');
    if (!canvas || !legend || !totalEl) return;
    if (!entries || !entries.length || totalBytes === 0) {
      const ctx0 = ensureHiDPI(canvas);
      if (ctx0) {
        ctx0.clearRect(0,0,canvas._cssW||220,canvas._cssH||220);
        ctx0.fillStyle = '#6f688a';
        ctx0.font = '12px system-ui, sans-serif';
        ctx0.textAlign = 'center';
        const w = canvas._cssW || 220, h = canvas._cssH || 220;
        ctx0.fillText('No storage used yet', w/2, h/2);
      }
      legend.innerHTML = '<span class="muted" style="font-size:13px">All stores are empty — data appears here once accounts and content exist.</span>';
      totalEl.textContent = 'Total: ' + fmtBytes(0);
      return;
    }
    const ctx = ensureHiDPI(canvas);
    if (!ctx) {
      // Canvas hidden (tab not active) — still build legend; chart draws on next frame.
      let html = '';
      entries.forEach((e, i) => {
        const color = STORAGE_COLORS[i % STORAGE_COLORS.length];
        const pct = ((e.bytes / totalBytes) * 100);
        html += '<div class="storage-legend-item">'
          + '<span class="storage-legend-swatch" style="background:' + color + '"></span>'
          + '<span class="storage-legend-label">' + esc(e.label) + '</span>'
          + '<span class="storage-legend-value">' + esc(fmtBytes(e.bytes)) + '</span>'
          + '<span class="storage-legend-pct">' + pct.toFixed(1) + '%</span>'
          + '</div>';
      });
      legend.innerHTML = html;
      totalEl.textContent = 'Total: ' + fmtBytes(totalBytes) + ' across ' + entries.length + ' stores';
      return;
    }
    const w = canvas._cssW, h = canvas._cssH;
    const cx = w / 2, cy = h / 2;
    const outerR = Math.min(w, h) / 2 - 6;
    const innerR = outerR * 0.58;
    ctx.clearRect(0, 0, w, h);

    let angle = -Math.PI / 2;
    entries.forEach((e, i) => {
      const color = STORAGE_COLORS[i % STORAGE_COLORS.length];
      const slice = (e.bytes / totalBytes) * Math.PI * 2;
      if (slice <= 0) return;
      ctx.beginPath();
      ctx.moveTo(cx + Math.cos(angle) * innerR, cy + Math.sin(angle) * innerR);
      ctx.arc(cx, cy, outerR, angle, angle + slice);
      ctx.arc(cx, cy, innerR, angle + slice, angle, true);
      ctx.closePath();
      ctx.fillStyle = color;
      ctx.fill();
      // thin separator between slices
      ctx.strokeStyle = '#151122';
      ctx.lineWidth = 1.5;
      ctx.stroke();
      // stash slice for hit-test tooltip
      e._start = angle; e._end = angle + slice; e._color = color;
      angle += slice;
    });

    // center label
    ctx.fillStyle = '#ece8f7';
    ctx.font = '700 14px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(fmtBytes(totalBytes), cx, cy - 4);
    ctx.fillStyle = '#8d86a8';
    ctx.font = '10px system-ui, sans-serif';
    ctx.fillText('total', cx, cy + 12);

    // legend
    let html2 = '';
    entries.forEach((e, i) => {
      const color = STORAGE_COLORS[i % STORAGE_COLORS.length];
      const pct = ((e.bytes / totalBytes) * 100);
      html2 += '<div class="storage-legend-item">'
        + '<span class="storage-legend-swatch" style="background:' + color + '"></span>'
        + '<span class="storage-legend-label">' + esc(e.label) + '</span>'
        + '<span class="storage-legend-value">' + esc(fmtBytes(e.bytes)) + '</span>'
        + '<span class="storage-legend-pct">' + pct.toFixed(1) + '%</span>'
        + '</div>';
    });
    legend.innerHTML = html2;
    totalEl.textContent = 'Total: ' + fmtBytes(totalBytes) + ' across ' + entries.length + ' stores';

    // hover tooltip for slices
    if (!canvas._storageHoverBound) {
      canvas._storageHoverBound = true;
      const hoverTip = tip;
      canvas.addEventListener('mousemove', (ev) => {
        const rect = canvas.getBoundingClientRect();
        const x = ev.clientX - rect.left, y = ev.clientY - rect.top;
        const scaleX = (canvas._cssW || 220) / rect.width;
        const scaleY = (canvas._cssH || 220) / rect.height;
        const lx = x * scaleX, ly = y * scaleY;
        const dx = lx - cx, dy = ly - cy;
        const dist = Math.sqrt(dx*dx + dy*dy);
        if (dist < innerR || dist > outerR) { hoverTip.style.display = 'none'; return; }
        let a = Math.atan2(dy, dx);
        if (a < -Math.PI/2) a += Math.PI*2;
        let hit = null;
        for (const e of entries) {
          let s = e._start, en = e._end;
          if (a >= s && a < en) { hit = e; break; }
        }
        if (!hit) { hoverTip.style.display = 'none'; return; }
        const pct2 = ((hit.bytes / totalBytes)*100).toFixed(1);
        hoverTip.innerHTML = '<div><span style="color:' + hit._color + '">●</span> '
          + esc(hit.label) + ' <strong>' + esc(fmtBytes(hit.bytes)) + '</strong>'
          + ' <span class="t">' + pct2 + '%</span></div>';
        hoverTip.style.display = 'block';
        const tw = hoverTip.offsetWidth;
        const left = ev.clientX + 14 + tw > window.innerWidth ? ev.clientX - 14 - tw : ev.clientX + 14;
        hoverTip.style.left = left + 'px';
        hoverTip.style.top = (ev.clientY - 12) + 'px';
      });
      canvas.addEventListener('mouseleave', () => { hoverTip.style.display = 'none'; });
    }
  }

  let storageCache = null;
  async function loadStorage() {
    try {
      const res = await fetch('/admin/storage');
      if (!res.ok) return;
      const data = await res.json();
      storageCache = data;
      drawStorageChart(data.entries || [], data.totalBytes || 0);
    } catch (_) {}
  }

  // Redraw cached storage chart when tab becomes visible (canvas was 0×0 before).
  const metricsPanel = document.getElementById('panel-metrics');
  if (metricsPanel) {
    const obs = new MutationObserver(() => {
      if (metricsPanel.classList.contains('active') && storageCache) {
        drawStorageChart(storageCache.entries || [], storageCache.totalBytes || 0);
      }
      // also keep live graphs crisp after tab switch
      redrawAll();
    });
    obs.observe(metricsPanel, { attributes: true, attributeFilter: ['class'] });
    window.addEventListener('resize', () => {
      if (storageCache) drawStorageChart(storageCache.entries || [], storageCache.totalBytes || 0);
      redrawAll();
    });
  }

  loadRange('minute');
  poll();
  loadStorage();
  setInterval(poll, 2000);
  setInterval(() => {
    if (currentRange !== 'minute') loadRange(currentRange);
  }, 30000);
  setInterval(loadStorage, 30000);
})();
''';

  // ---- Helpers -------------------------------------------------------------

  /// PBKDF2 over the client's already-derived auth key. Kept `async` so the
  /// call sites stay unchanged; the work itself is fast (20k iterations).
  Future<Uint8List> _hashAuthKey(Uint8List authKey, Uint8List salt) async =>
      pbkdf2Sha256(authKey, salt, _serverHashIterations, 32);

  /// Creates a session and returns (token, expiresAtMs). Caller holds the lock.
  Future<(String, int)> _createSession(StoredUser user,
      {String? deviceLabel}) async {
    final token = base64UrlEncode(randomBytes(32)).replaceAll('=', '');
    final tokenHash = c.sha256.convert(utf8.encode(token)).toString();
    final now = DateTime.now().millisecondsSinceEpoch;
    final expires = now + config.tokenTtl.inMilliseconds;
    store.pruneSessions();
    store.sessionsByTokenHash[tokenHash] = StoredSession(
      tokenHash: tokenHash,
      userId: user.id,
      createdAtMs: now,
      expiresAtMs: expires,
      deviceLabel: _sanitizeDeviceLabel(deviceLabel),
    );
    await store.saveSessions();
    return (token, expires);
  }

  /// Trims and caps a client-supplied device label so it can't be used to
  /// stuff an oversized/garbage value into the sessions file.
  static String? _sanitizeDeviceLabel(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.length > 60 ? trimmed.substring(0, 60) : trimmed;
  }

  /// Generates a fresh verification token, stores only its hash against the
  /// user (mirroring how session tokens are handled), and returns the raw
  /// token to send by email. Caller holds the store lock.
  Future<String> _issueVerificationToken(StoredUser user) async {
    final token = base64UrlEncode(randomBytes(32)).replaceAll('=', '');
    user.verificationTokenHash =
        c.sha256.convert(utf8.encode(token)).toString();
    user.verificationExpiresAtMs =
        DateTime.now().millisecondsSinceEpoch + config.verificationTtl.inMilliseconds;
    return token;
  }

  /// Best-effort send; a mail outage should not make registration fail
  /// outright since the user can always request a fresh link.
  Future<void> _sendVerificationEmail(StoredUser user, String token) async {
    try {
      await mailer.sendVerificationEmail(toEmail: user.email, token: token);
    } catch (e) {
      stderr.writeln(
          '[luma] could not send verification email to ${user.email}: $e');
    }
  }

  static String? _nullIfBlank(String? raw) {
    final trimmed = raw?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  static String? _normalizeEmail(Object? raw) {
    if (raw is! String) return null;
    final email = raw.trim().toLowerCase();
    if (email.length > 254 || !emailPattern.hasMatch(email)) return null;
    return email;
  }

  static Uint8List? _decodeB64(Object? raw,
      {required int minLen, required int maxLen}) {
    if (raw is! String || raw.length > 512) return null;
    try {
      final bytes = base64Decode(raw);
      if (bytes.length < minLen || bytes.length > maxLen) return null;
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> _readJson(Request request) async {
    final declared = request.contentLength ?? -1;
    if (declared > _maxJsonBody) {
      throw const FormatException('body too large');
    }
    // Enforce the cap while streaming, not after: a chunked request has no
    // Content-Length, so checking only the fully-buffered string would let a
    // client stream an arbitrarily large body into RAM first.
    Future<String> readCapped() async {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in request.read()) {
        builder.add(chunk);
        if (builder.length > _maxJsonBody) {
          throw const FormatException('body too large');
        }
      }
      return utf8.decode(builder.takeBytes());
    }

    final body = await readCapped().timeout(const Duration(seconds: 15),
        onTimeout: () => throw const FormatException('body read timed out'));
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('expected JSON object');
    }
    return decoded;
  }

}

/// One node of the /admin/website page tree: a path segment that either is
/// an actual page ([pagePath] set), a folder grouping deeper pages
/// ([children] non-empty), or both — e.g. `wiki/simply-cozy` existing
/// alongside `wiki/simply-cozy/sub-page`.
class _WikiTreeNode {
  final Map<String, _WikiTreeNode> children = {};
  String? pagePath;
  /// Set when no page exists at this path, but some other page links to it.
  String? phantomPath;
}

/// Result type for [Api._parseSharedEventBody]: either a validated set of
/// fields or a single validation error to surface to the client.
class _ParsedSharedEvent {
  const _ParsedSharedEvent({
    required this.title,
    required this.description,
    required this.location,
    required this.startMs,
    required this.endMs,
    required this.allDay,
    required this.color,
    required this.recurrence,
    required this.recurrenceEndMs,
    required this.reminderMinutes,
    required this.visibility,
    required this.visibleMemberUserIds,
  });

  final String title;
  final String? description;
  final String? location;
  final int startMs;
  final int endMs;
  final bool allDay;
  final int color;
  final String recurrence;
  final int? recurrenceEndMs;
  final int? reminderMinutes;
  final String visibility;
  final List<String> visibleMemberUserIds;
}

class _ParseError {
  const _ParseError(this.code, this.message);
  final String code;
  final String message;
}
