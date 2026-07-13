import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/widgets.dart';
import '../../../../sync/sync_scope.dart';
import '../../../../theme/luma_theme.dart';
import 'chat_repository.dart';
import 'data/chat_api.dart';
import 'secure_chat_scope.dart';
import 'widgets/chat_invite_dialog.dart';

const _wideBreakpoint = 760.0;

/// The Chat plugin: invite another Luma user by email, they accept from
/// their own Invites list, and every message after that is end-to-end
/// encrypted on-device — the sync server only ever relays ciphertext it
/// cannot read. See chat_repository.dart / data/chat_crypto.dart.
class SecureChatPage extends StatefulWidget {
  const SecureChatPage({super.key});

  @override
  State<SecureChatPage> createState() => _SecureChatPageState();
}

class _SecureChatPageState extends State<SecureChatPage> {
  String? _selectedConversationId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SecureChatScope.of(context).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.of(context);
    final chat = SecureChatScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([sync, chat]),
      builder: (context, _) {
        if (!sync.signedIn) return const _SignedOut();
        final conversations = chat.conversations;
        if (_selectedConversationId != null &&
            conversations.every((c) => c.id != _selectedConversationId)) {
          _selectedConversationId = null;
        }
        final list = _ConversationList(
          chat: chat,
          selectedId: _selectedConversationId,
          onSelect: (id) => setState(() => _selectedConversationId = id),
        );
        final thread = _selectedConversationId == null
            ? const LumaEmptyState(
                icon: Icons.lock_rounded,
                title: 'End-to-end encrypted chat',
                subtitle: 'Pick a conversation, or invite someone new by email.',
              )
            : _ChatThread(
                chat: chat,
                conversationId: _selectedConversationId!,
              );

        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _wideBreakpoint;
            if (!wide) {
              return _selectedConversationId == null
                  ? list
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () =>
                                  setState(() => _selectedConversationId = null),
                              icon: const Icon(Icons.arrow_back_rounded, size: 18),
                              label: const Text('Chats'),
                            ),
                          ),
                        ),
                        Expanded(child: thread),
                      ],
                    );
            }

            return Row(
              children: [
                SizedBox(width: 320, child: list),
                VerticalDivider(width: 1, color: context.luma.border),
                Expanded(child: thread),
              ],
            );
          },
        );
      },
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          LumaIconBadge(icon: Icons.lock_outline_rounded, color: luma.accent, size: 64),
          const SizedBox(height: 20),
          Text('Chat needs sync',
              style: TextStyle(
                  color: luma.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            width: 420,
            child: Text(
              'Sign in under Settings → Sync & account to invite people and '
              'chat. Messages are end-to-end encrypted on this device — the '
              'server only ever relays ciphertext.',
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textMuted, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.chat,
    required this.selectedId,
    required this.onSelect,
  });

  final ChatRepository chat;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final invites = chat.pendingInvites;
    final conversations = chat.conversations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text('Chat',
                    style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ),
              IconButton(
                tooltip: 'New chat',
                icon: Icon(Icons.person_add_alt_1_rounded, color: luma.accent),
                onPressed: () async {
                  final sent =
                      await showChatInviteDialog(context, chatRepo: chat);
                  if (sent && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite sent.')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        if (chat.lastError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(chat.lastError!,
                style: TextStyle(color: luma.danger, fontSize: 12)),
          ),
        if (invites.isNotEmpty) _InvitesSection(chat: chat, invites: invites),
        Expanded(
          child: conversations.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: LumaEmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'No chats yet',
                    subtitle: 'Invite someone by email to get started.',
                  ),
                )
              : ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (context, i) {
                    final c = conversations[i];
                    final selected = c.id == selectedId;
                    return ListTile(
                      selected: selected,
                      selectedTileColor: luma.accentSubtle,
                      leading: CircleAvatar(
                        backgroundColor: luma.accentSubtle,
                        child: Text(
                          c.peerEmail.isNotEmpty ? c.peerEmail[0].toUpperCase() : '?',
                          style: TextStyle(color: luma.accent, fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(c.peerEmail,
                          style: TextStyle(color: luma.textPrimary, fontSize: 14)),
                      subtitle: Text(
                        !c.peerReady
                            ? 'Waiting for them to set up encryption…'
                            : (c.lastMessage?.text.isNotEmpty ?? false)
                                ? c.lastMessage!.text
                                : 'No messages yet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: luma.textMuted, fontSize: 12),
                      ),
                      onTap: () => onSelect(c.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _InvitesSection extends StatelessWidget {
  const _InvitesSection({required this.chat, required this.invites});

  final ChatRepository chat;
  final List<RemoteChatInvite> invites;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: luma.accentSubtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invites', style: TextStyle(color: luma.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final invite in invites)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${invite.inviterEmail} wants to chat',
                      style: TextStyle(color: luma.textPrimary, fontSize: 12.5),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.check_circle_rounded, color: luma.success, size: 20),
                    tooltip: 'Accept',
                    onPressed: () => _respond(context, invite.id, accept: true),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.cancel_rounded, color: luma.danger, size: 20),
                    tooltip: 'Decline',
                    onPressed: () => _respond(context, invite.id, accept: false),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _respond(BuildContext context, String inviteId,
      {required bool accept}) async {
    try {
      if (accept) {
        await chat.acceptInvite(inviteId);
      } else {
        await chat.declineInvite(inviteId);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ChatApiException ? e.message : '$e')),
      );
    }
  }
}

class _ChatThread extends StatefulWidget {
  const _ChatThread({required this.chat, required this.conversationId});

  final ChatRepository chat;
  final String conversationId;

  @override
  State<_ChatThread> createState() => _ChatThreadState();
}

class _ChatThreadState extends State<_ChatThread> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.chat.sendMessage(widget.conversationId, text);
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final conv = widget.chat.conversation(widget.conversationId);
    if (conv == null) return const SizedBox.shrink();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.lock_rounded, size: 16, color: luma.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(conv.peerEmail,
                    style: TextStyle(
                        color: luma.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        Expanded(
          child: conv.messages.isEmpty
              ? LumaEmptyState(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Say hello',
                  subtitle: 'Messages here are end-to-end encrypted.',
                )
              : ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: conv.messages.length,
                  itemBuilder: (context, i) {
                    final m = conv.messages[conv.messages.length - 1 - i];
                    return _MessageBubble(message: m);
                  },
                ),
        ),
        if (!conv.peerReady)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              "${conv.peerEmail} hasn't set up chat encryption on a device yet — "
              "you'll be able to message them once they do.",
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: conv.peerReady && !_sending,
                  minLines: 1,
                  maxLines: 5,
                  style: TextStyle(color: luma.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Message…',
                    hintStyle: TextStyle(color: luma.textMuted),
                    filled: true,
                    fillColor: luma.surfaceHover,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: luma.accent),
                icon: _sending
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: luma.onAccent),
                      )
                    : Icon(Icons.send_rounded, color: luma.onAccent),
                onPressed: conv.peerReady ? _send : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessageView message;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final time = DateFormat.Hm().format(
        DateTime.fromMillisecondsSinceEpoch(message.createdAtMs));
    return Align(
      alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: message.mine ? luma.accent : luma.surfaceHover,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.failedToDecrypt ? 'Could not decrypt this message.' : message.text,
              style: TextStyle(
                color: message.mine ? luma.onAccent : luma.textPrimary,
                fontSize: 14,
                fontStyle: message.failedToDecrypt ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: (message.mine ? luma.onAccent : luma.textMuted).withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
