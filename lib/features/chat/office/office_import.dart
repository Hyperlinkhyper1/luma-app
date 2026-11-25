import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'office_document.dart';

/// What an import kept and what it had to leave behind.
class OfficeImport {
  const OfficeImport(this.document, {this.truncated = false});
  final OfficeDocument document;

  /// The file was bigger than luma's limits and was cut short.
  final bool truncated;
}

const _maxPartBytes = 64 * 1024 * 1024;
const _maxTotalBytes = 256 * 1024 * 1024;
const _maxBlocks = 4000;
const _maxSlides = 300;
const _maxRows = 5000;
const _maxColumns = 200;

/// Reads an uploaded .docx, .pptx or .xlsx into luma's editable model:
/// text, headings, lists, tables, slide titles and bullets, and cell values
/// and formulas. Pictures, charts, themes and fine formatting are not
/// carried over. Throws [FormatException] for anything that is not a
/// readable Office file.
OfficeImport importOfficeFile(String name, List<int> bytes) {
  final kind = officeKindOf(name);
  if (kind == null) {
    throw const FormatException(
      'Only .docx, .pptx and .xlsx files can be edited.',
    );
  }
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw FormatException(
      'This is not a readable .${kind.name} file. Files in the old '
      '.${kind.name.substring(0, 3)} format need to be saved as .${kind.name} first.',
    );
  }
  if (archive.isEmpty) {
    throw FormatException(
      'This is not a readable .${kind.name} file. Files in the old '
      '.${kind.name.substring(0, 3)} format need to be saved as .${kind.name} first.',
    );
  }
  var total = 0;
  for (final file in archive) {
    if (file.size > _maxPartBytes) {
      throw const FormatException('This file is too large to open.');
    }
    total += file.size;
  }
  if (total > _maxTotalBytes) {
    throw const FormatException('This file is too large to open.');
  }
  final package = _Package(archive);
  final title = _coreTitle(package);
  return switch (kind) {
    OfficeKind.docx => _importDocx(package, title),
    OfficeKind.pptx => _importPptx(package, title),
    OfficeKind.xlsx => _importXlsx(package, title),
  };
}

class _Package {
  _Package(Archive archive)
    : _files = {
        for (final file in archive)
          if (file.isFile) file.name.replaceAll('\\', '/'): file,
      };
  final Map<String, ArchiveFile> _files;

  XmlDocument? xml(String path) {
    final file = _files[path];
    if (file == null) return null;
    try {
      return XmlDocument.parse(utf8.decode(file.content, allowMalformed: true));
    } on XmlException {
      throw FormatException('The file is damaged ($path).');
    }
  }

  XmlDocument require(String path) =>
      xml(path) ??
      (throw FormatException('The file is missing its $path part.'));

  /// Relationship id → package path, for the part at [partPath].
  Map<String, String> relationships(String partPath) {
    final slash = partPath.lastIndexOf('/');
    final dir = slash < 0 ? '' : partPath.substring(0, slash);
    final file = partPath.substring(slash + 1);
    final rels = xml('${dir.isEmpty ? '' : '$dir/'}_rels/$file.rels');
    if (rels == null) return const {};
    return {
      for (final rel in rels.findAllElements('Relationship'))
        if (rel.getAttribute('TargetMode') != 'External')
          rel.getAttribute('Id') ?? '': _resolve(
            dir,
            rel.getAttribute('Target') ?? '',
          ),
    };
  }

  static String _resolve(String dir, String target) {
    final parts = <String>[];
    final joined = target.startsWith('/')
        ? target.substring(1)
        : '$dir/$target';
    for (final segment in joined.split('/')) {
      if (segment == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else if (segment.isNotEmpty && segment != '.') {
        parts.add(segment);
      }
    }
    return parts.join('/');
  }
}

/// Elements are matched on their local name, so `w:p` and a renamed prefix
/// both work.
Iterable<XmlElement> _children(XmlElement parent, String local) =>
    parent.childElements.where((e) => e.name.local == local);

XmlElement? _child(XmlElement? parent, String local) =>
    parent == null ? null : _children(parent, local).firstOrNull;

Iterable<XmlElement> _descendants(XmlNode parent, String local) =>
    parent.descendantElements.where((e) => e.name.local == local);

String? _attr(XmlElement? element, String local) {
  if (element == null) return null;
  for (final attribute in element.attributes) {
    if (attribute.name.local == local) return attribute.value;
  }
  return null;
}

/// The `r:id` relationship attribute. Matched on its namespace, because
/// elements like `p:sldId` also carry a plain `id`.
String? _relId(XmlElement element) {
  for (final attribute in element.attributes) {
    if (attribute.name.local == 'id' &&
        (attribute.name.namespaceUri?.endsWith('/relationships') ??
            attribute.name.prefix != null)) {
      return attribute.value;
    }
  }
  return null;
}

bool _on(XmlElement? toggle) {
  if (toggle == null) return false;
  final value = _attr(toggle, 'val');
  return value == null || !(value == '0' || value == 'false' || value == 'off');
}

String _coreTitle(_Package package) {
  final core = package.xml('docProps/core.xml');
  return core == null
      ? ''
      : _descendants(core, 'title').firstOrNull?.innerText.trim() ?? '';
}

/// Joins formatted runs into the inline Markdown the model and the preview
/// share, merging neighbours with the same formatting.
class _RunText {
  final _parts = <(String, bool, bool)>[];

  void add(String text, {bool bold = false, bool italic = false}) {
    if (text.isEmpty) return;
    if (_parts.isNotEmpty &&
        _parts.last.$2 == bold &&
        _parts.last.$3 == italic) {
      final last = _parts.removeLast();
      _parts.add((last.$1 + text, bold, italic));
    } else {
      _parts.add((text, bold, italic));
    }
  }

  String get markdown {
    final out = StringBuffer();
    for (final (text, bold, italic) in _parts) {
      final trimmed = text.trim();
      if (trimmed.isEmpty || (!bold && !italic)) {
        out.write(text);
        continue;
      }
      final lead = text.substring(0, text.indexOf(trimmed));
      final tail = text.substring(lead.length + trimmed.length);
      final mark = bold ? '**' : '*';
      out.write('$lead$mark$trimmed$mark$tail');
    }
    return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

// ---------------------------------------------------------------- Word

class _DocxContext {
  _DocxContext(_Package package) {
    final styles = package.xml('word/styles.xml');
    if (styles != null) {
      for (final style in _descendants(styles, 'style')) {
        final id = _attr(style, 'styleId');
        if (id == null) continue;
        styleNames[id] = (_attr(_child(style, 'name'), 'val') ?? id)
            .toLowerCase();
        final pPr = _child(style, 'pPr');
        final numPr = _child(pPr, 'numPr');
        if (numPr != null) styleNumbering[id] = numPr;
        final outline = _attr(_child(pPr, 'outlineLvl'), 'val');
        if (outline != null) styleOutline[id] = int.tryParse(outline) ?? 9;
      }
    }
    final numbering = package.xml('word/numbering.xml');
    if (numbering != null) {
      final abstracts = <String, Map<int, String>>{};
      for (final abstract in _descendants(numbering, 'abstractNum')) {
        abstracts[_attr(abstract, 'abstractNumId') ?? ''] = {
          for (final lvl in _children(abstract, 'lvl'))
            int.tryParse(_attr(lvl, 'ilvl') ?? '') ?? 0:
                _attr(_child(lvl, 'numFmt'), 'val') ?? 'decimal',
        };
      }
      for (final num in _descendants(numbering, 'num')) {
        final abstract = _attr(_child(num, 'abstractNumId'), 'val');
        numFormats[_attr(num, 'numId') ?? ''] = abstracts[abstract] ?? const {};
      }
    }
  }

  final styleNames = <String, String>{};
  final styleNumbering = <String, XmlElement>{};
  final styleOutline = <String, int>{};
  final numFormats = <String, Map<int, String>>{};
}

OfficeImport _importDocx(_Package package, String title) {
  final document = package.require('word/document.xml');
  final body = _descendants(document, 'body').firstOrNull;
  if (body == null) throw const FormatException('This Word file has no body.');
  final context = _DocxContext(package);
  final blocks = <DocBlock>[];
  var truncated = false;

  void walk(XmlElement container) {
    for (final element in container.childElements) {
      if (blocks.length >= _maxBlocks) {
        truncated = true;
        return;
      }
      switch (element.name.local) {
        case 'p':
          blocks.addAll(_docParagraph(element, context));
        case 'tbl':
          final rows = _docTable(element);
          if (rows.isNotEmpty) {
            blocks.add(DocBlock(DocBlockType.table, rows: rows));
          }
        case 'sdt':
          final content = _child(element, 'sdtContent');
          if (content != null) walk(content);
        case 'customXml' || 'ins' || 'smartTag':
          walk(element);
      }
    }
  }

  walk(body);
  if (title.isEmpty) {
    title =
        blocks
            .where((b) => b.type == DocBlockType.heading)
            .firstOrNull
            ?.text
            .replaceAll('*', '') ??
        '';
  }
  return OfficeImport(
    OfficeDocument(OfficeKind.docx, title: title, blocks: blocks),
    truncated: truncated,
  );
}

void _collectRuns(XmlElement parent, _RunText text, void Function() pageBreak) {
  for (final element in parent.childElements) {
    switch (element.name.local) {
      case 'r':
        final rPr = _child(element, 'rPr');
        final bold = _on(_child(rPr, 'b'));
        final italic = _on(_child(rPr, 'i'));
        for (final part in element.childElements) {
          switch (part.name.local) {
            case 't':
              text.add(part.innerText, bold: bold, italic: italic);
            case 'tab':
              text.add(' ');
            case 'br' || 'cr':
              if (_attr(part, 'type') == 'page') {
                pageBreak();
              } else {
                text.add(' ');
              }
          }
        }
      case 'hyperlink' || 'ins' || 'smartTag' || 'fldSimple' || 'customXml':
        _collectRuns(element, text, pageBreak);
      case 'sdt':
        final content = _child(element, 'sdtContent');
        if (content != null) _collectRuns(content, text, pageBreak);
    }
  }
}

List<DocBlock> _docParagraph(XmlElement p, _DocxContext context) {
  final pPr = _child(p, 'pPr');
  final styleId = _attr(_child(pPr, 'pStyle'), 'val') ?? '';
  final styleName = context.styleNames[styleId] ?? styleId.toLowerCase();
  var hasPageBreak = _child(pPr, 'pageBreakBefore') != null;
  final text = _RunText();
  _collectRuns(p, text, () => hasPageBreak = true);
  final content = text.markdown;
  final out = <DocBlock>[];
  if (hasPageBreak) out.add(const DocBlock(DocBlockType.pageBreak));
  if (content.isEmpty) return out;

  final headingMatch = RegExp(r'heading\s*(\d)').firstMatch(styleName);
  final outline =
      int.tryParse(_attr(_child(pPr, 'outlineLvl'), 'val') ?? '') ??
      context.styleOutline[styleId];
  final numPr = _child(pPr, 'numPr') ?? context.styleNumbering[styleId];
  if (styleName == 'title') {
    out.add(DocBlock(DocBlockType.heading, text: content, level: 1));
  } else if (headingMatch != null || (outline != null && outline < 3)) {
    final level = headingMatch != null
        ? int.parse(headingMatch.group(1)!)
        : outline! + 1;
    out.add(
      DocBlock(DocBlockType.heading, text: content, level: level.clamp(1, 3)),
    );
  } else if (numPr != null || styleName.startsWith('list')) {
    final level = int.tryParse(_attr(_child(numPr, 'ilvl'), 'val') ?? '') ?? 0;
    final numId = _attr(_child(numPr, 'numId'), 'val');
    final levels = context.numFormats[numId];
    final format = levels?[level] ?? levels?[0];
    if (numId == '0') {
      out.add(DocBlock(DocBlockType.paragraph, text: content));
    } else {
      final bullet = format == null
          ? !styleName.contains('number')
          : format == 'bullet' || format == 'none';
      out.add(
        DocBlock(
          bullet ? DocBlockType.bullet : DocBlockType.numbered,
          text: content,
          level: level.clamp(0, 2),
        ),
      );
    }
  } else if (styleName.contains('quote')) {
    out.add(DocBlock(DocBlockType.quote, text: content));
  } else {
    out.add(DocBlock(DocBlockType.paragraph, text: content));
  }
  return out;
}

List<List<String>> _docTable(XmlElement table) {
  final rows = <List<String>>[];
  for (final tr in _children(table, 'tr')) {
    final cells = <String>[];
    for (final tc in _children(tr, 'tc')) {
      final text = _RunText();
      for (final p in _descendants(tc, 'p')) {
        _collectRuns(p, text, () {});
        text.add(' ');
      }
      cells.add(text.markdown.replaceAll('|', '/'));
    }
    if (cells.any((c) => c.isNotEmpty)) rows.add(cells);
  }
  final header = rows.firstOrNull;
  final boldHeader = RegExp(r'^\*\*([^*]+)\*\*$');
  if (header != null &&
      header.every((c) => c.isEmpty || boldHeader.hasMatch(c)) &&
      header.any((c) => c.isNotEmpty)) {
    rows[0] = [for (final c in header) boldHeader.firstMatch(c)?.group(1) ?? c];
  }
  return rows;
}

// ---------------------------------------------------------- PowerPoint

OfficeImport _importPptx(_Package package, String title) {
  const presentationPath = 'ppt/presentation.xml';
  final presentation = package.require(presentationPath);
  final rels = package.relationships(presentationPath);
  final slides = <OfficeSlide>[];
  var truncated = false;
  for (final id in _descendants(presentation, 'sldId')) {
    if (slides.length >= _maxSlides) {
      truncated = true;
      break;
    }
    final path = rels[_relId(id)];
    final slide = path == null ? null : package.xml(path);
    if (slide == null) continue;
    if (_attr(slide.rootElement, 'show') == '0') continue;
    slides.add(_slide(slide));
  }
  if (title.isEmpty && slides.isNotEmpty) {
    title = slides.first.title.replaceAll('*', '');
  }
  return OfficeImport(
    OfficeDocument(OfficeKind.pptx, title: title, slides: slides),
    truncated: truncated,
  );
}

/// Titles are usually bold by design; the emphasis is not content.
String _unwrapBold(String text) {
  final match = RegExp(r'^\*\*([^*]+)\*\*$').firstMatch(text);
  return match?.group(1) ?? text;
}

OfficeSlide _slide(XmlDocument slide) {
  var title = '';
  var subtitle = '';
  final bullets = <SlideBullet>[];
  for (final shape in _descendants(slide, 'sp')) {
    final ph = _descendants(shape, 'ph').firstOrNull;
    final shapeName =
        (_attr(_descendants(shape, 'cNvPr').firstOrNull, 'name') ?? '')
            .toLowerCase();
    final type =
        _attr(ph, 'type') ??
        (ph == null && shapeName.startsWith('title')
            ? 'title'
            : ph == null && shapeName.startsWith('subtitle')
            ? 'subTitle'
            : null);
    if (type == 'sldNum' || type == 'dt' || type == 'ftr' || type == 'hdr') {
      continue;
    }
    final body = _child(shape, 'txBody');
    if (body == null) continue;
    final paragraphs = <(String, int)>[];
    for (final p in _children(body, 'p')) {
      final text = _RunText();
      for (final part in p.childElements) {
        if (part.name.local == 'r' || part.name.local == 'fld') {
          final rPr = _child(part, 'rPr');
          text.add(
            _child(part, 't')?.innerText ?? '',
            bold: _attr(rPr, 'b') == '1' || _attr(rPr, 'b') == 'true',
            italic: _attr(rPr, 'i') == '1' || _attr(rPr, 'i') == 'true',
          );
        } else if (part.name.local == 'br') {
          text.add(' ');
        }
      }
      final content = text.markdown;
      if (content.isEmpty) continue;
      final level = int.tryParse(_attr(_child(p, 'pPr'), 'lvl') ?? '') ?? 0;
      paragraphs.add((content, level));
    }
    if (paragraphs.isEmpty) continue;
    final joined = _unwrapBold(paragraphs.map((p) => p.$1).join(' '));
    if ((type == 'title' || type == 'ctrTitle') && title.isEmpty) {
      title = joined;
    } else if (type == 'subTitle' && subtitle.isEmpty) {
      subtitle = joined;
    } else {
      for (final (text, level) in paragraphs) {
        bullets.add(SlideBullet(text, level.clamp(0, 2)));
      }
    }
  }
  for (final table in _descendants(slide, 'tbl')) {
    for (final row in _children(table, 'tr')) {
      final cells = [
        for (final cell in _children(row, 'tc'))
          _descendants(cell, 't').map((t) => t.innerText).join(' ').trim(),
      ];
      if (cells.any((c) => c.isNotEmpty)) {
        bullets.add(SlideBullet(cells.join(' | ')));
      }
    }
  }
  if (title.isEmpty && bullets.isNotEmpty) {
    title = bullets.removeAt(0).text;
  }
  return OfficeSlide(title: title, subtitle: subtitle, bullets: bullets);
}

// --------------------------------------------------------------- Excel

OfficeImport _importXlsx(_Package package, String title) {
  const workbookPath = 'xl/workbook.xml';
  final workbook = package.require(workbookPath);
  final rels = package.relationships(workbookPath);
  final shared = <String>[];
  final sharedXml = package.xml(
    rels.values.where((p) => p.endsWith('sharedStrings.xml')).firstOrNull ??
        'xl/sharedStrings.xml',
  );
  if (sharedXml != null) {
    for (final si in _descendants(sharedXml, 'si')) {
      shared.add(
        si.descendantElements
            .where(
              (e) =>
                  e.name.local == 't' && e.parentElement?.name.local != 'rPh',
            )
            .map((t) => t.innerText)
            .join(),
      );
    }
  }
  final sheets = <OfficeSheet>[];
  var truncated = false;
  final usedNames = <String>{};
  for (final entry in _descendants(workbook, 'sheet')) {
    final path = rels[_relId(entry)];
    final xml = path == null ? null : package.xml(path);
    if (xml == null) continue;
    var name = safeSheetName(
      _attr(entry, 'name') ?? 'Sheet${sheets.length + 1}',
    );
    while (!usedNames.add(name.toLowerCase())) {
      name = safeSheetName('$name ${sheets.length + 1}');
    }
    final sheet = OfficeSheet(name);
    var nextRow = 0;
    for (final row in _descendants(xml, 'row')) {
      final rowIndex = (int.tryParse(_attr(row, 'r') ?? '') ?? nextRow + 1) - 1;
      nextRow = rowIndex + 1;
      if (rowIndex >= _maxRows) {
        truncated = true;
        break;
      }
      var nextCol = 0;
      for (final c in _children(row, 'c')) {
        final ref = parseCellName(_attr(c, 'r') ?? '');
        final col = ref?.$2 ?? nextCol;
        nextCol = col + 1;
        if (col >= _maxColumns) {
          truncated = true;
          continue;
        }
        final value = _cellValue(c, shared);
        if (value.isNotEmpty) sheet.setCell(rowIndex, col, value);
      }
    }
    sheets.add(sheet);
  }
  if (sheets.isEmpty) {
    throw const FormatException('This workbook has no sheets.');
  }
  return OfficeImport(
    OfficeDocument(OfficeKind.xlsx, title: title, sheets: sheets),
    truncated: truncated,
  );
}

String _cellValue(XmlElement c, List<String> shared) {
  final formula = _child(c, 'f')?.innerText.trim() ?? '';
  if (formula.isNotEmpty) return '=$formula';
  final raw = _child(c, 'v')?.innerText ?? '';
  switch (_attr(c, 't')) {
    case 's':
      final index = int.tryParse(raw);
      return index != null && index >= 0 && index < shared.length
          ? shared[index]
          : '';
    case 'inlineStr':
      return _descendants(c, 't').map((t) => t.innerText).join();
    case 'b':
      return raw == '1' ? 'TRUE' : 'FALSE';
    case 'str' || 'e':
      return raw;
    default:
      final number = num.tryParse(raw);
      return number == null ? raw : formatSheetNumber(number);
  }
}

/// The whole document as numbered Markdown, for the model's first look at an
/// upload, cut to [limit] characters.
String officeContentsForPrompt(OfficeDocument document, {int limit = 24000}) {
  final out = StringBuffer();
  for (var i = 0; i < document.partCount; i++) {
    final header = switch (document.kind) {
      OfficeKind.xlsx => '[$i] sheet "${document.sheets[i].name}"',
      _ => '[$i]',
    };
    final part = '$header\n${document.readPart(i)}\n\n';
    if (out.length + part.length > limit) {
      out.write(
        '… ${document.partCount - i} more ${switch (document.kind) {
          OfficeKind.docx => 'blocks',
          OfficeKind.pptx => 'slides',
          OfficeKind.xlsx => 'sheets',
        }}; read them with read_office_file.',
      );
      break;
    }
    out.write(part);
  }
  return out.toString().trimRight();
}
