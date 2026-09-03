import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/widgets.dart';
import '../sync/sync_api.dart';
import '../sync/sync_service.dart';
import '../theme/luma_theme.dart';

/// The published privacy policy and terms of service — linked wherever
/// someone is about to hand over an email address.
const _kPrivacyPolicyUrl = 'https://wiki.luma-app.cc/privacy';
const _kTermsOfServiceUrl = 'https://wiki.luma-app.cc/terms';

/// Shows the sign-in screen. Used from Settings, from the server-only plugin
/// gate, and as the app-wide first-run prompt (see `maybePromptAccountSetup`
/// in main.dart).
///
/// Resolves `true` when it closed because a sign-in, registration, or local
/// account setup actually completed; `false` for every other way it can close
/// (Cancel, tapping outside, back button). The first-run prompt uses that to
/// tell "the user set something up" apart from "the user dismissed this"
/// without inspecting sync state, which would conflate cancelling with a
/// pending-approval account.
Future<bool> showLoginScreen(
  BuildContext context,
  SyncService sync, {
  int initialMode = 1,
}) async {
  final completed = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Sign in',
    barrierColor: Colors.black.withValues(alpha: 0.62),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => LoginPage(sync: sync, initialMode: initialMode),
    transitionBuilder: (context, animation, _, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.03), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  );
  return completed ?? false;
}

/// Which panel the right-hand side is showing.
enum _Step {
  /// Provider buttons plus the email/password form.
  credentials,

  /// Waiting for the user to finish in their browser.
  browser,

  /// A provider vouched for an address; now the passphrase that actually
  /// decrypts the data.
  passphrase,

  /// Account created, but it still has to be approved.
  pending,
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.sync,
    this.initialMode = 1,
    this.providerLookup,
  });

  final SyncService sync;

  /// 0 = sign in, 1 = create account.
  final int initialMode;

  /// Which provider buttons to offer. Defaults to asking the server; widget
  /// tests substitute their own, since flutter_test refuses real requests
  /// and the answer would always come back empty.
  @visibleForTesting
  final Future<List<OAuthProviderInfo>> Function(String serverUrl)?
      providerLookup;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  /// Below this the brand panel is dropped and the form goes full-bleed.
  static const _wideBreakpoint = 900.0;

  // There is only one luma sync server; its address is a fixed constant, not
  // something read from (possibly stale, device-specific) saved state. It
  // stays editable for self-hosters.
  final _server = TextEditingController(text: kDefaultSyncServerUrl);
  late final _email = TextEditingController(text: widget.sync.email ?? '');
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _passphrase = TextEditingController();
  final _passphraseConfirm = TextEditingController();

  late int _mode = widget.initialMode;

  /// true = cloud account (a server, sign in / create tabs, provider
  /// buttons). false = local-only, serverless identity for P2P pairing.
  bool _cloudMode = true;

  /// Shown only when the operator configured them; empty is the normal
  /// answer for a self-hosted server and simply hides the buttons.
  List<OAuthProviderInfo> _providers = const [];
  bool _serverFieldVisible = false;

  _Step _step = _Step.credentials;
  OAuthSignInHandle? _handle;
  OAuthPollResult? _identity;
  String? _pendingProviderId;

  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  @override
  void dispose() {
    _handle?.close();
    _server.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _passphrase.dispose();
    _passphraseConfirm.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    final lookup = widget.providerLookup ??
        (url) => widget.sync.availableOAuthProviders(url);
    final found = await lookup(_server.text);
    if (!mounted) return;
    setState(() => _providers = found);
  }

  // ---- Email + password ---------------------------------------------------

  Future<void> _submitCredentials() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    final creating = !_cloudMode || _mode == 1;
    if (creating && _password.text.length < 10) {
      setState(() => _error =
          'Use at least 10 characters — this password protects your '
          'encrypted data.');
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    if (creating && _password.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    await _run(() async {
      if (!_cloudMode) {
        await widget.sync
            .setLocalAccount(email: email, password: _password.text);
        _finish();
        return;
      }
      final urlError = SyncApi.validateServerUrl(_server.text);
      if (urlError != null) {
        setState(() {
          _error = urlError;
          _serverFieldVisible = true;
        });
        return;
      }
      if (_mode == 0) {
        await widget.sync.signIn(
          serverUrl: _server.text,
          email: email,
          password: _password.text,
        );
        _finish();
        return;
      }
      final pendingMessage = await widget.sync.register(
        serverUrl: _server.text,
        email: email,
        password: _password.text,
      );
      if (pendingMessage == null) {
        _finish();
        return;
      }
      // The account exists but is not approved yet, so nothing is signed in.
      setState(() {
        _step = _Step.pending;
        _info = pendingMessage;
      });
    });
  }

  // ---- Google / GitHub ----------------------------------------------------

  Future<void> _startProvider(OAuthProviderInfo provider) async {
    final urlError = SyncApi.validateServerUrl(_server.text);
    if (urlError != null) {
      setState(() {
        _error = urlError;
        _serverFieldVisible = true;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
      _pendingProviderId = provider.id;
    });
    OAuthSignInHandle? handle;
    try {
      handle = await widget.sync.startOAuthSignIn(
        serverUrl: _server.text,
        providerId: provider.id,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pendingProviderId = null;
        _error = _describe(e);
      });
      return;
    }
    if (!mounted) {
      handle.close();
      return;
    }
    _handle?.close();
    setState(() {
      _handle = handle;
      _busy = false;
      _step = _Step.browser;
    });
    await _openAuthUrl();

    // The poll runs for minutes against a server that can go away mid-flow,
    // so a thrown request is an ordinary outcome here, not a crash.
    OAuthPollResult result;
    try {
      result = await widget.sync.waitForOAuthIdentity(handle);
    } catch (e) {
      result = OAuthPollResult(status: 'error', message: _describe(e));
    }
    if (!mounted || _handle != handle) return;
    if (!result.isReady) {
      handle.close();
      setState(() {
        _handle = null;
        _step = _Step.credentials;
        _pendingProviderId = null;
        _error = result.message ?? 'Sign-in did not complete.';
      });
      return;
    }
    setState(() {
      _identity = result;
      _step = _Step.passphrase;
      // An existing account is unlocked with the passphrase it already has,
      // so there is nothing to confirm against.
      _passphrase.clear();
      _passphraseConfirm.clear();
    });
  }

  Future<void> _openAuthUrl() async {
    final handle = _handle;
    if (handle == null) return;
    final opened = await launchUrl(
      Uri.parse(handle.authUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      setState(() => _error =
          'Could not open your browser. Copy the link below and open it '
          'yourself.');
    }
  }

  Future<void> _submitPassphrase() async {
    final handle = _handle;
    final identity = _identity;
    if (handle == null || identity == null) return;
    final isNew = !identity.existingAccount;

    if (_passphrase.text.isEmpty) {
      setState(() => _error = isNew
          ? 'Choose a passphrase.'
          : 'Enter your luma passphrase to unlock your data.');
      return;
    }
    if (isNew && _passphrase.text.length < 10) {
      setState(() => _error =
          'Use at least 10 characters — this passphrase is what encrypts '
          'your data.');
      return;
    }
    if (isNew && _passphrase.text != _passphraseConfirm.text) {
      setState(() => _error = 'Passphrases do not match.');
      return;
    }

    await _run(() async {
      final pendingMessage = await widget.sync.completeOAuthSignIn(
        handle: handle,
        identity: identity,
        passphrase: _passphrase.text,
      );
      if (pendingMessage == null) {
        _handle = null;
        _finish();
        return;
      }
      _handle = null;
      setState(() {
        _step = _Step.pending;
        _info = pendingMessage;
      });
    });
  }

  void _cancelProviderFlow() {
    _handle?.close();
    setState(() {
      _handle = null;
      _identity = null;
      _pendingProviderId = null;
      _step = _Step.credentials;
      _error = null;
      _info = null;
    });
  }

  // ---- Plumbing -----------------------------------------------------------

  /// Runs [action] with the busy flag set and any thrown error surfaced,
  /// which is the same shape every submit in here needs.
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = _describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _describe(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  void _finish() {
    if (mounted) Navigator.of(context).pop(true);
  }

  void _close() {
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= _wideBreakpoint;
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: wide ? 940 : 460,
                    maxHeight: 680,
                  ),
                  child: Material(
                    color: luma.surface,
                    elevation: 24,
                    shadowColor: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: luma.border),
                      ),
                      child: Row(
                        children: [
                          if (wide)
                            const SizedBox(width: 380, child: _BrandPanel()),
                          Expanded(child: _buildFormPane(wide)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormPane(bool wide) {
    final luma = context.luma;
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(wide ? 40 : 26, 26, wide ? 40 : 26, 26),
          child: SingleChildScrollView(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, ?current],
                ),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    _Step.credentials => _credentialsPanel(wide),
                    _Step.browser => _browserPanel(),
                    _Step.passphrase => _passphrasePanel(),
                    _Step.pending => _pendingPanel(),
                  },
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            onPressed: _busy ? null : _close,
            icon: Icon(Icons.close_rounded, size: 20, color: luma.textMuted),
            tooltip: 'Close',
            splashRadius: 18,
          ),
        ),
      ],
    );
  }

  // ---- Panel: credentials -------------------------------------------------

  Widget _credentialsPanel(bool wide) {
    final creating = !_cloudMode || _mode == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!wide) ...[
          const _CompactBrandHeader(),
          const SizedBox(height: 20),
        ],
        _Heading(
          title: _cloudMode
              ? (_mode == 0 ? 'Welcome back' : 'Create your account')
              : 'Set up local-only sync',
          subtitle: _cloudMode
              ? (_mode == 0
                  ? 'Sign in to pick up where your other devices left off.'
                  : 'One account, every device — encrypted before it leaves '
                      'this one.')
              : 'No server, no account. Devices pair directly over your '
                  'own network.',
        ),
        const SizedBox(height: 20),

        if (_cloudMode) ...[
          LumaSegmentedTabs(
            tabs: const ['Sign in', 'Create account'],
            selectedIndex: _mode,
            onSelect: (i) => setState(() {
              _mode = i;
              _error = null;
              _info = null;
            }),
          ),
          const SizedBox(height: 20),
          if (_providers.isNotEmpty) ...[
            for (final provider in _providers) ...[
              _ProviderButton(
                provider: provider,
                busy: _busy && _pendingProviderId == provider.id,
                enabled: !_busy,
                onTap: () => _startProvider(provider),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            const _OrDivider(),
            const SizedBox(height: 18),
          ],
        ],

        _LoginField(
          controller: _email,
          label: 'Email',
          icon: Icons.alternate_email_rounded,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 12),
        _LoginField(
          controller: _password,
          label: 'Password',
          icon: Icons.lock_outline_rounded,
          enabled: !_busy,
          obscure: true,
          autofillHints: [
            creating ? AutofillHints.newPassword : AutofillHints.password,
          ],
          onSubmitted: creating ? null : (_) => _submitCredentials(),
        ),
        if (creating) ...[
          const SizedBox(height: 12),
          _LoginField(
            controller: _confirm,
            label: 'Confirm password',
            icon: Icons.lock_reset_rounded,
            enabled: !_busy,
            obscure: true,
            onSubmitted: (_) => _submitCredentials(),
          ),
        ],

        if (_serverFieldVisible) ...[
          const SizedBox(height: 12),
          _LoginField(
            controller: _server,
            label: 'Server address',
            icon: Icons.dns_rounded,
            enabled: !_busy && _cloudMode,
            onChanged: (_) => _loadProviders(),
          ),
        ],

        const SizedBox(height: 18),
        LumaPrimaryButton(
          label: _cloudMode
              ? (_mode == 0 ? 'Sign in' : 'Create account')
              : 'Set up',
          expand: true,
          loading: _busy && _pendingProviderId == null,
          onTap: _busy ? null : _submitCredentials,
        ),

        _MessageBlock(error: _error, info: _info),

        const SizedBox(height: 16),
        if (creating) const _KeyWarning(),
        if (creating) const SizedBox(height: 12),

        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 6,
          children: [
            _TinyLink(
              label: _cloudMode
                  ? 'Use local-only sync'
                  : 'Use a luma account instead',
              icon: _cloudMode ? Icons.wifi_rounded : Icons.cloud_rounded,
              onTap: _busy
                  ? null
                  : () => setState(() {
                        _cloudMode = !_cloudMode;
                        _error = null;
                        _info = null;
                      }),
            ),
            if (_cloudMode && !_serverFieldVisible)
              _TinyLink(
                label: 'Self-hosted server',
                icon: Icons.dns_rounded,
                onTap: _busy
                    ? null
                    : () => setState(() => _serverFieldVisible = true),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const _LegalLinks(),
      ],
    );
  }

  // ---- Panel: waiting on the browser --------------------------------------

  Widget _browserPanel() {
    final luma = context.luma;
    final provider = _providerById(_pendingProviderId);
    final name = provider?.name ?? 'your provider';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        Center(
          child: _ProviderGlyph(
            providerId: _pendingProviderId ?? '',
            size: 44,
            padded: true,
          ),
        ),
        const SizedBox(height: 22),
        _Heading(
          title: 'Continue in your browser',
          subtitle: 'We opened $name in your browser. Finish signing in '
              'there, then come back — this page updates on its own.',
          centered: true,
        ),
        const SizedBox(height: 24),
        Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation(luma.accent),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _MessageBlock(error: _error, info: _info),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LumaGhostButton(
              label: 'Reopen the page',
              icon: Icons.open_in_new_rounded,
              onTap: _openAuthUrl,
            ),
            const SizedBox(width: 10),
            LumaGhostButton(
              label: 'Copy link',
              icon: Icons.link_rounded,
              onTap: () async {
                final url = _handle?.authUrl;
                if (url == null) return;
                await Clipboard.setData(ClipboardData(text: url));
                if (mounted) {
                  setState(() => _info = 'Link copied to your clipboard.');
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        Center(
          child: _TinyLink(
            label: 'Cancel and go back',
            icon: Icons.arrow_back_rounded,
            onTap: _cancelProviderFlow,
          ),
        ),
      ],
    );
  }

  // ---- Panel: the passphrase ----------------------------------------------

  Widget _passphrasePanel() {
    final identity = _identity;
    if (identity == null) return const SizedBox.shrink();
    final isNew = !identity.existingAccount;
    final provider = _providerById(_pendingProviderId);
    final providerName = provider?.name ?? 'your provider';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        _IdentityChip(
          providerId: _pendingProviderId ?? '',
          email: identity.email ?? '',
          displayName: identity.displayName,
        ),
        const SizedBox(height: 20),
        _Heading(
          title: isNew ? 'One last thing' : 'Unlock your data',
          subtitle: isNew
              ? '$providerName proved who you are, but it cannot unlock your '
                  'data — nothing can except a passphrase only you know. '
                  'Choose one now; you will need it on every device.'
              : 'This account already exists, so $providerName signed you '
                  'straight into it. Enter the luma passphrase you set up — '
                  'the same one you would type to sign in with a password.',
        ),
        const SizedBox(height: 20),
        _LoginField(
          controller: _passphrase,
          label: isNew ? 'Choose a passphrase' : 'Your luma passphrase',
          icon: Icons.key_rounded,
          enabled: !_busy,
          obscure: true,
          autofocus: true,
          autofillHints: [
            isNew ? AutofillHints.newPassword : AutofillHints.password,
          ],
          onSubmitted: isNew ? null : (_) => _submitPassphrase(),
        ),
        if (isNew) ...[
          const SizedBox(height: 10),
          _StrengthMeter(controller: _passphrase),
          const SizedBox(height: 12),
          _LoginField(
            controller: _passphraseConfirm,
            label: 'Confirm passphrase',
            icon: Icons.lock_reset_rounded,
            enabled: !_busy,
            obscure: true,
            onSubmitted: (_) => _submitPassphrase(),
          ),
        ],
        const SizedBox(height: 18),
        LumaPrimaryButton(
          label: isNew ? 'Create account' : 'Unlock and sign in',
          expand: true,
          loading: _busy,
          onTap: _busy ? null : _submitPassphrase,
        ),
        _MessageBlock(error: _error, info: _info),
        const SizedBox(height: 16),
        if (isNew) const _KeyWarning(),
        const SizedBox(height: 12),
        Center(
          child: _TinyLink(
            label: 'Use a different account',
            icon: Icons.arrow_back_rounded,
            onTap: _busy ? null : _cancelProviderFlow,
          ),
        ),
      ],
    );
  }

  // ---- Panel: waiting for approval ----------------------------------------

  Widget _pendingPanel() {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 28),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: luma.accentSubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mark_email_read_rounded,
                size: 30, color: luma.accent),
          ),
        ),
        const SizedBox(height: 22),
        _Heading(
          title: 'Almost there',
          subtitle: _info ??
              'Your account has to be approved before you can sign in.',
          centered: true,
        ),
        const SizedBox(height: 24),
        LumaPrimaryButton(
          label: 'Back to sign in',
          expand: true,
          onTap: () => setState(() {
            _step = _Step.credentials;
            _mode = 0;
            _identity = null;
            _pendingProviderId = null;
            _info = null;
            _error = null;
          }),
        ),
        const SizedBox(height: 10),
        Center(
          child: _TinyLink(
            label: 'Close',
            icon: Icons.close_rounded,
            onTap: _close,
          ),
        ),
      ],
    );
  }

  OAuthProviderInfo? _providerById(String? id) {
    for (final provider in _providers) {
      if (provider.id == id) return provider;
    }
    return null;
  }
}

// ---- Brand panel ------------------------------------------------------------

/// The left half on wide screens: the accent slab that makes this read as a
/// front door rather than a settings dialog.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final on = luma.onAccent;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [luma.accentHover, luma.accent],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Two soft discs bleeding off the edges, so the slab has depth
          // without needing an image.
          Positioned(
            top: -70,
            right: -60,
            child: _Disc(size: 220, color: on.withValues(alpha: 0.07)),
          ),
          Positioned(
            bottom: -90,
            left: -70,
            child: _Disc(size: 260, color: on.withValues(alpha: 0.05)),
          ),
          Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/icon.png',
                        width: 34,
                        height: 34,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'luma',
                      style: TextStyle(
                        color: on,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'Everything you keep here,\non every device you use.',
                  style: TextStyle(
                    color: on,
                    fontSize: 25,
                    height: 1.28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 22),
                const _BrandPoint(
                  icon: Icons.lock_rounded,
                  text: 'Encrypted on this device before it ever leaves it.',
                ),
                const _BrandPoint(
                  icon: Icons.tune_rounded,
                  text: 'Nothing syncs until you switch it on, per feature.',
                ),
                const _BrandPoint(
                  icon: Icons.wifi_rounded,
                  text: 'Or skip the server entirely and pair over your '
                      'own network.',
                ),
                const Spacer(),
                Text(
                  'Not even we can read your data.',
                  style: TextStyle(
                    color: on.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _BrandPoint extends StatelessWidget {
  const _BrandPoint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final on = context.luma.onAccent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: on.withValues(alpha: 0.85)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: on.withValues(alpha: 0.85),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the brand panel collapses to on a phone.
class _CompactBrandHeader extends StatelessWidget {
  const _CompactBrandHeader();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.asset('assets/images/icon.png', width: 30, height: 30),
        ),
        const SizedBox(width: 10),
        Text(
          'luma',
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

// ---- Provider buttons -------------------------------------------------------

class _ProviderButton extends StatefulWidget {
  const _ProviderButton({
    required this.provider,
    required this.onTap,
    required this.busy,
    required this.enabled,
  });

  final OAuthProviderInfo provider;
  final VoidCallback onTap;
  final bool busy;
  final bool enabled;

  @override
  State<_ProviderButton> createState() => _ProviderButtonState();
}

class _ProviderButtonState extends State<_ProviderButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final active = widget.enabled && !widget.busy;
    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: active ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 46,
          decoration: BoxDecoration(
            color: _hovering && active ? luma.surfaceHover : luma.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovering && active ? luma.accent : luma.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.busy)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation(luma.accent),
                  ),
                )
              else
                _ProviderGlyph(providerId: widget.provider.id, size: 18),
              const SizedBox(width: 12),
              Text(
                'Continue with ${widget.provider.name}',
                style: TextStyle(
                  color: active ? luma.textPrimary : luma.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The provider's own mark. Both are the vendor-published sign-in marks —
/// using anything else on these buttons is what their brand guidelines
/// forbid. GitHub's is monochrome, so it takes the current text color;
/// Google's four-colour G must not be recoloured.
class _ProviderGlyph extends StatelessWidget {
  const _ProviderGlyph({
    required this.providerId,
    required this.size,
    this.padded = false,
  });

  final String providerId;
  final double size;

  /// Wraps the mark in a soft rounded square, for the larger standalone use
  /// on the "continue in your browser" panel.
  final bool padded;

  static const _googleSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>''';

  static const _githubPath =
      'M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 '
      '0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-'
      '1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 '
      '2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59'
      '.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-'
      '.27s1.36.09 2 .27c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.'
      '56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 '
      '1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-'
      '3.58-8-8-8z';

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final Widget glyph = switch (providerId) {
      'google' => SvgPicture.string(_googleSvg, width: size, height: size),
      'github' => SvgPicture.string(
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">'
          '<path fill="${_hex(luma.textPrimary)}" d="$_githubPath"/></svg>',
          width: size,
          height: size,
        ),
      _ => Icon(Icons.account_circle_rounded,
          size: size, color: luma.textSecondary),
    };
    if (!padded) return glyph;
    return Container(
      padding: EdgeInsets.all(size * 0.42),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(size * 0.42),
        border: Border.all(color: luma.border),
      ),
      child: glyph,
    );
  }

  static String _hex(Color color) =>
      '#${((color.toARGB32()) & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

/// The verified address, shown above the passphrase step so it is obvious
/// which account is about to be unlocked.
class _IdentityChip extends StatelessWidget {
  const _IdentityChip({
    required this.providerId,
    required this.email,
    this.displayName,
  });

  final String providerId;
  final String email;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        children: [
          _ProviderGlyph(providerId: providerId, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (displayName != null && displayName!.isNotEmpty)
                  Text(
                    displayName!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.verified_rounded, size: 18, color: luma.success),
        ],
      ),
    );
  }
}

// ---- Small pieces -----------------------------------------------------------

class _Heading extends StatelessWidget {
  const _Heading({
    required this.title,
    required this.subtitle,
    this.centered = false,
  });

  final String title;
  final String subtitle;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: luma.textMuted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _LoginField extends StatefulWidget {
  const _LoginField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.enabled,
    this.obscure = false,
    this.autofocus = false,
    this.keyboardType,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;
  final bool obscure;
  final bool autofocus;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  State<_LoginField> createState() => _LoginFieldState();
}

class _LoginFieldState extends State<_LoginField> {
  late bool _hidden = widget.obscure;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: focused ? luma.accent : luma.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(
            widget.icon,
            size: 18,
            color: focused ? luma.accent : luma.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              obscureText: _hidden,
              keyboardType: widget.keyboardType,
              autofillHints: widget.autofillHints,
              onSubmitted: widget.onSubmitted,
              onChanged: widget.onChanged,
              style: TextStyle(color: luma.textPrimary, fontSize: 14),
              cursorColor: luma.accent,
              decoration: InputDecoration(
                labelText: widget.label,
                labelStyle: TextStyle(color: luma.textMuted, fontSize: 14),
                floatingLabelStyle: TextStyle(
                  color: focused ? luma.accent : luma.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          if (widget.obscure)
            IconButton(
              onPressed: () => setState(() => _hidden = !_hidden),
              icon: Icon(
                _hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
                color: luma.textMuted,
              ),
              tooltip: _hidden ? 'Show' : 'Hide',
              splashRadius: 18,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}

/// A four-step strength read-out for a passphrase being chosen. Deliberately
/// crude — it exists to nudge length, which is the only thing that meaningfully
/// helps against an offline attack on a PBKDF2-derived key.
class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.controller});

  final TextEditingController controller;

  static const _labels = ['Too short', 'Weak', 'Good', 'Strong'];

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final value = controller.text;
        final score = _score(value);
        final color = switch (score) {
          <= 0 => luma.danger,
          1 => Colors.orange.shade400,
          2 => luma.accent,
          _ => luma.success,
        };
        return Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  decoration: BoxDecoration(
                    color: value.isEmpty
                        ? luma.border
                        : (i <= score ? color : luma.border),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i < 3) const SizedBox(width: 5),
            ],
            const SizedBox(width: 10),
            SizedBox(
              width: 62,
              child: Text(
                value.isEmpty ? '' : _labels[score.clamp(0, 3)],
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: value.isEmpty ? luma.textMuted : color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static int _score(String value) {
    if (value.length < 10) return 0;
    var score = 1;
    if (value.length >= 16) score++;
    if (value.length >= 24 ||
        (RegExp(r'\d').hasMatch(value) &&
            RegExp(r'[^A-Za-z0-9]').hasMatch(value))) {
      score++;
    }
    return score;
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Expanded(child: Divider(color: luma.border, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or with your email',
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Expanded(child: Divider(color: luma.border, height: 1)),
      ],
    );
  }
}

/// The one thing about this account model that genuinely cannot be undone,
/// so it gets said plainly rather than buried.
class _KeyWarning extends StatelessWidget {
  const _KeyWarning();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: luma.accentSubtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 16, color: luma.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Everything is encrypted with this before it leaves the device. '
              'If you forget it, your synced data cannot be recovered — there '
              'is no reset.',
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The error/info slot every panel shares, so a message never shifts the
/// layout differently depending on which step raised it.
class _MessageBlock extends StatelessWidget {
  const _MessageBlock({this.error, this.info});

  final String? error;
  final String? info;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final message = error ?? info;
    if (message == null) return const SizedBox(height: 16);
    final isError = error != null;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 16,
            color: isError ? luma.danger : luma.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? luma.danger : luma.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyLink extends StatelessWidget {
  const _TinyLink({required this.label, required this.icon, this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final enabled = onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14, color: enabled ? luma.accent : luma.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: enabled ? luma.accent : luma.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    TextStyle style() => TextStyle(color: luma.textMuted, fontSize: 11);
    Widget link(String label, String url) => MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => launchUrl(Uri.parse(url),
                mode: LaunchMode.externalApplication),
            child: Text(
              label,
              style: style().copyWith(
                color: luma.textSecondary,
                decoration: TextDecoration.underline,
                decorationColor: luma.textMuted,
              ),
            ),
          ),
        );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Text('By continuing you agree to our', style: style()),
        link('Terms of service', _kTermsOfServiceUrl),
        Text('and', style: style()),
        link('Privacy policy', _kPrivacyPolicyUrl),
      ],
    );
  }
}
