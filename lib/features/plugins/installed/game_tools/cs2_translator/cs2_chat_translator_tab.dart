import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../sync/sync_scope.dart';
import '../../../../../theme/luma_theme.dart';
import 'cs2_teammate_voice_service.dart';
import 'cs2_translator_service.dart';

/// Game Tools' CS2 chat translator: setup steps, the script's options, a
/// start/stop control for the overlay and the script's own output.
class Cs2ChatTranslatorTab extends StatefulWidget {
  const Cs2ChatTranslatorTab({super.key});

  static const launchOptions = '-condebug -netconport 2121';

  @override
  State<Cs2ChatTranslatorTab> createState() => _Cs2ChatTranslatorTabState();
}

class _Cs2ChatTranslatorTabState extends State<Cs2ChatTranslatorTab> {
  final _service = Cs2TranslatorService.instance;
  final _voice = Cs2TeammateVoiceService.instance;
  List<Cs2VoiceInputDevice> _voiceDevices = [];
  int? _voiceDevice;
  bool _loadingDevices = false;
  String? _deviceError;
  final _lang = TextEditingController();
  final _hide = TextEditingController();
  final _lines = TextEditingController();
  final _x = TextEditingController();
  final _y = TextEditingController();
  final _logPath = TextEditingController();

  Cs2TranslatorOptions _options = const Cs2TranslatorOptions();
  bool _loaded = false;
  String? _foundLog;
  bool _searched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onService);
    _voice.addListener(_onService);
    if (Cs2TranslatorService.supported) _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _voice.configure(SyncScope.maybeOf(context));
  }

  Future<void> _findVoiceDevices() async {
    setState(() {
      _loadingDevices = true;
      _deviceError = null;
    });
    try {
      final devices = await _voice.listDevices();
      if (!mounted) return;
      setState(() {
        _voiceDevices = devices;
        _voiceDevice = null;
      });
    } catch (error) {
      if (mounted) setState(() => _deviceError = '$error');
    } finally {
      if (mounted) setState(() => _loadingDevices = false);
    }
  }

  Future<void> _load() async {
    final options = await _service.loadOptions();
    final found = await _service.findConsoleLog();
    if (!mounted) return;
    setState(() {
      _options = options;
      _lang.text = options.targetLang;
      _hide.text = '${options.hideAfterSeconds}';
      _lines.text = '${options.maxLines}';
      _x.text = '${options.overlayX}';
      _y.text = options.overlayY?.toString() ?? '';
      _logPath.text = options.logPath;
      _foundLog = found;
      _searched = true;
      _loaded = true;
    });
  }

  void _onService() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onService);
    _voice.removeListener(_onService);
    for (final c in [_lang, _hide, _lines, _x, _y, _logPath]) {
      c.dispose();
    }
    super.dispose();
  }

  Cs2TranslatorOptions _readFields() => _options.copyWith(
    targetLang: _lang.text.trim().isEmpty ? 'en' : _lang.text.trim(),
    hideAfterSeconds: int.tryParse(_hide.text) ?? _options.hideAfterSeconds,
    maxLines: int.tryParse(_lines.text) ?? _options.maxLines,
    overlayX: int.tryParse(_x.text) ?? _options.overlayX,
    overlayY: () => int.tryParse(_y.text),
    logPath: _logPath.text.trim(),
  );

  Future<void> _start({bool test = false}) async {
    final options = _readFields();
    _options = options;
    await _service.saveOptions(options);
    final error = test
        ? await _service.runTest(options)
        : await _service.start(options);
    if (mounted) setState(() => _error = error);
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;

    return ListView(
      padding: EdgeInsets.all(context.isPhoneWidth ? 16 : 24),
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.cs2TrTitle,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t.cs2TrSubtitle,
                  style: TextStyle(color: luma.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                if (!Cs2TranslatorService.supported)
                  LumaEmptyState(
                    icon: Icons.desktop_windows_outlined,
                    title: t.cs2TrWindowsOnly,
                  )
                else ...[
                  _setupCard(t, luma),
                  const SizedBox(height: 14),
                  _optionsCard(t, luma),
                  const SizedBox(height: 14),
                  _controls(t, luma),
                  const SizedBox(height: 14),
                  _voiceCard(t, luma),
                  const SizedBox(height: 14),
                  _outputCard(t, luma),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _voiceCard(L t, LumaPalette luma) => LumaCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(t.cs2TeammateVoiceTitle, luma),
        Text(
          t.cs2TeammateVoiceDescription,
          style: TextStyle(color: luma.textSecondary),
        ),
        const SizedBox(height: 12),
        Text(
          t.cs2TeammateVoicePrivacy,
          style: TextStyle(color: luma.textSecondary),
        ),
        const SizedBox(height: 12),
        if (_voiceDevices.isNotEmpty)
          DropdownButtonFormField<int>(
            initialValue: _voiceDevice,
            decoration: InputDecoration(labelText: t.cs2TeammateVoiceSource),
            items: [
              for (final device in _voiceDevices)
                DropdownMenuItem(
                  value: device.id,
                  child: Text(device.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _voice.running
                ? null
                : (value) => setState(() => _voiceDevice = value),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _loadingDevices || _voice.running
                  ? null
                  : _findVoiceDevices,
              icon: const Icon(Icons.refresh),
              label: Text(t.cs2TeammateVoiceFindSources),
            ),
            if (_voice.running)
              FilledButton.icon(
                onPressed: _voice.stop,
                icon: const Icon(Icons.stop),
                label: Text(t.cs2TeammateVoiceStop),
              )
            else
              FilledButton.icon(
                onPressed: _voiceDevice == null || !_service.running
                    ? null
                    : () =>
                          _voice.start(_voiceDevice!, _readFields().targetLang),
                icon: const Icon(Icons.hearing),
                label: Text(t.cs2TeammateVoiceStart),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _voice.running ? t.cs2TeammateVoiceRunning : t.cs2TeammateVoiceIdle,
          style: TextStyle(color: luma.textSecondary),
        ),
        if (_deviceError != null || _voice.error != null) ...[
          const SizedBox(height: 8),
          Text(
            _deviceError ?? _voice.error!,
            style: TextStyle(color: luma.textSecondary),
          ),
        ],
      ],
    ),
  );

  Widget _heading(String text, LumaPalette luma) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: TextStyle(
        color: luma.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _step(int n, Widget child, LumaPalette luma) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: luma.accentSubtle,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$n',
            style: TextStyle(
              color: luma.accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: child),
      ],
    ),
  );

  Widget _setupCard(L t, LumaPalette luma) {
    final body = TextStyle(color: luma.textSecondary, fontSize: 13);
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(t.cs2TrSetupTitle, luma),
          _step(
            1,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.cs2TrSetupLaunchOptions, style: body),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: luma.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: luma.border),
                        ),
                        child: SelectableText(
                          Cs2ChatTranslatorTab.launchOptions,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: t.cs2TrCopy,
                      icon: Icon(
                        Icons.copy_rounded,
                        size: 18,
                        color: luma.textMuted,
                      ),
                      onPressed: () {
                        Clipboard.setData(
                          const ClipboardData(
                            text: Cs2ChatTranslatorTab.launchOptions,
                          ),
                        );
                        ScaffoldMessenger.maybeOf(
                          context,
                        )?.showSnackBar(SnackBar(content: Text(t.cs2TrCopied)));
                      },
                    ),
                  ],
                ),
              ],
            ),
            luma,
          ),
          _step(2, Text(t.cs2TrSetupWindowed, style: body), luma),
          if (_searched)
            Row(
              children: [
                Icon(
                  _foundLog != null
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  size: 16,
                  color: _foundLog != null ? luma.success : luma.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _foundLog != null
                        ? t.cs2TrLogFound(_foundLog!)
                        : t.cs2TrLogMissing,
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, LumaPalette luma) =>
      InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: luma.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: luma.border),
        ),
      );

  Widget _field(
    TextEditingController controller,
    String label,
    LumaPalette luma, {
    bool numeric = false,
  }) => TextField(
    controller: controller,
    enabled: _loaded && !_service.running,
    keyboardType: numeric ? TextInputType.number : null,
    inputFormatters: numeric
        ? [FilteringTextInputFormatter.allow(RegExp(r'-?[0-9]*'))]
        : null,
    style: TextStyle(color: luma.textPrimary, fontSize: 14),
    decoration: _decoration(label, luma),
  );

  Widget _optionsCard(L t, LumaPalette luma) {
    final phone = context.isPhoneWidth;
    Widget pair(Widget a, Widget b) => phone
        ? Column(children: [a, const SizedBox(height: 10), b])
        : Row(
            children: [
              Expanded(child: a),
              const SizedBox(width: 10),
              Expanded(child: b),
            ],
          );

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(t.cs2TrOptionsTitle, luma),
          pair(
            _field(_lang, t.cs2TrTargetLang, luma),
            _field(_hide, t.cs2TrHideAfter, luma, numeric: true),
          ),
          const SizedBox(height: 10),
          pair(
            _field(_lines, t.cs2TrMaxLines, luma, numeric: true),
            pair(
              _field(_x, t.cs2TrOverlayX, luma, numeric: true),
              _field(_y, t.cs2TrOverlayY, luma, numeric: true),
            ),
          ),
          const SizedBox(height: 10),
          _field(_logPath, t.cs2TrLogPath, luma),
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _options.overlay,
            onChanged: !_loaded || _service.running
                ? null
                : (v) =>
                      setState(() => _options = _options.copyWith(overlay: v)),
            title: Text(
              t.cs2TrShowOverlay,
              style: TextStyle(color: luma.textPrimary, fontSize: 14),
            ),
            subtitle: Text(
              t.cs2TrShowOverlayHint,
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls(L t, LumaPalette luma) {
    final busy = _service.running || _service.testing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (_service.running)
              LumaPrimaryButton(
                label: t.cs2TrStop,
                icon: Icons.stop_rounded,
                onTap: _service.stop,
              )
            else
              LumaPrimaryButton(
                label: t.cs2TrStart,
                icon: Icons.translate_rounded,
                loading: _service.testing,
                onTap: _loaded && !busy ? _start : null,
              ),
            LumaGhostButton(
              label: t.cs2TrTest,
              icon: Icons.science_outlined,
              onTap: _loaded && !busy ? () => _start(test: true) : null,
            ),
          ],
        ),
        if (_service.running) ...[
          const SizedBox(height: 10),
          Text(
            _options.overlay ? t.cs2TrRunning : t.cs2TrRunningNoOverlay,
            style: TextStyle(color: luma.success, fontSize: 12.5),
          ),
        ],
        if (_error case final error?) ...[
          const SizedBox(height: 10),
          Text(
            t.cs2TrStartFailed(error),
            style: TextStyle(color: luma.danger, fontSize: 12.5),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          t.cs2TrHowItWorks,
          style: TextStyle(color: luma.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _outputCard(L t, LumaPalette luma) {
    final lines = _service.output;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(t.cs2TrOutputTitle, luma),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 80, maxHeight: 320),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: luma.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: luma.border),
            ),
            child: lines.isEmpty
                ? Text(
                    t.cs2TrOutputEmpty,
                    style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                  )
                : SingleChildScrollView(
                    reverse: true,
                    child: SelectableText(
                      lines.join('\n'),
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
