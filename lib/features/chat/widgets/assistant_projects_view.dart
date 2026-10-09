import 'package:flutter/material.dart';

import '../../../theme/luma_theme.dart';
import '../data/chat_repository.dart';

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
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (project != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onOpenProject(null),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('All projects'),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Text(
                project?.name ?? 'Projects',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w600,
                  color: context.luma.textPrimary,
                ),
              ),
              if (project == null)
                FilledButton.icon(
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New project'),
                ),
              if (project != null)
                FilledButton.icon(
                  onPressed: () => onNewChat(project.id),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New chat'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            project?.description.isNotEmpty == true
                ? project!.description
                : project == null
                ? 'Keep chats and memory together for each project.'
                : 'Chats here use your global memory and this project’s memory.',
            style: TextStyle(color: context.luma.textSecondary),
          ),
          const SizedBox(height: 20),
          if (project == null) ...[
            if (snapshot.hasError) const Text('Could not load projects.'),
            if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator(),
            if (projects.isEmpty && snapshot.hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Text(
                  'Create your first project to start a dedicated chat space.',
                ),
              ),
            for (final p in projects)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(p.name),
                  subtitle: p.description.isEmpty
                      ? null
                      : Text(
                          p.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => onOpenProject(p.id),
                ),
              ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Project memory',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextButton.icon(
                          onPressed: () => _edit(context, project),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit project'),
                        ),
                      ],
                    ),
                    Text(
                      project.memory.isEmpty
                          ? 'No project memory yet. Add notes here or ask the assistant to remember a project fact.'
                          : project.memory,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Only chats in this project can use this memory. The memory setting in Customize applies here too.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Chats',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
            ),
            StreamBuilder<List<ChatConversationRecord>>(
              stream: repository.watchConversations(),
              builder: (context, chats) {
                final visible = (chats.data ?? const <ChatConversationRecord>[])
                    .where((c) => c.projectId == project.id)
                    .toList();
                return Column(
                  children: [
                    if (visible.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No chats in this project yet.'),
                      ),
                    for (final chat in visible)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                        ),
                        title: Text(chat.title),
                        onTap: () => onOpenChat(chat.id),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _delete(context, project),
                child: Text(
                  'Delete project',
                  style: TextStyle(color: context.luma.danger),
                ),
              ),
            ),
          ],
        ],
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
          width: 520,
          child: SingleChildScrollView(
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
                    ),
                    validator: (value) => value?.trim().isEmpty == true
                        ? 'Enter a project name'
                        : null,
                  ),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  if (project != null)
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
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Save'),
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
        content: const Text(
          'This removes the project and its memory. Its chats return to the main chat list; generated files stay in Artifacts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
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
