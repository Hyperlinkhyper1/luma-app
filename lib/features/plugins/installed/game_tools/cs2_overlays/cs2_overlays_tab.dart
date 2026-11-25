import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import 'cs2_bomb_timer_card.dart';
import 'cs2_overlay_widgets.dart';
import 'cs2_translator_service.dart';

/// Game Tools' CS2 overlays: transparent windows that sit on top of the game
/// — the chat translator and the bomb timer — each with its own start/stop.
class Cs2OverlaysTab extends StatelessWidget {
  const Cs2OverlaysTab({super.key});

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
                  t.cs2OverlaysTitle,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t.cs2OverlaysSubtitle,
                  style: TextStyle(color: luma.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                if (!Cs2TranslatorService.supported)
                  LumaEmptyState(
                    icon: Icons.desktop_windows_outlined,
                    title: t.cs2OverlaysWindowsOnly,
                  )
                else ...[
                  Cs2StatusLine(ok: false, text: t.cs2TrSetupWindowed),
                  const SizedBox(height: 14),
                  const Cs2ChatTranslatorCard(),
                  const SizedBox(height: 14),
                  const Cs2BombTimerCard(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The chat translator overlay: CS2's launch option, start/stop and a
/// sample-line test up front, with the options and the script's output
/// folded away underneath.
class Cs2ChatTranslatorCard extends StatefulWidget {
  const Cs2ChatTranslatorCard({super.key});

  static const launchOptions = '-condebug';

  @override
  State<Cs2ChatTranslatorCard> createState() => _Cs2ChatTranslatorCardState();
}

class _Cs2ChatTranslatorCardState extends State<Cs2ChatTranslatorCard> {
  final _service = Cs2TranslatorService.instance;
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
    _load();
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
    final busy = _service.running || _service.testing;

    return Cs2OverlayCard(
      icon: Icons.translate_rounded,
      title: t.cs2TrTitle,
      description: t.cs2TrSubtitle,
      running: _service.running,
      action: _service.running
          ? LumaPrimaryButton(
              label: t.cs2TrStop,
              icon: Icons.stop_rounded,
              onTap: _service.stop,
            )
          : LumaPrimaryButton(
              label: t.cs2TrStart,
              icon: Icons.play_arrow_rounded,
              loading: _service.testing,
              onTap: _loaded && !busy ? _start : null,
            ),
      children: [
        const SizedBox(height: 16),
        Text(
          t.cs2TrSetupLaunchOptions,
          style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: 6),
        _launchOptionsRow(t, luma),
        if (_searched) ...[
          const SizedBox(height: 10),
          Cs2StatusLine(
            ok: _foundLog != null,
            text: _foundLog != null
                ? t.cs2TrLogFound(_foundLog!)
                : t.cs2TrLogMissing,
          ),
        ],
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
        const SizedBox(height: 8),
        Divider(color: luma.border, height: 16),
        Cs2Disclosure(
          title: t.cs2TrOptionsTitle,
          child: _optionsPanel(t, luma),
        ),
        Cs2Disclosure(title: t.cs2TrOutputTitle, child: _output(t, luma)),
      ],
    );
  }

  Widget _launchOptionsRow(L t, LumaPalette luma) => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: luma.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: luma.border),
        ),
        child: SelectableText(
          Cs2ChatTranslatorCard.launchOptions,
          style: TextStyle(
            color: luma.textPrimary,
            fontFamily: 'monospace',
            fontSize: 13,
          ),
        ),
      ),
      const SizedBox(width: 6),
      IconButton(
        tooltip: t.cs2TrCopy,
        icon: Icon(Icons.copy_rounded, size: 18, color: luma.textMuted),
        onPressed: () {
          Clipboard.setData(
            const ClipboardData(text: Cs2ChatTranslatorCard.launchOptions),
          );
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(SnackBar(content: Text(t.cs2TrCopied)));
        },
      ),
    ],
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
    decoration: cs2FieldDecoration(label, luma),
  );

  Widget _optionsPanel(L t, LumaPalette luma) {
    final phone = context.isPhoneWidth;
    final busy = _service.running || _service.testing;
    Widget pair(Widget a, Widget b) => phone
        ? Column(children: [a, const SizedBox(height: 10), b])
        : Row(
            children: [
              Expanded(child: a),
              const SizedBox(width: 10),
              Expanded(child: b),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              : (v) => setState(() => _options = _options.copyWith(overlay: v)),
          title: Text(
            t.cs2TrShowOverlay,
            style: TextStyle(color: luma.textPrimary, fontSize: 14),
          ),
          subtitle: Text(
            t.cs2TrShowOverlayHint,
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 6),
        LumaGhostButton(
          label: t.cs2TrTest,
          icon: Icons.science_outlined,
          onTap: _loaded && !busy ? () => _start(test: true) : null,
        ),
        const SizedBox(height: 10),
        Text(
          t.cs2TrHowItWorks,
          style: TextStyle(color: luma.textMuted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }

  Widget _output(L t, LumaPalette luma) {
    final lines = _service.output;
    return Container(
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
    );
  }
}
