import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../settings/settings_controller.dart';
import '../../settings/settings_scope.dart';
import '../../settings/sync_section.dart';
import '../../sync/sync_scope.dart';
import '../../sync/sync_service.dart';
import '../../theme/luma_theme.dart';
import '../plugins/plugin_scope.dart';
import '../plugins/installed/qr_code_generator/qr_code_scope.dart';
import 'ai_agent_store.dart';
import 'ai_key_store.dart';
import 'ai_tools.dart';
import 'chat_controller.dart';
import 'chat_scope.dart';
import 'providers/ai_modes.dart';
import 'providers/ai_providers.dart';
import 'providers/ai_usage.dart';
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
      syncService: SyncScope.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncService = SyncScope.of(context);
    return ListenableBuilder(
      listenable: syncService,
      builder: (context, _) {
        if (!syncService.p2pReady) {
          return _NoAccountState(syncService: syncService);
        }
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
              syncService: syncService,
              settings: SettingsScope.of(context),
              activeConversationId: _activeConversationId,
              onSelectConversation: (id) =>
                  setState(() => _activeConversationId = id),
              onOpenSettings: widget.onOpenSettings,
              onOpenPlugin: widget.onOpenPlugin,
            );
          },
        );
      },
    );
  }
}

/// Shown in place of the assistant until the user has set up a luma account
/// (cloud or local-only — see [SyncService.p2pReady]). The assistant talks to
/// external AI providers, so it's gated behind account creation the same way
/// the rest of the account-scoped surface is.
class _NoAccountState extends StatelessWidget {
  const _NoAccountState({required this.syncService});

  final SyncService syncService;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LumaEmptyState(
        icon: Icons.person_add_rounded,
        title: 'Create an account to continue',
        subtitle:
            'Set up a luma account — just an email and password, no server '
            'required — before chatting with the assistant.',
        action: LumaPrimaryButton(
          label: 'Set up account',
          icon: Icons.person_add_rounded,
          onTap: () => showAccountSetupDialog(context, syncService),
        ),
      ),
    );
  }
}

class _ChatBody extends StatefulWidget {
  const _ChatBody({
    required this.controller,
    required this.keyStore,
    required this.syncService,
    required this.settings,
    required this.activeConversationId,
    required this.onSelectConversation,
    required this.onOpenSettings,
    required this.onOpenPlugin,
  });

  final ChatController controller;
  final AiKeyStore keyStore;
  final SyncService syncService;
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
  late Future<bool> _keyAvailableFuture = _checkKeyAvailable();

  /// Whether the assistant can be used with the current provider: either a
  /// key is saved locally on this device, or (for Luma Support/Mistral and
  /// Luma AI/Google) the sync server has an operator-configured key that
  /// chats will be proxied through — see [ChatController].
  Future<bool> _checkKeyAvailable() async {
    if (await widget.keyStore.readKey(_providerId) != null) return true;
    if (_providerId == AiProviderId.mistral.name) {
      return widget.syncService.mistralKeyConfiguredOnServer();
    }
    if (_providerId == AiProviderId.google.name) {
      final status = await widget.syncService.aiStatus();
      return status?.googleConfigured ?? false;
    }
    return false;
  }

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
      setState(() => _keyAvailableFuture = _checkKeyAvailable());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _keyAvailableFuture,
      builder: (context, snap) {
        if (snap.hasError) {
          return _LoadError(error: snap.error!);
        }
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          );
        }
        if (snap.data != true) {
          return _NoKeyState(
            settings: widget.settings,
            onOpenSettings: widget.onOpenSettings,
            onRecheck: _recheckKey,
          );
        }
        return AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) => _ChatLayout(
            controller: widget.controller,
            keyStore: widget.keyStore,
            syncService: widget.syncService,
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
    required this.keyStore,
    required this.syncService,
    required this.activeConversationId,
    required this.onSelectConversation,
    required this.onOpenPlugin,
  });

  final ChatController controller;
  final AiKeyStore keyStore;
  final SyncService syncService;
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
                keyStore: keyStore,
                syncService: syncService,
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
                        onLongPress: () =>
                            _showContextMenu(context, null, c),
                        onSecondaryTapDown: (details) => _showContextMenu(
                            context, details.globalPosition, c),
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
                              Row(
                                children: [
                                  if (c.pinned) ...[
                                    Icon(Icons.push_pin_rounded,
                                        size: 12, color: luma.accent),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: Text(
                                      c.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: luma.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
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

  /// Right-click (or long-press, on touch) menu for a conversation: rename,
  /// pin/unpin, delete. [globalPosition] anchors the menu at the click point;
  /// pass null (long-press has no useful point) to center it in the overlay.
  Future<void> _showContextMenu(
    BuildContext context,
    Offset? globalPosition,
    ChatConversationRecord c,
  ) async {
    final luma = context.luma;
    final repo = ChatScope.of(context);
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final anchor = globalPosition ?? overlay.size.center(Offset.zero);
    final position = RelativeRect.fromRect(
      Rect.fromPoints(anchor, anchor),
      Offset.zero & overlay.size,
    );

    final action = await showMenu<String>(
      context: context,
      position: position,
      color: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: luma.border),
      ),
      items: [
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        PopupMenuItem(
          value: 'pin',
          child: Text(c.pinned ? 'Unpin' : 'Pin'),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: luma.danger)),
        ),
      ],
    );

    if (!context.mounted) return;
    switch (action) {
      case 'rename':
        _renameConversation(context, c);
      case 'pin':
        repo.setPinned(c.id, !c.pinned);
      case 'delete':
        _confirmDelete(context, c);
    }
  }

  void _renameConversation(BuildContext context, ChatConversationRecord c) {
    final luma = context.luma;
    final repo = ChatScope.of(context);
    final controller = TextEditingController(text: c.title);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: luma.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: luma.border),
        ),
        title: Text('Rename conversation',
            style: TextStyle(color: luma.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: luma.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: luma.background,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: luma.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: luma.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: luma.accent),
            ),
          ),
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) repo.renameConversation(c.id, trimmed);
            Navigator.of(dialogContext).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) repo.renameConversation(c.id, trimmed);
              Navigator.of(dialogContext).pop();
            },
            child: Text('Save', style: TextStyle(color: luma.accent)),
          ),
        ],
      ),
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
    required this.keyStore,
    required this.syncService,
    required this.settings,
    required this.onOpenPlugin,
  });

  final int conversationId;
  final ChatController controller;
  final AiKeyStore keyStore;
  final SyncService syncService;
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
        const SizedBox(height: 20),
        _ChatComposer(
          conversationId: conversationId,
          controller: controller,
          keyStore: keyStore,
          syncService: syncService,
          settings: settings,
        ),
      ],
    );
  }
}

/// The input area of a conversation: the Luma AI mode picker (when that
/// provider is active), the text field, and a usage caption. Usage comes
/// from the sync server when chatting through a shared key — expressed as
/// percentages of the token budget for Luma AI, and as "N of 15 messages"
/// for Luma Support — or from the local daily counter otherwise.
class _ChatComposer extends StatefulWidget {
  const _ChatComposer({
    required this.conversationId,
    required this.controller,
    required this.keyStore,
    required this.syncService,
    required this.settings,
  });

  final int conversationId;
  final ChatController controller;
  final AiKeyStore keyStore;
  final SyncService syncService;
  final SettingsController settings;

  @override
  State<_ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<_ChatComposer> {
  String? _caption;
  bool _blocked = false;
  bool _wasSending = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.settings.addListener(_refreshUsage);
    _refreshUsage();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.settings.removeListener(_refreshUsage);
    super.dispose();
  }

  void _onControllerChanged() {
    // Refresh the usage caption when a send finishes (isSending true→false).
    final sending = widget.controller.isSending;
    if (_wasSending && !sending) _refreshUsage();
    _wasSending = sending;
  }

  Future<void> _refreshUsage() async {
    final settings = widget.settings;
    final providerId = settings.aiProviderId;
    final localKey = await widget.keyStore.readKey(providerId);

    String caption;
    bool blocked;
    if (localKey == null && providerId == AiProviderId.google.name) {
      final status = await widget.syncService.aiStatus();
      if (status == null) {
        caption = 'Usage unavailable — check your connection';
        blocked = false;
      } else {
        caption =
            'AI usage: ${status.fiveHourPct}% (5-hour) · ${status.weeklyPct}% (weekly)';
        blocked = status.fiveHourPct >= 100 || status.weeklyPct >= 100;
      }
    } else if (localKey == null && providerId == AiProviderId.mistral.name) {
      final status = await widget.syncService.aiStatus();
      if (status == null) {
        caption = 'Usage unavailable — check your connection';
        blocked = false;
      } else {
        caption =
            '${status.supportRemaining} of ${status.supportLimit} support messages left today';
        blocked = status.supportRemaining <= 0;
      }
    } else {
      final remaining = settings.aiCallsRemainingToday;
      caption = '$remaining messages left today';
      blocked = remaining <= 0;
    }

    if (!mounted) return;
    setState(() {
      _caption = caption;
      _blocked = blocked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return ChatInputBar(
      sending: widget.controller.isSending,
      enabled: !_blocked,
      caption: _caption ?? '',
      modelSelector: _ModelSelector(settings: settings),
      onSend: (text) =>
          widget.controller.sendMessage(widget.conversationId, text),
    );
  }
}

/// One entry in the model menu: a user-facing name mapped to the provider
/// (and, for Luma AI, the intelligence mode) it actually selects.
class _ModelChoice {
  const _ModelChoice(this.label, this.providerId, [this.mode]);

  final String label;
  final String providerId;

  /// [AiMode.name] to activate, for the Luma AI (Google) tiers.
  final String? mode;

  bool isActive(SettingsController settings) =>
      settings.aiProviderId == providerId &&
      (mode == null || settings.aiMode == mode);
}

final List<_ModelChoice> _lumaModels = [
  for (final mode in AiMode.values)
    _ModelChoice(
        'Luma ${mode.displayName}', AiProviderId.google.name, mode.name),
  _ModelChoice('Luma Assistant 1.0', AiProviderId.mistral.name),
];

final List<_ModelChoice> _apiKeyModels = [
  _ModelChoice('Anthropic Claude', AiProviderId.anthropic.name),
  _ModelChoice('OpenAI', AiProviderId.openai.name),
];

/// Claude-style model picker: a small pill under the typing bar showing the
/// active model's name; tapping it expands a menu of every model — the four
/// luma-branded ones plus an "API key" section for bring-your-own-key
/// providers. Selecting one flips the provider (and Luma AI mode) in
/// Settings, which the surrounding chat body already listens to.
class _ModelSelector extends StatelessWidget {
  const _ModelSelector({required this.settings});
  final SettingsController settings;

  _ModelChoice get _active =>
      [..._lumaModels, ..._apiKeyModels].firstWhere(
        (c) => c.isActive(settings),
        orElse: () => _lumaModels.first,
      );

  Future<void> _openMenu(BuildContext context) async {
    final luma = context.luma;
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    // The button's own rect, relative to the overlay — the same anchor
    // PopupMenuButton itself uses. showMenu positions the menu's top-left
    // here and then, if it would overflow the bottom of the window, shifts
    // the whole menu up just enough to stay on screen (see
    // _PopupMenuRouteLayout._fitInsideScreen in the framework) — that's what
    // makes it "expand upward" here, since the pill sits near the bottom.
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    PopupMenuItem<_ModelChoice> item(_ModelChoice choice) {
      final selected = choice.isActive(settings);
      final usageKey = modelUsageKeyFor(choice.providerId,
          mode: choice.mode == null ? null : aiModeById(choice.mode!));
      final count = settings.modelUsage[usageKey] ?? 0;
      final weight = kModelUsageEntries
          .firstWhere((e) => e.key == usageKey,
              orElse: () => const ModelUsageEntry('', '', 1))
          .weight;
      final usageLabel = count == 0
          ? 'Unused'
          : '$count msg${count == 1 ? '' : 's'}${weight > 1 ? ' ·×$weight' : ''}';
      return PopupMenuItem<_ModelChoice>(
        value: choice,
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: Text(
                choice.label,
                style: TextStyle(
                  color: selected ? luma.accent : luma.textPrimary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Text(usageLabel,
                style: TextStyle(color: luma.textMuted, fontSize: 10.5)),
            const SizedBox(width: 8),
            SizedBox(
              width: 16,
              child: selected
                  ? Icon(Icons.check_rounded, size: 16, color: luma.accent)
                  : null,
            ),
          ],
        ),
      );
    }

    PopupMenuItem<_ModelChoice> header(String text) =>
        PopupMenuItem<_ModelChoice>(
          enabled: false,
          height: 30,
          child: Text(
            text,
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        );

    final picked = await showMenu<_ModelChoice>(
      context: context,
      position: position,
      constraints: const BoxConstraints(minWidth: 270, maxWidth: 330),
      color: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: luma.border),
      ),
      items: [
        header('Models'),
        ..._lumaModels.map(item),
        const PopupMenuDivider(height: 10),
        header('API key'),
        ..._apiKeyModels.map(item),
      ],
    );

    if (picked == null) return;
    settings.setAiProviderId(picked.providerId);
    if (picked.mode != null) settings.setAiMode(picked.mode!);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openMenu(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: luma.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _active.label,
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.expand_less_rounded,
                  size: 13, color: luma.textMuted),
            ],
          ),
        ),
      ),
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
  const _NoKeyState({
    required this.settings,
    required this.onOpenSettings,
    required this.onRecheck,
  });

  final SettingsController settings;
  final VoidCallback onOpenSettings;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LumaEmptyState(
        icon: Icons.smart_toy_rounded,
        title: 'This model isn\'t available yet',
        subtitle:
            'Add your own API key in Settings to use it — stored locally on '
            'this device only — or switch to another model below.',
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
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
            const SizedBox(height: 12),
            _ModelSelector(settings: settings),
          ],
        ),
      ),
    );
  }
}
