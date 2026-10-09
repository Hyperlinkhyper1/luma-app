import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../data/mc_text.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_span_editor.dart';
import '../../ui/mc_style.dart';

/// Rich chat messages for /tellraw: styled parts with click actions and
/// hover text, previewed as chat.
class TellrawTool extends StatefulWidget {
  const TellrawTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<TellrawTool> createState() => _TellrawToolState();
}

class _TellrawToolState extends State<TellrawTool> {
  String _target = '@a';
  final List<McTextSpan> _spans = [
    McTextSpan(text: '[Server] ', color: 'gold', bold: true),
    McTextSpan(text: 'Vote for us today and get a reward! ', color: 'white'),
    McTextSpan(
      text: 'Click here',
      color: 'aqua',
      underlined: true,
      click: McClickAction.openUrl,
      clickValue: 'https://example.com/vote',
      hover: 'Opens the voting page',
    ),
  ];
  bool _pretty = false;
  int? _hovered;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final json = mcComponentJson(_spans, pretty: _pretty);
    return widget.host.frame(
      context,
      child: McSplit(
        controlsWidth: 460,
        controls: McPanel(
          title: t.mcTellMessage,
          icon: Icons.chat_rounded,
          child: McSpanEditor(spans: _spans, events: true, onChanged: () => setState(() {})),
        ),
        result: McFormColumn(
          children: [
            McGameBackdrop(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    children: [
                      for (var i = 0; i < _spans.length; i++)
                        MouseRegion(
                          onEnter: (_) => setState(() => _hovered = i),
                          onExit: (_) => setState(() => _hovered = null),
                          cursor: _spans[i].click == McClickAction.none
                              ? MouseCursor.defer
                              : SystemMouseCursors.click,
                          child: McTextPreview(spans: [_spans[i]], fontSize: 16),
                        ),
                    ],
                  ),
                  if (_hovered != null && _spans[_hovered!].hover.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xF0100010),
                        border: Border.all(color: const Color(0xFF2A0D5F), width: 2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: McTextPreview(spans: [McTextSpan(text: _spans[_hovered!].hover)], fontSize: 13),
                    ),
                ],
              ),
            ),
            Text(
              t.mcTellHoverHelp,
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
            McField(
              label: t.mcSendTo,
              child: McTextField(
                initialValue: _target,
                monospace: true,
                onChanged: (v) => setState(() => _target = v.trim().isEmpty ? '@a' : v.trim()),
              ),
            ),
            McSwitch(label: t.mcTellPretty, value: _pretty, onChanged: (v) => setState(() => _pretty = v)),
            McCodeBox(code: '/tellraw $_target ${mcComponentJson(_spans)}', title: t.mcCommand),
            if (_pretty) McCodeBox(code: json, title: t.mcTellComponent),
            Text(
              t.mcTellNote,
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
