import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../data/mc_text.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_style.dart';

/// The message under a server's name in the multiplayer list: two lines of
/// `&` codes, previewed in a server-list row and escaped for
/// server.properties.
class MotdTool extends StatefulWidget {
  const MotdTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<MotdTool> createState() => _MotdToolState();
}

class _MotdToolState extends State<MotdTool> {
  final TextEditingController _line1 = TextEditingController(text: '&6&l✦ luma SMP ✦ &r&7— &aSurvival 26.3');
  final TextEditingController _line2 = TextEditingController(text: '&bNew season started! &d&oJoin now');
  final TextEditingController _name = TextEditingController(text: 'luma SMP');
  int _online = 12;
  int _max = 50;
  TextEditingController? _focused;

  @override
  void dispose() {
    _line1.dispose();
    _line2.dispose();
    _name.dispose();
    super.dispose();
  }

  void _insert(String code) {
    final c = _focused ?? _line1;
    final sel = c.selection;
    final start = sel.isValid ? sel.start : c.text.length;
    final end = sel.isValid ? sel.end : c.text.length;
    c.value = TextEditingValue(
      text: c.text.replaceRange(start, end, code),
      selection: TextSelection.collapsed(offset: start + code.length),
    );
    setState(() {});
  }

  String get _legacy => '${mcToLegacy(mcParseLegacy(_line1.text))}\n${mcToLegacy(mcParseLegacy(_line2.text))}';

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final l1 = mcParseLegacy(_line1.text);
    final l2 = mcParseLegacy(_line2.text);
    final width1 = _line1.text.replaceAll(RegExp(r'[&§][0-9a-fk-or]', caseSensitive: false), '').length;
    final width2 = _line2.text.replaceAll(RegExp(r'[&§][0-9a-fk-or]', caseSensitive: false), '').length;
    return widget.host.frame(
      context,
      child: McFormColumn(
        children: [
          McPanel(
            title: t.mcMotdLines,
            icon: Icons.edit_note_rounded,
            child: McFormColumn(
              gap: 10,
              children: [
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final c in McChatColor.values)
                      Tooltip(
                        message: '${c.label} &${c.code}',
                        child: InkWell(
                          onTap: () => _insert('&${c.code}'),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(color: c.color, borderRadius: BorderRadius.circular(5)),
                          ),
                        ),
                      ),
                    for (final f in McFormat.values)
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: Text('&${f.code}'),
                        tooltip: f == McFormat.reset ? t.mcColorReset : mcPretty(f.name),
                        onPressed: () => _insert('&${f.code}'),
                      ),
                  ],
                ),
                Focus(
                  onFocusChange: (f) => f ? _focused = _line1 : null,
                  child: McTextField(controller: _line1, monospace: true, onChanged: (_) => setState(() {})),
                ),
                Focus(
                  onFocusChange: (f) => f ? _focused = _line2 : null,
                  child: McTextField(controller: _line2, monospace: true, onChanged: (_) => setState(() {})),
                ),
                if (width1 > 45 || width2 > 45)
                  Text(
                    t.mcMotdTooLong,
                    style: TextStyle(color: luma.warning, fontSize: 12),
                  ),
              ],
            ),
          ),
          McGameBackdrop(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6F6F6F),
                    border: Border.all(color: const Color(0xFF9A9A9A)),
                  ),
                  child: const Icon(Icons.dns_rounded, color: Colors.white70),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: McTextPreview(spans: [McTextSpan(text: _name.text)], fontSize: 15),
                          ),
                          McTextPreview(
                            spans: [McTextSpan(text: '$_online/$_max', color: 'gray')],
                            fontSize: 14,
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.signal_cellular_alt_rounded, color: Color(0xFF55FF55), size: 16),
                        ],
                      ),
                      const SizedBox(height: 3),
                      McTextPreview(spans: l1, fontSize: 14, maxLines: 1),
                      McTextPreview(spans: l2, fontSize: 14, maxLines: 1),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: McTextField(
                  controller: _name,
                  hint: t.mcMotdServerName,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Text(t.mcMotdPlayers, style: TextStyle(color: luma.textSecondary, fontSize: 12.5)),
              McStepper(value: _online, max: 9999, onChanged: (v) => setState(() => _online = v)),
              Text(t.mcMotdOf, style: TextStyle(color: luma.textSecondary, fontSize: 12.5)),
              McStepper(value: _max, min: 1, max: 9999, onChanged: (v) => setState(() => _max = v)),
            ],
          ),
          McCodeBox(
            code: 'motd=${mcPropertiesEscape(_legacy)}',
            title: 'server.properties',
            note: t.mcMotdEscapeNote,
          ),
          McCodeBox(code: _legacy, title: t.mcMotdRaw),
          McCodeBox(
            code: '${mcToMiniMessage(l1)}<newline>${mcToMiniMessage(l2)}',
            title: t.mcMotdMiniMessage,
          ),
        ],
      ),
    );
  }
}
