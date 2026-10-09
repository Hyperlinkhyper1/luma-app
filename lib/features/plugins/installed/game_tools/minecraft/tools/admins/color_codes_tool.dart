import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../data/mc_dyes.dart';
import '../../data/mc_text.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_style.dart';

String _formatName(L t, McFormat f) => switch (f) {
  McFormat.obfuscated => t.mcObfuscated,
  McFormat.bold => t.mcBold,
  McFormat.strikethrough => t.mcStrikethrough,
  McFormat.underlined => t.mcUnderlined,
  McFormat.italic => t.mcItalic,
  McFormat.reset => t.mcColorReset.split(' ').first,
};

/// Every colour and formatting code, plus an editor that previews `&` codes
/// and converts them to `§`, MiniMessage and JSON.
class ColorCodesTool extends StatefulWidget {
  const ColorCodesTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<ColorCodesTool> createState() => _ColorCodesToolState();
}

class _ColorCodesToolState extends State<ColorCodesTool> {
  final TextEditingController _text = TextEditingController(
    text: '&6&lWelcome &r&7to &bluma&7! &aHave fun&r &c❤',
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _insert(String code) {
    final sel = _text.selection;
    final text = _text.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final next = text.replaceRange(start, end, code);
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + code.length),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final spans = mcParseLegacy(_text.text);
    return widget.host.frame(
      context,
      child: McFormColumn(
        children: [
          McPanel(
            title: t.mcColorTry,
            icon: Icons.edit_note_rounded,
            child: McFormColumn(
              gap: 10,
              children: [
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final c in McChatColor.values)
                      McSwatch(
                        color: c.color,
                        tooltip: '${c.label} — &${c.code}',
                        size: 26,
                        onTap: () => _insert('&${c.code}'),
                        child: Center(
                          child: Text(
                            c.code,
                            style: TextStyle(
                              color: c.color.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    for (final f in McFormat.values)
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: Text('&${f.code} ${_formatName(t, f)}'),
                        onPressed: () => _insert('&${f.code}'),
                      ),
                  ],
                ),
                McTextField(
                  controller: _text,
                  monospace: true,
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                ),
                McGameBackdrop(
                  child: McTextPreview(spans: spans, fontSize: 18),
                ),
                Text(
                  t.mcColorHelp,
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          McGrid(
            minTileWidth: 340,
            children: [
              McCodeBox(code: mcToLegacy(spans), title: t.mcColorSection),
              McCodeBox(code: mcToLegacy(spans, sign: '&', hex: true), title: t.mcColorAmpersand),
              McCodeBox(code: mcToMiniMessage(spans), title: t.mcColorMiniMessage),
              McCodeBox(code: mcComponentJson(spans), title: t.mcColorJson),
            ],
          ),
          McPanel(
            title: t.mcColorCodes,
            icon: Icons.palette_rounded,
            child: Table(
              columnWidths: const {
                0: FixedColumnWidth(40),
                1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(),
                3: FlexColumnWidth(),
                4: FlexColumnWidth(1.2),
                5: FlexColumnWidth(1.5),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    for (final h in ['', t.mcColorName, t.mcColorCode, t.mcColorSectionCol, t.mcColorHex, 'JSON'])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(h, style: TextStyle(color: luma.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                for (final c in McChatColor.values)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(color: c.color, borderRadius: BorderRadius.circular(5)),
                        ),
                      ),
                      Text(c.label, style: TextStyle(color: luma.textPrimary, fontSize: 13)),
                      _Copyable('&${c.code}'),
                      _Copyable('§${c.code}'),
                      _Copyable(mcHex(c.color)),
                      _Copyable(c.id),
                    ],
                  ),
              ],
            ),
          ),
          McPanel(
            title: t.mcColorFormatting,
            icon: Icons.format_bold_rounded,
            child: Column(
              children: [
                for (final (f, what) in [
                  (McFormat.bold, t.mcBold),
                  (McFormat.italic, t.mcItalic),
                  (McFormat.underlined, t.mcUnderlined),
                  (McFormat.strikethrough, t.mcStrikethrough),
                  (McFormat.obfuscated, t.mcColorObfuscatedDetail),
                  (McFormat.reset, t.mcColorReset),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(width: 60, child: _Copyable('&${f.code}')),
                        SizedBox(width: 60, child: _Copyable('§${f.code}')),
                        Expanded(child: Text(what, style: TextStyle(color: luma.textSecondary, fontSize: 13))),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  t.mcColorOrderNote,
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Copyable extends StatelessWidget {
  const _Copyable(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => mcCopy(context, text, what: L.of(context).mcColorCopied(text)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(text, style: mcMono(context, size: 12.5)),
      ),
    );
  }
}
