import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'sftp_dialogs.dart';
import 'sftp_site.dart';

/// What the editor hands back: the site to save, plus the secret the user
/// typed (null when they typed none, or chose not to save it).
typedef SiteDraft = ({SftpSite site, String? secret});

/// The screen shown while nothing is connected: every saved server, and the
/// way in to add one.
class SftpSiteManagerView extends StatelessWidget {
  const SftpSiteManagerView({
    super.key,
    required this.sites,
    required this.loading,
    required this.connectingSiteId,
    required this.onConnect,
    required this.onEdit,
    required this.onDelete,
    required this.onNew,
    this.error,
  });

  final List<SftpSite> sites;
  final bool loading;

  /// The site currently being connected, so its card can show a spinner.
  final String? connectingSiteId;

  final ValueChanged<SftpSite> onConnect;
  final ValueChanged<SftpSite> onEdit;
  final ValueChanged<SftpSite> onDelete;
  final VoidCallback onNew;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  LumaIconBadge(icon: Icons.storage_rounded, color: luma.accent),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Site Manager',
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Your servers, saved on this device only.',
                          style: TextStyle(
                            color: luma.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  LumaPrimaryButton(
                    label: 'New site',
                    icon: Icons.add_rounded,
                    onTap: onNew,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (error != null) ...[
                _ErrorCard(message: error!),
                const SizedBox(height: 14),
              ],
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (sites.isEmpty)
                LumaCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: 46,
                    horizontal: 24,
                  ),
                  child: LumaEmptyState(
                    icon: Icons.dns_rounded,
                    title: 'No servers yet',
                    subtitle:
                        'Add a server with its host name, username, password '
                        'and port — luma connects straight to it from this '
                        'device.',
                    action: LumaPrimaryButton(
                      label: 'Add a server',
                      icon: Icons.add_rounded,
                      onTap: onNew,
                    ),
                  ),
                )
              else
                for (final site in sites) ...[
                  _SiteCard(
                    site: site,
                    connecting: connectingSiteId == site.id,
                    busy: connectingSiteId != null,
                    onConnect: () => onConnect(site),
                    onEdit: () => onEdit(site),
                    onDelete: () => onDelete(site),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 8),
              _PrivacyNote(luma: luma),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: luma.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: luma.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: luma.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.luma});

  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, size: 15, color: luma.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Connections go straight from this device to your server. Nothing '
            'passes through a luma server, and saved passwords stay encrypted '
            'here — they are never synced.',
            style: TextStyle(color: luma.textMuted, fontSize: 11.5, height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _SiteCard extends StatefulWidget {
  const _SiteCard({
    required this.site,
    required this.connecting,
    required this.busy,
    required this.onConnect,
    required this.onEdit,
    required this.onDelete,
  });

  final SftpSite site;
  final bool connecting;
  final bool busy;
  final VoidCallback onConnect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_SiteCard> createState() => _SiteCardState();
}

class _SiteCardState extends State<_SiteCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final site = widget.site;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.busy ? null : widget.onConnect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hovering ? luma.surfaceHover : luma.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovering ? luma.accent : luma.border,
            ),
          ),
          child: Row(
            children: [
              LumaIconBadge(
                icon: site.authMode == SftpAuthMode.key
                    ? Icons.key_rounded
                    : Icons.dns_rounded,
                color: luma.accent,
                size: 38,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      site.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      site.endpointLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (site.saveSecret && site.secretToken != null)
                Tooltip(
                  message: 'Password saved, encrypted on this device',
                  child: Icon(
                    Icons.lock_rounded,
                    size: 15,
                    color: luma.textMuted,
                  ),
                ),
              const SizedBox(width: 6),
              if (widget.connecting)
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                )
              else ...[
                IconButton(
                  onPressed: widget.busy ? null : widget.onEdit,
                  tooltip: 'Edit site',
                  icon: const Icon(Icons.edit_rounded, size: 17),
                  color: luma.textSecondary,
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                ),
                IconButton(
                  onPressed: widget.busy ? null : widget.onDelete,
                  tooltip: 'Remove site',
                  icon: const Icon(Icons.delete_outline_rounded, size: 17),
                  color: luma.textSecondary,
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Adds or edits a site. Returns null when the user cancels.
Future<SiteDraft?> showSftpSiteEditor(
  BuildContext context, {
  SftpSite? site,
  String? existingSecret,
}) {
  return showDialog<SiteDraft>(
    context: context,
    builder: (context) => _SiteEditorDialog(
      site: site,
      existingSecret: existingSecret,
    ),
  );
}

class _SiteEditorDialog extends StatefulWidget {
  const _SiteEditorDialog({this.site, this.existingSecret});

  final SftpSite? site;
  final String? existingSecret;

  @override
  State<_SiteEditorDialog> createState() => _SiteEditorDialogState();
}

class _SiteEditorDialogState extends State<_SiteEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _secret;
  late final TextEditingController _remoteDirectory;

  late SftpAuthMode _authMode;
  late bool _saveSecret;
  String? _keyPath;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final site = widget.site;
    _name = TextEditingController(text: site?.name ?? '');
    _host = TextEditingController(text: site?.host ?? '');
    _port = TextEditingController(text: (site?.port ?? 22).toString());
    _username = TextEditingController(text: site?.username ?? '');
    _secret = TextEditingController(text: widget.existingSecret ?? '');
    _remoteDirectory = TextEditingController(text: site?.remoteDirectory ?? '');
    _authMode = site?.authMode ?? SftpAuthMode.password;
    _saveSecret = site?.saveSecret ?? true;
    _keyPath = site?.keyPath;
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _secret.dispose();
    _remoteDirectory.dispose();
    super.dispose();
  }

  Future<void> _pickKey() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Choose a private key',
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    setState(() => _keyPath = path);
  }

  void _submit() {
    final host = _host.text.trim();
    if (host.isEmpty) {
      setState(() => _error = 'A host name or IP address is required.');
      return;
    }
    final username = _username.text.trim();
    if (username.isEmpty) {
      setState(() => _error = 'A username is required.');
      return;
    }
    final port = int.tryParse(_port.text.trim());
    if (port == null || port < 1 || port > 65535) {
      setState(() => _error = 'Port must be a number between 1 and 65535.');
      return;
    }
    if (_authMode == SftpAuthMode.key &&
        (_keyPath == null || _keyPath!.isEmpty)) {
      setState(() => _error = 'Choose the private key file to sign in with.');
      return;
    }

    final existing = widget.site;
    final draft = SftpSite(
      id: existing?.id ?? newSftpSiteId(),
      name: _name.text.trim(),
      host: host,
      port: port,
      username: username,
      authMode: _authMode,
      keyPath: _authMode == SftpAuthMode.key ? _keyPath : null,
      saveSecret: _saveSecret,
      secretToken: existing?.secretToken,
      remoteDirectory: _remoteDirectory.text.trim(),
      localDirectory: existing?.localDirectory ?? '',
      lastUsed: existing?.lastUsed,
    );

    Navigator.of(context).pop((
      site: draft,
      secret: _saveSecret ? _secret.text : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final isKey = _authMode == SftpAuthMode.key;

    return Dialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: luma.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
              child: Row(
                children: [
                  LumaIconBadge(
                    icon: Icons.dns_rounded,
                    color: luma.accent,
                    size: 34,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.site == null ? 'New site' : 'Edit site',
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _field(_name, 'Name', hint: 'My VPS'),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _field(
                            _host,
                            'Host',
                            hint: 'example.com or 203.0.113.10',
                            autofocus: widget.site == null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field(
                            _port,
                            'Port',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _field(_username, 'Username', hint: 'root'),
                    const SizedBox(height: 16),
                    Text(
                      'Sign in with',
                      style: TextStyle(color: luma.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    LumaSegmentedTabs(
                      tabs: const ['Password', 'SSH key'],
                      selectedIndex: isKey ? 1 : 0,
                      onSelect: (index) => setState(() {
                        _authMode = index == 0
                            ? SftpAuthMode.password
                            : SftpAuthMode.key;
                        _error = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    if (isKey) ...[
                      _KeyFileRow(
                        path: _keyPath,
                        onPick: _pickKey,
                        onClear: () => setState(() => _keyPath = null),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _secret,
                      obscureText: _obscure,
                      style: TextStyle(color: luma.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: isKey ? 'Key passphrase' : 'Password',
                        helperText: isKey
                            ? 'Leave empty if the key has no passphrase.'
                            : null,
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Show' : 'Hide',
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    SftpCheckRow(
                      value: _saveSecret,
                      label: isKey
                          ? 'Save the passphrase for this site'
                          : 'Save the password for this site',
                      subtitle:
                          'Encrypted on this device. Untick and luma asks '
                          'every time you connect.',
                      onChanged: (value) => setState(() => _saveSecret = value),
                    ),
                    const SizedBox(height: 6),
                    _field(
                      _remoteDirectory,
                      'Open this folder on connect',
                      hint: '/var/www (optional)',
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: TextStyle(color: luma.danger, fontSize: 12.5),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  LumaGhostButton(
                    label: 'Cancel',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  LumaPrimaryButton(
                    label: 'Save site',
                    icon: Icons.check_rounded,
                    onTap: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    TextInputType? keyboardType,
    bool autofocus = false,
  }) {
    final luma = context.luma;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      autofocus: autofocus,
      style: TextStyle(color: luma.textPrimary, fontSize: 14),
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

class _KeyFileRow extends StatelessWidget {
  const _KeyFileRow({
    required this.path,
    required this.onPick,
    required this.onClear,
  });

  final String? path;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        children: [
          Icon(Icons.key_rounded, size: 16, color: luma.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              path ?? 'No private key chosen',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: path == null ? luma.textMuted : luma.textPrimary,
                fontSize: 12.5,
              ),
            ),
          ),
          if (path != null)
            IconButton(
              onPressed: onClear,
              tooltip: 'Clear',
              icon: const Icon(Icons.close_rounded, size: 16),
              color: luma.textMuted,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          TextButton(
            onPressed: onPick,
            child: Text('Browse', style: TextStyle(color: luma.accent)),
          ),
        ],
      ),
    );
  }
}
