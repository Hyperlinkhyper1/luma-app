import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../../../../l10n/current_l.dart';
import '../../../../sync/sync_service.dart';
import 'data/chat_api.dart';
import 'data/chat_cache_store.dart';
import 'data/chat_crypto.dart';
import 'data/chat_key_store.dart';

/// One decrypted message, ready for display.
class ChatMessageView {
  const ChatMessageView({
    required this.id,
    required this.mine,
    required this.text,
    required this.createdAtMs,
    this.failedToDecrypt = false,
    this.unverified = false,
  });

  final String id;
  final bool mine;
  final String text;
  final int createdAtMs;
  final bool failedToDecrypt;

  /// Sent by an older app in the anonymous v1 format, so nothing proves
  /// who wrote it (see ChatCrypto).
  final bool unverified;
}

/// One conversation, with its decrypted message history.
class ChatConversationView {
  const ChatConversationView({
    required this.id,
    required this.peerUserId,
    required this.peerEmail,
    required this.peerPublicKey,
    required this.pinnedPeerKey,
    required this.messages,
  });

  final String id;
  final String peerUserId;
  final String peerEmail;
  final String? peerPublicKey;

  /// The peer key this device trusted first (or last approved). Messages
  /// are only accepted from, and sealed for, this key.
  final String? pinnedPeerKey;
  final List<ChatMessageView> messages;

  /// Whether the peer has ever published an encryption key — until they do,
  /// no message can be sealed for them.
  bool get peerReady => peerPublicKey != null;

  /// The server now hands out a different key for the peer than the one
  /// pinned here. Either they set chat up on a new device, or someone —
  /// the server included — is trying to read along. Sending stops until
  /// the user compares safety numbers and calls
  /// [ChatRepository.trustNewKey].
  bool get keyChanged =>
      peerPublicKey != null &&
      pinnedPeerKey != null &&
      peerPublicKey != pinnedPeerKey;

  ChatMessageView? get lastMessage => messages.isEmpty ? null : messages.last;
}

/// Orchestrates the end-to-end encrypted Chat plugin: generates and persists
/// this device's X25519 identity, publishes its public key, sends/accepts
/// email invites, and encrypts/decrypts messages client-side — the server
/// (via [ChatApi]) only ever sees public keys and ciphertext. Talks to its
/// own plain (non zero-knowledge-sync) endpoints for the same reason
/// [FamilyRepository] does — see server/lib/chat_store.dart.
class ChatRepository extends ChangeNotifier {
  ChatRepository(this._sync);

  final SyncService _sync;

  ChatCacheStore? _cache;
  ChatApi? _api;
  String? _apiServerUrl;
  String? _apiToken;
  String? _uploadedKeyForToken;
  SimpleKeyPair? _identity;
  String? _ownPublicKey;

  Timer? _periodic;
  bool _refreshing = false;
  String? _lastError;

  final Map<String, int> _lastFetchedMsByConversation = {};

  static const _periodicInterval = Duration(seconds: 6);

  // ---- Public state -----------------------------------------------------

  bool get ready => _cache != null && _identity != null;
  String? get lastError => _lastError;

  List<RemoteChatInvite> get pendingInvites => (_cache?.invitesJson ?? const [])
      .map((j) => RemoteChatInvite.fromJson(j as Map<String, dynamic>))
      .toList();

  List<ChatConversationView> get conversations {
    final cache = _cache;
    if (cache == null) return const [];
    return (cache.conversationsJson)
        .map((j) => RemoteConversation.fromJson(j as Map<String, dynamic>))
        .map(_toView)
        .toList()
      ..sort((a, b) {
        final aMs = a.lastMessage?.createdAtMs ?? 0;
        final bMs = b.lastMessage?.createdAtMs ?? 0;
        return bMs.compareTo(aMs);
      });
  }

  ChatConversationView? conversation(String id) {
    for (final c in conversations) {
      if (c.id == id) return c;
    }
    return null;
  }

  ChatConversationView _toView(RemoteConversation c) {
    final rawMessages = _cache?.messagesByConversation[c.id] ?? const [];
    final messages = rawMessages.map((raw) {
      final m = raw as Map<String, dynamic>;
      return ChatMessageView(
        id: m['id'] as String,
        mine: (m['senderUserId'] as String) != c.peerUserId,
        text: m['text'] as String? ?? '',
        createdAtMs: m['createdAtMs'] as int,
        failedToDecrypt: m['failed'] as bool? ?? false,
        unverified: m['verified'] == false && m['failed'] != true,
      );
    }).toList()
      ..sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    return ChatConversationView(
      id: c.id,
      peerUserId: c.peerUserId,
      peerEmail: c.peerEmail,
      peerPublicKey: c.peerPublicKey,
      pinnedPeerKey: _cache?.pinnedKeys[c.peerUserId],
      messages: messages,
    );
  }

  String? get ownPublicKey => _ownPublicKey;

  // ---- Lifecycle ----------------------------------------------------------

  Future<void> init() async {
    _cache = await ChatCacheStore.load();
    final keyStore = await ChatKeyStore.load();
    _identity = await keyStore.loadIdentity();
    if (_identity == null) {
      _identity = await ChatCrypto.generateIdentity();
      await keyStore.saveIdentity(_identity!);
    }
    _ownPublicKey = await ChatCrypto.encodePublicKey(_identity!);
    notifyListeners();

    _sync.addListener(_onSyncChanged);
    _onSyncChanged();
    _periodic = Timer.periodic(_periodicInterval, (_) {
      if (_sync.serverReady) unawaited(refresh());
    });
  }

  @override
  void dispose() {
    _periodic?.cancel();
    _sync.removeListener(_onSyncChanged);
    _api?.close();
    super.dispose();
  }

  void _onSyncChanged() {
    if (!_sync.serverReady) {
      _api?.close();
      _api = null;
      _apiServerUrl = null;
      _apiToken = null;
      return;
    }
    if (_api != null &&
        _apiServerUrl == _sync.serverUrl &&
        _apiToken == _sync.authToken) {
      return;
    }
    _api?.close();
    _apiServerUrl = _sync.serverUrl;
    _apiToken = _sync.authToken;
    _api = ChatApi(_sync.serverUrl!, token: _sync.authToken);
    unawaited(_ensureKeyUploaded());
  }

  Future<void> _ensureKeyUploaded() async {
    final api = _api;
    final key = _ownPublicKey;
    if (api == null || key == null || _uploadedKeyForToken == _apiToken) {
      unawaited(refresh());
      return;
    }
    try {
      await api.putPublicKey(key);
      _uploadedKeyForToken = _apiToken;
    } on ChatApiException catch (e) {
      // The server only lets a recent sign-in replace a chat key; say so
      // rather than leaving peers sealing messages for a key we lack.
      if (e.code == 'reauth_required') _lastError = e.message;
    } catch (_) {
      // Will retry on the next periodic refresh via _onSyncChanged staying stable.
    }
    unawaited(refresh());
  }

  /// Opens [blob] as a message from [senderUserId] in [conv]: the peer's
  /// messages must come from their pinned key, ours from our own.
  Future<OpenedMessage> _open(
      String blob, String senderUserId, RemoteConversation conv) async {
    final sender = senderUserId == conv.peerUserId
        ? (_cache!.pinnedKeys[conv.peerUserId] ?? conv.peerPublicKey)
        : _ownPublicKey;
    if (sender == null) {
      throw ChatCryptoException(currentL.secureChatCouldNotDecrypt);
    }
    return ChatCrypto.open(blob, _identity!,
        expectedSender: ChatCrypto.decodePublicKey(sender));
  }

  Map<String, dynamic> _messageJson(
      {required String id,
      required String senderUserId,
      required int createdAtMs,
      required String blob,
      OpenedMessage? opened}) =>
      {
        'id': id,
        'senderUserId': senderUserId,
        'createdAtMs': createdAtMs,
        'text': opened?.text ?? '',
        'failed': opened == null,
        if (opened != null) 'verified': opened.authenticated,
        // Kept only while unreadable, so trusting a peer's new key can try
        // again.
        if (opened == null) 'blob': blob,
      };

  /// Pins the peer's current key after the user has checked it (ideally by
  /// comparing safety numbers), and retries the messages that would not
  /// open under the old one.
  Future<void> trustNewKey(String conversationId) async {
    final cache = _cache;
    final conv = conversation(conversationId);
    final key = conv?.peerPublicKey;
    if (cache == null || conv == null || key == null) return;
    cache.pinnedKeys[conv.peerUserId] = key;
    final remote = RemoteConversation.fromJson({
      'id': conv.id,
      'peerUserId': conv.peerUserId,
      'peerEmail': conv.peerEmail,
      'peerPublicKey': key,
      'createdAtMs': 0,
    });
    final messages = List<dynamic>.of(
        cache.messagesByConversation[conversationId] ?? const []);
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i] as Map<String, dynamic>;
      final blob = m['blob'];
      if (m['failed'] != true || blob is! String) continue;
      OpenedMessage? opened;
      try {
        opened = await _open(blob, m['senderUserId'] as String, remote);
      } on ChatCryptoException {
        opened = null;
      }
      messages[i] = _messageJson(
          id: m['id'] as String,
          senderUserId: m['senderUserId'] as String,
          createdAtMs: m['createdAtMs'] as int,
          blob: blob,
          opened: opened);
    }
    cache.messagesByConversation[conversationId] = messages;
    await cache.save();
    notifyListeners();
  }

  /// Pulls invites and conversations, then any new messages in each
  /// conversation, decrypting as it goes. Safe to call anytime; concurrent
  /// calls collapse into a no-op.
  Future<void> refresh() async {
    final api = _api;
    final cache = _cache;
    final identity = _identity;
    if (api == null || cache == null || identity == null || _refreshing) return;
    _refreshing = true;
    try {
      if (_uploadedKeyForToken != _apiToken && _ownPublicKey != null) {
        try {
          await api.putPublicKey(_ownPublicKey!);
          _uploadedKeyForToken = _apiToken;
        } catch (_) {}
      }

      final invites = await api.listMyInvites();
      final remoteConversations = await api.listConversations();

      for (final conv in remoteConversations) {
        // Trust on first use: the first key seen for a peer is the one
        // every later message is checked against.
        final peerKey = conv.peerPublicKey;
        if (peerKey != null) cache.pinnedKeys.putIfAbsent(conv.peerUserId, () => peerKey);
        final sinceMs = _lastFetchedMsByConversation[conv.id];
        List<RemoteChatMessage> newMessages;
        try {
          newMessages = await api.listMessages(conv.id, sinceMs: sinceMs);
        } catch (_) {
          continue;
        }
        if (newMessages.isEmpty) continue;

        final existing = List<dynamic>.of(
            cache.messagesByConversation[conv.id] ?? const []);
        final existingIds = existing
            .map((e) => (e as Map<String, dynamic>)['id'] as String)
            .toSet();

        for (final m in newMessages) {
          if (existingIds.contains(m.id)) continue;
          OpenedMessage? opened;
          try {
            opened = await _open(m.blob, m.senderUserId, conv);
          } on ChatCryptoException {
            opened = null;
          }
          existing.add(_messageJson(
              id: m.id,
              senderUserId: m.senderUserId,
              createdAtMs: m.createdAtMs,
              blob: m.blob,
              opened: opened));
          if (m.createdAtMs >
              (_lastFetchedMsByConversation[conv.id] ?? 0)) {
            _lastFetchedMsByConversation[conv.id] = m.createdAtMs;
          }
        }
        cache.messagesByConversation[conv.id] = existing;
      }

      cache
        ..conversationsJson =
            remoteConversations.map((c) => _conversationToJson(c)).toList()
        ..invitesJson = invites
            .map((i) => {
                  'id': i.id,
                  'inviterEmail': i.inviterEmail,
                  'createdAtMs': i.createdAtMs,
                  'expiresAtMs': i.expiresAtMs,
                })
            .toList();
      await cache.save();
      _lastError = null;
    } catch (e) {
      _lastError = '$e';
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _conversationToJson(RemoteConversation c) => {
        'id': c.id,
        'peerUserId': c.peerUserId,
        'peerEmail': c.peerEmail,
        'peerPublicKey': c.peerPublicKey,
        'createdAtMs': c.createdAtMs,
      };

  // ---- Mutations ------------------------------------------------------------

  Future<void> sendInvite(String email) async {
    final api = _requireApi();
    await api.sendInvite(email);
    await refresh();
  }

  Future<void> acceptInvite(String inviteId) async {
    final api = _requireApi();
    await api.acceptInvite(inviteId);
    await refresh();
  }

  Future<void> sendEmailVerificationCode() =>
      _requireApi().sendEmailVerificationCode();

  Future<void> confirmEmail(String code) => _requireApi().confirmEmail(code);

  Future<void> declineInvite(String inviteId) async {
    final api = _requireApi();
    await api.declineInvite(inviteId);
    await refresh();
  }

  /// Encrypts [text] separately for the peer and for ourselves (so our own
  /// sent history stays readable), then sends both sealed blobs. Throws
  /// [StateError] if the peer hasn't published an encryption key yet.
  Future<void> sendMessage(String conversationId, String text) async {
    final api = _requireApi();
    final identity = _identity;
    if (identity == null) throw StateError(currentL.secureChatNotReady);
    final conv = conversation(conversationId);
    final peerKey = conv?.peerPublicKey;
    if (peerKey == null) {
      throw StateError(currentL.secureChatPeerNoKey);
    }
    if (conv!.keyChanged) {
      throw StateError(currentL.secureChatKeyChangedSendBlocked(conv.peerEmail));
    }

    final blobForRecipient = await ChatCrypto.seal(
        text, ChatCrypto.decodePublicKey(peerKey), identity);
    final blobForSender = await ChatCrypto.seal(
        text, ChatCrypto.decodePublicKey(_ownPublicKey!), identity);

    await api.sendMessage(conversationId,
        blobForRecipient: blobForRecipient, blobForSender: blobForSender);
    await refresh();
  }

  ChatApi _requireApi() {
    final api = _api;
    if (api == null) throw StateError(currentL.secureChatNotSignedIn);
    return api;
  }
}
