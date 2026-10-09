import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';

import '../../data/mc_text.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_span_editor.dart';
import '../../ui/mc_style.dart';

/// Titles, subtitles and action bars with their fade timings, previewed on
/// screen and written out as /title commands.
class TitleTool extends StatefulWidget {
  const TitleTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<TitleTool> createState() => _TitleToolState();
}

class _TitleToolState extends State<TitleTool> with SingleTickerProviderStateMixin {
  String _target = '@a';
  final List<McTextSpan> _title = [McTextSpan(text: 'Welcome', color: 'gold', bold: true)];
  final List<McTextSpan> _subtitle = [McTextSpan(text: 'to the server', color: 'gray')];
  final List<McTextSpan> _actionbar = [McTextSpan(text: 'Type /spawn to get started', color: 'yellow')];
  bool _useSubtitle = true;
  bool _useActionbar = false;
  int _fadeIn = 10;
  int _stay = 70;
  int _fadeOut = 20;

  late final AnimationController _play = AnimationController(vsync: this);

  @override
  void dispose() {
    _play.dispose();
    super.dispose();
  }

  void _preview() {
    final total = _fadeIn + _stay + _fadeOut;
    _play
      ..duration = Duration(milliseconds: total * 50)
      ..forward(from: 0);
  }

  double get _opacity {
    if (!_play.isAnimating && _play.value == 0) return 1;
    final total = (_fadeIn + _stay + _fadeOut).toDouble();
    final t = _play.value * total;
    if (t < _fadeIn) return t / _fadeIn;
    if (t < _fadeIn + _stay) return 1;
    return (1 - (t - _fadeIn - _stay) / _fadeOut).clamp(0.0, 1.0);
  }

  String get _commands {
    final lines = <String>[
      '/title $_target times $_fadeIn $_stay $_fadeOut',
      if (_useSubtitle) '/title $_target subtitle ${mcComponentJson(_subtitle)}',
      '/title $_target title ${mcComponentJson(_title)}',
      if (_useActionbar) '/title $_target actionbar ${mcComponentJson(_actionbar)}',
    ];
    return lines.join('\n');
  }

  Widget _ticks(L t, String label, int value, ValueChanged<int> set) => McSlider(
    label: label,
    value: value.toDouble(),
    min: 0,
    max: 200,
    divisions: 200,
    format: (v) => t.mcTitleTicks(v.round(), (v / 20).toStringAsFixed(1)),
    onChanged: (v) => setState(() => set(v.round())),
  );

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return widget.host.frame(
      context,
      child: McSplit(
        controlsWidth: 440,
        controls: McFormColumn(
          children: [
            McPanel(
              title: t.mcTitleTitle,
              icon: Icons.title_rounded,
              child: McSpanEditor(spans: _title, onChanged: () => setState(() {})),
            ),
            McPanel(
              title: t.mcTitleSubtitle,
              icon: Icons.short_text_rounded,
              trailing: Switch(value: _useSubtitle, onChanged: (v) => setState(() => _useSubtitle = v)),
              child: _useSubtitle
                  ? McSpanEditor(spans: _subtitle, onChanged: () => setState(() {}))
                  : const SizedBox.shrink(),
            ),
            McPanel(
              title: t.mcTitleActionbar,
              icon: Icons.notes_rounded,
              trailing: Switch(value: _useActionbar, onChanged: (v) => setState(() => _useActionbar = v)),
              child: _useActionbar
                  ? McSpanEditor(spans: _actionbar, onChanged: () => setState(() {}))
                  : const SizedBox.shrink(),
            ),
            McPanel(
              title: t.mcTitleTiming,
              icon: Icons.timer_outlined,
              child: Column(
                children: [
                  _ticks(t, t.mcTitleFadeIn, _fadeIn, (v) => _fadeIn = v),
                  _ticks(t, t.mcTitleStay, _stay, (v) => _stay = v),
                  _ticks(t, t.mcTitleFadeOut, _fadeOut, (v) => _fadeOut = v),
                ],
              ),
            ),
          ],
        ),
        result: McFormColumn(
          children: [
            AnimatedBuilder(
              animation: _play,
              builder: (context, _) => McGameBackdrop(
                sky: true,
                height: 300,
                padding: EdgeInsets.zero,
                child: Stack(
                  children: [
                    Align(
                      alignment: const Alignment(0, -0.2),
                      child: Opacity(
                        opacity: _opacity,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            McTextPreview(spans: _title, fontSize: 40, align: TextAlign.center),
                            if (_useSubtitle) ...[
                              const SizedBox(height: 6),
                              McTextPreview(spans: _subtitle, fontSize: 18, align: TextAlign.center),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (_useActionbar)
                      Align(
                        alignment: const Alignment(0, 0.82),
                        child: McTextPreview(spans: _actionbar, fontSize: 14, align: TextAlign.center),
                      ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: McButton(label: t.mcTitlePlay, icon: Icons.play_arrow_rounded, primary: false, onTap: _preview),
            ),
            McField(
              label: t.mcShowTo,
              child: McTextField(
                initialValue: _target,
                monospace: true,
                onChanged: (v) => setState(() => _target = v.trim().isEmpty ? '@a' : v.trim()),
              ),
            ),
            McCodeBox(
              code: _commands,
              title: t.mcCommands,
              note: t.mcTitleOrder,
            ),
          ],
        ),
      ),
    );
  }
}
