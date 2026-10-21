import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'command_dashboard_repository.dart';
import 'command_icons.dart';
import 'command_models.dart';

/// Adds or edits one dashboard button. Returns the saved command, or null
/// when cancelled. [isNew] marks a prefilled [initial] (a picked .bat file)
/// as an add rather than an edit.
Future<DashCommand?> showCommandEditor(
  BuildContext context, {
  DashCommand? initial,
  bool isNew = false,
}) =>
    showDialog<DashCommand>(
      context: context,
      builder: (_) => _CommandEditor(
        initial: initial,
        isNew: isNew || initial == null,
      ),
    );

class _CommandEditor extends StatefulWidget {
  const _CommandEditor({required this.initial, required this.isNew});
  final DashCommand? initial;
  final bool isNew;

  @override
  State<_CommandEditor> createState() => _CommandEditorState();
}

class _CommandEditorState extends State<_CommandEditor> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _command = TextEditingController(text: widget.initial?.command);
  late final _dir =
      TextEditingController(text: widget.initial?.workingDirectory);
  late final _port =
      TextEditingController(text: widget.initial?.port?.toString());
  late CommandKind _kind = widget.initial?.kind ?? CommandKind.shell;
  late bool _admin = widget.initial?.runAsAdmin ?? false;
  late bool _host = widget.initial?.keepsRunning ?? false;
  late bool _ownWindow = widget.initial?.ownWindow ?? false;
  late String _icon = widget.initial?.icon ?? 'terminal';

  String? _nameError;
  String? _commandError;
  String? _portError;

  @override
  void dispose() {
    _name.dispose();
    _command.dispose();
    _dir.dispose();
    _port.dispose();
    super.dispose();
  }

  void _applyPreset(CommandPreset preset) {
    setState(() {
      _kind = CommandKind.shell;
      _name.text = preset.name;
      _command.text = preset.command;
      _admin = preset.runAsAdmin;
      _host = preset.keepsRunning;
      _port.text = preset.port?.toString() ?? '';
      _icon = preset.icon;
      _nameError = _commandError = _portError = null;
    });
  }

  Future<void> _pickScript() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['bat', 'cmd', 'ps1'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    setState(() {
      _command.text = path;
      _commandError = null;
      if (_name.text.trim().isEmpty) {
        final name = fileName(path);
        final dot = name.lastIndexOf('.');
        _name.text = dot > 0 ? name.substring(0, dot) : name;
      }
    });
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.getDirectoryPath();
    if (path != null) setState(() => _dir.text = path);
  }

  void _save() {
    final t = L.of(context);
    final name = _name.text.trim();
    final command = _command.text.trim();
    final portText = _port.text.trim();
    final port = portText.isEmpty ? null : int.tryParse(portText);
    setState(() {
      _nameError = name.isEmpty ? t.cmdDashErrorName : null;
      _commandError = command.isEmpty
          ? (_kind == CommandKind.script
              ? t.cmdDashErrorScript
              : t.cmdDashErrorCommand)
          : null;
      _portError = _host &&
              portText.isNotEmpty &&
              (port == null || port < 1 || port > 65535)
          ? t.cmdDashErrorPort
          : null;
    });
    if (_nameError != null || _commandError != null || _portError != null) {
      return;
    }
    final dir = _dir.text.trim();
    Navigator.pop(
      context,
      DashCommand(
        id: widget.initial?.id ?? CommandDashboardRepository.newId(),
        name: name,
        kind: _kind,
        command: command,
        workingDirectory: dir.isEmpty ? null : dir,
        runAsAdmin: _admin,
        keepsRunning: _host,
        port: _host ? port : null,
        ownWindow: _ownWindow,
        icon: _icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final isScript = _kind == CommandKind.script;

    return AlertDialog(
      title: Text(widget.isNew ? t.cmdDashEditorAddTitle : t.cmdDashEditorEditTitle),
      content: SizedBox(
        width: lumaDialogWidth(context, 520),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isNew && !isScript) ...[
                _SectionLabel(t.cmdDashPresets),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in commandPresets)
                      ActionChip(
                        avatar: Icon(commandIcon(preset.icon), size: 16),
                        label: Text(preset.name),
                        onPressed: () => _applyPreset(preset),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
              TextField(
                controller: _name,
                autofocus: widget.isNew && widget.initial == null,
                decoration: InputDecoration(
                  labelText: t.cmdDashFieldName,
                  errorText: _nameError,
                ),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
              const SizedBox(height: 16),
              LumaSegmentedTabs(
                tabs: [t.cmdDashKindCommand, t.cmdDashKindScript],
                selectedIndex: isScript ? 1 : 0,
                onSelect: (i) => setState(() {
                  final next = i == 1 ? CommandKind.script : CommandKind.shell;
                  if (next != _kind) _command.clear();
                  _kind = next;
                  _commandError = null;
                }),
              ),
              const SizedBox(height: 12),
              if (isScript)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _command,
                        style: monoStyle.copyWith(fontSize: 13),
                        decoration: InputDecoration(
                          labelText: t.cmdDashFieldScript,
                          errorText: _commandError,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: LumaGhostButton(
                        label: t.cmdDashBrowse,
                        icon: Icons.folder_open_rounded,
                        onTap: _pickScript,
                      ),
                    ),
                  ],
                )
              else
                TextField(
                  controller: _command,
                  style: monoStyle.copyWith(fontSize: 13),
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: t.cmdDashFieldCommand,
                    hintText: t.cmdDashFieldCommandHint,
                    errorText: _commandError,
                  ),
                  onChanged: (_) {
                    if (_commandError != null) {
                      setState(() => _commandError = null);
                    }
                  },
                ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _dir,
                      decoration: InputDecoration(
                        labelText: t.cmdDashFieldWorkingDir,
                        helperText: t.cmdDashFieldWorkingDirHelper,
                        helperMaxLines: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: IconButton(
                      tooltip: t.cmdDashBrowse,
                      onPressed: _pickFolder,
                      icon: Icon(Icons.folder_open_rounded, color: luma.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Toggle(
                icon: Icons.admin_panel_settings_rounded,
                iconColor: luma.warning,
                title: t.cmdDashAdminToggle,
                subtitle: t.cmdDashAdminToggleHelp,
                value: _admin,
                onChanged: (v) => setState(() => _admin = v),
              ),
              _Toggle(
                icon: Icons.cell_tower_rounded,
                iconColor: luma.accent,
                title: t.cmdDashHostToggle,
                subtitle: t.cmdDashHostToggleHelp,
                value: _host,
                onChanged: (v) => setState(() {
                  _host = v;
                  _portError = null;
                }),
              ),
              if (_host)
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 0, 8),
                  child: TextField(
                    controller: _port,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: t.cmdDashFieldPort,
                      helperText: t.cmdDashFieldPortHelper,
                      errorText: _portError,
                    ),
                  ),
                ),
              _Toggle(
                icon: Icons.open_in_new_rounded,
                iconColor: luma.textSecondary,
                title: t.cmdDashOwnWindowToggle,
                subtitle: t.cmdDashOwnWindowToggleHelp,
                value: _ownWindow,
                onChanged: (v) => setState(() => _ownWindow = v),
              ),
              const SizedBox(height: 14),
              _SectionLabel(t.cmdDashIcon),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in commandIcons.entries)
                    _IconChoice(
                      icon: entry.value,
                      selected: entry.key == _icon,
                      onTap: () => setState(() => _icon = entry.key),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cmdDashCancel),
        ),
        LumaPrimaryButton(label: t.cmdDashSave, onTap: _save),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: context.luma.textSecondary,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: luma.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: selected ? luma.accentSubtle : luma.surfaceHover,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? luma.accent : luma.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: selected ? luma.accent : luma.textSecondary,
          ),
        ),
      ),
    );
  }
}
