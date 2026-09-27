import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../account/plan.dart';
import '../../app/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/settings_controller.dart';
import '../../settings/settings_scope.dart';
import '../../settings/sync_section.dart';
import '../../sync/sync_scope.dart';
import '../../sync/sync_service.dart';
import '../../theme/luma_theme.dart';
import '../plugins/installed/ai_usage/ai_usage_scope.dart';
import '../plugins/plugin_scope.dart';
import '../plugins/plugin_repository.dart';
import '../plugins/installed/qr_code_generator/qr_code_scope.dart';
import '../plugins/installed/calendar/calendar_scope.dart';
import '../plugins/installed/steam_tools/cs2_market_scope.dart';
import '../notes/notes_repository.dart';
import 'account/assistant_panels.dart';
import 'ai_agent_store.dart';
import 'ai_key_store.dart';
import 'local_model_store.dart';
import 'ai_tools.dart';
import 'web_search_client.dart';
import 'chat_controller.dart';
import 'chat_scope.dart';
import 'chat_usage.dart';
import 'memory/assistant_memory_scope.dart';
import 'providers/ai_modes.dart';
import 'providers/ai_providers.dart';
import 'providers/ai_usage.dart';
import 'providers/local_qwen_client.dart';
import 'data/chat_repository.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/chat_markdown.dart';
import 'widgets/chat_message_list.dart';
import 'widgets/chat_moon.dart';
import 'widgets/chat_usage_meter.dart';

const _wideBreakpoint = 760.0;

/// The AI Assistant tab: chats with the selected hosted provider or the
/// optional local model, with tool use for actions like installing a plugin
/// or generating a QR code on the user's behalf.
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.onOpenSettings,
    required this.onOpenPlugin,
    required this.onNavigate,
  });

  final VoidCallback onOpenSettings;
  final ValueChanged<String> onOpenPlugin;
  final ValueChanged<String> onNavigate;

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
    final memory = AssistantMemoryScope.maybeOf(context);
    return _controller ??= ChatController(
      repository: ChatScope.of(context),
      keyStore: keyStore,
      agentStore: agentStore,
      tools: AiToolRegistry(
        pluginRepository: PluginScope.of(context),
        qrCodeRepository: QrCodeScope.of(context),
        calendarRepository: CalendarScope.of(context),
        notesRepository: NotesRepository(),
        cs2MarketRepository: Cs2MarketScope.of(context),
        navigate: widget.onNavigate,
        memory: memory,
        webSearch: WebSearchClient(syncService: SyncScope.of(context)),
      ),
      settings: SettingsScope.of(context),
      syncService: SyncScope.of(context),
      aiUsage: AiUsageScope.maybeOf(context),
      memory: memory,
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncService = SyncScope.of(context);
    return ListenableBuilder(
      listenable: syncService,
      builder: (context, _) {
        if (!syncService.p2pReady &&
            SettingsScope.of(context).aiProviderId != AiProviderId.local.name) {
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
    if (_providerId == AiProviderId.local.name) {
      final installed = await LocalModelStore.instance.isInstalled;
      if (installed) widget.controller.warmUpLocalModel();
      return installed;
    }
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
    LocalModelStore.instance.addListener(_onLocalModelChanged);
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettingsChanged);
    LocalModelStore.instance.removeListener(_onLocalModelChanged);
    super.dispose();
  }

  void _onLocalModelChanged() {
    if (_providerId == AiProviderId.local.name) _recheckKey();
  }

  void _onSettingsChanged() {
    if (widget.settings.aiProviderId != _providerId) {
      // Hand the on-device model's RAM/VRAM back when switching away from it.
      if (_providerId == AiProviderId.local.name) LocalQwenClient.release();
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
            localModel: _providerId == AiProviderId.local.name,
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

/// The Claude-app arrangement of the assistant: a collapsible sidebar of
/// chats on the left (a drawer on phones), and a main pane with a slim title
/// bar over either the greeting screen (no chat picked) or the transcript,
/// with the composer centred at the bottom.
class _ChatLayout extends StatefulWidget {
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
  State<_ChatLayout> createState() => _ChatLayoutState();
}

class _ChatLayoutState extends State<_ChatLayout> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _homeText = TextEditingController();
  final _homeFocus = FocusNode();
  bool _sidebarOpen = true;

  /// The conversation a reply is being fetched for, so the thinking moon
  /// only shows in that chat even if the user wanders to another one.
  int? _pendingConversationId;

  @override
  void dispose() {
    _homeText.dispose();
    _homeFocus.dispose();
    super.dispose();
  }

  void _select(int? id) {
    _scaffoldKey.currentState?.closeDrawer();
    widget.onSelectConversation(id);
  }

  /// Sends [text] into [conversationId], or — from the greeting screen —
  /// into a brand-new chat, which is only created once there's something to
  /// put in it (so "New chat" never leaves empty conversations behind).
  Future<void> _send(int? conversationId, String text) async {
    final id =
        conversationId ?? await ChatScope.of(context).createConversation();
    if (conversationId == null) widget.onSelectConversation(id);
    setState(() => _pendingConversationId = id);
    try {
      await widget.controller.sendMessage(id, text);
    } finally {
      if (mounted) setState(() => _pendingConversationId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        final activeId = widget.activeConversationId;
        final sidebar = _Sidebar(
          activeConversationId: activeId,
          syncService: widget.syncService,
          onSelect: _select,
          onOpenPlugin: widget.onOpenPlugin,
          onCollapse: wide
              ? () => setState(() => _sidebarOpen = false)
              : () => _scaffoldKey.currentState?.closeDrawer(),
        );

        final composer = _ChatComposer(
          conversationId: activeId,
          onOpenPlugin: widget.onOpenPlugin,
          controller: widget.controller,
          keyStore: widget.keyStore,
          syncService: widget.syncService,
          settings: settings,
          textController: activeId == null ? _homeText : null,
          focusNode: activeId == null ? _homeFocus : null,
          hintText: activeId == null
              ? L.of(context).assistantHowCanIHelp
              : null,
          minLines: activeId == null ? 2 : 1,
          autofocus: true,
          onSend: (text) => _send(activeId, text),
        );

        final Widget body = activeId == null
            ? _HomeView(
                syncService: widget.syncService,
                composer: composer,
                onSuggestion: (prompt) {
                  _homeText.value = TextEditingValue(
                    text: prompt,
                    selection: TextSelection.collapsed(offset: prompt.length),
                  );
                  _homeFocus.requestFocus();
                },
              )
            : _ConversationThread(
                key: ValueKey(activeId),
                conversationId: activeId,
                thinking:
                    widget.controller.isSending &&
                    _pendingConversationId == activeId,
                composer: composer,
                onOpenPlugin: widget.onOpenPlugin,
              );

        final main = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TitleBar(
              activeConversationId: activeId,
              showSidebarButton: !wide || !_sidebarOpen,
              showNewChatButton: !wide || !_sidebarOpen,
              onToggleSidebar: wide
                  ? () => setState(() => _sidebarOpen = true)
                  : () => _scaffoldKey.currentState?.openDrawer(),
              onSelect: _select,
            ),
            Expanded(child: body),
          ],
        );

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.transparent,
          drawer: wide
              ? null
              : Drawer(
                  width: 300,
                  backgroundColor: context.luma.rail,
                  shape: const RoundedRectangleBorder(),
                  child: SafeArea(child: sidebar),
                ),
          body: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerLeft,
                      child: _sidebarOpen
                          ? SizedBox(
                              width: 264,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: context.luma.rail,
                                  border: Border(
                                    right: BorderSide(
                                      color: context.luma.border,
                                    ),
                                  ),
                                ),
                                child: sidebar,
                              ),
                            )
                          : const SizedBox(width: 0),
                    ),
                    Expanded(child: main),
                  ],
                )
              : main,
        );
      },
    );
  }
}

/// The chat sidebar: collapse toggle, "New chat", a search box, Starred and
/// Recents sections, and the signed-in account at the foot.
class _Sidebar extends StatefulWidget {
  const _Sidebar({
    required this.activeConversationId,
    required this.syncService,
    required this.onSelect,
    required this.onCollapse,
    required this.onOpenPlugin,
  });

  final int? activeConversationId;
  final SyncService syncService;
  final ValueChanged<int?> onSelect;
  final VoidCallback onCollapse;
  final ValueChanged<String> onOpenPlugin;

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ChatScope.of(context);
    final luma = context.luma;
    final t = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.assistantChats,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontFamily: chatSerifFamily,
                    fontFamilyFallback: chatSerifFallback,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _IconAction(
                icon: Icons.view_sidebar_outlined,
                tooltip: t.assistantToggleSidebar,
                onTap: widget.onCollapse,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _SidebarRow(
            onTap: () => widget.onSelect(null),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: luma.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 17,
                    color: luma.onAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  t.assistantNewChat,
                  style: TextStyle(
                    color: luma.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
          child: SizedBox(
            height: 36,
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              style: TextStyle(color: luma.textPrimary, fontSize: 13.5),
              cursorColor: luma.accent,
              decoration: InputDecoration(
                isDense: true,
                hintText: t.assistantSearchChats,
                hintStyle: TextStyle(color: luma.textMuted, fontSize: 13.5),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: luma.textMuted,
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                filled: true,
                fillColor: luma.background.withValues(alpha: 0.6),
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamData<List<ChatConversationRecord>>(
            stream: repo.watchConversations(),
            builder: (context, conversations) {
              final visible = _query.isEmpty
                  ? conversations
                  : conversations
                        .where((c) => c.title.toLowerCase().contains(_query))
                        .toList();
              if (visible.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _query.isEmpty ? t.assistantNoChats : t.assistantNoMatches,
                    style: TextStyle(color: luma.textMuted, fontSize: 13),
                  ),
                );
              }
              final starred = visible.where((c) => c.pinned).toList();
              final recents = visible.where((c) => !c.pinned).toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                children: [
                  if (starred.isNotEmpty) ...[
                    _SectionLabel(t.assistantStarred),
                    for (final c in starred) _tile(c),
                    const SizedBox(height: 10),
                  ],
                  if (recents.isNotEmpty) ...[
                    _SectionLabel(t.assistantRecents),
                    for (final c in recents) _tile(c),
                  ],
                ],
              );
            },
          ),
        ),
        Divider(height: 1, color: luma.border),
        _AccountFooter(
          syncService: widget.syncService,
          onOpenPlugin: widget.onOpenPlugin,
        ),
      ],
    );
  }

  Widget _tile(ChatConversationRecord c) => _ConversationTile(
    conversation: c,
    selected: c.id == widget.activeConversationId,
    onTap: () => widget.onSelect(c.id),
    onMenu: (position) => _showConversationMenu(
      context,
      position,
      c,
      activeConversationId: widget.activeConversationId,
      onSelect: widget.onSelect,
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Text(
        text,
        style: TextStyle(
          color: context.luma.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// A hoverable, rounded sidebar row.
class _SidebarRow extends StatefulWidget {
  const _SidebarRow({
    required this.child,
    required this.onTap,
    this.selected = false,
    this.onSecondaryTap,
    this.onLongPress,
    this.onHover,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool selected;
  final void Function(Offset globalPosition)? onSecondaryTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onHover;

  @override
  State<_SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<_SidebarRow> {
  bool _hovering = false;

  void _setHover(bool value) {
    setState(() => _hovering = value);
    widget.onHover?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onSecondaryTapDown: widget.onSecondaryTap == null
            ? null
            : (d) => widget.onSecondaryTap!(d.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? luma.surfaceHover
                : _hovering
                ? luma.surfaceHover.withValues(alpha: 0.6)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
    required this.onMenu,
  });

  final ChatConversationRecord conversation;
  final bool selected;
  final VoidCallback onTap;

  /// Opens the rename/star/delete menu; null anchors it mid-screen.
  final void Function(Offset? globalPosition) onMenu;

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final showMenuButton = _hovering || widget.selected;
    return _SidebarRow(
      selected: widget.selected,
      onTap: widget.onTap,
      onHover: (v) => setState(() => _hovering = v),
      onLongPress: () => widget.onMenu(null),
      onSecondaryTap: widget.onMenu,
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.conversation.title,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                color: widget.selected ? luma.textPrimary : luma.textSecondary,
                fontSize: 13.5,
                fontWeight: widget.selected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
          if (showMenuButton)
            Builder(
              builder: (buttonContext) => _IconAction(
                icon: Icons.more_horiz_rounded,
                size: 26,
                onTap: () {
                  final box = buttonContext.findRenderObject()! as RenderBox;
                  widget.onMenu(
                    box.localToGlobal(box.size.bottomLeft(Offset.zero)),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// The signed-in account at the bottom of the sidebar: an initial avatar,
/// the account name, plan and email. Clicking it opens the account menu —
/// Usage, Settings and Agents — upward from the footer, as in the Claude app.
class _AccountFooter extends StatefulWidget {
  const _AccountFooter({required this.syncService, required this.onOpenPlugin});
  final SyncService syncService;
  final ValueChanged<String> onOpenPlugin;

  @override
  State<_AccountFooter> createState() => _AccountFooterState();
}

class _AccountFooterState extends State<_AccountFooter> {
  bool _hovering = false;

  void _openMenu() {
    final box = context.findRenderObject()! as RenderBox;
    showAssistantAccountMenu(
      context,
      footerRect: box.localToGlobal(Offset.zero) & box.size,
      email: widget.syncService.email,
      onOpenPlugin: widget.onOpenPlugin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final email = widget.syncService.email;
    final name = _displayName(context, widget.syncService) ?? 'luma';
    final plan = planById(SettingsScope.of(context).selectedPlanId);
    return Padding(
      padding: const EdgeInsets.all(6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _openMenu,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
            decoration: BoxDecoration(
              color: _hovering
                  ? luma.surfaceHover.withValues(alpha: 0.6)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: luma.accentSubtle,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    name.characters.first.toUpperCase(),
                    style: TextStyle(
                      color: luma.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        email == null ? plan.name : '${plan.name} · $email',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 17,
                  color: luma.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The name for the greeting and account footer: what the user asked to be
/// called in the assistant's settings, else a best-effort first name — the
/// OS user name on desktop, otherwise the letters leading the account email.
String? _displayName(BuildContext context, SyncService syncService) {
  final callMe = AssistantMemoryScope.maybeOf(context)?.profile.callMe.trim();
  if (callMe != null && callMe.isNotEmpty) return callMe;
  String? raw;
  try {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      raw = Platform.environment['USERNAME'] ?? Platform.environment['USER'];
    }
  } catch (_) {
    raw = null;
  }
  raw ??= syncService.email?.split('@').first;
  final match = RegExp(r'^[A-Za-zÀ-ɏ]+').firstMatch(raw ?? '');
  final word = match?.group(0);
  if (word == null || word.isEmpty) return null;
  return word[0].toUpperCase() + word.substring(1).toLowerCase();
}

/// Small square icon button in the sidebar/title bar style.
class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 32,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      iconSize: size * 0.56,
      color: luma.textSecondary,
      style: IconButton.styleFrom(
        minimumSize: Size.square(size),
        maximumSize: Size.square(size),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon),
    );
  }
}

/// The slim bar over the main pane: the sidebar/new-chat buttons when the
/// sidebar is hidden, and the open chat's title as a dropdown for star,
/// rename and delete.
class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.activeConversationId,
    required this.showSidebarButton,
    required this.showNewChatButton,
    required this.onToggleSidebar,
    required this.onSelect,
  });

  final int? activeConversationId;
  final bool showSidebarButton;
  final bool showNewChatButton;
  final VoidCallback onToggleSidebar;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final repo = ChatScope.of(context);
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            if (showSidebarButton)
              _IconAction(
                icon: Icons.view_sidebar_outlined,
                tooltip: t.assistantToggleSidebar,
                onTap: onToggleSidebar,
              ),
            if (showNewChatButton && activeConversationId != null)
              _IconAction(
                icon: Icons.edit_square,
                tooltip: t.assistantNewChat,
                onTap: () => onSelect(null),
              ),
            const SizedBox(width: 6),
            if (activeConversationId != null)
              Flexible(
                child: StreamBuilder<List<ChatConversationRecord>>(
                  stream: repo.watchConversations(),
                  builder: (context, snap) {
                    final c = snap.data
                        ?.where((c) => c.id == activeConversationId)
                        .firstOrNull;
                    if (c == null) return const SizedBox.shrink();
                    return Builder(
                      builder: (anchorContext) => TextButton(
                        onPressed: () {
                          final box =
                              anchorContext.findRenderObject()! as RenderBox;
                          _showConversationMenu(
                            context,
                            box.localToGlobal(box.size.bottomLeft(Offset.zero)),
                            c,
                            activeConversationId: activeConversationId,
                            onSelect: onSelect,
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: luma.textPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (c.pinned) ...[
                              Icon(
                                Icons.star_rounded,
                                size: 15,
                                color: luma.accent,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                c.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: luma.textMuted,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The greeting screen shown for a new chat: the moon and a time-of-day
/// greeting in serif, the composer in the middle of the page, and a row of
/// suggestion chips that prefill it.
class _HomeView extends StatelessWidget {
  const _HomeView({
    required this.syncService,
    required this.composer,
    required this.onSuggestion,
  });

  final SyncService syncService;
  final Widget composer;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final name = _displayName(context, syncService);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? (name == null
              ? t.assistantGreetingMorning
              : t.assistantGreetingMorningName(name))
        : hour < 18
        ? (name == null
              ? t.assistantGreetingAfternoon
              : t.assistantGreetingAfternoonName(name))
        : (name == null
              ? t.assistantGreetingEvening
              : t.assistantGreetingEveningName(name));

    final suggestions = [
      (
        Icons.extension_rounded,
        t.assistantSuggestPlugin,
        t.assistantSuggestPluginPrompt,
      ),
      (
        Icons.qr_code_2_rounded,
        t.assistantSuggestQr,
        t.assistantSuggestQrPrompt,
      ),
      (
        Icons.calendar_month_rounded,
        t.assistantSuggestWeek,
        t.assistantSuggestWeekPrompt,
      ),
      (
        Icons.sticky_note_2_rounded,
        t.assistantSuggestNote,
        t.assistantSuggestNotePrompt,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const ChatMoon(size: 40),
                      const SizedBox(width: 14),
                      Flexible(
                        child: Text(
                          greeting,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontFamily: chatSerifFamily,
                            fontFamilyFallback: chatSerifFallback,
                            fontSize: constraints.maxWidth < 500 ? 28 : 36,
                            fontWeight: FontWeight.w400,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  composer,
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (icon, label, prompt) in suggestions)
                        _SuggestionChip(
                          icon: icon,
                          label: label,
                          onTap: () => onSuggestion(prompt),
                        ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatefulWidget {
  const _SuggestionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_SuggestionChip> createState() => _SuggestionChipState();
}

class _SuggestionChipState extends State<_SuggestionChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovering
                ? luma.surfaceHover
                : luma.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: luma.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: luma.textSecondary),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: _hovering ? luma.textPrimary : luma.textSecondary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rename / star / delete for a conversation, from the sidebar's "…"
/// button, a right-click or long-press, or the title-bar dropdown.
/// [globalPosition] anchors the menu; null centres it in the overlay.
Future<void> _showConversationMenu(
  BuildContext context,
  Offset? globalPosition,
  ChatConversationRecord c, {
  required int? activeConversationId,
  required ValueChanged<int?> onSelect,
}) async {
  final luma = context.luma;
  final t = L.of(context);
  final repo = ChatScope.of(context);
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final anchor = globalPosition == null
      ? overlay.size.center(Offset.zero)
      : overlay.globalToLocal(globalPosition);
  final position = RelativeRect.fromRect(
    Rect.fromPoints(anchor, anchor),
    Offset.zero & overlay.size,
  );

  PopupMenuItem<String> item(
    String value,
    IconData icon,
    String label, {
    Color? color,
  }) => PopupMenuItem(
    value: value,
    height: 38,
    child: Row(
      children: [
        Icon(icon, size: 17, color: color ?? luma.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(color: color ?? luma.textPrimary, fontSize: 13.5),
        ),
      ],
    ),
  );

  final action = await showMenu<String>(
    context: context,
    position: position,
    color: luma.surface,
    constraints: const BoxConstraints(minWidth: 180),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: luma.border),
    ),
    items: [
      item(
        'pin',
        c.pinned ? Icons.star_rounded : Icons.star_outline_rounded,
        c.pinned ? t.assistantUnstar : t.assistantStar,
      ),
      item('rename', Icons.edit_outlined, t.assistantRename),
      item(
        'delete',
        Icons.delete_outline_rounded,
        t.assistantDelete,
        color: luma.danger,
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
      _confirmDelete(
        context,
        c,
        activeConversationId: activeConversationId,
        onSelect: onSelect,
      );
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
      title: Text(
        'Rename conversation',
        style: TextStyle(color: luma.textPrimary),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: TextStyle(color: luma.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: luma.background,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
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

void _confirmDelete(
  BuildContext context,
  ChatConversationRecord c, {
  required int? activeConversationId,
  required ValueChanged<int?> onSelect,
}) {
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
      title: Text(
        'Delete "${c.title}"?',
        style: TextStyle(color: luma.textPrimary),
      ),
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

class _ConversationThread extends StatelessWidget {
  const _ConversationThread({
    super.key,
    required this.conversationId,
    required this.thinking,
    required this.composer,
    required this.onOpenPlugin,
  });

  final int conversationId;
  final bool thinking;
  final Widget composer;
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
            thinking: thinking,
            onOpenQrPlugin: () => onOpenPlugin('qr-code-generator'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: chatColumnWidth),
              child: composer,
            ),
          ),
        ),
      ],
    );
  }
}

/// The composer wired to the active provider: the text field, then — like
/// the Claude app's footer — the model picker and a usage ring beside the
/// send button. The ring shows how full the conversation's context window
/// is; its panel adds the provider's limits: the Luma AI token budgets from
/// the sync server, the local daily counter for a user's own API key, or
/// nothing at all for the on-device model.
class _ChatComposer extends StatefulWidget {
  const _ChatComposer({
    required this.conversationId,
    required this.controller,
    required this.keyStore,
    required this.syncService,
    required this.settings,
    required this.onSend,
    required this.onOpenPlugin,
    this.textController,
    this.focusNode,
    this.hintText,
    this.minLines = 1,
    this.autofocus = false,
  });

  /// Null on the greeting screen, before the chat exists.
  final int? conversationId;
  final ChatController controller;
  final AiKeyStore keyStore;
  final SyncService syncService;
  final SettingsController settings;
  final ValueChanged<String> onSend;
  final ValueChanged<String> onOpenPlugin;
  final TextEditingController? textController;
  final FocusNode? focusNode;
  final String? hintText;
  final int minLines;
  final bool autofocus;

  @override
  State<_ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<_ChatComposer> {
  static const _aiUsagePluginId = 'ai-usage';

  List<ChatUsageLimit> _limits = const [];
  String? _limitsNote;
  bool _blocked = false;
  bool _wasSending = false;
  bool _usagePluginInstalled = false;
  Stream<List<ChatMessageRecord>>? _messages;
  StreamSubscription<List<InstalledPluginRecord>>? _installedSub;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.settings.addListener(_refreshUsage);
    LocalModelStore.instance.addListener(_refreshUsage);
    _refreshUsage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messages ??= _watchMessages();
    _installedSub ??= PluginScope.of(context).watchInstalled().listen((all) {
      final installed = all.any((p) => p.pluginId == _aiUsagePluginId);
      if (installed != _usagePluginInstalled && mounted) {
        setState(() => _usagePluginInstalled = installed);
      }
    });
  }

  @override
  void didUpdateWidget(_ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _messages = _watchMessages();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.settings.removeListener(_refreshUsage);
    LocalModelStore.instance.removeListener(_refreshUsage);
    _installedSub?.cancel();
    super.dispose();
  }

  Stream<List<ChatMessageRecord>>? _watchMessages() {
    final id = widget.conversationId;
    return id == null ? null : ChatScope.of(context).watchMessages(id);
  }

  void _onControllerChanged() {
    // Refresh the limits when a send finishes (isSending true→false).
    final sending = widget.controller.isSending;
    if (_wasSending && !sending) _refreshUsage();
    _wasSending = sending;
  }

  Future<void> _refreshUsage() async {
    final t = L.of(context);
    final settings = widget.settings;
    final providerId = settings.aiProviderId;
    List<ChatUsageLimit> limits = const [];
    String? note;
    bool blocked;

    if (providerId == AiProviderId.local.name) {
      blocked = !await LocalModelStore.instance.isInstalled;
      note = t.assistantNoLimits;
    } else if (providerId == AiProviderId.google.name &&
        await widget.keyStore.readKey(providerId) == null) {
      final status = await widget.syncService.aiStatus();
      if (status == null) {
        note = t.assistantUsageUnavailable;
        blocked = false;
      } else {
        limits = [
          ChatUsageLimit(
            label: t.assistantFiveHourLimit,
            detail: '${status.fiveHourPct}%',
            fraction: status.fiveHourPct / 100,
          ),
          ChatUsageLimit(
            label: t.assistantWeeklyLimit,
            detail: '${status.weeklyPct}%',
            fraction: status.weeklyPct / 100,
          ),
        ];
        blocked = status.fiveHourPct >= 100 || status.weeklyPct >= 100;
      }
    } else {
      final limit = settings.aiDailyCallLimit;
      final used = limit - settings.aiCallsRemainingToday;
      limits = [
        ChatUsageLimit(
          label: t.assistantDailyMessages,
          detail: t.assistantMessagesOf(used, limit),
          fraction: used / limit,
        ),
      ];
      blocked = used >= limit;
    }

    if (!mounted) return;
    setState(() {
      _limits = limits;
      _limitsNote = note;
      _blocked = blocked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final t = L.of(context);
    final providerId = settings.aiProviderId;
    final meter = StreamBuilder<List<ChatMessageRecord>>(
      stream: _messages,
      builder: (context, snap) => ChatUsageMeter(
        contextWindow: contextWindowFor(providerId),
        lastReply: snap.data == null ? null : ChatReplyUsage.latest(snap.data!),
        limits: _limits,
        limitsTitle:
            '${t.assistantUsageLimits} · ${aiProviderById(providerId).displayName}',
        limitsNote: _limitsNote,
        onOpenBreakdown: _usagePluginInstalled
            ? () => widget.onOpenPlugin(_aiUsagePluginId)
            : null,
      ),
    );
    return ChatInputBar(
      sending: widget.controller.isSending,
      enabled: !_blocked,
      caption: '',
      modelSelector: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModelSelector(settings: settings),
          meter,
        ],
      ),
      controller: widget.textController,
      focusNode: widget.focusNode,
      hintText: widget.hintText,
      minLines: widget.minLines,
      autofocus: widget.autofocus,
      onSend: widget.onSend,
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
      'Luma ${mode.displayName}',
      AiProviderId.google.name,
      mode.name,
    ),
  if (LocalModelStore.supported)
    _ModelChoice('Luma Assistant', AiProviderId.local.name),
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

  _ModelChoice get _active => [
    ..._lumaModels,
    ..._apiKeyModels,
  ].firstWhere((c) => c.isActive(settings), orElse: () => _lumaModels.first);

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
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    PopupMenuItem<_ModelChoice> item(_ModelChoice choice) {
      final selected = choice.isActive(settings);
      final usageKey = modelUsageKeyFor(
        choice.providerId,
        mode: choice.mode == null ? null : aiModeById(choice.mode!),
      );
      final count = settings.modelUsage[usageKey] ?? 0;
      final weight = kModelUsageEntries
          .firstWhere(
            (e) => e.key == usageKey,
            orElse: () => const ModelUsageEntry('', '', 1),
          )
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
            Text(
              usageLabel,
              style: TextStyle(color: luma.textMuted, fontSize: 10.5),
            ),
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
    return TextButton(
      onPressed: () => _openMenu(context),
      style: TextButton.styleFrom(
        foregroundColor: luma.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _active.label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 17,
            color: luma.textMuted,
          ),
        ],
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
          title: "The assistant wouldn't wake up",
          subtitle: '$error',
        ),
      ),
    );
  }
}

class _NoKeyState extends StatelessWidget {
  const _NoKeyState({
    required this.settings,
    required this.localModel,
    required this.onOpenSettings,
    required this.onRecheck,
  });

  final SettingsController settings;
  final bool localModel;
  final VoidCallback onOpenSettings;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    if (localModel) {
      final store = LocalModelStore.instance;
      return Center(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => LumaEmptyState(
            icon: Icons.smart_toy_rounded,
            title: 'Download Luma Assistant',
            subtitle: !LocalModelStore.supported
                ? 'The on-device model is not available on this platform.'
                : store.isDownloading
                ? 'Downloading Qwen3.5-0.8B (${LocalModelStore.modelSizeLabel})…'
                : 'Download Qwen3.5-0.8B (${LocalModelStore.modelSizeLabel}) to start chatting. It runs on this device.',
            action: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!LocalModelStore.supported) ...[
                  const Text('Choose another model from the selector below.'),
                ] else if (store.isDownloading) ...[
                  SizedBox(
                    width: 280,
                    child: LinearProgressIndicator(value: store.progress),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    store.progress == null
                        ? 'Downloading model…'
                        : '${(store.progress! * 100).toStringAsFixed(0)}%',
                  ),
                ] else
                  LumaPrimaryButton(
                    label: 'Download model',
                    icon: Icons.download_rounded,
                    onTap: () async {
                      await store.download();
                      onRecheck();
                    },
                  ),
                if (store.error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Download failed: ${store.error}',
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 12),
                _ModelSelector(settings: settings),
              ],
            ),
          ),
        ),
      );
    }
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
