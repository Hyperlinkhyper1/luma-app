import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';

import '../../app/widgets.dart';
import '../../app/pin_dialog.dart';
import '../../settings/settings_scope.dart';
import '../../theme/luma_theme.dart';
import 'password_entry_sheet.dart';
import 'password_repository.dart';
import 'password_scope.dart';

/// Root of the Password Manager destination: a searchable list of stored
/// credentials with an action to add a new one.
class PasswordsPage extends StatefulWidget {
  const PasswordsPage({super.key});

  @override
  State<PasswordsPage> createState() => _PasswordsPageState();
}

class _PasswordsPageState extends State<PasswordsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = PasswordScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: TextStyle(color: luma.textPrimary),
                  decoration: pwInputDecoration(
                    luma,
                    hint: 'Search by service, email or username',
                  ).copyWith(
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 18, color: luma.textMuted),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              const SizedBox(width: 12),
              LumaPrimaryButton(
                label: 'Add',
                icon: Icons.add_rounded,
                onTap: () => showPasswordEntrySheet(context, repo: repo),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamData<List<PasswordRecord>>(
            stream: repo.watchAll(),
            builder: (context, all) {
              final records = _filter(all, _query);
              if (all.isEmpty) {
                return LumaEmptyState(
                  icon: Icons.lock_rounded,
                  title: 'No saved passwords yet',
                  subtitle:
                      'Add your first credential and it will be stored encrypted on this device.',
                );
              }
              if (records.isEmpty) {
                return LumaEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matches',
                  subtitle: 'No credential matches "$_query".',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                itemCount: records.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _CredentialCard(
                  record: records[i],
                  repo: repo,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static List<PasswordRecord> _filter(List<PasswordRecord> all, String query) {
    if (query.isEmpty) return all;
    final q = query.toLowerCase();
    return all
        .where((r) =>
            r.service.toLowerCase().contains(q) ||
            r.email.toLowerCase().contains(q) ||
            (r.username?.toLowerCase().contains(q) ?? false))
        .toList(growable: false);
  }
}

class _CredentialCard extends StatefulWidget {
  const _CredentialCard({required this.record, required this.repo});
  final PasswordRecord record;
  final PasswordRepository repo;

  @override
  State<_CredentialCard> createState() => _CredentialCardState();
}

class _CredentialCardState extends State<_CredentialCard> {
  bool _revealed = false;

  Future<bool> _requirePin() async {
    final settings = SettingsScope.of(context);
    if (settings.lockPasswordHash == null) return true;
    
    final pin = await showPinDialog(context, title: 'Enter PIN to unlock');
    if (pin == null) return false;
    
    final hash = sha256.convert(utf8.encode(pin)).toString();
    if (hash == settings.lockPasswordHash) return true;
    
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
    }
    return false;
  }

  Future<void> _copy(String label, String value) async {
    if (!await _requirePin()) return;
    if (!mounted) return;
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Future<void> _confirmDelete() async {
    if (!await _requirePin()) return;
    if (!mounted) return;
    final luma = context.luma;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text('Delete credential?',
            style: TextStyle(color: luma.textPrimary)),
        content: Text(
          'This will permanently remove the saved credential for "${widget.record.service}".',
          style: TextStyle(color: luma.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: luma.danger)),
          ),
        ],
      ),
    );
    if (ok == true) await widget.repo.delete(widget.record.id);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final r = widget.record;
    final initial = (r.icon != null && r.icon!.isNotEmpty)
        ? r.icon!
        : (r.service.isNotEmpty ? r.service[0].toUpperCase() : '?');

    return LumaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: luma.accentSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: (r.icon != null && r.icon!.startsWith('data:image/'))
                    ? Image.memory(
                        base64Decode(r.icon!.split(',').last),
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40,
                      )
                    : Text(
                        initial,
                        style: TextStyle(
                          color: luma.accent,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.service,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.email,
                      style: TextStyle(color: luma.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _IconAction(
                icon: Icons.edit_rounded,
                tooltip: 'Edit',
                onTap: () async {
                  if (!await _requirePin()) return;
                  if (!mounted) return;
                  showPasswordEntrySheet(
                    context,
                    repo: widget.repo,
                    existing: r,
                  );
                },
              ),
              _IconAction(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete',
                color: luma.danger,
                onTap: _confirmDelete,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Field(
            label: 'Password',
            value: _revealed ? r.password : '•' * (r.password.isEmpty ? 8 : 10),
            mono: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IconAction(
                  icon: _revealed
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  tooltip: _revealed ? 'Hide' : 'Reveal',
                  onTap: () async {
                    if (!_revealed) {
                      if (!await _requirePin()) return;
                      if (!mounted) return;
                    }
                    setState(() => _revealed = !_revealed);
                  },
                ),
                _IconAction(
                  icon: Icons.copy_rounded,
                  tooltip: 'Copy password',
                  onTap: () => _copy('Password', r.password),
                ),
              ],
            ),
          ),
          _Field(
            label: 'Email',
            value: r.email,
            trailing: _IconAction(
              icon: Icons.copy_rounded,
              tooltip: 'Copy email',
              onTap: () => _copy('Email', r.email),
            ),
          ),
          if (r.username != null && r.username!.isNotEmpty)
            _Field(
              label: 'Username',
              value: r.username!,
              trailing: _IconAction(
                icon: Icons.copy_rounded,
                tooltip: 'Copy username',
                onTap: () => _copy('Username', r.username!),
              ),
            ),
          if (r.phone != null && r.phone!.isNotEmpty)
            _Field(label: 'Phone', value: r.phone!),
          if (r.info != null && r.info!.isNotEmpty)
            _Field(label: 'Info', value: r.info!),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.trailing,
    this.mono = false,
  });
  final String label;
  final String value;
  final Widget? trailing;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 36),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          SizedBox(
            width: 76,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label,
                style: TextStyle(
                  color: luma.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: SelectableText(
                value,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 13,
                  fontFeatures: mono
                      ? const [FontFeature.tabularFigures()]
                      : null,
                  fontFamily: mono ? 'monospace' : null,
                ),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    ),
  );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 18, color: color ?? luma.textSecondary),
        splashRadius: 18,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }
}
