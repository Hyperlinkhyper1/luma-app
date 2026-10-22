import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../sync/sync_scope.dart';
import '../../../../../theme/luma_theme.dart';
import 'cs2_voice_protocol.dart';
import 'cs2_voice_translate_service.dart';

class Cs2VoiceTranslateTab extends StatefulWidget {
  const Cs2VoiceTranslateTab({super.key});

  @override
  State<Cs2VoiceTranslateTab> createState() => _Cs2VoiceTranslateTabState();
}

class _Cs2VoiceTranslateTabState extends State<Cs2VoiceTranslateTab> {
  final _service = Cs2VoiceTranslateService.instance;
  bool _loaded = false;
  bool _changingSettings = false;
  String? _actionError;

  static const _languages = <String, String>{
    'English': 'English',
    'Dutch': 'Nederlands',
    'French': 'Français',
    'Spanish': 'Español',
    'German': 'Deutsch',
    'Italian': 'Italiano',
    'Portuguese': 'Português',
    'Polish': 'Polski',
    'Russian': 'Русский',
    'Ukrainian': 'Українська',
    'Turkish': 'Türkçe',
    'Arabic': 'العربية',
    'Chinese': '中文',
    'Japanese': '日本語',
    'Korean': '한국어',
  };

  @override
  void initState() {
    super.initState();
    if (Cs2VoiceTranslateService.supported) unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sync = SyncScope.maybeOf(context);
    if (sync != null) _service.configure(sync);
  }

  Future<void> _load() async {
    try {
      await _service.load();
      if (mounted) setState(() => _loaded = true);
    } catch (error) {
      if (mounted) setState(() => _actionError = '$error');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_changingSettings) return;
    setState(() {
      _changingSettings = true;
      _actionError = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _actionError = '$error');
    } finally {
      if (mounted) setState(() => _changingSettings = false);
    }
  }

  Future<void> _rebind() async {
    final t = L.of(context);
    await _run(() async {
      final restoreEnabled = _service.enabled;
      if (restoreEnabled) await _service.setEnabled(false);
      if (!mounted) return;
      try {
        HotKey? recorded;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setDialogState) => AlertDialog(
              backgroundColor: dialogContext.luma.surface,
              title: Text(t.cs2VoiceHotkeyTitle),
              content: SizedBox(
                width: 280,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.cs2VoiceHotkeyHint),
                    const SizedBox(height: 16),
                    HotKeyRecorder(
                      initalHotKey: _service.hotKey,
                      onHotKeyRecorded: (value) =>
                          setDialogState(() => recorded = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(t.settingsResetCancel),
                ),
                TextButton(
                  onPressed: recorded == null
                      ? null
                      : () => Navigator.of(dialogContext).pop(true),
                  child: Text(t.petSettingsRebindSave),
                ),
              ],
            ),
          ),
        );
        if (confirmed == true && recorded != null && mounted) {
          await _service.setHotKey(recorded!);
        }
      } finally {
        if (restoreEnabled && mounted) await _service.setEnabled(true);
      }
    });
  }

  Future<void> _customLanguage() async {
    final t = L.of(context);
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final language = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.luma.surface,
        title: Text(t.cs2VoiceCustomLanguage),
        content: SizedBox(
          width: 300,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: t.cs2VoiceTargetLanguage,
                hintText: t.cs2VoiceLanguageHint,
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? t.cs2VoiceLanguageRequired
                  : null,
              onFieldSubmitted: (_) {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(controller.text.trim());
                }
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t.settingsResetCancel),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
            child: Text(t.petSettingsRebindSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (language != null && mounted) {
      await _run(() => _service.setTargetLanguage(language));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final error = _actionError ?? _service.error;
        final active = _service.recording || _service.busy;
        final canConfigure = _loaded && !_changingSettings && !active;
        return ListView(
          padding: EdgeInsets.all(context.isPhoneWidth ? 16 : 24),
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t.cs2VoiceTitle,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.cs2VoiceSubtitle,
                      style: TextStyle(color: luma.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    if (!Cs2VoiceTranslateService.supported)
                      LumaEmptyState(
                        icon: Icons.desktop_windows_outlined,
                        title: t.cs2TrWindowsOnly,
                      )
                    else ...[
                      _setupCard(t, luma),
                      const SizedBox(height: 14),
                      LumaCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: _service.enabled,
                                onChanged: _loaded && !_changingSettings
                                    ? (value) =>
                                          _run(() => _service.setEnabled(value))
                                    : null,
                                title: Text(t.cs2VoiceEnable),
                                subtitle: Text(t.cs2VoiceEnableHint),
                              ),
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              key: ValueKey(_service.targetLanguage),
                              initialValue: _service.targetLanguage,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: t.cs2VoiceTargetLanguage,
                                border: const OutlineInputBorder(),
                              ),
                              items: [
                                for (final entry in _languages.entries)
                                  DropdownMenuItem(
                                    value: entry.key,
                                    child: Text(entry.value),
                                  ),
                                if (!_languages.containsKey(
                                  _service.targetLanguage,
                                ))
                                  DropdownMenuItem(
                                    value: _service.targetLanguage,
                                    child: Text(_service.targetLanguage),
                                  ),
                              ],
                              onChanged: canConfigure
                                  ? (value) {
                                      if (value != null) {
                                        _run(
                                          () =>
                                              _service.setTargetLanguage(value),
                                        );
                                      }
                                    }
                                  : null,
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: canConfigure
                                    ? _customLanguage
                                    : null,
                                child: Text(t.cs2VoiceCustomLanguage),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              t.cs2VoiceHotkeyTitle,
                              style: TextStyle(
                                color: luma.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                HotKeyVirtualView(hotKey: _service.hotKey),
                                LumaGhostButton(
                                  label: t.cs2VoiceChangeHotkey,
                                  icon: Icons.keyboard_outlined,
                                  onTap: canConfigure ? _rebind : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              t.cs2VoiceRecordingHint,
                              style: TextStyle(
                                color: luma.textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t.cs2VoiceAllowanceHint,
                              style: TextStyle(
                                color: luma.textMuted,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          LumaPrimaryButton(
                            label: _service.recording
                                ? t.cs2VoiceStopAndSend
                                : t.cs2VoiceRecord,
                            icon: _service.recording
                                ? Icons.stop_rounded
                                : Icons.mic_rounded,
                            onTap:
                                _loaded &&
                                    _service.enabled &&
                                    !_changingSettings &&
                                    (_service.recording || !_service.busy)
                                ? () => _run(_service.toggleRecording)
                                : null,
                          ),
                          if (active)
                            LumaGhostButton(
                              label: t.cs2VoiceCancel,
                              icon: Icons.close_rounded,
                              onTap: _service.cancel,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _loaded ? _service.status : t.cs2VoiceLoading,
                          style: TextStyle(
                            color: _service.recording
                                ? luma.danger
                                : luma.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            error,
                            style: TextStyle(color: luma.danger, fontSize: 13),
                          ),
                        ),
                        if (!_loaded)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => _run(_load),
                              child: Text(t.cs2VoiceRetry),
                            ),
                          ),
                      ],
                      const SizedBox(height: 18),
                      _resultCard(
                        t.cs2VoiceTranscript,
                        _service.transcript,
                        t.cs2VoiceTranscriptEmpty,
                        luma,
                      ),
                      const SizedBox(height: 14),
                      _resultCard(
                        t.cs2VoiceTranslation,
                        _service.translation,
                        t.cs2VoiceTranslationEmpty,
                        luma,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _setupCard(L t, LumaPalette luma) => LumaCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.cs2TrSetupTitle,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          t.cs2VoiceSetup,
          style: TextStyle(color: luma.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Flexible(
              child: SelectableText(
                cs2SayBindCommand,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: t.cs2TrCopy,
              icon: const Icon(Icons.copy_rounded, size: 18),
              onPressed: () {
                Clipboard.setData(
                  const ClipboardData(text: cs2SayBindCommand),
                );
                ScaffoldMessenger.maybeOf(
                  context,
                )?.showSnackBar(SnackBar(content: Text(t.cs2TrCopied)));
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          t.cs2VoiceAdminRouting,
          style: TextStyle(color: luma.textMuted, fontSize: 12.5),
        ),
      ],
    ),
  );

  Widget _resultCard(
    String title,
    String? value,
    String empty,
    LumaPalette luma,
  ) => LumaCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        SelectableText(
          value?.isNotEmpty == true ? value! : empty,
          style: TextStyle(
            color: value?.isNotEmpty == true
                ? luma.textPrimary
                : luma.textMuted,
            height: 1.4,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}
