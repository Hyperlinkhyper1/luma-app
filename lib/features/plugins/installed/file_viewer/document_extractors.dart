import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

/// Pure-Dart extraction helpers for the File Viewer plugin. Every function is
/// top-level and takes/returns sendable values so it can run via [compute].

// ---- PDF --------------------------------------------------------------------

/// Extracts the text of every page of a PDF. Pages with no extractable text
/// (scanned pages, pure images) come back as empty strings.
List<String> extractPdfPages(Uint8List bytes) {
  final document = PdfDocument(inputBytes: bytes);
  try {
    final extractor = PdfTextExtractor(document);
    return [
      for (var i = 0; i < document.pages.count; i++)
        extractor.extractText(startPageIndex: i, endPageIndex: i).trim(),
    ];
  } finally {
    document.dispose();
  }
}

// ---- DOCX -------------------------------------------------------------------

/// One paragraph of a Word document with just enough styling to render a
/// readable approximation: heading level (0 = body), bold, and list bullets.
class DocxParagraph {
  const DocxParagraph({
    required this.text,
    this.headingLevel = 0,
    this.bold = false,
    this.bullet = false,
  });

  final String text;
  final int headingLevel;
  final bool bold;
  final bool bullet;
}

/// Reads `word/document.xml` out of the docx zip and flattens it into styled
/// paragraphs. Tables are included row by row with cells joined by tabs.
List<DocxParagraph> extractDocxParagraphs(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  ArchiveFile? entry;
  for (final f in archive.files) {
    if (f.name == 'word/document.xml') {
      entry = f;
      break;
    }
  }
  if (entry == null) {
    throw const FormatException(
        'This file does not look like a Word document.');
  }

  final doc = XmlDocument.parse(utf8.decode(entry.content as List<int>));
  final body = doc.findAllElements('w:body').firstOrNull;
  if (body == null) {
    throw const FormatException('Could not find the document body.');
  }

  final paragraphs = <DocxParagraph>[];
  for (final el in body.childElements) {
    if (el.name.qualified == 'w:p') {
      paragraphs.add(_parseParagraph(el));
    } else if (el.name.qualified == 'w:tbl') {
      for (final row in el.findAllElements('w:tr')) {
        final cells = [
          for (final cell in row.findElements('w:tc'))
            cell.findAllElements('w:p').map(_paragraphText).join(' ').trim(),
        ];
        paragraphs.add(DocxParagraph(text: cells.join('\t')));
      }
    }
  }
  return paragraphs;
}

DocxParagraph _parseParagraph(XmlElement p) {
  final props = p.getElement('w:pPr');
  final styleId = props?.getElement('w:pStyle')?.getAttribute('w:val') ?? '';

  var headingLevel = 0;
  final match = RegExp(r'^(?:Heading|Kop|Titre|berschrift)(\d)$',
          caseSensitive: false)
      .firstMatch(styleId);
  if (match != null) {
    headingLevel = int.parse(match.group(1)!).clamp(1, 6);
  } else if (styleId.toLowerCase() == 'title') {
    headingLevel = 1;
  }

  final bullet = props?.getElement('w:numPr') != null;

  // Treat the paragraph as bold when every non-empty run is bold.
  final runs = p.findAllElements('w:r').toList();
  var bold = runs.isNotEmpty;
  for (final r in runs) {
    final text = r.findElements('w:t').map((t) => t.innerText).join();
    if (text.trim().isEmpty) continue;
    final b = r.getElement('w:rPr')?.getElement('w:b');
    if (b == null || b.getAttribute('w:val') == '0') {
      bold = false;
      break;
    }
  }

  return DocxParagraph(
    text: _paragraphText(p),
    headingLevel: headingLevel,
    bold: bold,
    bullet: bullet,
  );
}

String _paragraphText(XmlElement p) {
  final buf = StringBuffer();
  for (final node in p.descendantElements) {
    switch (node.name.qualified) {
      case 'w:t':
        buf.write(node.innerText);
      case 'w:tab':
        buf.write('\t');
      case 'w:br':
        buf.write('\n');
    }
  }
  return buf.toString();
}

// ---- XLSX -------------------------------------------------------------------

/// Reads the first worksheet of an xlsx into a rectangular grid of strings.
/// An xlsx is a zip of XML parts: shared strings + per-sheet cell data.
List<List<String>> extractXlsxGrid(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);

  ArchiveFile? find(String name) {
    for (final f in archive.files) {
      if (f.name == name) return f;
    }
    return null;
  }

  String content(ArchiveFile f) => utf8.decode(f.content as List<int>);

  final sharedStrings = <String>[];
  final sst = find('xl/sharedStrings.xml');
  if (sst != null) {
    final doc = XmlDocument.parse(content(sst));
    for (final si in doc.findAllElements('si')) {
      // A string item may be split across multiple <t> runs.
      sharedStrings
          .add(si.findAllElements('t').map((t) => t.innerText).join());
    }
  }

  final sheetFiles = archive.files
      .where(
          (f) => f.name.startsWith('xl/worksheets/') && f.name.endsWith('.xml'))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  if (sheetFiles.isEmpty) {
    throw const FormatException('This workbook has no worksheets.');
  }

  final doc = XmlDocument.parse(content(sheetFiles.first));
  final rows = <List<String>>[];
  var maxCols = 0;

  for (final rowEl in doc.findAllElements('row')) {
    final cells = <String>[];
    for (final c in rowEl.findElements('c')) {
      final ref = c.getAttribute('r'); // e.g. "C5"
      final colIdx = ref == null ? cells.length : _colIndex(ref);
      while (cells.length < colIdx) {
        cells.add('');
      }

      final type = c.getAttribute('t');
      String value;
      if (type == 'inlineStr') {
        value = c.findAllElements('t').map((e) => e.innerText).join();
      } else {
        final v = c.findElements('v').firstOrNull?.innerText ?? '';
        if (type == 's') {
          final idx = int.tryParse(v);
          value = (idx != null && idx < sharedStrings.length)
              ? sharedStrings[idx]
              : '';
        } else {
          value = v;
        }
      }
      cells.add(value);
    }
    if (cells.length > maxCols) maxCols = cells.length;
    rows.add(cells);
  }

  // Pad rows so the grid is rectangular.
  for (final row in rows) {
    while (row.length < maxCols) {
      row.add('');
    }
  }
  return rows;
}

/// Converts a cell reference like "AB12" to a zero-based column index.
int _colIndex(String ref) {
  var idx = 0;
  for (final code in ref.codeUnits) {
    if (code >= 65 && code <= 90) {
      idx = idx * 26 + (code - 64);
    } else if (code >= 97 && code <= 122) {
      idx = idx * 26 + (code - 96);
    } else {
      break; // hit the row digits
    }
  }
  return idx - 1;
}
