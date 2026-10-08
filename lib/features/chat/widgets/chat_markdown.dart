import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/luma_theme.dart';
import '../memory/assistant_memory_repository.dart';
import '../memory/assistant_memory_scope.dart';

/// Serif body text for assistant replies, the way the Claude app sets its
/// responses. Georgia ships with Windows; the fallbacks cover Linux and
/// Android.
const chatSerifFamily = 'Georgia';
const chatSerifFallback = ['Times New Roman', 'Noto Serif', 'serif'];

/// The reply typeface and size the user picked in the assistant's settings
/// (serif at 16px when there's no preference to read).
TextStyle chatBodyTextStyle(BuildContext context) {
  final memory = AssistantMemoryScope.maybeOf(context);
  final size = 16 * (memory?.textSize.scale ?? 1.0);
  return switch (memory?.font ?? ChatFont.serif) {
    ChatFont.serif => TextStyle(
      fontFamily: chatSerifFamily,
      fontFamilyFallback: chatSerifFallback,
      fontSize: size,
    ),
    ChatFont.sans => TextStyle(fontSize: size * 0.96),
    ChatFont.mono => TextStyle(
      fontFamily: 'Consolas',
      fontFamilyFallback: const ['Menlo', 'monospace'],
      fontSize: size * 0.9,
    ),
  };
}

/// Renders an assistant reply as Markdown: headings, lists, quotes, rules,
/// fenced code (with a language label and copy button), and inline bold,
/// italic, code and links.
///
/// Unlike most Markdown renderers, single newlines inside a paragraph are
/// kept — models lean on them for short line-broken answers, and joining
/// them would run those lines together.
class ChatMarkdown extends StatelessWidget {
  const ChatMarkdown({super.key, required this.source, this.color});

  final String source;

  /// Overrides the body text colour, e.g. for an error reply.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final blocks = _parse(source.replaceAll('\r\n', '\n'));
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < blocks.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == blocks.length - 1 ? 0 : blocks[i].spacingAfter,
              ),
              child: _buildBlock(context, blocks[i]),
            ),
        ],
      ),
    );
  }

  static List<_Block> _parse(String text) {
    final blocks = <_Block>[];
    final lines = text.split('\n');
    final paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      final joined = paragraph.join('\n').trim();
      paragraph.clear();
      if (joined.isNotEmpty) blocks.add(_Block(_Kind.paragraph, joined));
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.startsWith('```')) {
        flushParagraph();
        final language = trimmed.substring(3).trim();
        final code = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          code.add(lines[i]);
          i++;
        }
        blocks.add(_Block(_Kind.code, code.join('\n'), marker: language));
        continue;
      }

      if (trimmed.isEmpty) {
        flushParagraph();
        continue;
      }

      if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed)) {
        flushParagraph();
        blocks.add(_Block(_Kind.rule, ''));
        continue;
      }

      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      if (heading != null) {
        flushParagraph();
        blocks.add(
          _Block(
            _Kind.heading,
            heading.group(2)!.trim(),
            level: heading.group(1)!.length,
          ),
        );
        continue;
      }

      if (trimmed.startsWith('>')) {
        flushParagraph();
        final quote = <String>[trimmed.replaceFirst(RegExp(r'^>\s?'), '')];
        while (i + 1 < lines.length && lines[i + 1].trim().startsWith('>')) {
          i++;
          quote.add(lines[i].trim().replaceFirst(RegExp(r'^>\s?'), ''));
        }
        blocks.add(_Block(_Kind.quote, quote.join('\n')));
        continue;
      }

      final indent = line.length - line.trimLeft().length;
      final bullet = RegExp(r'^[-*+]\s+(.*)$').firstMatch(trimmed);
      if (bullet != null) {
        flushParagraph();
        blocks.add(
          _Block(
            _Kind.listItem,
            bullet.group(1)!,
            marker: indent >= 2 ? '◦' : '•',
            level: indent ~/ 2,
          ),
        );
        continue;
      }

      final numbered = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(trimmed);
      if (numbered != null) {
        flushParagraph();
        blocks.add(
          _Block(
            _Kind.listItem,
            numbered.group(2)!,
            marker: '${numbered.group(1)}.',
            level: indent ~/ 2,
          ),
        );
        continue;
      }

      paragraph.add(trimmed);
    }
    flushParagraph();

    // Tighten the gap between consecutive list items only.
    for (var i = 0; i < blocks.length - 1; i++) {
      if (blocks[i].kind == _Kind.listItem &&
          blocks[i + 1].kind != _Kind.listItem) {
        blocks[i].spacingAfter = 14;
      }
    }
    return blocks;
  }

  Widget _buildBlock(BuildContext context, _Block block) {
    final luma = context.luma;
    switch (block.kind) {
      case _Kind.heading:
        const sizes = [22.0, 19.0, 17.0, 16.0, 15.5, 15.5];
        return Padding(
          padding: EdgeInsets.only(top: block.level <= 2 ? 6 : 2),
          child: Text.rich(
            _inline(
              context,
              block.text,
              size: sizes[block.level.clamp(1, 6) - 1],
              weight: FontWeight.w700,
            ),
          ),
        );
      case _Kind.rule:
        return Divider(color: luma.border, height: 1);
      case _Kind.quote:
        return Container(
          padding: const EdgeInsets.only(left: 14),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: luma.border, width: 3)),
          ),
          child: Text.rich(
            _inline(context, block.text, colorOverride: luma.textSecondary),
          ),
        );
      case _Kind.code:
        return _CodeBlock(code: block.text, language: block.marker);
      case _Kind.listItem:
        return Padding(
          padding: EdgeInsets.only(left: 4.0 + block.level * 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: block.marker.length > 2 ? 30 : 22,
                child: Text(
                  block.marker,
                  style: _bodyStyle(
                    context,
                  ).copyWith(color: luma.textSecondary),
                ),
              ),
              Expanded(child: Text.rich(_inline(context, block.text))),
            ],
          ),
        );
      case _Kind.paragraph:
        return Text.rich(_inline(context, block.text));
    }
  }

  TextStyle _bodyStyle(BuildContext context) => chatBodyTextStyle(
    context,
  ).copyWith(color: color ?? context.luma.textPrimary, height: 1.6);

  static final _inlinePattern = RegExp(
    r'\[[^\]]+\]\([^)\s]+\)'
    r'|\*\*[^*]+\*\*'
    r'|__[^_]+__'
    r'|(?<![\w*])\*[^*\n]+\*(?!\w)'
    r'|(?<!\w)_[^_\n]+_(?!\w)'
    r'|`[^`\n]+`',
  );

  TextSpan _inline(
    BuildContext context,
    String text, {
    double? size,
    FontWeight? weight,
    Color? colorOverride,
  }) {
    final luma = context.luma;
    final scale = AssistantMemoryScope.maybeOf(context)?.textSize.scale ?? 1.0;
    final base = _bodyStyle(context).copyWith(
      fontSize: size == null ? null : size * scale,
      fontWeight: weight,
      color: colorOverride,
    );
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _inlinePattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      if (token.startsWith('[')) {
        final parts = RegExp(r'^\[([^\]]+)\]\(([^)\s]+)\)$').firstMatch(token);
        final label = parts?.group(1) ?? token;
        final uri = Uri.tryParse(parts?.group(2) ?? '');
        final launchable =
            uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
        spans.add(
          TextSpan(
            text: label,
            style: TextStyle(
              color: luma.accent,
              decoration: TextDecoration.underline,
              decorationColor: luma.accent.withValues(alpha: 0.5),
            ),
            mouseCursor: launchable ? SystemMouseCursors.click : null,
            recognizer: launchable
                ? (TapGestureRecognizer()
                    ..onTap = () =>
                        launchUrl(uri, mode: LaunchMode.externalApplication))
                : null,
          ),
        );
      } else if (token.startsWith('**') || token.startsWith('__')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else if (token.startsWith('*') || token.startsWith('_')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: TextStyle(
              fontFamily: 'Consolas',
              fontFamilyFallback: const ['Menlo', 'monospace'],
              fontSize: (size ?? 16) * scale * 0.86,
              color: luma.danger,
              backgroundColor: luma.surfaceHover,
            ),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: base, children: spans);
  }
}

/// A fenced code block: a slim header with the language and a copy button,
/// over a horizontally scrollable monospace body.
class _CodeBlock extends StatefulWidget {
  const _CodeBlock({required this.code, required this.language});

  final String code;
  final String language;

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Container(
      decoration: BoxDecoration(
        color: luma.rail,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            color: luma.surface,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.language.isEmpty
                        ? t.chatCodeLanguagePlainText
                        : widget.language,
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                ),
                TextButton.icon(
                  onPressed: _copy,
                  style: TextButton.styleFrom(
                    foregroundColor: luma.textSecondary,
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  icon: Icon(
                    _copied ? Icons.check_rounded : Icons.content_copy_rounded,
                    size: 14,
                  ),
                  label: Text(_copied ? t.assistantCopied : t.assistantCopy),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(14),
            child: Text(
              widget.code,
              style: TextStyle(
                color: luma.textPrimary,
                fontFamily: 'Consolas',
                fontFamilyFallback: const ['Menlo', 'monospace'],
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Kind { paragraph, heading, listItem, quote, code, rule }

class _Block {
  _Block(this.kind, this.text, {this.level = 0, this.marker = ''})
    : spacingAfter = switch (kind) {
        _Kind.listItem => 6,
        _Kind.heading => 8,
        _ => 14,
      };

  final _Kind kind;
  final String text;
  final int level;
  final String marker;
  double spacingAfter;
}
