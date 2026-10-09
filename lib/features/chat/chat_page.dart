import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../account/plan.dart';
import '../../app/widgets.dart';
import '../../finance/finance_scope.dart';
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
import 'ai_key_store.dart';
import 'assistant_compose_mode.dart';
import 'assistant_files.dart';
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
import 'widgets/compose_mode_menu.dart';
import 'widgets/assistant_projects_view.dart';
import 'widgets/assistant_artifacts_view.dart';

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
  late final Future<AiKeyStore> _storesFuture = _loadKeyStore();
  ChatController? _controller;
  int? _activeConversationId;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  static Future<AiKeyStore> _loadKeyStore() {
    return AiKeyStore.load();
  }

  ChatController _controllerFor(AiKeyStore keyStore) {
    final memory = AssistantMemoryScope.maybeOf(context);
    return _controller ??= ChatController(
      repository: ChatScope.of(context),
      keyStore: keyStore,
      tools: AiToolRegistry(
        pluginRepository: PluginScope.of(context),
        qrCodeRepository: QrCodeScope.of(context),
        calendarRepository: CalendarScope.of(context),
        notesRepository: NotesRepository(),
        cs2MarketRepository: Cs2MarketScope.of(context),
        financeRepository: FinanceScope.of(context),
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
        return FutureBuilder<AiKeyStore>(
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
            final keyStore = snap.data!;
            final controller = _controllerFor(keyStore);
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
    final t = L.of(context);
    return Center(
      child: LumaEmptyState(
        icon: Icons.person_add_rounded,
        title: t.assistantNeedsAccountTitle,
        subtitle: t.assistantNeedsAccountBody,
        action: LumaPrimaryButton(
          label: t.assistantSetUpAccount,
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
        return AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) => _ChatLayout(
            controller: widget.controller,
            keyStore: widget.keyStore,
            syncService: widget.syncService,
            activeConversationId: widget.activeConversationId,
            onSelectConversation: widget.onSelectConversation,
            onOpenPlugin: widget.onOpenPlugin,
            chatUnavailable: snap.data == true
                ? null
                : _NoKeyState(
                    settings: widget.settings,
                    localModel: _providerId == AiProviderId.local.name,
                    onOpenSettings: widget.onOpenSettings,
                    onRecheck: _recheckKey,
                  ),
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
    this.chatUnavailable,
  });

  final ChatController controller;
  final AiKeyStore keyStore;
  final SyncService syncService;
  final int? activeConversationId;
  final ValueChanged<int?> onSelectConversation;
  final ValueChanged<String> onOpenPlugin;
  final Widget? chatUnavailable;

  @override
  State<_ChatLayout> createState() => _ChatLayoutState();
}

class _ChatLayoutState extends State<_ChatLayout> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _homeText = TextEditingController();
  final _homeFocus = FocusNode();
  bool _sidebarOpen = true;
  String _view = 'chat';
  int? _projectId;
  String? _artifactType;
  final List<AssistantAttachment> _attachments = [];
  int _selectionRevision = 0;

  /// The + menu mode, kept here so it survives the greeting screen turning
  /// into the new chat's thread.
  AssistantComposeMode _composeMode = AssistantComposeMode.chat;

  /// Pictures require Orbit or Nova. Plan/research require Nova, with
  /// research restricted to the models that can run it.
  AssistantComposeMode _effectiveComposeMode(SettingsController settings) {
    if (_composeMode == AssistantComposeMode.picture &&
        assistantFilesAllowed(settings.selectedPlanId)) {
      return _composeMode;
    }
    if (!composeModesUnlocked(settings.selectedPlanId)) {
      return AssistantComposeMode.chat;
    }
    if (_composeMode == AssistantComposeMode.deepResearch &&
        !deepResearchAvailable(settings.aiProviderId, settings.aiMode)) {
      return AssistantComposeMode.chat;
    }
    return _composeMode;
  }

  /// The conversation a reply is being fetched for, so the thinking moon
  /// only shows in that chat even if the user wanders to another one.
  int? _pendingConversationId;

  @override
  void dispose() {
    _homeText.dispose();
    _homeFocus.dispose();
    super.dispose();
  }

  Future<void> _select(int? id) async {
    final revision = ++_selectionRevision;
    _scaffoldKey.currentState?.closeDrawer();
    widget.onSelectConversation(id);
    setState(() {
      _view = 'chat';
      _attachments.clear();
      _projectId = null;
    });
    if (id != null) {
      final project = await ChatScope.of(context).projectForConversation(id);
      if (mounted && revision == _selectionRevision) {
        setState(() => _projectId = project?.id);
      }
    }
  }

  void _openProjects([int? id]) {
    _selectionRevision++;
    _scaffoldKey.currentState?.closeDrawer();
    setState(() {
      _view = 'projects';
      _projectId = id;
      _attachments.clear();
    });
  }

  void _newProjectChat(int id) {
    _selectionRevision++;
    widget.onSelectConversation(null);
    setState(() {
      _view = 'chat';
      _projectId = id;
      _attachments.clear();
    });
  }

  Future<void> _upload() async {
    final settings = SettingsScope.of(context);
    if (!assistantFilesAllowed(settings.selectedPlanId)) return;
    final supportsImages = await widget.controller.supportsImageInput();
    if (!mounted) return;
    final picked = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        ...AssistantAttachment.textExtensions,
        if (supportsImages) ...AssistantAttachment.imageExtensions,
      ],
    );
    if (picked == null || !mounted) return;
    try {
      if (_attachments.length + picked.files.length > 3) {
        throw const FormatException('Choose up to three attachments.');
      }
      final loaded = <AssistantAttachment>[];
      for (final file in picked.files) {
        if (file.path == null) {
          throw const FormatException('This file could not be opened.');
        }
        loaded.add(await AssistantAttachment.fromFile(File(file.path!)));
      }
      if (mounted && assistantFilesAllowed(settings.selectedPlanId)) {
        setState(() => _attachments.addAll(loaded));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  /// Sends [text] into [conversationId], or — from the greeting screen —
  /// into a brand-new chat, which is only created once there's something to
  /// put in it (so "New chat" never leaves empty conversations behind).
  Future<void> _send(int? conversationId, String text) async {
    if (widget.controller.isSending) return;
    final settings = SettingsScope.of(context);
    final mode = _effectiveComposeMode(settings);
    final id =
        conversationId ??
        await ChatScope.of(context).createConversation(projectId: _projectId);
    if (!mounted) return;
    if (conversationId == null) widget.onSelectConversation(id);
    setState(() => _pendingConversationId = id);
    try {
      await widget.controller.sendMessage(
        id,
        text,
        mode: mode,
        artifactType: assistantFilesAllowed(settings.selectedPlanId)
            ? _artifactType
            : null,
        attachments: assistantFilesAllowed(settings.selectedPlanId)
            ? List.of(_attachments)
            : const [],
      );
      if (mounted) setState(() => _attachments.clear());
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
        final sidebar = AssistantSidebar(
          activeConversationId: activeId,
          syncService: widget.syncService,
          onSelect: _select,
          onOpenPlugin: widget.onOpenPlugin,
          onProjects: () => _openProjects(),
          onArtifacts: () {
            _scaffoldKey.currentState?.closeDrawer();
            setState(() => _view = 'artifacts');
          },
          selectedView: _view,
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
          composeMode: _effectiveComposeMode(settings),
          onComposeModeChanged: (mode) => setState(() => _composeMode = mode),
          onSend: (text) => _send(activeId, text),
          artifactType: assistantFilesAllowed(settings.selectedPlanId)
              ? _artifactType
              : null,
          onArtifactTypeChanged: (type) => setState(() => _artifactType = type),
          attachments: assistantFilesAllowed(settings.selectedPlanId)
              ? _attachments
              : const [],
          onRemoveAttachment: (a) => setState(() => _attachments.remove(a)),
          onUpload: _upload,
        );

        final Widget body = _view == 'projects'
            ? AssistantProjectsView(
                repository: ChatScope.of(context),
                projectId: _projectId,
                onOpenProject: _openProjects,
                onOpenChat: _select,
                onNewChat: _newProjectChat,
              )
            : _view == 'artifacts'
            ? AssistantArtifactsView(
                repository: ChatScope.of(context),
                onOpenChat: _select,
              )
            : widget.chatUnavailable ??
                  (activeId == null
                      ? _HomeView(
                          syncService: widget.syncService,
                          composer: composer,
                          onSuggestion: (prompt) {
                            _homeText.value = TextEditingValue(
                              text: prompt,
                              selection: TextSelection.collapsed(
                                offset: prompt.length,
                              ),
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
                          draft: widget.controller.draftReply,
                          activity: widget.controller.activity,
                          composer: composer,
                          onOpenPlugin: widget.onOpenPlugin,
                        ));

        final main = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TitleBar(
              activeConversationId: _view == 'chat' ? activeId : null,
              showSidebarButton: !wide || !_sidebarOpen,
              showNewChatButton: !wide || !_sidebarOpen,
              onToggleSidebar: wide
                  ? () => setState(() => _sidebarOpen = true)
                  : () => _scaffoldKey.currentState?.openDrawer(),
              onSelect: _select,
            ),
            if (_view == 'chat' && _projectId != null)
              StreamBuilder<List<ChatProjectRecord>>(
                stream: ChatScope.of(context).watchProjects(),
                builder: (context, snap) {
                  final project = snap.data
                      ?.where((p) => p.id == _projectId)
                      .firstOrNull;
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: TextButton.icon(
                        onPressed: () => _openProjects(_projectId),
                        icon: const Icon(Icons.folder_outlined, size: 16),
                        label: Text(project?.name ?? 'Project'),
                      ),
                    ),
                  );
                },
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
class AssistantSidebar extends StatefulWidget {
  const AssistantSidebar({
    super.key,
    required this.activeConversationId,
    required this.syncService,
    required this.onSelect,
    required this.onCollapse,
    required this.onOpenPlugin,
    required this.onProjects,
    required this.onArtifacts,
    required this.selectedView,
  });

  final int? activeConversationId;
  final SyncService syncService;
  final ValueChanged<int?> onSelect;
  final VoidCallback onCollapse;
  final ValueChanged<String> onOpenPlugin;
  final VoidCallback onProjects;
  final VoidCallback onArtifacts;
  final String selectedView;

  @override
  State<AssistantSidebar> createState() => _SidebarState();
}

class _SidebarState extends State<AssistantSidebar> {
  final _search = TextEditingController();
  String _query = '';
  bool _moreOpen = false;

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
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
          child: Row(
            children: [
              _IconAction(
                icon: Icons.menu_rounded,
                tooltip: t.assistantToggleSidebar,
                onTap: widget.onCollapse,
              ),
              _IconAction(
                icon: Icons.view_sidebar_outlined,
                tooltip: t.assistantToggleSidebar,
                onTap: widget.onCollapse,
              ),
              const Spacer(),
            ],
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            children: [
              _navigation(
                Icons.add_circle_outline_rounded,
                'New',
                () => widget.onSelect(null),
              ),
              _navigation(
                Icons.folder_outlined,
                'Projects',
                widget.onProjects,
                selected: widget.selectedView == 'projects',
              ),
              _navigation(
                Icons.category_outlined,
                'Artifacts',
                widget.onArtifacts,
                selected: widget.selectedView == 'artifacts',
              ),
              _navigation(
                Icons.work_outline_rounded,
                'Customize',
                () => showAssistantPanel(
                  context,
                  AssistantPanel.settings,
                  onOpenPlugin: widget.onOpenPlugin,
                ),
              ),
              _navigation(
                _moreOpen
                    ? Icons.expand_more_rounded
                    : Icons.chevron_right_rounded,
                'More',
                () => setState(() => _moreOpen = !_moreOpen),
              ),
              if (_moreOpen) ...[
                _navigation(
                  Icons.data_usage_rounded,
                  t.assistantMenuUsage,
                  () => showAssistantPanel(
                    context,
                    AssistantPanel.usage,
                    onOpenPlugin: widget.onOpenPlugin,
                  ),
                ),
                _navigation(
                  Icons.smart_toy_outlined,
                  t.assistantMenuAgents,
                  () => showAssistantPanel(
                    context,
                    AssistantPanel.agents,
                    onOpenPlugin: widget.onOpenPlugin,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              StreamData<List<ChatConversationRecord>>(
                stream: repo.watchConversations(query: _query),
                builder: (context, conversations) {
                  final visible = _query.isEmpty
                      ? conversations.where((c) => c.projectId == null).toList()
                      : conversations;
                  if (visible.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _query.isEmpty
                            ? t.assistantNoChats
                            : t.assistantNoMatches,
                        style: TextStyle(color: luma.textMuted, fontSize: 13),
                      ),
                    );
                  }
                  final starred = visible.where((c) => c.pinned).toList();
                  final recents = visible.where((c) => !c.pinned).toList();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    ),
                  );
                },
              ),
            ],
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

  Widget _navigation(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool selected = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: _SidebarRow(
      onTap: onTap,
      selected: selected,
      child: Row(
        children: [
          Icon(icon, size: 19, color: context.luma.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: context.luma.textPrimary, fontSize: 14),
          ),
        ],
      ),
    ),
  );

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
      item('project', Icons.drive_file_move_outlined, 'Move to project'),
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
    case 'project':
      final projects = await repo.watchProjects().first;
      if (!context.mounted) return;
      final selected = await showDialog<int>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Move chat'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, -1),
              child: const Text('Main chats'),
            ),
            for (final project in projects)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, project.id),
                child: Text(project.name),
              ),
            if (projects.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Create a project from Projects first.'),
              ),
          ],
        ),
      );
      if (selected != null) {
        await repo.moveConversation(c.id, selected == -1 ? null : selected);
        if (c.id == activeConversationId) onSelect(c.id);
      }
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
  final t = L.of(context);
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
        t.assistantRenameTitle,
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
          child: Text(
            t.commonCancel,
            style: TextStyle(color: luma.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () {
            final trimmed = controller.text.trim();
            if (trimmed.isNotEmpty) repo.renameConversation(c.id, trimmed);
            Navigator.of(dialogContext).pop();
          },
          child: Text(t.commonSave, style: TextStyle(color: luma.accent)),
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
  final t = L.of(context);
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
        t.assistantDeleteTitle(c.title),
        style: TextStyle(color: luma.textPrimary),
      ),
      content: Text(
        t.assistantDeleteBody,
        style: TextStyle(color: luma.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(
            t.commonCancel,
            style: TextStyle(color: luma.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () {
            repo.deleteConversation(c.id);
            if (c.id == activeConversationId) onSelect(null);
            Navigator.of(dialogContext).pop();
          },
          child: Text(t.commonDelete, style: TextStyle(color: luma.danger)),
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
    required this.draft,
    required this.activity,
    required this.composer,
    required this.onOpenPlugin,
  });

  final int conversationId;
  final bool thinking;
  final ValueListenable<String> draft;
  final ValueListenable<AssistantActivity?> activity;
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
            draft: draft,
            activity: activity,
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
    required this.composeMode,
    required this.onComposeModeChanged,
    required this.artifactType,
    required this.onArtifactTypeChanged,
    required this.attachments,
    required this.onRemoveAttachment,
    required this.onUpload,
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
  final AssistantComposeMode composeMode;
  final ValueChanged<AssistantComposeMode> onComposeModeChanged;
  final String? artifactType;
  final ValueChanged<String?> onArtifactTypeChanged;
  final List<AssistantAttachment> attachments;
  final ValueChanged<AssistantAttachment> onRemoveAttachment;
  final VoidCallback onUpload;
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
        final modeUsage = status.usageFor(settings.aiMode);
        limits = [
          ChatUsageLimit(
            label: t.assistantFiveHourLimit,
            detail: '${modeUsage.fiveHourPct}%',
            fraction: modeUsage.fiveHourPct / 100,
          ),
          ChatUsageLimit(
            label: t.assistantWeeklyLimit,
            detail: '${modeUsage.weeklyPct}%',
            fraction: modeUsage.weeklyPct / 100,
          ),
        ];
        blocked = modeUsage.fiveHourPct >= 100 || modeUsage.weeklyPct >= 100;
      }
    } else {
      note = t.assistantUsageUnlimited;
      blocked = false;
    }

    if (!mounted) return;
    setState(() {
      _limits = limits;
      _limitsNote = note;
      _blocked = blocked;
    });
  }

  Future<ComposeModeAvailability> _composeModeAvailability() async {
    final settings = widget.settings;
    final status = await widget.syncService.aiStatus();
    return ComposeModeAvailability(
      research: deepResearchAvailable(settings.aiProviderId, settings.aiMode),
      picture: status?.pictureConfigured ?? false,
      picturePercent: status?.pictureWeeklyPct,
    );
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
    final composeMode = widget.composeMode;
    return ChatInputBar(
      sending: widget.controller.isSending,
      enabled: !_blocked,
      caption: '',
      leading: ComposeModeButton(
        mode: composeMode,
        onChanged: widget.onComposeModeChanged,
        availability: _composeModeAvailability,
        modesAllowed: composeModesUnlocked(settings.selectedPlanId),
        filesAllowed: assistantFilesAllowed(settings.selectedPlanId),
        artifactType: widget.artifactType,
        onArtifactTypeChanged: widget.onArtifactTypeChanged,
        onUpload: widget.onUpload,
      ),
      hasAttachments: widget.attachments.isNotEmpty,
      attachments: widget.attachments.isEmpty
          ? null
          : Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final attachment in widget.attachments)
                  InputChip(
                    label: Text(
                      attachment.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onDeleted: () => widget.onRemoveAttachment(attachment),
                    avatar: Icon(
                      attachment.isImage
                          ? Icons.image_outlined
                          : Icons.description_outlined,
                      size: 16,
                    ),
                  ),
              ],
            ),
      modelSelector: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: _ModelSelector(
              settings: settings,
              picture: composeMode == AssistantComposeMode.picture,
            ),
          ),
          meter,
        ],
      ),
      controller: widget.textController,
      focusNode: widget.focusNode,
      hintText: switch (composeMode) {
        AssistantComposeMode.plan => t.assistantPlanComposerHint,
        AssistantComposeMode.deepResearch => t.assistantResearchComposerHint,
        AssistantComposeMode.picture => t.assistantPictureComposerHint,
        AssistantComposeMode.chat =>
          widget.artifactType == null
              ? widget.hintText
              : 'Describe the .${widget.artifactType} file you want to create…',
      },
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

List<_ModelChoice> _lumaModelsFor(
  SettingsController settings,
  Map<String, String> modeVersions,
) => [
  for (final mode in AiMode.values.where(
    (mode) => mode.availableForPlan(settings.selectedPlanId),
  ))
    _ModelChoice(
      'Luma ${mode.displayNameFor(modeVersions[mode.name])}',
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
class _ModelSelector extends StatefulWidget {
  const _ModelSelector({required this.settings, this.picture = false});
  final SettingsController settings;

  /// Picture mode draws with the admin-picked image model whatever chat
  /// model is selected, so the pill names that instead and stops opening.
  final bool picture;

  @override
  State<_ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends State<_ModelSelector> {
  SyncService? _sync;
  Map<String, String> modeVersions = const {};

  SettingsController get settings => widget.settings;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sync = SyncScope.of(context);
    if (identical(sync, _sync)) return;
    _sync = sync;
    _refreshVersions();
  }

  Future<void> _refreshVersions() async {
    final sync = _sync;
    final status = await sync?.aiStatus();
    if (!mounted || !identical(sync, _sync)) return;
    setState(() => modeVersions = status?.modeVersions ?? const {});
  }

  _ModelChoice get _active =>
      [..._lumaModelsFor(settings, modeVersions), ..._apiKeyModels].firstWhere(
        (c) => c.isActive(settings),
        orElse: () => _lumaModelsFor(settings, modeVersions).first,
      );

  Future<void> _openMenu() async {
    await _refreshVersions();
    if (!mounted) return;
    final luma = context.luma;
    final t = L.of(context);
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
      final usageLabel = count == 0
          ? t.assistantModelUnused
          : t.assistantModelMessageCount(count);
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
        header(t.assistantModelsHeader),
        ..._lumaModelsFor(settings, modeVersions).map(item),
        const PopupMenuDivider(height: 10),
        header(t.assistantApiKeyHeader),
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
    final picture = widget.picture;
    return TextButton(
      onPressed: picture ? null : _openMenu,
      style: TextButton.styleFrom(
        foregroundColor: luma.textSecondary,
        disabledForegroundColor: luma.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              picture ? 'Luma Picture 1.0' : _active.label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          if (!picture) ...[
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 17,
              color: luma.textMuted,
            ),
          ],
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
          title: L.of(context).assistantWouldntWakeUp,
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
    final t = L.of(context);
    if (localModel) {
      final store = LocalModelStore.instance;
      return Center(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => LumaEmptyState(
            icon: Icons.smart_toy_rounded,
            title: t.assistantDownloadTitle,
            subtitle: !LocalModelStore.supported
                ? t.assistantDownloadUnsupported
                : store.isDownloading
                ? t.assistantDownloadingModel(
                    LocalModelStore.modelDisplayName,
                    LocalModelStore.modelSizeLabel,
                  )
                : t.assistantDownloadPrompt(
                    LocalModelStore.modelDisplayName,
                    LocalModelStore.modelSizeLabel,
                  ),
            action: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!LocalModelStore.supported) ...[
                  Text(t.assistantChooseAnotherModel),
                ] else if (store.isDownloading) ...[
                  SizedBox(
                    width: 280,
                    child: LinearProgressIndicator(value: store.progress),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    store.progress == null
                        ? t.assistantDownloadingModelShort
                        : '${(store.progress! * 100).toStringAsFixed(0)}%',
                  ),
                ] else
                  LumaPrimaryButton(
                    label: t.assistantDownloadModel,
                    icon: Icons.download_rounded,
                    onTap: () async {
                      await store.download();
                      onRecheck();
                    },
                  ),
                if (store.error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    t.assistantDownloadFailed('${store.error}'),
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
        title: t.assistantModelUnavailableTitle,
        subtitle: t.assistantModelUnavailableBody,
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LumaPrimaryButton(
                  label: t.assistantOpenSettings,
                  icon: Icons.settings_rounded,
                  onTap: onOpenSettings,
                ),
                const SizedBox(width: 10),
                LumaGhostButton(
                  label: t.assistantIAddedKey,
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
