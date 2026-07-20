import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../../../app/widgets.dart';
import '../../../../sync/sync_scope.dart';
import '../_shared/windows_webview.dart';
import '../secure_chat/secure_chat_scope.dart';

/// Subway Builder is a self-contained HTML5/canvas transit-simulation game
/// (bundled as `assets/subway_builder/index.html`) rather than a native Dart
/// rewrite, so it runs inside an embedded WebView. The game autosaves its
/// state in the WebView's local storage.
///
/// Co-op rooms are hosted server-side (see server/lib/subway_store.dart),
/// so the game's own JS talks to the sync server directly using a session
/// token handed to it once at load — see `_bridgeAuthContext`. The one
/// thing that can't happen in JS is actually sending an invite: chat
/// messages are end-to-end encrypted client-side, so composing one has to
/// go through the real Chat plugin (`SecureChatScope`) here in Dart. That's
/// the only reason this page talks to the WebView's JS at all — every other
/// plugin in this codebase just loads HTML and shows a spinner.
class SubwayBuilderPage extends StatefulWidget {
  const SubwayBuilderPage({super.key});

  @override
  State<SubwayBuilderPage> createState() => _SubwayBuilderPageState();
}

class _SubwayBuilderPageState extends State<SubwayBuilderPage> {
  InAppWebViewController? _inAppController;
  StreamSubscription? _windowsMsgSub;
  bool _loading = true;

  // ---- Bridge call handlers (shared by both WebView backends) -----------

  Map<String, dynamic> _bridgeAuthContext() {
    final sync = SyncScope.of(context);
    return {
      'signedIn': sync.signedIn,
      'token': sync.authToken,
      'serverUrl': sync.serverUrl,
      'email': sync.email,
    };
  }

  List<Map<String, dynamic>> _bridgeChatContacts() {
    final chat = SecureChatScope.of(context);
    return chat.conversations
        .map((c) => {
              'conversationId': c.id,
              'peerUserId': c.peerUserId,
              'peerEmail': c.peerEmail,
              'ready': c.peerReady,
            })
        .toList();
  }

  Future<Map<String, dynamic>> _bridgeSendChatMessage(
      String conversationId, String text) async {
    final chat = SecureChatScope.of(context); // read before the await
    try {
      await chat.sendMessage(conversationId, text);
      return {'ok': true};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  Future<dynamic> _dispatchBridgeCall(String name, List<dynamic> args) async {
    switch (name) {
      case 'authContext':
        return _bridgeAuthContext();
      case 'chatContacts':
        return _bridgeChatContacts();
      case 'sendChatMessage':
        return _bridgeSendChatMessage(args[0] as String, args[1] as String);
      default:
        throw StateError('Unknown bridge call: $name');
    }
  }

  // ---- Windows wiring: webview_windows exposes a raw postMessage channel,
  // so request/response correlation (the `id` field) is handled by hand
  // here to match what flutter_inappwebview's addJavaScriptHandler gives
  // for free on the other platforms.
  void _onWindowsController(WebviewController controller) {
    _windowsMsgSub = controller.webMessage.listen((raw) async {
      Map<String, dynamic> msg;
      try {
        msg = raw is String
            ? jsonDecode(raw) as Map<String, dynamic>
            : Map<String, dynamic>.from(raw as Map);
      } catch (e) {
        return;
      }
      final id = msg['id'];
      final name = msg['name'] as String? ?? '';
      final callArgs = (msg['args'] as List?) ?? const [];
      try {
        final result = await _dispatchBridgeCall(name, callArgs);
        await controller.postWebMessage(jsonEncode({'id': id, 'result': result}));
      } catch (e) {
        await controller.postWebMessage(jsonEncode({'id': id, 'error': e.toString()}));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isLinux) {
      return const Center(
        child: LumaEmptyState(
          icon: Icons.videogame_asset_off_outlined,
          title: 'Not available on Linux',
          subtitle: 'Subway Builder requires an embedded WebView that is '
              'not yet supported on this platform.',
        ),
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: Platform.isWindows
              ? WindowsWebview(
                  fileUrl: Uri.file(
                    windowsAssetPath('assets/subway_builder/index.html'),
                  ).toString(),
                  onController: _onWindowsController,
                  onLoaded: () {
                    if (mounted) setState(() => _loading = false);
                  },
                )
              : InAppWebView(
                  initialFile: 'assets/subway_builder/index.html',
                  initialSettings: InAppWebViewSettings(
                    transparentBackground: true,
                    supportZoom: false,
                    disableHorizontalScroll: false,
                    disableVerticalScroll: false,
                  ),
                  onWebViewCreated: (controller) {
                    _inAppController = controller;
                    controller.addJavaScriptHandler(
                      handlerName: 'luma_bridge',
                      callback: (args) async {
                        final name = args[0] as String;
                        final callArgs =
                            (args.length > 1 ? args[1] : const []) as List;
                        return await _dispatchBridgeCall(name, callArgs);
                      },
                    );
                  },
                  onLoadStop: (controller, url) {
                    if (mounted) setState(() => _loading = false);
                  },
                ),
        ),
        if (_loading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  @override
  void dispose() {
    _windowsMsgSub?.cancel();
    _inAppController?.dispose();
    super.dispose();
  }
}
