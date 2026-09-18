import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';

/// A small Markdown renderer for Modrinth project descriptions.
///
/// Modrinth bodies are author-written Markdown with a fair amount of inline
/// HTML (centred banners, `<br>`, badge images). Pulling in a full Markdown
/// package for one screen would be heavy, so this handles the subset those
/// pages actually use — headings, lists, quotes, rules, fenced code, images,
/// links, and inline emphasis — and degrades anything else to plain text
/// rather than printing raw markup at the reader.
class MarkdownLite extends StatelessWidget {
  const MarkdownLite({
    super.key,
    required this.source,
    this.onLinkTap,
    this.textScale = 1,
  });

  final String source;
  final void Function(String url)? onLinkTap;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final blocks = _parse(_normalise(source));
    if (blocks.isEmpty) {
      return Text(
        'This project has no description.',
        style: TextStyle(color: luma.textMuted, fontSize: 13),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks)
          Padding(
            padding: EdgeInsets.only(bottom: block.spacingAfter),
            child: _buildBlock(context, block),
          ),
      ],
    );
  }

  // ── Preprocessing ─────────────────────────────────────────────────────

  /// Folds the HTML Modrinth authors mix into their Markdown down to things
  /// the block parser understands, then drops the remaining tags.
  static String _normalise(String raw) {
    var text = raw.replaceAll('\r\n', '\n');
    text = text.replaceAllMapped(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      (_) => '\n',
    );
    text = text.replaceAllMapped(
      RegExp(r'''<img[^>]*src=["']([^"']+)["'][^>]*>''', caseSensitive: false),
      (m) => '\n![](${m.group(1)})\n',
    );
    text = text.replaceAllMapped(
      RegExp(r'''<a[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>''',
          caseSensitive: false, dotAll: true),
      (m) => '[${m.group(2)}](${m.group(1)})',
    );
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    return text;
  }

  // ── Block parsing ─────────────────────────────────────────────────────

  static List<_Block> _parse(String text) {
    final blocks = <_Block>[];
    final lines = text.split('\n');
    final paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      final joined = paragraph.join(' ').trim();
      paragraph.clear();
      if (joined.isEmpty) return;
      // A paragraph that is nothing but an image is a banner, not prose.
      final imageOnly = RegExp(r'^!\[[^\]]*\]\(([^)\s]+)\)$').firstMatch(joined);
      if (imageOnly != null) {
        blocks.add(_Block.image(imageOnly.group(1)!));
      } else {
        blocks.add(_Block.paragraph(joined));
      }
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.startsWith('```')) {
        flushParagraph();
        final code = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          code.add(lines[i]);
          i++;
        }
        blocks.add(_Block.code(code.join('\n')));
        continue;
      }

      if (trimmed.isEmpty) {
        flushParagraph();
        continue;
      }

      if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed)) {
        flushParagraph();
        blocks.add(_Block.rule());
        continue;
      }

      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      if (heading != null) {
        flushParagraph();
        blocks.add(_Block.heading(heading.group(1)!.length, heading.group(2)!.trim()));
        continue;
      }

      if (trimmed.startsWith('> ') || trimmed == '>') {
        flushParagraph();
        blocks.add(_Block.quote(trimmed.replaceFirst(RegExp(r'^>\s?'), '')));
        continue;
      }

      final bullet = RegExp(r'^[-*+]\s+(.*)$').firstMatch(trimmed);
      if (bullet != null) {
        flushParagraph();
        blocks.add(_Block.listItem('•', bullet.group(1)!));
        continue;
      }

      final numbered = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(trimmed);
      if (numbered != null) {
        flushParagraph();
        blocks.add(_Block.listItem('${numbered.group(1)}.', numbered.group(2)!));
        continue;
      }

      paragraph.add(trimmed);
    }
    flushParagraph();
    return blocks;
  }

  // ── Block rendering ───────────────────────────────────────────────────

  Widget _buildBlock(BuildContext context, _Block block) {
    final luma = context.luma;
    switch (block.kind) {
      case _BlockKind.heading:
        final sizes = [22.0, 19.0, 17.0, 15.5, 14.5, 14.0];
        final level = block.level.clamp(1, 6);
        return Padding(
          padding: EdgeInsets.only(top: level <= 2 ? 8 : 4),
          child: Text.rich(
            _inline(context, block.text, baseSize: sizes[level - 1], bold: true),
          ),
        );
      case _BlockKind.rule:
        return Divider(color: luma.border, height: 1);
      case _BlockKind.quote:
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: luma.accent.withValues(alpha: 0.07),
            border: Border(left: BorderSide(color: luma.accent, width: 3)),
          ),
          child: Text.rich(_inline(context, block.text)),
        );
      case _BlockKind.code:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: luma.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: luma.border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              block.text,
              style: TextStyle(
                color: luma.textSecondary,
                fontFamily: 'monospace',
                fontSize: 12.5 * textScale,
                height: 1.45,
              ),
            ),
          ),
        );
      case _BlockKind.listItem:
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  block.marker,
                  style: TextStyle(color: luma.textMuted, fontSize: 13.5 * textScale),
                ),
              ),
              Expanded(child: Text.rich(_inline(context, block.text))),
            ],
          ),
        );
      case _BlockKind.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            block.text,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : const SizedBox(height: 4),
          ),
        );
      case _BlockKind.paragraph:
        return Text.rich(_inline(context, block.text));
    }
  }

  // ── Inline rendering ──────────────────────────────────────────────────

  static final _inlinePattern = RegExp(
    r'!\[[^\]]*\]\([^)\s]+\)'
    r'|\[[^\]]*\]\([^)\s]+\)'
    r'|\*\*[^*]+\*\*'
    r'|__[^_]+__'
    r'|\*[^*\n]+\*'
    r'|`[^`]+`',
  );

  TextSpan _inline(
    BuildContext context,
    String text, {
    double baseSize = 13.5,
    bool bold = false,
  }) {
    final luma = context.luma;
    final base = TextStyle(
      color: bold ? luma.textPrimary : luma.textSecondary,
      fontSize: baseSize * textScale,
      height: 1.5,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    );
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _inlinePattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      if (token.startsWith('![')) {
        // Inline images inside prose are almost always badges; the alt text
        // carries the meaning and the sprite does not survive a text run.
        final alt = RegExp(r'^!\[([^\]]*)\]').firstMatch(token)?.group(1) ?? '';
        if (alt.isNotEmpty) spans.add(TextSpan(text: alt));
      } else if (token.startsWith('[')) {
        final parts = RegExp(r'^\[([^\]]*)\]\(([^)\s]+)\)$').firstMatch(token);
        final label = parts?.group(1) ?? token;
        final url = parts?.group(2);
        spans.add(TextSpan(
          text: label,
          style: TextStyle(
            color: luma.accent,
            decoration: TextDecoration.underline,
            decorationColor: luma.accent.withValues(alpha: 0.5),
          ),
          recognizer: url == null || onLinkTap == null
              ? null
              : (TapGestureRecognizer()..onTap = () => onLinkTap!(url)),
        ));
      } else if (token.startsWith('**') || token.startsWith('__')) {
        spans.add(TextSpan(
          text: token.substring(2, token.length - 2),
          style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700),
        ));
      } else if (token.startsWith('*')) {
        spans.add(TextSpan(
          text: token.substring(1, token.length - 1),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      } else {
        spans.add(TextSpan(
          text: token.substring(1, token.length - 1),
          style: TextStyle(
            fontFamily: 'monospace',
            color: luma.textPrimary,
            backgroundColor: luma.border.withValues(alpha: 0.4),
          ),
        ));
      }
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return TextSpan(style: base, children: spans);
  }
}

enum _BlockKind { paragraph, heading, listItem, quote, code, rule, image }

class _Block {
  _Block(this.kind, this.text, {this.level = 0, this.marker = ''});
  final _BlockKind kind;
  final String text;
  final int level;
  final String marker;

  factory _Block.paragraph(String text) => _Block(_BlockKind.paragraph, text);
  factory _Block.heading(int level, String text) =>
      _Block(_BlockKind.heading, text, level: level);
  factory _Block.listItem(String marker, String text) =>
      _Block(_BlockKind.listItem, text, marker: marker);
  factory _Block.quote(String text) => _Block(_BlockKind.quote, text);
  factory _Block.code(String text) => _Block(_BlockKind.code, text);
  factory _Block.rule() => _Block(_BlockKind.rule, '');
  factory _Block.image(String url) => _Block(_BlockKind.image, url);

  double get spacingAfter => switch (kind) {
        _BlockKind.listItem => 4,
        _BlockKind.heading => 8,
        _BlockKind.rule => 14,
        _BlockKind.image => 14,
        _ => 12,
      };
}
