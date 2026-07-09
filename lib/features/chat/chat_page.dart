import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../settings/settings_controller.dart';
import '../../settings/settings_scope.dart';
import '../../theme/luma_theme.dart';
import '../plugins/plugin_scope.dart';
import '../plugins/installed/qr_code_generator/qr_code_scope.dart';
import 'ai_agent_store.dart';
import 'ai_key_store.dart';
import 'ai_tools.dart';
import 'chat_controller.dart';
import 'chat_scope.dart';
import 'data/chat_repository.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/chat_message_list.dart';

const _wideBreakpoint = 760.0;

/// The AI Assistant tab: a chat UI backed by the user's own API key for
/// whichever provider is selected in Settings (stored locally, see
/// [AiKeyStore]) with tool use for actions like installing a plugin or
/// generating a QR code on the user's behalf.
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.onOpenSettings,
    required this.onOpenPlugin,
  });

  final VoidCallback onOpenSettings;
  final ValueChanged<String> onOpenPlugin;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final Future<(AiKeyStore, AiAgentStore)> _storesFuture = _loadStores();
  ChatController? _controller;
  int? _activeConversationId;

  static Future<(AiKeyStore, AiAgentStore)> _loadStores() async {
    final keyStore = await AiKeyStore.load();
    final agentStore = await AiAgentStore.load();
    return (keyStore, agentStore);
  }

  ChatController _controllerFor(AiKeyStore keyStore, AiAgentStore agentStore) {
    return _controller ??= ChatController(
      repository: ChatScope.of(context),
      keyStore: keyStore,
      agentStore: agentStore,
      tools: AiToolRegistry(
        pluginRepository: PluginScope.of(context),
        qrCodeRepository: QrCodeScope.of(context),
      ),
      settings: SettingsScope.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(AiKeyStore, AiAgentStore)>(
      future: _storesFuture,
      builder: (context, snap) {
        if (snap.hasError) {
          return _LoadError(error: snap.error!);
        }
        if (!snap.hasData) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          );
        }
        final (keyStore, agentStore) = snap.data!;
        final controller = _controllerFor(keyStore, agentStore);
        return _ChatBody(
          controller: controller,
          keyStore: keyStore,
          settings: SettingsScope.of(context),
          activeConversationId: _activeConversationId,
          onSelectConversation: (id) =>
              setState(() => _activeConversationId = id),
          onOpenSettings: widget.onOpenSettings,
          onOpenPlugin: widget.onOpenPlugin,
        );
      },
    );
  }
}

class _ChatBody extends StatefulWidget {
  const _ChatBody({
    required this.controller,
    required this.keyStore,
    required this.settings,
    required this.activeConversationId,
    required this.onSelectConversation,
    required this.onOpenSettings,
    required this.onOpenPlugin,
  });

  final ChatController controller;
  final AiKeyStore keyStore;
  final SettingsController settings;
  final int? activeConversationId;
  final ValueChanged<int?> onSelectConversation;
  final VoidCallback onOpenSettings;
  final ValueChanged<String> onOpenPlugin;

  @override
  State<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<_ChatBody> {
  late String _providerId = widget.settings.aiProviderId;
  late Future<String?> _apiKeyFuture =
      widget.keyStore.readKey(_providerId);

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (widget.settings.aiProviderId != _providerId) {
      _providerId = widget.settings.aiProviderId;
      _recheckKey();
    }
  }

  void _recheckKey() =>
      setState(() => _apiKeyFuture = widget.keyStore.readKey(_providerId));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _apiKeyFuture,
      builder: (context, snap) {
        if (snap.hasError) {
          return _LoadError(error: snap.error!);
        }
        if (!snap.hasData) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          );
        }
        if (snap.data == null) {
          return _NoKeyState(
            onOpenSettings: widget.onOpenSettings,
            onRecheck: _recheckKey,
          );
        }
        return AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) => _ChatLayout(
            controller: widget.controller,
            activeConversationId: widget.activeConversationId,
            onSelectConversation: widget.onSelectConversation,
            onOpenPlugin: widget.onOpenPlugin,
          ),
        );
      },
    );
  }
}

class _ChatLayout extends StatelessWidget {
  const _ChatLayout({
    required this.controller,
    required this.activeConversationId,
    required this.onSelectConversation,
    required this.onOpenPlugin,
  });

  final ChatController controller;
  final int? activeConversationId;
  final ValueChanged<int?> onSelectConversation;
  final ValueChanged<String> onOpenPlugin;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        final list = _ConversationList(
          activeConversationId: activeConversationId,
          onSelect: onSelectConversation,
        );
        final thread = activeConversationId == null
            ? const LumaEmptyState(
                icon: Icons.smart_toy_rounded,
                title: 'No conversation selected',
                subtitle: 'Start a new one to talk with the assistant.',
              )
            : _ConversationThread(
                conversationId: activeConversationId!,
                controller: controller,
                settings: settings,
                onOpenPlugin: onOpenPlugin,
              );

        if (!wide) {
          return activeConversationId == null
              ? Padding(padding: const EdgeInsets.all(16), child: list)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => onSelectConversation(null),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('Conversations'),
                        ),
                      ),
                    ),
                    Expanded(child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: thread,
                    )),
                  ],
                );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 280,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                child: list,
              ),
            ),
            VerticalDivider(width: 1, color: context.luma.border),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
                child: thread,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.activeConversationId,
    required this.onSelect,
  });

  final int? activeConversationId;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    final repo = ChatScope.of(context);
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LumaPrimaryButton(
          label: 'New conversation',
          icon: Icons.add_rounded,
          expand: true,
          onTap: () async {
            final id = await repo.createConversation();
            onSelect(id);
          },
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamData<List<ChatConversationRecord>>(
            stream: repo.watchConversations(),
            builder: (context, conversations) {
              if (conversations.isEmpty) {
                return Center(
                  child: Text(
                    'No conversations yet.',
                    style: TextStyle(color: luma.textMuted, fontSize: 13),
                  ),
                );
              }
              return ListView.builder(
                itemCount: conversations.length,
                itemBuilder: (context, i) {
                  final c = conversations[i];
                  final selected = c.id == activeConversationId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => onSelect(c.id),
                        onLongPress: () => _confirmDelete(context, c),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected ? luma.accentSubtle : luma.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? luma.accent : luma.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: luma.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _relative(c.updatedAt),
                                style:
                                    TextStyle(color: luma.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, ChatConversationRecord c) {
    final luma = context.luma;
    final repo = ChatScope.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: luma.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: luma.border),
        ),
        title: Text('Delete "${c.title}"?',
            style: TextStyle(color: luma.textPrimary)),
        content: Text(
          'This removes the conversation and its messages.',
          style: TextStyle(color: luma.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              repo.deleteConversation(c.id);
              if (c.id == activeConversationId) onSelect(null);
              Navigator.of(dialogContext).pop();
            },
            child: Text('Delete', style: TextStyle(color: luma.danger)),
          ),
        ],
      ),
    );
  }

  static String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ConversationThread extends StatelessWidget {
  const _ConversationThread({
    required this.conversationId,
    required this.controller,
    required this.settings,
    required this.onOpenPlugin,
  });

  final int conversationId;
  final ChatController controller;
  final SettingsController settings;
  final ValueChanged<String> onOpenPlugin;

  @override
  Widget build(BuildContext context) {
    final repo = ChatScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ChatMessageList(
            stream: repo.watchMessages(conversationId),
            onOpenQrPlugin: () => onOpenPlugin('qr-code-generator'),
          ),
        ),
        const SizedBox(height: 8),
        ChatInputBar(
          sending: controller.isSending,
          remainingToday: settings.aiCallsRemainingToday,
          onSend: (text) => controller.sendMessage(conversationId, text),
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LumaEmptyState(
          icon: Icons.error_outline_rounded,
          title: "Couldn't load the assistant",
          subtitle: '$error',
        ),
      ),
    );
  }
}

class _NoKeyState extends StatelessWidget {
  const _NoKeyState({required this.onOpenSettings, required this.onRecheck});

  final VoidCallback onOpenSettings;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LumaEmptyState(
        icon: Icons.smart_toy_rounded,
        title: 'Connect an AI provider',
        subtitle:
            'Pick a provider and add your own API key in Settings to start '
            "chatting with the assistant. It's stored locally on this "
            'device only.',
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LumaPrimaryButton(
              label: 'Open Settings',
              icon: Icons.settings_rounded,
              onTap: onOpenSettings,
            ),
            const SizedBox(width: 10),
            LumaGhostButton(
              label: 'I added a key',
              icon: Icons.refresh_rounded,
              onTap: onRecheck,
            ),
          ],
        ),
      ),
    );
  }
}
