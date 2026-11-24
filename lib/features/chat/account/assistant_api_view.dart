import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../../settings/settings_controller.dart';
import '../../../settings/settings_scope.dart';
import '../../../theme/luma_theme.dart';
import '../../plugins/installed/ai_usage/ai_usage_scope.dart';
import '../ai_key_store.dart';
import '../providers/ai_client.dart';
import '../providers/ai_providers.dart';

/// The assistant's one API screen: every bring-your-own-key provider
/// (Claude, OpenAI, OpenRouter, Google Gemini) with its key, the model to
/// use and a button to chat with it.
class AssistantApiKeys extends StatelessWidget {
  const AssistantApiKeys({super.key});

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final settings = SettingsScope.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            L.of(context).assistantApiIntro,
            style: TextStyle(color: luma.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          for (final provider in kApiKeyProviders) ...[
            _ProviderCard(provider: provider, settings: settings),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _ProviderCard extends StatefulWidget {
  const _ProviderCard({required this.provider, required this.settings});

  final AiProviderInfo provider;
  final SettingsController settings;

  @override
  State<_ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends State<_ProviderCard> {
  final _key = TextEditingController();
  late final _model = TextEditingController(
    text: widget.settings.aiModelFor(_id) ?? '',
  );
  bool _obscure = true;
  bool _saving = false;
  bool _testing = false;
  bool _loaded = false;
  String? _savedMasked;

  String get _id => widget.provider.id.name;

  @override
  void initState() {
    super.initState();
    _loadSavedKey();
  }

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _loadSavedKey() async {
    final key = await (await AiKeyStore.load()).readKey(_id);
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _savedMasked = key == null ? null : _mask(key);
    });
  }

  static String _mask(String key) {
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 7)}••••${key.substring(key.length - 4)}';
  }

  Future<void> _save() async {
    final t = L.of(context);
    final key = _key.text.trim();
    if (key.isEmpty && _savedMasked == null) {
      _snack(t.aiSettingsEnterKeyFirst);
      return;
    }
    setState(() => _saving = true);
    widget.settings.setAiModel(_id, _model.text);
    if (key.isNotEmpty) {
      await (await AiKeyStore.load()).saveKey(_id, key);
      _key.clear();
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (key.isNotEmpty) _savedMasked = _mask(key);
    });
    _snack(t.aiSettingsKeySaved);
  }

  Future<void> _test() async {
    final t = L.of(context);
    final aiUsage = AiUsageScope.maybeOf(context);
    final typed = _key.text.trim();
    final key = typed.isNotEmpty
        ? typed
        : await (await AiKeyStore.load()).readKey(_id);
    if (key == null || key.isEmpty) {
      _snack(t.aiSettingsEnterKeyFirst);
      return;
    }
    final model = _model.text.trim().isNotEmpty
        ? _model.text
        : widget.settings.aiModelFor(_id);
    setState(() => _testing = true);
    try {
      final result = await aiClientFor(_id, model: model).chat(
        apiKey: key,
        history: const [AiTurn(role: 'user', text: 'Hi')],
        systemPrompt: '',
        tools: const [],
        executeTool: (_, _) async => const {},
        metadataFor: (_, _) => null,
      );
      if (result.usage case final usage?) {
        await aiUsage?.recordLumaCall(
          providerId: _id,
          usage: usage,
          feature: 'Key test',
        );
      }
      _snack(t.aiSettingsConnectionWorks);
    } on AiError catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(t.aiSettingsCouldNotVerifyKey('$e'));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _remove() async {
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
          t.aiSettingsRemoveKeyBody(widget.provider.displayName),
          style: TextStyle(color: luma.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              t.commonCancel,
              style: TextStyle(color: luma.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.commonRemove, style: TextStyle(color: luma.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await (await AiKeyStore.load()).clearKey(_id);
    if (!mounted) return;
    setState(() => _savedMasked = null);
    _snack(t.aiSettingsKeyRemoved);
  }

  Future<void> _openKeyPage() async {
    final url = widget.provider.keyUrl;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _decoration(LumaPalette luma, String hint, {Widget? suffix}) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color),
    );
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: TextStyle(color: luma.textMuted),
      filled: true,
      fillColor: luma.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: border(luma.border),
      enabledBorder: border(luma.border),
      focusedBorder: border(luma.accent),
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final provider = widget.provider;
    final inUse = widget.settings.aiProviderId == _id;

    final header = Row(
      children: [
        Icon(provider.icon, size: 18, color: luma.accent),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                provider.displayName,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                !_loaded ? '' : _savedMasked ?? t.assistantApiNoKey,
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        if (inUse)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: luma.accentSubtle,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: luma.accent),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_rounded, size: 14, color: luma.accent),
                const SizedBox(width: 4),
                Text(
                  t.assistantApiInUse,
                  style: TextStyle(
                    color: luma.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          LumaGhostButton(
            label: t.assistantApiUseInChat,
            icon: Icons.chat_bubble_outline_rounded,
            onTap: _savedMasked == null
                ? null
                : () => widget.settings.setAiProviderId(_id),
          ),
      ],
    );

    final keyField = TextField(
      controller: _key,
      obscureText: _obscure,
      style: TextStyle(color: luma.textPrimary),
      decoration: _decoration(
        luma,
        _savedMasked != null ? t.aiSettingsHintReplaceKey : provider.keyHint,
        suffix: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            color: luma.textMuted,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );

    final modelField = TextField(
      controller: _model,
      style: TextStyle(color: luma.textPrimary),
      decoration: _decoration(
        luma,
        t.assistantApiModelHint(provider.defaultModel ?? ''),
      ).copyWith(labelText: t.assistantApiModel),
      onSubmitted: (value) => widget.settings.setAiModel(_id, value),
    );

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 520
                ? Column(
                    children: [
                      keyField,
                      const SizedBox(height: 10),
                      modelField,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(flex: 3, child: keyField),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: modelField),
                    ],
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
                onTap: _testing ? null : _test,
              ),
              if (_savedMasked != null)
                LumaGhostButton(
                  label: t.aiSettingsRemoveKey,
                  icon: Icons.delete_outline_rounded,
                  onTap: _remove,
                ),
              if (provider.keyUrl != null)
                LumaGhostButton(
                  label: t.assistantApiGetKey,
                  icon: Icons.open_in_new_rounded,
                  onTap: _openKeyPage,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
