import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'ai_workbench_models.dart';
import 'ai_workbench_repository.dart';
import 'ai_workbench_scope.dart';

/// Builds reusable specialist definitions and installs them into Codex,
/// Claude Code or opencode.
class AiAgentBuilderTab extends StatefulWidget {
  const AiAgentBuilderTab({super.key});

  @override
  State<AiAgentBuilderTab> createState() => _AiAgentBuilderTabState();
}

class _AiAgentBuilderTabState extends State<AiAgentBuilderTab> {
  String? _selectedId;
  String? _editingId;
  bool _editorReady = false;
  bool _saving = false;
  AiAgentTarget _target = AiAgentTarget.codex;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _instructionsController;
  late final TextEditingController _outputController;
  late final TextEditingController _modelController;
  final Set<String> _selectedLibraryIds = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _instructionsController = TextEditingController();
    _outputController = TextEditingController();
    _modelController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _outputController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _select(AiAgentDefinition? agent) {
    setState(() {
      _selectedId = agent?.id;
      _editingId = agent?.id;
      _nameController.text = agent?.name ?? '';
      _descriptionController.text = agent?.description ?? '';
      _instructionsController.text = agent?.instructions ?? '';
      _outputController.text = agent?.outputFormat ?? '';
      _modelController.text = agent?.preferredModel ?? '';
      _selectedLibraryIds
        ..clear()
        ..addAll(agent?.libraryEntryIds ?? const []);
      _editorReady = true;
    });
  }

  void _ensureSelection(AiWorkbenchRepository repo) {
    if (!repo.loaded || _editorReady) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _editorReady) return;
      _select(repo.agents.firstOrNull);
    });
  }

  Future<void> _save(AiWorkbenchRepository repo) async {
    setState(() => _saving = true);
    await repo.saveAgent(
      id: _editingId,
      name: _nameController.text,
      description: _descriptionController.text,
      instructions: _instructionsController.text,
      outputFormat: _outputController.text,
      libraryEntryIds: _selectedLibraryIds.toList(),
      preferredModel: _modelController.text,
    );
    if (!mounted) return;
    final selected = repo.agents
        .where((agent) => agent.id == (_editingId ?? ''))
        .firstOrNull;
    setState(() {
      _saving = false;
      _selectedId = selected?.id ?? repo.agents.firstOrNull?.id;
      _editingId = _selectedId;
    });
    _toast(L.of(context).aiAgentSaved);
  }

  Future<void> _delete(
    AiWorkbenchRepository repo,
    AiAgentDefinition agent,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L.of(context).aiAgentDeleteTitle),
        content: Text(L.of(context).aiAgentDeleteBody(agent.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(L.of(context).commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await repo.deleteAgent(agent.id);
    if (mounted) _select(repo.agents.firstOrNull);
  }

  Future<void> _copyPrompt(
    AiWorkbenchRepository repo,
    AiAgentDefinition agent,
  ) async {
    await Clipboard.setData(ClipboardData(text: repo.codexPrompt(agent)));
    if (mounted) _toast(L.of(context).aiAgentPromptCopied(_target.label));
  }

  Future<void> _exportAgent(
    AiWorkbenchRepository repo,
    AiAgentDefinition agent,
  ) async {
    final target = _target;
    final contents = repo.agentFileFor(agent, target);
    final path = await FilePicker.saveFile(
      dialogTitle: L.of(context).aiAgentExportDialogTitle(
        target.label,
        target.fileLabel,
      ),
      fileName: AiWorkbenchRepository.exportFileNameFor(agent, target),
      type: FileType.custom,
      allowedExtensions: ['md'],
      bytes: Uint8List.fromList(utf8.encode(contents)),
    );
    if (path == null) return;
    if (!Platform.isAndroid) {
      await File(path).writeAsString(contents, flush: true);
    }
    if (mounted) {
      _toast(
        L.of(context).aiAgentExported(target.label, target.fileLabel),
      );
    }
  }

  Future<void> _installAgent(
    AiWorkbenchRepository repo,
    AiAgentDefinition agent,
  ) async {
    final target = _target;
    final project = await FilePicker.getDirectoryPath(
      dialogTitle: L.of(context).aiAgentChooseProjectFolder(target.label),
    );
    if (project == null) return;
    final relative = AiWorkbenchRepository.projectPathFor(agent, target);
    final path = [project, ...relative].join(Platform.pathSeparator);
    if (await File(path).exists() && mounted) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(L.of(context).aiAgentReplaceTitle(target.fileLabel)),
          content: Text(
            L.of(context).aiAgentReplaceBody(relative.join('/')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(L.of(context).commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(L.of(context).aiAgentReplace),
            ),
          ],
        ),
      );
      if (replace != true) return;
    }
    final written = await repo.installAgent(agent, project, target);
    if (mounted) _toast(L.of(context).aiAgentInstalledAt(written));
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final repo = AiWorkbenchScope.of(context);
    _ensureSelection(repo);
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        if (!repo.loaded) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2.4),
          );
        }
        final selected = _selectedId == null
            ? null
            : repo.agents.where((agent) => agent.id == _selectedId).firstOrNull;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AgentHeader(
                count: repo.agents.length,
                onNew: () => _select(null),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 760;
                    final list = _AgentList(
                      agents: repo.agents,
                      selectedId: _selectedId,
                      onSelect: _select,
                      onNew: () => _select(null),
                    );
                    final editor = _AgentEditor(
                      agent: selected,
                      nameController: _nameController,
                      descriptionController: _descriptionController,
                      instructionsController: _instructionsController,
                      outputController: _outputController,
                      modelController: _modelController,
                      libraryEntries: repo.markdownEntries,
                      selectedLibraryIds: _selectedLibraryIds,
                      saving: _saving,
                      target: _target,
                      onTargetChanged: (target) =>
                          setState(() => _target = target),
                      onToggleLibrary: (id, value) => setState(
                        () => value
                            ? _selectedLibraryIds.add(id)
                            : _selectedLibraryIds.remove(id),
                      ),
                      onSave: () => _save(repo),
                      onDelete: selected == null
                          ? null
                          : () => _delete(repo, selected),
                      onCopyPrompt: selected == null
                          ? null
                          : () => _copyPrompt(repo, selected),
                      onExport: selected == null
                          ? null
                          : () => _exportAgent(repo, selected),
                      onInstall: selected == null
                          ? null
                          : () => _installAgent(repo, selected),
                    );
                    if (narrow) {
                      return Column(
                        children: [
                          SizedBox(height: 190, child: list),
                          const SizedBox(height: 12),
                          Expanded(child: editor),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 260, child: list),
                        const SizedBox(width: 14),
                        Expanded(child: editor),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AgentHeader extends StatelessWidget {
  const _AgentHeader({required this.count, required this.onNew});
  final int count;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L.of(context).aiAgentHeader,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              L.of(context).aiAgentHeaderCount(count),
              style: TextStyle(color: context.luma.textSecondary),
            ),
          ],
        ),
      ),
      LumaPrimaryButton(
        label: L.of(context).aiAgentNew,
        icon: Icons.add_rounded,
        onTap: onNew,
      ),
    ],
  );
}

class _AgentList extends StatelessWidget {
  const _AgentList({
    required this.agents,
    required this.selectedId,
    required this.onSelect,
    required this.onNew,
  });
  final List<AiAgentDefinition> agents;
  final String? selectedId;
  final ValueChanged<AiAgentDefinition?> onSelect;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    if (agents.isEmpty) {
      return LumaCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 32,
              color: context.luma.textMuted,
            ),
            const SizedBox(height: 10),
            Text(
              t.aiAgentEmptyTitle,
              style: TextStyle(
                color: context.luma.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              t.aiAgentEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.luma.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            LumaGhostButton(
              label: t.aiAgentCreate,
              icon: Icons.add_rounded,
              onTap: onNew,
            ),
          ],
        ),
      );
    }
    return LumaCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        itemCount: agents.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: context.luma.border),
        itemBuilder: (context, index) {
          final agent = agents[index];
          final selected = agent.id == selectedId;
          return ListTile(
            dense: true,
            selected: selected,
            selectedTileColor: context.luma.accentSubtle,
            leading: Icon(
              Icons.smart_toy_outlined,
              size: 19,
              color: selected ? context.luma.accent : context.luma.textMuted,
            ),
            title: Text(
              agent.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              agent.description.isEmpty
                  ? t.aiAgentSpecialistSubtitle
                  : agent.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onSelect(agent),
          );
        },
      ),
    );
  }
}

class _AgentEditor extends StatelessWidget {
  const _AgentEditor({
    required this.agent,
    required this.nameController,
    required this.descriptionController,
    required this.instructionsController,
    required this.outputController,
    required this.modelController,
    required this.libraryEntries,
    required this.selectedLibraryIds,
    required this.saving,
    required this.target,
    required this.onTargetChanged,
    required this.onToggleLibrary,
    required this.onSave,
    required this.onDelete,
    required this.onCopyPrompt,
    required this.onExport,
    required this.onInstall,
  });
  final AiAgentDefinition? agent;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController instructionsController;
  final TextEditingController outputController;
  final TextEditingController modelController;
  final List<AiMarkdownEntry> libraryEntries;
  final Set<String> selectedLibraryIds;
  final bool saving;
  final AiAgentTarget target;
  final ValueChanged<AiAgentTarget> onTargetChanged;
  final void Function(String id, bool value) onToggleLibrary;
  final VoidCallback onSave;
  final VoidCallback? onDelete;
  final VoidCallback? onCopyPrompt;
  final VoidCallback? onExport;
  final VoidCallback? onInstall;

  InputDecoration _decoration(String label, String hint) =>
      InputDecoration(labelText: label, hintText: hint);

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return LumaCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  agent == null ? t.aiAgentNew : t.aiAgentEdit,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (agent != null)
                IconButton(
                  tooltip: t.aiAgentDeleteTooltip,
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline_rounded, color: luma.danger),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: _decoration(t.commonName, t.aiAgentNameHint),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    decoration: _decoration(
                      t.aiAgentFieldDescription,
                      t.aiAgentDescriptionHint,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: modelController,
                    decoration: _decoration(
                      t.aiAgentFieldModel,
                      t.aiAgentModelHint,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: instructionsController,
                    minLines: 6,
                    maxLines: 10,
                    decoration: _decoration(
                      t.aiAgentFieldInstructions,
                      t.aiAgentInstructionsHint,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: outputController,
                    minLines: 3,
                    maxLines: 6,
                    decoration: _decoration(
                      t.aiAgentFieldOutput,
                      t.aiAgentOutputHint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.aiAgentLibraryContext,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.aiAgentLibraryContextHelp,
                    style: TextStyle(color: luma.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  if (libraryEntries.isEmpty)
                    Text(
                      t.aiAgentLibraryEmpty,
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    )
                  else ...[
                    for (final entry in libraryEntries)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: selectedLibraryIds.contains(entry.id),
                        title: Text(entry.title),
                        subtitle: Text(
                          entry.tags.isEmpty
                              ? t.aiMarkdownNoteLabel
                              : entry.tags.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onChanged: (value) =>
                            onToggleLibrary(entry.id, value ?? false),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (agent != null) ...[
            Row(
              children: [
                Text(
                  t.aiAgentUseWith,
                  style: TextStyle(color: luma.textSecondary, fontSize: 12),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: LumaSegmentedTabs(
                      tabs: [
                        for (final option in AiAgentTarget.values) option.label,
                      ],
                      selectedIndex: target.index,
                      onSelect: (i) =>
                          onTargetChanged(AiAgentTarget.values[i]),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (agent != null)
                LumaGhostButton(
                  label: t.aiAgentCopyPrompt,
                  icon: Icons.copy_rounded,
                  onTap: onCopyPrompt,
                ),
              if (agent != null)
                LumaGhostButton(
                  label: t.aiAgentExportFile(target.fileLabel),
                  icon: Icons.download_rounded,
                  onTap: onExport,
                ),
              if (agent != null)
                LumaGhostButton(
                  label: t.aiAgentInstallFor(target.label),
                  icon: Icons.integration_instructions_rounded,
                  onTap: onInstall,
                ),
              LumaPrimaryButton(
                label: saving ? t.aiUsageSaving : t.aiAgentSave,
                icon: Icons.save_rounded,
                onTap: saving ? null : onSave,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
