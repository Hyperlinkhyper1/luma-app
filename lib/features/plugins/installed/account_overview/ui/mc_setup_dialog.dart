import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
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

  bool _testBusy = false;
  bool? _testOk;
  String? _testResult;

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
    final t = L.of(context);
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
        _trackNotice = t.mcSetupNowTracking(project.name);
      });
    } catch (e) {
      if (mounted) setState(() => _trackError = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Hits CurseForge directly with whatever key is currently typed, so the
  /// user sees the real HTTP status and body instead of the generic
  /// "rejected" message a normal fetch collapses everything into.
  Future<void> _testCurseKey() async {
    final t = L.of(context);
    final key = _clean(_curseKey);
    if (key == null) {
      setState(() {
        _testOk = false;
        _testResult = t.mcSetupEnterKeyFirst;
      });
      return;
    }
    setState(() {
      _testBusy = true;
      _testOk = null;
      _testResult = null;
    });
    try {
      final result =
          await McContentScope.of(context).testCurseforgeKey(key);
      if (!mounted) return;
      setState(() {
        _testOk = result.ok;
        _testResult = result.ok
            ? t.mcSetupKeyWorks
            : 'HTTP ${result.statusCode}: ${_trimBody(result.body)}';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _testOk = false;
          _testResult = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _testBusy = false);
    }
  }

  String _trimBody(String body) =>
      body.length > 220 ? '${body.substring(0, 220)}…' : body;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
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
              t.mcSetupPlatformsTitle,
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
                note: t.mcSetupModrinthNote,
                tone: luma.success,
              ),
              _field(
                controller: _modrinthUser,
                label: t.mcSetupModrinthUsername,
                hint: t.mcSetupModrinthUsernameHint,
              ),
              _field(
                controller: _modrinthToken,
                label: t.mcSetupModrinthToken,
                hint: 'mrp_…',
                obscure: true,
                helper: t.mcSetupModrinthTokenHelper,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: AccountLinkButton(
                  label: t.mcSetupModrinthTokenLink,
                  icon: Icons.open_in_new_rounded,
                  onTap: () =>
                      openExternal('https://modrinth.com/settings/pats'),
                ),
              ),
              const SizedBox(height: 18),
              _PlatformHeader(
                platform: McPlatform.curseforge,
                note: t.mcSetupCurseNote,
                tone: luma.warning,
              ),
              _field(
                controller: _curseKey,
                label: t.mcSetupCurseKey,
                hint: t.mcSetupCurseKeyHint,
                obscure: true,
              ),
              Row(
                children: [
                  AccountLinkButton(
                    label: t.mcSetupCurseKeysLink,
                    icon: Icons.open_in_new_rounded,
                    onTap: () => openExternal(
                        'https://console.curseforge.com/#/api-keys'),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    height: 30,
                    child: LumaGhostButton(
                      label: _testBusy ? t.mcSetupTestingKey : t.mcSetupTestKey,
                      icon: Icons.wifi_tethering_rounded,
                      onTap: _busy || _testBusy ? null : _testCurseKey,
                    ),
                  ),
                ],
              ),
              if (_testResult != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _testResult!,
                    style: TextStyle(
                      color: _testOk == true ? luma.success : luma.danger,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              _field(
                controller: _curseAuthor,
                label: t.mcSetupAuthorId,
                hint: t.mcSetupAuthorIdHint,
                helper: t.mcSetupAuthorIdHelper,
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
                  label: t.mcSetupCurseConsole,
                  icon: Icons.open_in_new_rounded,
                  onTap: () => openExternal('https://console.curseforge.com/'),
                ),
              ),
              const SizedBox(height: 18),
              _PlatformHeader(
                platform: McPlatform.planetMinecraft,
                note: t.mcSetupPmcNote,
                tone: luma.accent,
              ),
              _field(
                controller: _pmcUser,
                label: t.mcSetupPmcUsername,
                hint: t.mcSetupPmcUsernameHint,
              ),
              if (!PmcWebViewFetcher.isSupported)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: AccountNotice(
                    message: t.mcSetupPmcUnsupported,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                t.mcSetupPrivacy,
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
            child: Text(t.mcSetupDisconnectAll),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: luma.textSecondary),
          child: Text(t.commonCancel),
        ),
        const SizedBox(width: 6),
        LumaPrimaryButton(
          label: t.commonSave,
          loading: _busy,
          onTap: _busy ? null : _save,
        ),
      ],
    );
  }

  Future<bool> _confirmDisconnect(BuildContext context) async {
    final luma = context.luma;
    final t = L.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text(
          t.mcSetupDisconnectTitle,
          style: TextStyle(color: luma.textPrimary, fontSize: 16),
        ),
        content: Text(
          t.mcSetupDisconnectBody,
          style: TextStyle(color: luma.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: luma.textSecondary),
            child: Text(t.accountOverviewKeepIt),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: luma.danger),
            child: Text(t.accountOverviewDisconnect),
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
    final t = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.mcSetupTrackTitle,
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
                  hintText: t.mcSetupTrackHint,
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
                label: t.mcSetupTrack,
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
    final t = L.of(context);
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
            tooltip: t.mcSetupStopTracking(id),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
