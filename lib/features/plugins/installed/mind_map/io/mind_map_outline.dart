/// Plain-text interchange for mind maps.
///
/// Everything here is pure string work with no Flutter or database
/// dependency, so the round trip is covered by unit tests. Pasting an
/// indented outline is the fastest way to get a whole map on screen, so the
/// parser is deliberately forgiving: tabs or spaces, any bullet character,
/// or Markdown headings all describe the same shape.
library;

/// A node in an outline, independent of how it is stored.
class OutlineNode {
  OutlineNode({
    required this.label,
    this.note,
    this.link,
    List<OutlineNode>? children,
  }) : children = children ?? [];

  String label;
  String? note;
  String? link;
  final List<OutlineNode> children;

  int get descendantCount =>
      children.length + children.fold<int>(0, (sum, c) => sum + c.descendantCount);
}

class MindMapOutline {
  const MindMapOutline._();

  static final _headingPattern = RegExp(r'^(#{1,6})\s+(.*)$');
  static final _bulletPattern = RegExp(r'^([-*+•]|\d+[.)])\s+');
  static final _linkPattern = RegExp(r'^\[(.+)\]\((\S+)\)$');

  /// Parses an indented outline into a forest.
  ///
  /// Depth comes from leading whitespace, or from the number of `#` when the
  /// line is a Markdown heading. The indent unit is inferred from the
  /// smallest indent in the text, so 2-space, 4-space and tab outlines all
  /// work without the user choosing anything.
  static List<OutlineNode> parse(String text) {
    final rawLines = text.split(RegExp(r'\r?\n'));

    final entries = <_ParsedLine>[];
    for (final raw in rawLines) {
      if (raw.trim().isEmpty) continue;

      final expanded = raw.replaceAll('\t', '    ');
      final indent = expanded.length - expanded.trimLeft().length;
      var body = expanded.trim();

      final heading = _headingPattern.firstMatch(body);
      if (heading != null) {
        entries.add(_ParsedLine(
          headingLevel: heading.group(1)!.length - 1,
          indent: indent,
          text: heading.group(2)!.trim(),
        ));
        continue;
      }

      // A `> ...` line annotates the node above it rather than making a node.
      if (body.startsWith('>')) {
        if (entries.isNotEmpty) {
          final note = body.substring(1).trim();
          final last = entries.last;
          last.note = last.note == null ? note : '${last.note}\n$note';
        }
        continue;
      }

      body = body.replaceFirst(_bulletPattern, '');
      if (body.isEmpty) continue;
      entries.add(_ParsedLine(headingLevel: null, indent: indent, text: body));
    }

    if (entries.isEmpty) return [];

    // Infer the indent unit from the smallest non-zero indent actually used.
    final indents = entries
        .where((e) => e.headingLevel == null && e.indent > 0)
        .map((e) => e.indent)
        .toList();
    final unit = indents.isEmpty ? 2 : indents.reduce((a, b) => a < b ? a : b);

    final roots = <OutlineNode>[];
    final stack = <_StackEntry>[];

    for (final entry in entries) {
      final depth = entry.headingLevel ?? (unit == 0 ? 0 : entry.indent ~/ unit);

      var label = entry.text;
      String? link;
      final linkMatch = _linkPattern.firstMatch(label);
      if (linkMatch != null) {
        label = linkMatch.group(1)!;
        link = linkMatch.group(2);
      }

      final node = OutlineNode(label: label, note: entry.note, link: link);

      while (stack.isNotEmpty && stack.last.depth >= depth) {
        stack.removeLast();
      }
      if (stack.isEmpty) {
        roots.add(node);
      } else {
        stack.last.node.children.add(node);
      }
      stack.add(_StackEntry(depth: depth, node: node));
    }

    return roots;
  }

  /// Renders a forest as an indented Markdown bullet list.
  static String toMarkdown(List<OutlineNode> roots) {
    final buffer = StringBuffer();
    for (final root in roots) {
      _writeMarkdown(buffer, root, 0);
    }
    return buffer.toString();
  }

  static void _writeMarkdown(StringBuffer buffer, OutlineNode node, int depth) {
    final indent = '  ' * depth;
    final label = node.link == null || node.link!.isEmpty
        ? node.label
        : '[${node.label}](${node.link})';
    buffer.writeln('$indent- $label');
    final note = node.note;
    if (note != null && note.trim().isNotEmpty) {
      for (final line in note.trim().split(RegExp(r'\r?\n'))) {
        buffer.writeln('$indent  > ${line.trim()}');
      }
    }
    for (final child in node.children) {
      _writeMarkdown(buffer, child, depth + 1);
    }
  }

  /// Renders a forest as OPML, the outline format most mind-map and
  /// outliner apps can import.
  static String toOpml(List<OutlineNode> roots, {required String title}) {
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<opml version="2.0">')
      ..writeln('  <head>')
      ..writeln('    <title>${_escape(title)}</title>')
      ..writeln('  </head>')
      ..writeln('  <body>');
    for (final root in roots) {
      _writeOpml(buffer, root, 2);
    }
    buffer
      ..writeln('  </body>')
      ..writeln('</opml>');
    return buffer.toString();
  }

  static void _writeOpml(StringBuffer buffer, OutlineNode node, int depth) {
    final indent = '  ' * depth;
    final attributes = StringBuffer('text="${_escape(node.label)}"');
    if (node.note != null && node.note!.trim().isNotEmpty) {
      attributes.write(' _note="${_escape(node.note!)}"');
    }
    if (node.link != null && node.link!.isNotEmpty) {
      attributes.write(' url="${_escape(node.link!)}"');
    }
    if (node.children.isEmpty) {
      buffer.writeln('$indent<outline $attributes/>');
      return;
    }
    buffer.writeln('$indent<outline $attributes>');
    for (final child in node.children) {
      _writeOpml(buffer, child, depth + 1);
    }
    buffer.writeln('$indent</outline>');
  }

  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

class _ParsedLine {
  _ParsedLine({required this.headingLevel, required this.indent, required this.text});
  final int? headingLevel;
  final int indent;
  final String text;
  String? note;
}

class _StackEntry {
  _StackEntry({required this.depth, required this.node});
  final int depth;
  final OutlineNode node;
}
