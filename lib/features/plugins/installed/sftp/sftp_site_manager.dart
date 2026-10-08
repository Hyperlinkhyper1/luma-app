import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'host/host_discovery.dart';
import 'host/host_protocol.dart';
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
    required this.onThisDevice,
    this.error,
    this.status,
    this.nearby = const [],
    this.discoveryAvailable = false,
    this.connectingNearbyId,
    this.onQuickConnect,
  });

  final List<SftpSite> sites;
  final bool loading;

  /// The site currently being connected, so its card can show a spinner.
  final String? connectingSiteId;

  final ValueChanged<SftpSite> onConnect;
  final ValueChanged<SftpSite> onEdit;
  final ValueChanged<SftpSite> onDelete;
  final VoidCallback onNew;

  /// Opens the "This device" screen: the credentials another device needs to
  /// connect *to* this one, live only while that screen is open.
  final VoidCallback onThisDevice;

  final String? error;

  /// What an in-progress connection is waiting on, when that is worth saying
  /// — the other device's user pressing Allow, most of all.
  final String? status;

  /// luma devices hosting on this network right now, minus the ones already
  /// saved as sites.
  final List<DiscoveredHost> nearby;

  /// Whether this platform can look for them at all. When it cannot, the
  /// section is left out rather than promising devices that never appear.
  final bool discoveryAvailable;

  /// The nearby device being connected to, so its card can show a spinner.
  final String? connectingNearbyId;

  final ValueChanged<DiscoveredHost>? onQuickConnect;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(onNew: onNew, onThisDevice: onThisDevice),
              const SizedBox(height: 18),
              if (error != null) ...[
                _ErrorCard(message: error!),
                const SizedBox(height: 14),
              ],
              if (status != null) ...[
                _ErrorCard(
                  message: status!,
                  icon: Icons.hourglass_top_rounded,
                  tone: luma.accent,
                ),
                const SizedBox(height: 14),
              ],
              if (discoveryAvailable && onQuickConnect != null) ...[
                _NearbySection(
                  hosts: nearby,
                  connectingId: connectingNearbyId,
                  busy: connectingSiteId != null || connectingNearbyId != null,
                  onConnect: onQuickConnect!,
                ),
                const SizedBox(height: 18),
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
                    title: t.sftpSiteNoServersTitle,
                    subtitle: t.sftpSiteNoServersBody,
                    action: LumaPrimaryButton(
                      label: t.sftpSiteNew,
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

/// "On this network": luma devices that are hosting right now, one tap from
/// connecting. Only the address and port come from the network — the pairing
/// password is still typed, so being listed grants nothing.
class _NearbySection extends StatelessWidget {
  const _NearbySection({
    required this.hosts,
    required this.connectingId,
    required this.busy,
    required this.onConnect,
  });

  final List<DiscoveredHost> hosts;
  final String? connectingId;
  final bool busy;
  final ValueChanged<DiscoveredHost> onConnect;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.wifi_tethering_rounded, size: 16, color: luma.accent),
            const SizedBox(width: 8),
            Text(
              t.sftpNearbyTitle,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (hosts.isEmpty)
          Text(
            t.sftpNearbyEmpty,
            style: TextStyle(color: luma.textMuted, fontSize: 12, height: 1.4),
          )
        else
          for (final host in hosts) ...[
            _NearbyCard(
              host: host,
              connecting: connectingId == host.id,
              busy: busy,
              onConnect: () => onConnect(host),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _NearbyCard extends StatefulWidget {
  const _NearbyCard({
    required this.host,
    required this.connecting,
    required this.busy,
    required this.onConnect,
  });

  final DiscoveredHost host;
  final bool connecting;
  final bool busy;
  final VoidCallback onConnect;

  @override
  State<_NearbyCard> createState() => _NearbyCardState();
}

class _NearbyCardState extends State<_NearbyCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final host = widget.host;
    final enabled = !widget.busy && host.compatible;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: enabled ? widget.onConnect : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hovering && enabled ? luma.surfaceHover : luma.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovering && enabled ? luma.accent : luma.border,
            ),
          ),
          child: Row(
            children: [
              LumaIconBadge(
                icon: Icons.devices_rounded,
                color: luma.accent,
                size: 38,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host.deviceName,
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
                      host.compatible
                          ? '${host.address}:${host.port}'
                          : t.sftpNearbyOtherVersion(host.address),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: host.compatible
                            ? luma.textSecondary
                            : luma.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (widget.connecting)
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                )
              else
                LumaGhostButton(
                  label: t.sftpConnect,
                  icon: Icons.link_rounded,
                  onTap: enabled ? widget.onConnect : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Title, and the two directions this screen offers: out to a saved server,
/// or in to this device. On a phone the buttons drop below the title rather
/// than squeezing it.
class _Header extends StatelessWidget {
  const _Header({required this.onNew, required this.onThisDevice});

  final VoidCallback onNew;
  final VoidCallback onThisDevice;

  static const double _stackBelow = 560;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);

    final title = Row(
      children: [
        LumaIconBadge(icon: Icons.storage_rounded, color: luma.accent),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.sftpSiteManagerTitle,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                t.sftpSiteManagerSubtitle,
                style: TextStyle(color: luma.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < _stackBelow;
        final thisDevice = LumaGhostButton(
          label: t.sftpThisDeviceTitle,
          icon: Icons.smartphone_rounded,
          onTap: onThisDevice,
        );
        final newSite = LumaPrimaryButton(
          label: t.sftpSiteNew,
          icon: Icons.add_rounded,
          onTap: onNew,
        );

        if (!stacked) {
          return Row(
            children: [
              Expanded(child: title),
              thisDevice,
              const SizedBox(width: 8),
              newSite,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            title,
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: thisDevice),
                const SizedBox(width: 8),
                Expanded(child: newSite),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    this.icon = Icons.error_outline_rounded,
    this.tone,
  });

  final String message;
  final IconData icon;

  /// Defaults to the danger colour; a status that is not a failure passes
  /// its own.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = tone ?? luma.danger;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
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
    final t = L.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, size: 15, color: luma.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            t.sftpPrivacyNote,
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
    final t = L.of(context);
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
                icon: site.isLumaHost
                    ? Icons.devices_rounded
                    : site.authMode == SftpAuthMode.key
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
                  message: t.sftpPasswordSavedTooltip,
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
                  tooltip: t.sftpEditSiteTooltip,
                  icon: const Icon(Icons.edit_rounded, size: 17),
                  color: luma.textSecondary,
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                ),
                IconButton(
                  onPressed: widget.busy ? null : widget.onDelete,
                  tooltip: t.sftpRemoveSiteTooltip,
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

  late SftpTransport _transport;
  late SftpAuthMode _authMode;
  late bool _saveSecret;
  String? _keyPath;
  bool _obscure = true;
  String? _error;

  bool get _isLumaHost => _transport == SftpTransport.lumaHost;

  @override
  void initState() {
    super.initState();
    final site = widget.site;
    _transport = site?.transport ?? SftpTransport.ssh;
    _name = TextEditingController(text: site?.name ?? '');
    _host = TextEditingController(text: site?.host ?? '');
    _port = TextEditingController(
      text: (site?.port ?? (_isLumaHost ? kDefaultHostPort : 22)).toString(),
    );
    _username = TextEditingController(text: site?.username ?? '');
    _secret = TextEditingController(text: widget.existingSecret ?? '');
    _remoteDirectory = TextEditingController(text: site?.remoteDirectory ?? '');
    _authMode = site?.authMode ?? SftpAuthMode.password;
    _saveSecret = site?.saveSecret ?? true;
    _keyPath = site?.keyPath;
  }

  /// Switches the kind of endpoint, moving the port to the new default when
  /// it is still the old one — someone who typed their own port keeps it.
  void _setTransport(SftpTransport transport) {
    if (transport == _transport) return;
    setState(() {
      final previousDefault =
          _isLumaHost ? kDefaultHostPort : 22;
      _transport = transport;
      if (_port.text.trim() == '$previousDefault') {
        _port.text = '${_isLumaHost ? kDefaultHostPort : 22}';
      }
      if (_isLumaHost) {
        // A luma device has no accounts and no key files; the pairing password
        // is the whole of its authentication.
        _authMode = SftpAuthMode.password;
        _keyPath = null;
      }
      _error = null;
    });
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
      dialogTitle: L.of(context).sftpChoosePrivateKey,
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    setState(() => _keyPath = path);
  }

  void _submit() {
    final t = L.of(context);
    final host = _host.text.trim();
    if (host.isEmpty) {
      setState(() => _error = t.sftpErrHostRequired);
      return;
    }
    final username = _username.text.trim();
    if (!_isLumaHost && username.isEmpty) {
      setState(() => _error = t.sftpErrUsernameRequired);
      return;
    }
    final port = int.tryParse(_port.text.trim());
    if (port == null || port < 1 || port > 65535) {
      setState(() => _error = t.sftpPortRangeError);
      return;
    }
    if (!_isLumaHost &&
        _authMode == SftpAuthMode.key &&
        (_keyPath == null || _keyPath!.isEmpty)) {
      setState(() => _error = t.sftpErrKeyFileRequired);
      return;
    }

    final existing = widget.site;
    final draft = SftpSite(
      id: existing?.id ?? newSftpSiteId(),
      name: _name.text.trim(),
      host: host,
      port: port,
      username: username,
      transport: _transport,
      authMode: _isLumaHost ? SftpAuthMode.password : _authMode,
      keyPath:
          !_isLumaHost && _authMode == SftpAuthMode.key ? _keyPath : null,
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
    final t = L.of(context);
    final isKey = !_isLumaHost && _authMode == SftpAuthMode.key;

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
                      widget.site == null
                          ? t.sftpSiteNew
                          : t.sftpEditSiteTitle,
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
                    Text(
                      t.sftpEndpointQuestion,
                      style: TextStyle(color: luma.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    LumaSegmentedTabs(
                      tabs: [t.sftpTransportSshServer, t.sftpTransportLumaDevice],
                      selectedIndex: _isLumaHost ? 1 : 0,
                      onSelect: (index) => _setTransport(
                        index == 0
                            ? SftpTransport.ssh
                            : SftpTransport.lumaHost,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLumaHost
                          ? t.sftpLumaDeviceHint
                          : t.sftpSshServerHint,
                      style: TextStyle(
                        color: luma.textMuted,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _field(
                      _name,
                      t.commonName,
                      hint: _isLumaHost
                          ? t.sftpSiteNameHintLuma
                          : t.sftpSiteNameHintServer,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _field(
                            _host,
                            _isLumaHost
                                ? t.sftpHostFieldAddress
                                : t.sftpSiteFieldHost,
                            hint: _isLumaHost
                                ? '192.168.1.42'
                                : t.sftpSiteHostHint,
                            autofocus: widget.site == null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field(
                            _port,
                            t.sftpPortLabel,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    if (!_isLumaHost) ...[
                      const SizedBox(height: 12),
                      _field(_username, t.commonUsername, hint: 'root'),
                      const SizedBox(height: 16),
                      Text(
                        t.sftpSignInWith,
                        style:
                            TextStyle(color: luma.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      LumaSegmentedTabs(
                        tabs: [t.commonPassword, t.sftpSignInSshKey],
                        selectedIndex: isKey ? 1 : 0,
                        onSelect: (index) => setState(() {
                          _authMode = index == 0
                              ? SftpAuthMode.password
                              : SftpAuthMode.key;
                          _error = null;
                        }),
                      ),
                    ],
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
                        labelText: _isLumaHost
                            ? t.sftpPairingPasswordLabel
                            : isKey
                                ? t.sftpKeyPassphrase
                                : t.commonPassword,
                        helperText: _isLumaHost
                            ? t.sftpPairingPasswordHelper
                            : isKey
                                ? t.sftpKeyPassphraseHelper
                                : null,
                        suffixIcon: IconButton(
                          tooltip: _obscure ? t.sftpShow : t.sftpHide,
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
                      label: _isLumaHost
                          ? t.sftpSaveDeviceSecret
                          : isKey
                              ? t.sftpSaveKeyPassphrase
                              : t.sftpSaveSitePassword,
                      subtitle: _isLumaHost
                          ? t.sftpSaveDeviceSecretNote
                          : t.sftpSaveSiteSecretNote,
                      onChanged: (value) => setState(() => _saveSecret = value),
                    ),
                    const SizedBox(height: 6),
                    _field(
                      _remoteDirectory,
                      t.sftpOpenFolderOnConnect,
                      hint: _isLumaHost
                          ? t.sftpLumaFolderHint
                          : t.sftpSftpFolderHint,
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
                    label: t.commonCancel,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  LumaPrimaryButton(
                    label: t.sftpSaveSite,
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
    final t = L.of(context);
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
              path ?? t.sftpNoKeyChosen,
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
              tooltip: t.commonClear,
              icon: const Icon(Icons.close_rounded, size: 16),
              color: luma.textMuted,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          TextButton(
            onPressed: onPick,
            child: Text(t.commonBrowse, style: TextStyle(color: luma.accent)),
          ),
        ],
      ),
    );
  }
}
