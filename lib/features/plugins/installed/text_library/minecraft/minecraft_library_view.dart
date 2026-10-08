import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../../app/window_controls.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../settings/settings_scope.dart';
import '../../../../../sync/sync_scope.dart';
import '../../../../converter/schematic/textures/texture_downloader.dart';
import '../../_shared/native_webview.dart';
import '../../_shared/scene_localizations.dart';
import '../../_shared/windows_webview.dart' show windowsAssetPath;
import '../text_library_models.dart';
import '../text_library_repository.dart';
import '../text_library_scope.dart';
import 'book_review_api.dart';
import 'classroom_bridge.dart';
import 'mail_store.dart';
import 'market_store.dart';
import 'player_skin.dart';
import 'scene_protocol.dart';
import 'vanilla_assets.dart';

/// The Minecraft library: a three.js hall where every subject is a bookcase.
///
/// Like the airport, it runs in a real WebView2 window on Windows and in the
/// system WebView on Android. Nothing Flutter draws can sit on top of the
/// Windows window, so every control — the book editor included — lives in
/// the page, which sends commands back here to be written through the
/// repository.
class MinecraftLibraryView extends StatefulWidget {
  const MinecraftLibraryView({super.key});

  @override
  State<MinecraftLibraryView> createState() => _MinecraftLibraryViewState();
}

class _MinecraftLibraryViewState extends State<MinecraftLibraryView>
    with WidgetsBindingObserver {
  static const _asset = 'assets/text_library/scene/index.html';

  NativeWebviewController? _windows;
  InAppWebViewController? _android;
  StreamSubscription<LibrarySnapshot>? _library;
  LibrarySnapshot? _latest;
  late TextLibraryRepository _repository;
  late final ClassroomBridge _classroom = ClassroomBridge(send: _send);
  Timer? _timeout;
  Timer? _windowCheck;
  bool _ready = false;
  bool _tickerEnabled = true;
  bool _foreground = true;
  bool _onScreen = true;
  bool _downloading = false;
  String? _error;
  String? _sceneLanguage;
  int _generation = 0;

  bool get _showing => _tickerEnabled && _foreground && _onScreen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _armTimeout();
    // Closing luma on the desktop only hides it to the tray, which the
    // lifecycle never reports, and the hall's post and trader must not keep
    // counting time nobody spends in it.
    if (Platform.isWindows || Platform.isLinux) {
      _windowCheck = Timer.periodic(
        const Duration(seconds: 2),
        (_) => unawaited(_checkWindow()),
      );
    }
  }

  Future<void> _checkWindow() async {
    final onScreen = await windowOnScreen();
    if (!mounted || onScreen == _onScreen) return;
    _onScreen = onScreen;
    _sendVisibility();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (_sceneLanguage != language) {
      _sceneLanguage = language;
      if (_ready) {
        _send({
          'type': 'strings',
          'language': language,
          'strings': sceneStrings(L.of(context)),
          'sceneKeys': sceneKeyStrings(L.of(context), 'text_library/scene'),
          'sourceStrings':
              sceneSourceStrings(L.of(context), 'text_library/scene'),
        });
      }
    }
    final repository = TextLibraryScope.of(context);
    if (_library == null) {
      _repository = repository;
      _library = repository.watchLibrary().listen((snapshot) {
        _latest = snapshot;
        _sendLibrary();
      });
    }
    _classroom.attach(
      SyncScope.maybeOf(context),
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()?.notifier,
      language: Localizations.localeOf(context).languageCode,
    );
    final enabled = TickerMode.valuesOf(context).enabled;
    if (enabled != _tickerEnabled) {
      _tickerEnabled = enabled;
      _sendVisibility();
    }
  }

  void _armTimeout() {
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 25), () {
      if (!mounted || _ready) return;
      final t = L.of(context);
      setState(
        () => _error = Platform.isWindows
            ? t.textLibraryMcFailedWindows
            : t.textLibraryMcFailedAndroid,
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground =
        state == AppLifecycleState.resumed ||
        (Platform.isWindows && state == AppLifecycleState.inactive);
    _sendVisibility();
  }

  void _sendVisibility() => _send({'type': 'view', 'visible': _showing});

  void _sendLibrary() {
    final snapshot = _latest;
    if (snapshot != null) _send(libraryMessage(snapshot));
  }

  void _send(Map<String, Object?> message) {
    if (!_ready) return;
    final json = jsonEncode(message);
    final Future<void> delivery;
    if (_windows != null) {
      delivery = _windows!.post(json);
    } else if (_android != null) {
      delivery = _android!.evaluateJavascript(
        source: 'window.libraryReceive($json);',
      );
    } else {
      return;
    }
    unawaited(
      delivery.catchError((Object _) {
        if (mounted) setState(() => _error = L.of(context).textLibraryMcLost);
      }),
    );
  }

  Future<void> _receive(dynamic raw) async {
    if (!mounted) return;
    final Map<String, Object?> message;
    try {
      final value = raw is String ? jsonDecode(raw) : raw;
      if (value is! Map) return;
      message = Map<String, Object?>.from(value);
    } on FormatException {
      return;
    }
    try {
      await _handle(message);
    } catch (error) {
      final request = message['request'];
      if (request != null) {
        _send({'type': 'failed', 'request': request, 'message': '$error'});
      }
    }
  }

  Future<void> _handle(Map<String, Object?> message) async {
    final repository = _repository;
    switch (message['type']) {
      case 'ready':
        _timeout?.cancel();
        setState(() {
          _ready = true;
          _error = null;
        });
        _send({
          'type': 'init',
          'strings': sceneStrings(L.of(context)),
          'language': Localizations.localeOf(context).languageCode,
          'sceneKeys': sceneKeyStrings(L.of(context), 'text_library/scene'),
          'sourceStrings':
              sceneSourceStrings(L.of(context), 'text_library/scene'),
          'classStrings': classroomStringsByLanguage(),
          'reducedMotion': MediaQuery.of(context).disableAnimations,
        });
        _sendVisibility();
        _sendLibrary();
        final mail = await loadMail();
        _send({'type': 'mail', 'state': mail?.toJson()});
        final market = await loadMarket();
        _send({'type': 'market', 'state': market?.toJson()});
        await _classroom.ready();
        final saved = await loadSavedSkin();
        if (saved != null) _send(saved.toMessage());
      case 'mail':
        try {
          await saveMail(MailState.fromJson(message['state']));
        } catch (_) {
          // The next change saves it again.
        }
      case 'classroom':
        await _classroom.handle(message);
      case 'market':
        try {
          await saveMarket(MarketState.fromJson(message['state']));
        } catch (_) {
          // The next change saves it again.
        }
      case 'pickSkin':
        await _pickSkin();
      case 'skinName':
        final name = '${message['name'] ?? ''}';
        try {
          await _useSkin(await fetchSkinByName(name));
        } catch (_) {
          _send({'type': 'skin', 'failed': name});
        }
      case 'resetSkin':
        await clearSavedSkin();
        _send({'type': 'skin', 'data': null});
      case 'error':
        _fail('${message['message'] ?? ''}');
      case 'assetsWanted':
        final paths = (message['paths'] as List? ?? const [])
            .whereType<String>();
        final assets = await loadVanillaAssets(paths);
        _send({
          'type': 'assets',
          'source': assets?.label,
          'files': assets?.files ?? const <String, String>{},
        });
      case 'downloadVanilla':
        await _downloadVanilla(message);
      case 'createSubject':
        final id = await repository.createSubject(
          '${message['name'] ?? ''}',
          color: _dye(message['color']),
        );
        _reply(message, id);
      case 'renameSubject':
        final id = _int(message['id']);
        if (id != null) {
          await repository.renameSubject(id, '${message['name'] ?? ''}');
        }
      case 'saveBook':
        final subjectId = _int(message['subjectId']);
        if (subjectId == null) return;
        final id = await repository.saveText(
          id: _int(message['id']),
          subjectId: subjectId,
          title: '${message['title'] ?? ''}',
          spine: '${message['spine'] ?? ''}',
          body: RichDoc.decode(message['body'] as String?),
          cover: _dye(message['cover']),
          slot: _int(message['slot']),
        );
        _reply(message, id);
      case 'moveBook':
        final id = _int(message['id']);
        final subjectId = _int(message['subjectId']);
        final slot = _int(message['slot']);
        if (id != null && subjectId != null && slot != null) {
          await repository.moveText(id, subjectId: subjectId, slot: slot);
        }
      case 'deleteBook':
        final id = _int(message['id']);
        if (id != null) await repository.deleteText(id);
      case 'reviewBook':
        await _reviewBook(message);
    }
  }

  /// Sends a book from the market's review desk to the reviewer on the luma
  /// server, and hands its answer back to the page, which files it with the
  /// post as a letter for the next in-game day. A failure goes back as a
  /// `failed` reply with a message for the desk's screen.
  Future<void> _reviewBook(Map<String, Object?> message) async {
    final t = L.of(context);
    final id = _int(message['id']);
    final text = id == null
        ? null
        : _latest?.subjects
              .expand((s) => _latest!.textsOf(s.id))
              .where((x) => x.id == id)
              .firstOrNull;
    if (text == null || text.body.isBlank) {
      throw BookReviewException(t.textLibraryMcReviewEmpty);
    }
    final sync = SyncScope.maybeOf(context);
    final baseUrl = sync?.serverUrl;
    if (sync == null || !sync.serverReady || baseUrl == null) {
      throw BookReviewException(t.textLibraryMcReviewSignIn);
    }
    final api = BookReviewApi(baseUrl, token: sync.authToken);
    try {
      final result = await api.review(
        text.title,
        text.body.plainText,
        signIn: t.textLibraryMcReviewSignIn,
        unreachable: t.textLibraryMcReviewUnreachable,
      );
      _send({
        'type': 'reviewed',
        'request': message['request'],
        'result': result,
      });
    } finally {
      api.close();
    }
  }

  Future<void> _downloadVanilla(Map<String, Object?> message) async {
    if (_downloading) return;
    _downloading = true;
    try {
      await downloadVanillaTextures(
        onProgress: (progress) => _send({
          'type': 'download',
          'stage': progress.stage,
          'fraction': progress.fraction,
        }),
      );
      _send({'type': 'downloadDone'});
    } catch (error) {
      _send({'type': 'downloadFailed', 'message': '$error'});
    } finally {
      _downloading = false;
    }
  }

  Future<void> _pickSkin() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png'],
      withData: true,
    );
    final file = picked?.files.singleOrNull;
    if (file == null) return;
    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    final name = file.name.replaceFirst(
      RegExp(r'\.png$', caseSensitive: false),
      '',
    );
    final skin = bytes == null ? null : skinFromPng(bytes, label: name);
    if (skin == null) {
      _send({'type': 'skin', 'failed': file.name});
      return;
    }
    await _useSkin(skin);
  }

  Future<void> _useSkin(PlayerSkin skin) async {
    try {
      await saveSkin(skin);
    } catch (_) {
      // Still wear it for now; it just won't be remembered.
    }
    _send(skin.toMessage());
  }

  void _reply(Map<String, Object?> message, int id) {
    final request = message['request'];
    if (request != null) _send({'type': 'saved', 'request': request, 'id': id});
  }

  static int? _int(Object? value) => switch (value) {
    final int i => i,
    final num n => n.toInt(),
    final String s => int.tryParse(s),
    _ => null,
  };

  static DyeColor? _dye(Object? value) {
    final index = _int(value);
    return index == null ? null : DyeColor.at(index);
  }

  void _fail(String message) {
    if (!mounted) return;
    _timeout?.cancel();
    setState(
      () =>
          _error = message.isEmpty ? L.of(context).textLibraryMcLost : message,
    );
  }

  void _retry() {
    _windows = null;
    _android = null;
    setState(() {
      _generation++;
      _ready = false;
      _error = null;
    });
    _armTimeout();
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: Platform.isWindows
              ? NativeWebview(
                  key: ValueKey(_generation),
                  fileUrl: Uri.file(windowsAssetPath(_asset)).toString(),
                  visible: _error == null,
                  background: const Color(0xFF1B140E),
                  onCreated: (controller) => _windows = controller,
                  onMessage: _receive,
                  onError: _fail,
                )
              : InAppWebView(
                  key: ValueKey(_generation),
                  initialFile: _asset,
                  initialSettings: InAppWebViewSettings(
                    supportZoom: false,
                    transparentBackground: true,
                    mediaPlaybackRequiresUserGesture: false,
                  ),
                  onWebViewCreated: (controller) {
                    _android = controller;
                    controller.addJavaScriptHandler(
                      handlerName: 'library',
                      callback: (args) {
                        if (args.isNotEmpty) _receive(args.first);
                        return null;
                      },
                    );
                  },
                  onReceivedError: (_, request, error) {
                    if (request.isForMainFrame == true) {
                      _fail(error.description);
                    }
                  },
                ),
        ),
        if (_error != null)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(t.textLibraryMcRetry),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeout?.cancel();
    _windowCheck?.cancel();
    unawaited(_library?.cancel());
    _classroom.dispose();
    super.dispose();
  }
}
