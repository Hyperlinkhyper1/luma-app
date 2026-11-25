import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/widgets.dart';
import '../../../theme/luma_theme.dart';
import '../data/chat_repository.dart';
import 'assistant_artifacts_view.dart';
import 'package:luma/l10n/app_localizations.dart';

class AssistantProjectsView extends StatelessWidget {
  const AssistantProjectsView({
    super.key,
    required this.repository,
    required this.projectId,
    required this.onOpenProject,
    required this.onOpenChat,
    required this.onNewChat,
  });
  final ChatRepository repository;
  final int? projectId;
  final ValueChanged<int?> onOpenProject;
  final ValueChanged<int> onOpenChat;
  final ValueChanged<int> onNewChat;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ChatProjectRecord>>(
    stream: repository.watchProjects(),
    builder: (context, snapshot) {
      final projects = snapshot.data ?? const [];
      final project = projects.where((p) => p.id == projectId).firstOrNull;
      if (project != null) return _projectDetail(context, project);
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Text(
                L.of(context).assistantProjectsTitle,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w600,
                  color: context.luma.textPrimary,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(L.of(context).assistantProjectsNew),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            L.of(context).assistantProjectsSubtitle,
            style: TextStyle(color: context.luma.textSecondary),
          ),
          const SizedBox(height: 20),
          if (snapshot.hasError)
            Text(L.of(context).assistantProjectsLoadFailed),
          if (snapshot.connectionState == ConnectionState.waiting)
            const LinearProgressIndicator(),
          if (projects.isEmpty && snapshot.hasData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Text(L.of(context).assistantProjectsEmpty),
            ),
          for (final p in projects)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProjectTile(
                project: p,
                onTap: () => onOpenProject(p.id),
              ),
            ),
        ],
      );
    },
  );

  Widget _projectDetail(BuildContext context, ChatProjectRecord project) =>
      StreamBuilder<List<ChatConversationRecord>>(
        stream: repository.watchConversations(),
        builder: (context, snapshot) {
          final chats =
              (snapshot.data ?? const <ChatConversationRecord>[])
                  .where((c) => c.projectId == project.id)
                  .toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final pad = context.isPhoneWidth ? 16.0 : 28.0;
              final header = _ProjectHeader(
                project: project,
                chats: chats,
                onBack: () => onOpenProject(null),
                onNewChat: () => onNewChat(project.id),
                onEdit: () => _edit(context, project),
              );
              final chatSection = _ProjectChats(
                repository: repository,
                chats: chats,
                onOpenChat: onOpenChat,
                onNewChat: () => onNewChat(project.id),
              );
              final side = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProjectMemoryCard(
                    project: project,
                    onEdit: () => _edit(context, project),
                  ),
                  const SizedBox(height: 16),
                  const _ProjectHowCard(),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _delete(context, project),
                      style: TextButton.styleFrom(
                        foregroundColor: context.luma.danger,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text(L.of(context).assistantProjectDelete),
                    ),
                  ),
                ],
              );
              return ListView(
                padding: EdgeInsets.fromLTRB(pad, pad - 8, pad, pad),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          header,
                          const SizedBox(height: 24),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: chatSection),
                                const SizedBox(width: 24),
                                Expanded(flex: 2, child: side),
                              ],
                            )
                          else ...[
                            chatSection,
                            const SizedBox(height: 24),
                            side,
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

  Future<void> _edit(BuildContext context, [ChatProjectRecord? project]) async {
    final name = TextEditingController(text: project?.name);
    final description = TextEditingController(text: project?.description);
    final memory = TextEditingController(text: project?.memory);
    final form = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(project == null ? 'New project' : 'Edit project'),
        content: SizedBox(
          width: lumaDialogWidth(context, 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 6),
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    autofocus: true,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Project name',
                      counterText: '',
                    ),
                    validator: (value) => value?.trim().isEmpty == true
                        ? 'Enter a project name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: description,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  if (project != null) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: memory,
                      minLines: 5,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        labelText: 'Project memory',
                        helperText: 'Facts and context for this project only',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: Text(L.of(context).commonSave),
          ),
        ],
      ),
    );
    if (saved == true) {
      if (project == null) {
        final id = await repository.createProject(
          name.text,
          description: description.text,
        );
        onOpenProject(id);
      } else {
        await repository.updateProject(
          project.id,
          name: name.text,
          description: description.text,
          memory: memory.text,
        );
      }
    }
    // Dialog fields finish their exit animation before their controllers are released.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    description.dispose();
    memory.dispose();
  }

  Future<void> _delete(BuildContext context, ChatProjectRecord project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${project.name}?'),
        content: Text(L.of(context).assistantProjectDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L.of(context).commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.luma.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(L.of(context).commonDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repository.deleteProject(project.id);
      onOpenProject(null);
    }
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.project, required this.onTap});
  final ChatProjectRecord project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final name = project.name.trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final description = project.description.trim();
    final radius = BorderRadius.circular(16);
    return Material(
      color: luma.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: luma.border),
      ),
      child: InkWell(
        borderRadius: radius,
        hoverColor: luma.surfaceHover,
        highlightColor: luma.accentSubtle,
        splashColor: luma.accent.withValues(alpha: 0.12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: luma.accentSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: luma.accent.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: luma.accent,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: luma.textPrimary,
                      ),
                    ),
                    if (description.isNotEmpty && description != '-') ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: luma.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right_rounded, color: luma.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({
    required this.project,
    required this.chats,
    required this.onBack,
    required this.onNewChat,
    required this.onEdit,
  });
  final ChatProjectRecord project;
  final List<ChatConversationRecord> chats;
  final VoidCallback onBack;
  final VoidCallback onNewChat;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final l = L.of(context);
    final description = project.description.trim();
    final name = project.name.trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final hasMemory = project.memory.trim().isNotEmpty;
    final lastActive = chats.isEmpty ? null : chats.first.updatedAt;
    final phone = context.isPhoneWidth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: Text(l.assistantProjectsAll),
        ),
        const SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(phone ? 18 : 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: luma.border),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(luma.surface, luma.accent, 0.16)!,
                luma.surface,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: phone ? 52 : 64,
                    height: phone ? 52 : 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: luma.accentSubtle,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: luma.accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: phone ? 23 : 28,
                        fontWeight: FontWeight.w700,
                        color: luma.accent,
                      ),
                    ),
                  ),
                  SizedBox(width: phone ? 14 : 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: phone ? 23 : 27,
                            fontWeight: FontWeight.w700,
                            color: luma.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description.isEmpty || description == '-'
                              ? l.assistantProjectDescriptionFallback
                              : description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: luma.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 14,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatPill(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: l.assistantProjectChatCount(chats.length),
                      ),
                      _StatPill(
                        icon: hasMemory
                            ? Icons.lightbulb_rounded
                            : Icons.lightbulb_outline_rounded,
                        label: hasMemory
                            ? l.assistantProjectMemorySaved
                            : l.assistantProjectMemoryNone,
                        highlighted: hasMemory,
                      ),
                      if (lastActive != null)
                        _StatPill(
                          icon: Icons.schedule_rounded,
                          label: l.assistantProjectLastActive(
                            DateFormat.MMMd(l.localeName).format(lastActive),
                          ),
                        ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(l.assistantProjectEdit),
                      ),
                      FilledButton.icon(
                        onPressed: onNewChat,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(l.assistantNewChat),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });
  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = highlighted ? luma.accent : luma.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted
            ? luma.accentSubtle
            : luma.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12.5, color: color)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, this.trailing});
  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: context.luma.accent),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: context.luma.textPrimary,
          ),
        ),
      ),
      ?trailing,
    ],
  );
}

class _ProjectChats extends StatefulWidget {
  const _ProjectChats({
    required this.repository,
    required this.chats,
    required this.onOpenChat,
    required this.onNewChat,
  });
  final ChatRepository repository;
  final List<ChatConversationRecord> chats;
  final ValueChanged<int> onOpenChat;
  final VoidCallback onNewChat;

  @override
  State<_ProjectChats> createState() => _ProjectChatsState();
}

class _ProjectChatsState extends State<_ProjectChats> {
  late final Stream<List<ChatArtifactRecord>> _artifacts = widget.repository
      .watchArtifacts();
  int _tab = 0;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ChatArtifactRecord>>(
    stream: _artifacts,
    builder: (context, snapshot) {
      final l = L.of(context);
      final chatIds = {for (final c in widget.chats) c.id};
      final artifacts =
          (snapshot.data ?? const <ChatArtifactRecord>[])
              .where((a) => chatIds.contains(a.conversationId))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return LumaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LumaSegmentedTabs(
              tabs: [
                '${l.assistantChats} · ${widget.chats.length}',
                '${l.assistantArtifactsTitle} · ${artifacts.length}',
              ],
              selectedIndex: _tab,
              onSelect: (index) => setState(() => _tab = index),
            ),
            const SizedBox(height: 14),
            if (_tab == 0)
              _chatList(context)
            else
              _artifactList(context, artifacts),
          ],
        ),
      );
    },
  );

  Widget _artifactList(
    BuildContext context,
    List<ChatArtifactRecord> artifacts,
  ) {
    final luma = context.luma;
    final l = L.of(context);
    if (artifacts.isEmpty) {
      return _EmptyPanel(
        icon: Icons.folder_open_rounded,
        title: l.assistantProjectNoArtifactsTitle,
        body: l.assistantProjectNoArtifactsBody,
      );
    }
    final date = DateFormat.MMMd(l.localeName);
    return Column(
      children: [
        for (final file in artifacts)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                hoverColor: luma.surfaceHover,
                onTap: () => openAssistantArtifact(context, file.path),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _ArtifactThumb(file: file),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: luma.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        date.format(file.createdAt.toLocal()),
                        style: TextStyle(fontSize: 12, color: luma.textMuted),
                      ),
                      if (file.conversationId != null)
                        IconButton(
                          tooltip: l.assistantArtifactViewChat,
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              widget.onOpenChat(file.conversationId!),
                          icon: Icon(
                            Icons.forum_outlined,
                            size: 18,
                            color: luma.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _chatList(BuildContext context) {
    final luma = context.luma;
    final l = L.of(context);
    final date = DateFormat.MMMd(l.localeName);
    final chats = widget.chats;
    final onOpenChat = widget.onOpenChat;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (chats.isEmpty)
          _EmptyChats(onNewChat: widget.onNewChat)
        else
          for (final chat in chats)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  hoverColor: luma.surfaceHover,
                  onTap: () => onOpenChat(chat.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: luma.accentSubtle,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            chat.pinned
                                ? Icons.push_pin_rounded
                                : Icons.chat_bubble_outline_rounded,
                            size: 16,
                            color: luma.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            chat.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: luma.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          date.format(chat.updatedAt),
                          style: TextStyle(fontSize: 12, color: luma.textMuted),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: luma.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _ArtifactThumb extends StatelessWidget {
  const _ArtifactThumb({required this.file});
  final ChatArtifactRecord file;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final isPicture = file.mimeType.startsWith('image/');
    final fallback = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: luma.accentSubtle,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        isPicture ? Icons.image_outlined : Icons.insert_drive_file_outlined,
        size: 18,
        color: luma.accent,
      ),
    );
    if (!isPicture || file.mimeType == 'image/svg+xml') return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(
        File(file.path),
        width: 38,
        height: 38,
        fit: BoxFit.cover,
        cacheWidth: 96,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: luma.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: luma.accentSubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: luma.accent, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: luma.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textSecondary, height: 1.4),
            ),
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats({required this.onNewChat});
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return _EmptyPanel(
      icon: Icons.auto_awesome_rounded,
      title: l.assistantProjectNoChatsTitle,
      body: l.assistantProjectNoChatsBody,
      action: FilledButton.tonalIcon(
        onPressed: onNewChat,
        icon: const Icon(Icons.add_rounded),
        label: Text(l.assistantProjectStartChat),
      ),
    );
  }
}

class _ProjectMemoryCard extends StatelessWidget {
  const _ProjectMemoryCard({required this.project, required this.onEdit});
  final ChatProjectRecord project;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final l = L.of(context);
    final empty = project.memory.trim().isEmpty;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            icon: Icons.lightbulb_outline_rounded,
            title: l.assistantProjectMemory,
            trailing: IconButton(
              tooltip: l.assistantProjectEdit,
              visualDensity: VisualDensity.compact,
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 10),
          if (empty) ...[
            Text(
              l.assistantProjectMemoryEmpty,
              style: TextStyle(color: luma.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l.assistantProjectAddMemory),
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: luma.background.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: luma.border),
              ),
              child: Text(
                project.memory,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: luma.textPrimary, height: 1.4),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            l.assistantProjectMemoryHint,
            style: TextStyle(fontSize: 12, color: luma.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ProjectHowCard extends StatelessWidget {
  const _ProjectHowCard();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final l = L.of(context);
    Widget row(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: luma.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: luma.textSecondary, height: 1.35),
            ),
          ),
        ],
      ),
    );
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            icon: Icons.info_outline_rounded,
            title: l.assistantProjectHowTitle,
          ),
          row(Icons.folder_outlined, l.assistantProjectHowChats),
          row(Icons.lock_outline_rounded, l.assistantProjectHowMemory),
          row(Icons.restore_rounded, l.assistantProjectHowDelete),
        ],
      ),
    );
  }
}
