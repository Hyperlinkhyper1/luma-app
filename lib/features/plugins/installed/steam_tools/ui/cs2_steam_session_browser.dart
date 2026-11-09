import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:webview_windows/webview_windows.dart' as win;

import '../../../../../l10n/app_localizations.dart';
import '../../_shared/windows_webview.dart';
import '../cs2_inventory_api.dart';
import '../cs2_steam_session.dart';

typedef _JsExec = Future<Object?> Function(String script);

const _communityHome = 'https://steamcommunity.com/';
const _idleUrl = 'about:blank';

/// The URL the sign-in window opens on.
const cs2SteamLoginUrl = 'https://steamcommunity.com/login/home/?goto=';

/// Where the page is and who Steam thinks is signed in. Every Steam
/// Community page sets `g_steamID`: false signed out, the SteamID64 string
/// signed in. Undefined means the page has not got that far yet.
const _stateScript = '''
(function(){try{return JSON.stringify({
  ready: document.readyState === 'complete',
  host: location.host,
  id: (typeof g_steamID === 'undefined') ? null : (g_steamID ? String(g_steamID) : '')
});}catch(e){return '';}})()
''';

/// Parsed [_stateScript] output, or null when the page could not answer.
({bool ready, String host, String? id})? _parseState(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  try {
    final data = jsonDecode(raw);
    if (data is! Map) return null;
    final id = data['id'];
    return (
      ready: data['ready'] == true,
      host: data['host'] is String ? data['host'] as String : '',
      id: id is String ? id : null,
    );
  } catch (_) {
    return null;
  }
}

/// The signed-in SteamID64 the page reports, '' signed out, null not known.
String? _steamIdFrom(Object? raw) {
  final state = _parseState(raw);
  if (state == null || state.host != 'steamcommunity.com') return null;
  final id = state.id;
  if (id == null) return null;
  return RegExp(r'^\d{17}$').hasMatch(id) ? id : '';
}

bool get cs2SteamSessionSupported =>
    Platform.isWindows || Platform.isAndroid || Platform.isIOS ||
    Platform.isMacOS;

/// A one-pixel browser that holds the user's Steam session and serves
/// [Cs2SteamSession] requests through it. Mounted only once the user has
/// chosen to sign in; it shares the cookie store with the sign-in window.
class Cs2SteamSessionBrowser extends StatefulWidget {
  const Cs2SteamSessionBrowser({super.key, required this.onReady});

  /// Called with the session once the engine is up, and null on dispose.
  final void Function(Cs2SteamSession? session) onReady;

  @override
  State<Cs2SteamSessionBrowser> createState() => _Cs2SteamSessionBrowserState();
}

class _Cs2SteamSessionBrowserState extends State<Cs2SteamSessionBrowser>
    implements Cs2SteamSession {
  win.WebviewController? _windowsController;
  InAppWebViewController? _mobileController;
  Future<void> _queue = Future.value();
  bool _registered = false;
  int _token = 0;

  @override
  void dispose() {
    widget.onReady(null);
    super.dispose();
  }

  void _register() {
    if (_registered) return;
    _registered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady(this);
    });
  }

  _JsExec get _exec {
    final windows = _windowsController;
    if (windows != null) return (script) => windows.executeScript(script);
    final mobile = _mobileController;
    if (mobile != null) {
      return (script) => mobile.evaluateJavascript(source: script);
    }
    throw StateError('The Steam browser is not ready yet.');
  }

  Future<void> _navigate(String url) async {
    final windows = _windowsController;
    if (windows != null) {
      await windows.loadUrl(url);
      return;
    }
    await _mobileController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  /// Runs [task] after any earlier one: two requests sharing one browser
  /// would navigate out from under each other.
  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  void _park() => unawaited(_navigate(_idleUrl).catchError((_) {}));

  /// Loads the Community home page and waits for it to say who is signed
  /// in. Returns the SteamID64, or '' when signed out.
  Future<String> _openCommunity() async {
    await _navigate(_communityHome);
    final deadline = DateTime.now().add(const Duration(seconds: 25));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) break;
      try {
        final raw = await _exec(_stateScript);
        final state = _parseState(raw);
        if (state == null || !state.ready) continue;
        final id = _steamIdFrom(raw);
        if (id != null) return id;
      } catch (_) {
        // A script sent mid-navigation fails; keep polling.
      }
    }
    throw const Cs2InventoryException('Steam Community did not finish loading.');
  }

  @override
  Future<String?> signedInSteamId() => _serial(() async {
    try {
      final id = await _openCommunity();
      return id.isEmpty ? null : id;
    } finally {
      _park();
    }
  });

  @override
  Future<Cs2InventoryPage> load(Uri uri) => _serial(() async {
    if (uri.scheme != 'https' || uri.host != 'steamcommunity.com') {
      throw ArgumentError.value(uri, 'uri', 'Only Steam Community URLs');
    }
    try {
      await _openCommunity();
      return await _fetch(uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path);
    } finally {
      _park();
    }
  });

  /// Same-origin fetch from inside the page, so the session cookie goes
  /// with it and never leaves the browser. WebView2 does not await
  /// promises, so the result is parked on window and polled for.
  Future<Cs2InventoryPage> _fetch(String path, {String? method, String? body}) async {
    final slot = '__lumaSteam${++_token}';
    final init = {
      'credentials': 'include',
      'method': ?method,
      'body': ?body,
      if (body != null)
        'headers': {'Content-Type': 'application/x-www-form-urlencoded'},
    };
    await _exec('''
(function(){
  fetch(${jsonEncode(path)}, ${jsonEncode(init)})
    .then(function(r){ return r.text().then(function(t){
      window.$slot = JSON.stringify({s: r.status, b: t});
    }); })
    .catch(function(e){ window.$slot = JSON.stringify({s: 0, b: String(e)}); });
  return 1;
})()
''');
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) break;
      final raw = await _exec(
        "(function(){var v = window.$slot; if (v == null) return ''; delete window.$slot; return v;})()",
      );
      if (raw is! String || raw.isEmpty) continue;
      final data = jsonDecode(raw);
      final status = data is Map && data['s'] is int ? data['s'] as int : 0;
      if (status == 0) {
        throw const Cs2InventoryException('Could not reach Steam. Try again later.');
      }
      return Cs2InventoryPage(status, data['b'] is String ? data['b'] as String : '');
    }
    throw const Cs2InventoryException('Steam did not answer in time.');
  }

  @override
  Future<void> signOut() => _serial(() async {
    try {
      if ((await _openCommunity()).isNotEmpty) {
        final sessionId = await _exec(
          "(typeof g_sessionID === 'string') ? g_sessionID : ''",
        );
        if (sessionId is String && sessionId.isNotEmpty) {
          await _fetch(
            '/login/logout/',
            method: 'POST',
            body: 'sessionid=${Uri.encodeQueryComponent(sessionId)}',
          );
        }
      }
      final mobile = _mobileController;
      if (mobile != null) {
        final cookies = CookieManager.instance();
        for (final host in const [
          'https://steamcommunity.com',
          'https://login.steampowered.com',
          'https://store.steampowered.com',
        ]) {
          await cookies.deleteCookies(url: WebUri(host));
        }
      }
      if ((await _openCommunity()).isNotEmpty) {
        // webview_windows can only clear every cookie at once. Signing out
        // has to actually sign out, so other embedded sites lose theirs too.
        await _windowsController?.clearCookies();
      }
    } finally {
      _park();
    }
  });

  @override
  Widget build(BuildContext context) {
    if (!cs2SteamSessionSupported) return const SizedBox.shrink();
    // Painted but tiny: an unpainted WebView2 never starts.
    return SizedBox(
      width: 1,
      height: 1,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: ClipRect(
            child: Platform.isWindows
                ? WindowsWebview(
                    fileUrl: _idleUrl,
                    onController: (controller) {
                      _windowsController = controller;
                      _register();
                    },
                  )
                : InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(_idleUrl)),
                    initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
                    onWebViewCreated: (controller) {
                      _mobileController = controller;
                      _register();
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

/// Opens Steam's own sign-in page and returns the SteamID64 of the account
/// the user signed in to, or null if they closed the window first.
Future<String?> showCs2SteamSignIn(BuildContext context) => showDialog<String>(
  context: context,
  builder: (_) => const _SteamSignInDialog(),
);

class _SteamSignInDialog extends StatefulWidget {
  const _SteamSignInDialog();

  @override
  State<_SteamSignInDialog> createState() => _SteamSignInDialogState();
}

class _SteamSignInDialogState extends State<_SteamSignInDialog> {
  _JsExec? _exec;
  Timer? _poll;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _check());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final exec = _exec;
    if (exec == null || _done) return;
    try {
      final id = _steamIdFrom(await exec(_stateScript));
      if (id == null || id.isEmpty || _done || !mounted) return;
      _done = true;
      Navigator.of(context).pop(id);
    } catch (_) {
      // Mid-navigation; the next tick tries again.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: size.width < 560 ? size.width : 520,
        height: size.height < 780 ? size.height * 0.9 : 700,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.steamCs2SignInWindowNote,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Platform.isWindows
                  ? WindowsWebview(
                      fileUrl: cs2SteamLoginUrl,
                      onController: (controller) =>
                          _exec = (script) => controller.executeScript(script),
                    )
                  : InAppWebView(
                      initialUrlRequest: URLRequest(url: WebUri(cs2SteamLoginUrl)),
                      initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
                      onWebViewCreated: (controller) => _exec =
                          (script) => controller.evaluateJavascript(source: script),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
