import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/current_l.dart';
import '../../settings/settings_controller.dart';
import '../../settings/settings_scope.dart';
import '../../sync/sync_scope.dart';
import '../../sync/sync_service.dart';
import '../../theme/luma_theme.dart';
import '../plugins/installed/ai_usage/ai_usage_scope.dart';
import 'ai_key_store.dart';
import 'local_model_store.dart';
import 'providers/ai_client.dart';
import 'providers/ai_providers.dart';
import 'providers/ai_usage.dart';
import 'providers/google_client.dart';
import 'providers/mistral_proxy_client.dart';

/// The "AI Assistant" settings block: choose a hosted provider or manage the
/// optional on-device model. Collapsed by default in [LumaCollapsibleSection].
class AiSettingsSection extends StatelessWidget {
  const AiSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProviderPicker(settings: settings),
          const SizedBox(height: 12),
          const _RetentionNotice(),
          const SizedBox(height: 12),
          // Re-mounts the key-management body whenever the provider changes,
          // so its per-provider loaded state (masked key, etc.) is fresh.
          if (settings.aiProviderId == AiProviderId.local.name &&
              LocalModelStore.supported)
            const _LocalModelBody()
          else if (settings.aiProviderId == AiProviderId.local.name)
            Text(
              L.of(context).aiSettingsLocalNotAvailableIos,
              style: TextStyle(color: context.luma.textMuted, fontSize: 12),
            )
          else
            _AiKeyBody(
              key: ValueKey(settings.aiProviderId),
              providerId: settings.aiProviderId,
            ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(L.of(context).settingsTrackBackendAiUsage),
            subtitle: Text(L.of(context).settingsTrackBackendAiUsageSub),
            value: settings.trackBackendAiUsage,
            onChanged: settings.setTrackBackendAiUsage,
          ),
          _ModelUsageSection(usage: settings.modelUsage),
        ],
      ),
    );
  }
}

class _RetentionNotice extends StatelessWidget {
  const _RetentionNotice();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LumaCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined, size: 17, color: luma.accent),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              L.of(context).aiSettingsRetentionNotice,
              style: TextStyle(
                color: luma.textMuted,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalModelBody extends StatefulWidget {
  const _LocalModelBody();

  @override
  State<_LocalModelBody> createState() => _LocalModelBodyState();
}

class _LocalModelBodyState extends State<_LocalModelBody> {
  final _store = LocalModelStore.instance;
  bool _installed = false;

  @override
  void initState() {
    super.initState();
    _refreshInstalled();
  }

  Future<void> _refreshInstalled() async {
    final installed = await _store.isInstalled;
    if (mounted) setState(() => _installed = installed);
  }

  Future<void> _download() async {
    await _store.download();
    await _refreshInstalled();
  }

  Future<void> _remove() async {
    await _store.remove();
    await _refreshInstalled();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) => LumaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_android_rounded, size: 17, color: luma.accent),
                const SizedBox(width: 8),
                Text(
                  t.aiSettingsLocalModelTitle(LocalModelStore.modelDisplayName),
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              t.aiSettingsLocalModelBlurb(LocalModelStore.modelSizeLabel),
              style: TextStyle(
                color: luma.textMuted,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
            if (_store.isDownloading) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(value: _store.progress),
              const SizedBox(height: 5),
              Text(
                _store.progress == null
                    ? t.aiSettingsDownloadingModel
                    : t.aiSettingsDownloadingModelPercent(
                        (_store.progress! * 100).toStringAsFixed(0),
                      ),
                style: TextStyle(color: luma.textMuted, fontSize: 11),
              ),
            ] else if (_store.error != null) ...[
              const SizedBox(height: 10),
              Text(
                t.aiSettingsDownloadFailed('${_store.error}'),
                style: TextStyle(color: luma.danger, fontSize: 11.5),
              ),
            ],
            const SizedBox(height: 12),
            if (_installed)
              Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: luma.accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.aiSettingsModelReady,
                      style: TextStyle(color: luma.textPrimary, fontSize: 12),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _remove,
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: Text(t.commonRemove),
                  ),
                ],
              )
            else
              FilledButton.icon(
                onPressed: _store.isDownloading ? null : _download,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(t.aiSettingsDownloadModel),
              ),
          ],
        ),
      ),
    );
  }
}

/// Which model has been used the most, across every provider — a simple
/// lifetime successful-message count for each model.
class _ModelUsageSection extends StatefulWidget {
  const _ModelUsageSection({required this.usage});
  final Map<String, int> usage;

  @override
  State<_ModelUsageSection> createState() => _ModelUsageSectionState();
}

class _ModelUsageSectionState extends State<_ModelUsageSection> {
  SyncService? _sync;
  Map<String, String> _modeVersions = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sync = SyncScope.of(context);
    if (identical(sync, _sync)) return;
    _sync = sync;
    sync.aiStatus().then((status) {
      if (!mounted || !identical(sync, _sync)) return;
      setState(() => _modeVersions = status?.modeVersions ?? const {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);

    final rows =
        kModelUsageEntries
            .map((e) => (entry: e, count: widget.usage[e.key] ?? 0))
            .where((r) => r.count > 0)
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));
    final maxScore = rows.isEmpty
        ? 1
        : rows.map((r) => r.count).reduce((a, b) => a > b ? a : b);

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 16, color: luma.accent),
              const SizedBox(width: 8),
              Text(
                t.aiSettingsModelUsage,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            t.aiSettingsModelUsageSubtitle,
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            Text(
              t.aiSettingsNoMessagesYet,
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in rows) ...[
                  _UsageRow(
                    label: r.entry.labelFor(_modeVersions),
                    count: r.count,
                    fraction: r.count / maxScore,
                    top: r == rows.first,
                  ),
                  if (r != rows.last) const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.label,
    required this.count,
    required this.fraction,
    required this.top,
  });

  final String label;
  final int count;
  final double fraction;
  final bool top;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final messages = L.of(context).assistantUsageMessageCount(count);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (top) ...[
              Icon(Icons.star_rounded, size: 13, color: luma.accent),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 12.5,
                fontWeight: top ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              messages,
              style: TextStyle(color: luma.textMuted, fontSize: 11.5),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.03, 1.0),
            minHeight: 6,
            backgroundColor: luma.border,
            valueColor: AlwaysStoppedAnimation(
              top ? luma.accent : luma.accent.withValues(alpha: 0.55),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProviderPicker extends StatelessWidget {
  const _ProviderPicker({required this.settings});
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final provider in kAiProviders)
          if (provider.id != AiProviderId.mistral &&
              (provider.id != AiProviderId.local || LocalModelStore.supported))
            _ProviderChip(
              provider: provider,
              selected: provider.id.name == settings.aiProviderId,
              onTap: () => settings.setAiProviderId(provider.id.name),
              luma: luma,
            ),
      ],
    );
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({
    required this.provider,
    required this.selected,
    required this.onTap,
    required this.luma,
  });

  final AiProviderInfo provider;
  final bool selected;
  final VoidCallback onTap;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? luma.accentSubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? luma.accent : luma.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                provider.icon,
                size: 16,
                color: selected ? luma.accent : luma.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                provider.displayName,
                style: TextStyle(
                  color: selected ? luma.accent : luma.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiKeyBody extends StatefulWidget {
  const _AiKeyBody({super.key, required this.providerId});
  final String providerId;

  @override
  State<_AiKeyBody> createState() => _AiKeyBodyState();
}

class _AiKeyBodyState extends State<_AiKeyBody> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _testing = false;
  bool _saving = false;
  String? _savedMasked;
  bool _fromServer = false;
  late final Future<void> _load = _loadSavedKey();

  AiProviderInfo get _provider => aiProviderById(widget.providerId);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Loads the locally-saved key, or — for the Luma Support (Mistral) and
  /// Luma AI (Google) providers, when nothing is saved yet and this device
  /// is signed into a sync server — checks whether the operator has a
  /// shared key configured there. Only a yes/no ever comes back; the key
  /// itself stays server-side and chat requests are proxied through the
  /// server instead (see ChatController).
  Future<void> _loadSavedKey() async {
    final store = await AiKeyStore.load();
    final key = await store.readKey(widget.providerId);
    var fromServer = false;
    if (key == null &&
        widget.providerId == AiProviderId.mistral.name &&
        mounted) {
      fromServer = await SyncScope.of(context).mistralKeyConfiguredOnServer();
    } else if (key == null &&
        widget.providerId == AiProviderId.google.name &&
        mounted) {
      final status = await SyncScope.of(context).aiStatus();
      fromServer = status?.googleConfigured ?? false;
    }
    if (!mounted) return;
    setState(() {
      _savedMasked = key == null ? null : _mask(key);
      _fromServer = fromServer;
    });
  }

  static String _mask(String key) {
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 7)}••••${key.substring(key.length - 4)}';
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    setState(() => _saving = true);
    final store = await AiKeyStore.load();
    await store.saveKey(widget.providerId, value);
    _controller.clear();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _savedMasked = _mask(value);
      _fromServer = false;
    });
    _showSnack(currentL.aiSettingsKeySaved);
  }

  Future<void> _testConnection() async {
    final typed = _controller.text.trim();
    final aiUsage = AiUsageScope.maybeOf(context);
    AiClient client = _provider.client;
    String? key = typed.isNotEmpty ? typed : null;
    if (key == null) {
      final store = await AiKeyStore.load();
      key = await store.readKey(widget.providerId);
    }
    if (key == null && _fromServer && mounted) {
      final sync = SyncScope.of(context);
      final serverUrl = sync.serverUrl;
      final token = sync.authToken;
      if (sync.serverReady && serverUrl != null && token != null) {
        client = widget.providerId == AiProviderId.google.name
            ? GoogleProxyClient(serverUrl: serverUrl)
            : MistralProxyClient(serverUrl: serverUrl);
        key = token;
      }
    }
    if (key == null || key.isEmpty) {
      _showSnack(currentL.aiSettingsEnterKeyFirst);
      return;
    }
    setState(() => _testing = true);
    try {
      final result = await client.chat(
        apiKey: key,
        history: const [AiTurn(role: 'user', text: 'Hi')],
        systemPrompt: '',
        tools: const [],
        executeTool: (_, __) async => const {},
        metadataFor: (_, __) => null,
      );
      final usage = result.usage;
      if (usage != null &&
          client is! GoogleProxyClient &&
          client is! MistralProxyClient) {
        await aiUsage?.recordLumaCall(
          providerId: widget.providerId,
          usage: usage,
          feature: 'Key test',
        );
      }
      _showSnack(currentL.aiSettingsConnectionWorks);
    } on AiError catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack(currentL.aiSettingsCouldNotVerifyKey('$e'));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _clear() async {
    final luma = context.luma;
    final t = L.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: luma.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: luma.border),
        ),
        title: Text(
          t.aiSettingsRemoveKeyTitle,
          style: TextStyle(color: luma.textPrimary),
        ),
        content: Text(
          t.aiSettingsRemoveKeyBody(_provider.displayName),
          style: TextStyle(color: luma.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.commonCancel, style: TextStyle(color: luma.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.commonRemove, style: TextStyle(color: luma.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final store = await AiKeyStore.load();
    await store.clearKey(widget.providerId);
    if (!mounted) return;
    setState(() {
      _savedMasked = null;
      _fromServer = false;
    });
    _showSnack(currentL.aiSettingsKeyRemoved);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return FutureBuilder<void>(
      future: _load,
      builder: (context, _) => LumaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_savedMasked != null) ...[
              Row(
                children: [
                  Icon(Icons.key_rounded, size: 16, color: luma.accent),
                  const SizedBox(width: 8),
                  Text(
                    _savedMasked!,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ] else if (_fromServer) ...[
              Row(
                children: [
                  Icon(Icons.cloud_done_rounded, size: 16, color: luma.accent),
                  const SizedBox(width: 8),
                  Text(
                    t.aiSettingsSharedKeyAvailable,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _controller,
              obscureText: _obscure,
              style: TextStyle(color: luma.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                hintText: _savedMasked != null
                    ? t.aiSettingsHintReplaceKey
                    : _fromServer
                    ? t.aiSettingsHintOverrideSharedKey
                    : _provider.keyHint,
                hintStyle: TextStyle(color: luma.textMuted),
                filled: true,
                fillColor: luma.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
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
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: luma.textMuted,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                LumaPrimaryButton(
                  label: t.commonSave,
                  icon: Icons.save_rounded,
                  loading: _saving,
                  onTap: _save,
                ),
                LumaGhostButton(
                  label: t.aiSettingsTestConnection,
                  icon: Icons.wifi_tethering_rounded,
                  onTap: _testing ? null : _testConnection,
                ),
                if (_savedMasked != null)
                  LumaGhostButton(
                    label: t.aiSettingsRemoveKey,
                    icon: Icons.delete_outline_rounded,
                    onTap: _clear,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _fromServer
                  ? t.aiSettingsSharedKeyExplanation(_provider.displayName)
                  : t.aiSettingsLocalKeyExplanation(_provider.displayName),
              style: TextStyle(
                color: luma.textMuted,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
