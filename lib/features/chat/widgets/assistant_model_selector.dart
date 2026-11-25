import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../settings/settings_controller.dart';
import '../../../sync/sync_scope.dart';
import '../../../sync/sync_service.dart';
import '../../../theme/luma_theme.dart';
import '../account/assistant_panels.dart';
import '../ai_key_store.dart';
import '../assistant_auto_router.dart';
import '../local_model_store.dart';
import '../providers/ai_modes.dart';
import '../providers/ai_providers.dart';
import '../providers/ai_usage.dart';
import 'compose_mode_menu.dart';

/// One entry in the model menu: a user-facing name mapped to the provider
/// (and, for Luma AI, the intelligence mode) it actually selects.
class _ModelChoice {
  const _ModelChoice(
    this.label,
    this.providerId, {
    this.mode,
    this.modelId,
    this.auto = false,
  });

  final String label;
  final String providerId;

  final AiMode? mode;
  final String? modelId;

  /// Luma Auto: picks a Luma AI mode, picture model or file per message.
  final bool auto;

  String get usageKey => auto
      ? kAutoModelUsageKey
      : modelUsageKeyFor(providerId, mode: mode);

  bool isActive(SettingsController settings) =>
      settings.aiProviderId == providerId &&
      (auto
          ? settings.aiMode == kAutoAiMode
          : mode == null || settings.aiMode == mode!.name) &&
      (modelId == null ||
          modelId ==
              (settings.aiModelFor(providerId) ??
                  aiProviderById(providerId).defaultModel));
}

List<_ModelChoice> _lumaModelsFor(
  SettingsController settings,
  Map<String, String> modeVersions,
) => [
  _ModelChoice('Luma Auto', AiProviderId.google.name, auto: true),
  for (final mode in AiMode.values.where(
    (mode) => mode.availableForPlan(settings.selectedPlanId),
  ))
    _ModelChoice(
      'Luma ${mode.displayNameFor(modeVersions[mode.name])}',
      AiProviderId.google.name,
      mode: mode,
    ),
  if (LocalModelStore.supported)
    _ModelChoice('Luma Assistant', AiProviderId.local.name),
];

const _apiKeyAction = _ModelChoice('', '');

/// Selects a Luma model or a saved model from a connected API provider.
class AssistantModelSelector extends StatefulWidget {
  const AssistantModelSelector({
    super.key,
    required this.settings,
    required this.keyStore,
    this.picture = false,
  });

  final SettingsController settings;
  final AiKeyStore keyStore;

  /// Picture mode draws with one of the two admin-picked image models
  /// whatever chat model is selected, so the pill names that instead and
  /// opens a Standard / Pro choice.
  final bool picture;

  @override
  State<AssistantModelSelector> createState() => _AssistantModelSelectorState();
}

class _AssistantModelSelectorState extends State<AssistantModelSelector> {
  SyncService? _sync;
  Map<String, String> _modeVersions = const {};
  AiServerStatus? _status;
  bool _pickerOpen = false;

  SettingsController get settings => widget.settings;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sync = SyncScope.of(context);
    if (identical(sync, _sync)) return;
    _sync = sync;
    _refreshVersions();
  }

  Future<void> _refreshVersions() async {
    final sync = _sync;
    final status = sync != null && sync.serverReady
        ? await sync.aiStatus()
        : null;
    if (!mounted || !identical(sync, _sync)) return;
    setState(() {
      _status = status;
      _modeVersions = status?.modeVersions ?? const {};
    });
  }

  /// Where a menu opened from the pill anchors: the pill's own rect,
  /// relative to the overlay.
  RelativeRect _menuPosition() {
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    return RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
  }

  /// The picture pill's menu: the operator's cheaper standard model and
  /// the pricier pro one, each with what a picture costs on this plan.
  Future<void> _openPictureMenu() async {
    await _refreshVersions();
    if (!mounted) return;
    final luma = context.luma;
    final status = _status;

    PopupMenuItem<String> item(
      String tier,
      String label,
      double? percent,
      bool available,
    ) {
      final selected = settings.pictureTier == tier;
      final enabled = available && percent != null;
      return PopupMenuItem<String>(
        value: tier,
        enabled: enabled,
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: !enabled
                      ? luma.textMuted
                      : selected
                      ? luma.accent
                      : luma.textPrimary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              enabled
                  ? '${formatPicturePercent(percent)}% weekly usage'
                  : 'Unavailable',
              style: TextStyle(color: luma.textMuted, fontSize: 10.5),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 16,
              child: selected
                  ? Icon(Icons.check_rounded, size: 16, color: luma.accent)
                  : null,
            ),
          ],
        ),
      );
    }

    final picked = await showMenu<String>(
      context: context,
      position: _menuPosition(),
      constraints: const BoxConstraints(minWidth: 270, maxWidth: 330),
      color: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: luma.border),
      ),
      items: [
        item(
          'standard',
          _pictureLabel('standard'),
          status?.pictureWeeklyPct,
          status?.pictureConfigured ?? false,
        ),
        item(
          'pro',
          _pictureLabel('pro'),
          status?.pictureProWeeklyPct,
          status?.pictureProConfigured ?? false,
        ),
      ],
    );
    if (mounted && picked != null) settings.setPictureTier(picked);
  }

  static String _pictureLabel(String tier) =>
      tier == 'pro' ? 'Luma Picture Pro' : 'Luma Picture';

  String get _activeLabel {
    final providerId = settings.aiProviderId;
    if (isApiKeyProvider(providerId)) {
      final provider = aiProviderById(providerId);
      return settings.aiModelFor(providerId) ??
          provider.defaultModel ??
          provider.displayName;
    }
    final lumaModels = _lumaModelsFor(settings, _modeVersions);
    return lumaModels
        .firstWhere(
          (choice) => choice.isActive(settings),
          orElse: () => lumaModels.firstWhere((choice) => !choice.auto),
        )
        .label;
  }

  Future<List<AiProviderInfo>> _connectedProviders() async {
    final providers = await Future.wait(
      kApiKeyProviders.map((provider) async {
        try {
          final key = await widget.keyStore.readKey(provider.id.name);
          return key == null || key.isEmpty ? null : provider;
        } catch (_) {
          return null;
        }
      }),
    );
    return providers.whereType<AiProviderInfo>().toList();
  }

  Iterable<_ModelChoice> _apiModels(List<AiProviderInfo> providers) sync* {
    for (final provider in providers) {
      final id = provider.id.name;
      final modelIds = <String>{
        ...settings.savedAiModelsFor(id),
        if (settings.aiProviderId == id)
          ?(settings.aiModelFor(id) ?? provider.defaultModel),
      };
      for (final model in modelIds) {
        yield _ModelChoice(model, id, modelId: model);
      }
    }
  }

  Future<void> _openPicker() async {
    if (_pickerOpen) return;
    _pickerOpen = true;
    try {
      if (widget.picture) {
        await _openPictureMenu();
      } else {
        await _openMenu();
      }
    } finally {
      _pickerOpen = false;
    }
  }

  Future<void> _openMenu() async {
    final (providers, _) = await (
      _connectedProviders(),
      _refreshVersions(),
    ).wait;
    if (!mounted) return;
    final luma = context.luma;
    final t = L.of(context);
    final counts = settings.modelUsage;
    final titleStyle = TextStyle(
      color: luma.textMuted,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );
    final captionStyle = TextStyle(color: luma.textMuted, fontSize: 10.5);
    final providerStyle = captionStyle.copyWith(color: luma.textSecondary);

    PopupMenuItem<_ModelChoice> item(_ModelChoice choice) {
      final selected = choice.isActive(settings);
      final apiModel = choice.modelId != null;
      final count =
          counts[choice.usageKey] ?? 0;
      final label = Text(
        choice.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: selected ? luma.accent : luma.textPrimary,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      );
      return PopupMenuItem<_ModelChoice>(
        value: choice,
        height: apiModel ? 44 : 40,
        child: Semantics(
          selected: selected,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (apiModel)
                      Tooltip(
                        message: choice.label,
                        excludeFromSemantics: true,
                        child: label,
                      )
                    else
                      label,
                    if (apiModel)
                      Text(
                        aiProviderById(choice.providerId).displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: providerStyle,
                      ),
                  ],
                ),
              ),
              if (!apiModel)
                Text(
                  count == 0
                      ? t.assistantModelUnused
                      : t.assistantModelMessageCount(count),
                  style: captionStyle,
                ),
              const SizedBox(width: 8),
              SizedBox(
                width: 16,
                child: selected
                    ? Icon(Icons.check_rounded, size: 16, color: luma.accent)
                    : null,
              ),
            ],
          ),
        ),
      );
    }

    final picked = await showMenu<_ModelChoice>(
      context: context,
      position: _menuPosition(),
      constraints: const BoxConstraints(minWidth: 270, maxWidth: 330),
      color: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: luma.border),
      ),
      items: [
        PopupMenuItem<_ModelChoice>(
          enabled: false,
          height: 30,
          child: Text(t.assistantModelsHeader, style: titleStyle),
        ),
        ..._lumaModelsFor(settings, _modeVersions).map(item),
        const PopupMenuDivider(height: 10),
        PopupMenuItem<_ModelChoice>(
          value: _apiKeyAction,
          height: 40,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.assistantApiKeyHeader,
                  style: titleStyle.copyWith(color: luma.textSecondary),
                ),
              ),
              Tooltip(
                message: providers.isEmpty
                    ? t.assistantApiAddKey
                    : t.assistantApiAddModel,
                child: Icon(Icons.add_rounded, size: 17, color: luma.accent),
              ),
            ],
          ),
        ),
        ..._apiModels(providers).map(item),
      ],
    );

    if (picked == null || !mounted) return;
    if (identical(picked, _apiKeyAction)) {
      await _openApiAction(providers);
    } else if (picked.modelId case final model?) {
      settings.selectAiModel(picked.providerId, model);
    } else {
      settings.setAiProviderId(picked.providerId);
      if (picked.auto) {
        settings.setAiMode(kAutoAiMode);
      } else if (picked.mode case final mode?) {
        settings.setAiMode(mode.name);
      }
    }
  }

  Future<void> _openApiAction(List<AiProviderInfo> providers) async {
    if (providers.isEmpty) {
      await showAssistantPanel(context, AssistantPanel.api);
      return;
    }
    final picked = await showDialog<_ModelChoice>(
      context: context,
      builder: (context) => _AddApiModelDialog(providers: providers),
    );
    if (picked == null || !mounted) return;
    if (identical(picked, _apiKeyAction)) {
      await showAssistantPanel(context, AssistantPanel.api);
    } else if (picked.modelId case final model?) {
      settings.selectAiModel(picked.providerId, model);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final picture = widget.picture;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => TextButton(
        onPressed: _openPicker,
        style: TextButton.styleFrom(
          foregroundColor: luma.textSecondary,
          disabledForegroundColor: luma.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                picture ? _pictureLabel(settings.pictureTier) : _activeLabel,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 17,
              color: luma.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddApiModelDialog extends StatefulWidget {
  const _AddApiModelDialog({required this.providers});

  final List<AiProviderInfo> providers;

  @override
  State<_AddApiModelDialog> createState() => _AddApiModelDialogState();
}

class _AddApiModelDialogState extends State<_AddApiModelDialog> {
  late AiProviderInfo _provider = widget.providers.first;
  String _modelId = '';

  void _add() {
    if (_modelId.isEmpty) return;
    Navigator.pop(
      context,
      _ModelChoice(_modelId, _provider.id.name, modelId: _modelId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return AlertDialog(
      title: Text(t.assistantApiAddModel),
      scrollable: true,
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<AiProviderInfo>(
              initialValue: _provider,
              isExpanded: true,
              decoration: InputDecoration(labelText: t.assistantApiProvider),
              items: [
                for (final provider in widget.providers)
                  DropdownMenuItem(
                    value: provider,
                    child: Text(
                      provider.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (provider) {
                if (provider != null) setState(() => _provider = provider);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: t.assistantApiModelId,
                hintText: _provider.defaultModel,
              ),
              onChanged: (value) => setState(() => _modelId = value.trim()),
              onSubmitted: (_) => _add(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context, _apiKeyAction),
                icon: const Icon(Icons.key_rounded, size: 16),
                label: Text(t.assistantApiManage),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.commonCancel),
        ),
        FilledButton(
          onPressed: _modelId.isEmpty ? null : _add,
          child: Text(t.commonAdd),
        ),
      ],
    );
  }
}
