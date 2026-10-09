import 'package:flutter/material.dart';

import '../../../../../../l10n/app_localizations.dart';
import '../../../../../../theme/luma_theme.dart';
import '../data/mc_dyes.dart';
import '../data/mc_text.dart';
import 'mc_style.dart';

/// Edits a list of styled text runs — the building block of tellraw, titles
/// and item names. Each run has its text, a colour and the five formats;
/// with [events] it also gets a click action and hover text.
class McSpanEditor extends StatefulWidget {
  const McSpanEditor({
    super.key,
    required this.spans,
    required this.onChanged,
    this.events = false,
    this.maxSpans = 12,
  });

  final List<McTextSpan> spans;
  final VoidCallback onChanged;
  final bool events;
  final int maxSpans;

  @override
  State<McSpanEditor> createState() => _McSpanEditorState();
}

class _McSpanEditorState extends State<McSpanEditor> {
  void _changed() {
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.spans.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SpanRow(
              key: ObjectKey(widget.spans[i]),
              span: widget.spans[i],
              events: widget.events,
              onChanged: _changed,
              onRemove: widget.spans.length <= 1
                  ? null
                  : () {
                      widget.spans.removeAt(i);
                      _changed();
                    },
            ),
          ),
        if (widget.spans.length < widget.maxSpans)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                widget.spans.add(McTextSpan(text: t.mcSpanMore, color: widget.spans.lastOrNull?.color));
                _changed();
              },
              icon: Icon(Icons.add_rounded, size: 16, color: luma.accent),
              label: Text(t.mcSpanAddPart),
            ),
          ),
      ],
    );
  }
}

class _SpanRow extends StatelessWidget {
  const _SpanRow({
    super.key,
    required this.span,
    required this.events,
    required this.onChanged,
    required this.onRemove,
  });

  final McTextSpan span;
  final bool events;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    Widget toggle(String label, bool value, ValueChanged<bool> set, {TextStyle? style}) => Tooltip(
      message: switch (label) {
        'B' => t.mcBold,
        'I' => t.mcItalic,
        'U' => t.mcUnderlined,
        'S' => t.mcStrikethrough,
        _ => t.mcObfuscated,
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          set(!value);
          onChanged();
        },
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: value ? luma.accentSubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: value ? luma.accent : luma.border),
          ),
          child: Text(
            label,
            style: (style ?? const TextStyle()).copyWith(
              color: value ? luma.accent : luma.textSecondary,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: luma.surfaceHover,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: McTextField(
                  initialValue: span.text,
                  hint: t.mcSpanText,
                  onChanged: (v) {
                    span.text = v;
                    onChanged();
                  },
                ),
              ),
              if (onRemove != null)
                McIconButton(icon: Icons.close_rounded, tooltip: t.mcRemovePart, onTap: onRemove),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              McColorButton(
                color: span.color,
                onChanged: (c) {
                  span.color = c;
                  onChanged();
                },
              ),
              toggle('B', span.bold, (v) => span.bold = v, style: const TextStyle(fontWeight: FontWeight.w900)),
              toggle('I', span.italic, (v) => span.italic = v, style: const TextStyle(fontStyle: FontStyle.italic)),
              toggle('U', span.underlined, (v) => span.underlined = v, style: const TextStyle(decoration: TextDecoration.underline)),
              toggle('S', span.strikethrough, (v) => span.strikethrough = v, style: const TextStyle(decoration: TextDecoration.lineThrough)),
              toggle('?', span.obfuscated, (v) => span.obfuscated = v),
            ],
          ),
          if (events) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 170,
                  child: McDropdown<McClickAction>(
                    values: McClickAction.values,
                    value: span.click,
                    label: (a) => a == McClickAction.none ? t.mcOnClickNothing : a.label(t),
                    onChanged: (a) {
                      span.click = a;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (span.click != McClickAction.none)
                  Expanded(
                    child: McTextField(
                      initialValue: span.clickValue,
                      monospace: true,
                      hint: switch (span.click) {
                        McClickAction.openUrl => 'https://…',
                        McClickAction.changePage => t.mcHintPageNumber,
                        McClickAction.copyToClipboard => t.mcHintTextToCopy,
                        _ => '/command',
                      },
                      onChanged: (v) {
                        span.clickValue = v;
                        onChanged();
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            McTextField(
              initialValue: span.hover,
              hint: t.mcHintHoverText,
              onChanged: (v) {
                span.hover = v;
                onChanged();
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// A colour chip that opens the sixteen chat colours plus a hex field.
class McColorButton extends StatelessWidget {
  const McColorButton({super.key, required this.color, required this.onChanged});

  /// A chat colour id, `#RRGGBB`, or null for the default.
  final String? color;
  final ValueChanged<String?> onChanged;

  Color _resolve() {
    final c = color;
    if (c == null) return Colors.white;
    if (c.startsWith('#')) return mcParseHex(c) ?? Colors.white;
    return McChatColor.fromId(c)?.color ?? Colors.white;
  }

  Future<void> _open(BuildContext context) async {
    final t = L.of(context);
    final hex = TextEditingController(text: color != null && color!.startsWith('#') ? color : '');
    final picked = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.mcTextColour),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in McChatColor.values)
                    McSwatch(
                      color: c.color,
                      tooltip: '${c.label} (&${c.code})',
                      selected: color == c.id,
                      size: 30,
                      onTap: () => Navigator.pop(context, c.id),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: hex,
                decoration: InputDecoration(labelText: t.mcHexColour, hintText: '#5BC0EB'),
                onSubmitted: (v) {
                  final c = mcParseHex(v);
                  if (c != null) Navigator.pop(context, mcHex(c));
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, ''), child: Text(t.mcDefault)),
          FilledButton(
            onPressed: () {
              final c = mcParseHex(hex.text);
              Navigator.pop(context, c == null ? null : mcHex(c));
            },
            child: Text(t.mcUseHex),
          ),
        ],
      ),
    );
    hex.dispose();
    if (picked == null) return;
    onChanged(picked.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final label = color == null
        ? L.of(context).mcDefault
        : color!.startsWith('#')
        ? color!
        : McChatColor.fromId(color!)?.label ?? color!;
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: () => _open(context),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: luma.border),
          color: luma.surface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: _resolve(),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.black.withValues(alpha: 0.25)),
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: luma.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
