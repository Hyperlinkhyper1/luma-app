import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../mc_content_scope.dart';
import '../mc_credentials.dart';
import '../mc_models.dart';
import 'account_shared.dart';
import 'pmc_webview_fetcher.dart';

/// Collects the per-platform credentials MC Content needs.
Future<void> showMcSetupDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => McContentScope(
        repository: McContentScope.of(context),
        child: const _McSetupDialog(),
      ),
    );

class _McSetupDialog extends StatefulWidget {
  const _McSetupDialog();

  @override
  State<_McSetupDialog> createState() => _McSetupDialogState();
}

class _McSetupDialogState extends State<_McSetupDialog> {
  final _modrinthUser = TextEditingController();
  final _modrinthToken = TextEditingController();
  final _curseKey = TextEditingController();
  final _curseAuthor = TextEditingController();
  final _curseProject = TextEditingController();
  final _pmcUser = TextEditingController();

  bool _prefilled = false;
  bool _busy = false;
  String? _trackError;
  String? _trackNotice;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The scope is unreadable from initState, and re-prefilling on every
    // dependency change would wipe out whatever is half-typed.
    if (_prefilled) return;
    _prefilled = true;
    final c = McContentScope.of(context).credentials;
    _modrinthUser.text = c.modrinthUsername ?? '';
    _modrinthToken.text = c.modrinthToken ?? '';
    _curseKey.text = c.curseforgeApiKey ?? '';
    _curseAuthor.text = c.curseforgeAuthorId ?? '';
    _pmcUser.text = c.pmcUsername ?? '';
  }

  @override
  void dispose() {
    _modrinthUser.dispose();
    _modrinthToken.dispose();
    _curseKey.dispose();
    _curseAuthor.dispose();
    _curseProject.dispose();
    _pmcUser.dispose();
    super.dispose();
  }

  String? _clean(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  McCredentials _current() {
    final existing = McContentScope.of(context).credentials;
    return McCredentials(
      modrinthUsername: _clean(_modrinthUser),
      modrinthToken: _clean(_modrinthToken),
      curseforgeApiKey: _clean(_curseKey),
      curseforgeAuthorId: _clean(_curseAuthor),
      curseforgeProjectIds: existing.curseforgeProjectIds,
      pmcUsername: _clean(_pmcUser),
    );
  }

  Future<void> _save() async {
    final repository = McContentScope.of(context);
    setState(() => _busy = true);
    await repository.saveCredentials(_current());
    if (mounted) Navigator.of(context).pop();
  }

  /// Saves the typed key first, so a project can be resolved on the very
  /// first visit rather than needing two trips through the dialog.
  Future<void> _trackProject() async {
    final repository = McContentScope.of(context);
    final input = _curseProject.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _busy = true;
      _trackError = null;
      _trackNotice = null;
    });
    try {
      if (_clean(_curseKey) != repository.credentials.curseforgeApiKey) {
        await repository.saveCredentials(_current());
      }
      final project = await repository.trackCurseforgeProject(input);
      if (!mounted) return;
      setState(() {
        _curseProject.clear();
        _trackNotice = 'Now tracking ${project.name}.';
      });
    } catch (e) {
      if (mounted) setState(() => _trackError = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = McContentScope.of(context);
    final tracked = repository.credentials.curseforgeProjectIds;

    return AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: context.lumaDecor.cardBorderRadius,
        side: BorderSide(color: luma.border),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      title: Row(
        children: [
          Icon(Icons.widgets_rounded, size: 20, color: luma.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Minecraft platforms',
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _PlatformHeader(
                platform: McPlatform.modrinth,
                note: 'Public — a username is all it takes.',
                tone: luma.success,
              ),
              _field(
                controller: _modrinthUser,
                label: 'Modrinth username',
                hint: 'e.g. jellysquid3',
              ),
              _field(
                controller: _modrinthToken,
                label: 'Access token (optional)',
                hint: 'mrp_…',
                obscure: true,
                helper: 'Only needed for real download history. Without it, '
                    'luma grows the graph itself from daily snapshots.',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: AccountLinkButton(
                  label: 'Modrinth token settings',
                  icon: Icons.open_in_new_rounded,
                  onTap: () =>
                      openExternal('https://modrinth.com/settings/pats'),
                ),
              ),
              const SizedBox(height: 18),
              _PlatformHeader(
                platform: McPlatform.curseforge,
                note: 'Needs an API key — CurseForge serves nothing without '
                    'one.',
                tone: luma.warning,
              ),
              _field(
                controller: _curseKey,
                label: 'CurseForge API key',
                hint: 'x-api-key from the Studios console',
                obscure: true,
              ),
              _field(
                controller: _curseAuthor,
                label: 'Author id (optional)',
                hint: 'numeric id, e.g. 123456',
                helper: 'CurseForge filters by numeric id and offers no '
                    'username lookup. Leave it blank and track projects '
                    'individually instead.',
              ),
              const SizedBox(height: 10),
              _TrackProjectField(
                controller: _curseProject,
                busy: _busy,
                error: _trackError,
                notice: _trackNotice,
                onTrack: _trackProject,
              ),
              if (tracked.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final id in tracked)
                      _TrackedChip(
                        id: id,
                        onRemove: _busy
                            ? null
                            : () => repository.untrackCurseforgeProject(id),
                      ),
                  ],
                ),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: AccountLinkButton(
                  label: 'CurseForge console',
                  icon: Icons.open_in_new_rounded,
                  onTap: () => openExternal('https://console.curseforge.com/'),
                ),
              ),
              const SizedBox(height: 18),
              _PlatformHeader(
                platform: McPlatform.planetMinecraft,
                note: 'No API — read from your public profile in an embedded '
                    'browser.',
                tone: luma.accent,
              ),
              _field(
                controller: _pmcUser,
                label: 'Planet Minecraft username',
                hint: 'e.g. cyprezz',
              ),
              if (!PmcWebViewFetcher.isSupported)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: AccountNotice(
                    message: 'This platform has no embedded browser engine, so '
                        'Planet Minecraft cannot be read here. Windows and '
                        'Android can.',
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Every key is encrypted on this device and sent only to the '
                'platform it belongs to. None of it reaches a luma server.',
                style: TextStyle(
                  color: luma.textMuted,
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actions: [
        if (repository.configured)
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    final confirmed = await _confirmDisconnect(context);
                    if (!confirmed || !context.mounted) return;
                    await McContentScope.of(context).disconnect();
                    if (context.mounted) Navigator.of(context).pop();
                  },
            style: TextButton.styleFrom(foregroundColor: luma.danger),
            child: const Text('Disconnect all'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: luma.textSecondary),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 6),
        LumaPrimaryButton(
          label: 'Save',
          loading: _busy,
          onTap: _busy ? null : _save,
        ),
      ],
    );
  }

  Future<bool> _confirmDisconnect(BuildContext context) async {
    final luma = context.luma;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text(
          'Disconnect every platform?',
          style: TextStyle(color: luma.textPrimary, fontSize: 16),
        ),
        content: Text(
          'The stored keys, the cached numbers and the download history luma '
          'has been recording are all deleted from this device. The history '
          'cannot be re-fetched — CurseForge and Planet Minecraft publish no '
          'past data.',
          style: TextStyle(color: luma.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: luma.textSecondary),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: luma.danger),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? helper,
    bool obscure = false,
  }) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            enabled: !_busy,
            obscureText: obscure,
            style: TextStyle(color: luma.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: luma.textMuted, fontSize: 12.5),
              helperText: helper,
              helperMaxLines: 3,
              helperStyle: TextStyle(color: luma.textMuted, fontSize: 11),
              filled: true,
              fillColor: luma.background,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: luma.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: luma.accent, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformHeader extends StatelessWidget {
  const _PlatformHeader({
    required this.platform,
    required this.note,
    required this.tone,
  });

  final McPlatform platform;
  final String note;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  platform.label,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  note,
                  style: TextStyle(
                    color: luma.textMuted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackProjectField extends StatelessWidget {
  const _TrackProjectField({
    required this.controller,
    required this.busy,
    required this.onTrack,
    this.error,
    this.notice,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onTrack;
  final String? error;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Track a single project',
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !busy,
                onSubmitted: (_) => onTrack(),
                style: TextStyle(color: luma.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Paste a CurseForge project URL or slug',
                  hintStyle: TextStyle(color: luma.textMuted, fontSize: 12.5),
                  errorText: error,
                  errorMaxLines: 3,
                  filled: true,
                  fillColor: luma.background,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: luma.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: luma.accent, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 46,
              child: LumaGhostButton(
                label: 'Track',
                icon: Icons.add_rounded,
                onTap: busy ? null : onTrack,
              ),
            ),
          ],
        ),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 13, color: luma.success),
                const SizedBox(width: 6),
                Text(
                  notice!,
                  style: TextStyle(color: luma.success, fontSize: 11.5),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TrackedChip extends StatelessWidget {
  const _TrackedChip({required this.id, required this.onRemove});

  final String id;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        color: luma.accentSubtle,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$id',
            style: TextStyle(
              color: luma.accent,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 13),
            color: luma.accent,
            tooltip: 'Stop tracking #$id',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
