import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/chat/office/office_document.dart';
import 'package:luma/features/chat/office/office_export.dart';
import 'package:xml/xml.dart';

Map<String, String> _unzip(List<int> bytes) => {
  for (final file in ZipDecoder().decodeBytes(bytes))
    if (file.isFile) file.name: utf8.decode(file.content as List<int>),
};

void main() {
  group('Word markdown', () {
    test('parses headings, lists, quotes, tables and paragraphs', () {
      final blocks = parseDocMarkdown('''
# Doel
Deze notitie geeft
een beeld.

- eerste
  - genest
1. stap een
2. stap twee
> citaat

| Naam | Score |
|---|---|
| A | 1 |
---
''');
      expect(blocks.map((b) => b.type), [
        DocBlockType.heading,
        DocBlockType.paragraph,
        DocBlockType.bullet,
        DocBlockType.bullet,
        DocBlockType.numbered,
        DocBlockType.numbered,
        DocBlockType.quote,
        DocBlockType.table,
        DocBlockType.pageBreak,
      ]);
      expect(blocks[1].text, 'Deze notitie geeft een beeld.');
      expect(blocks[3].level, 1);
      expect(blocks[7].rows, [
        ['Naam', 'Score'],
        ['A', '1'],
      ]);
    });

    test('round-trips each block through its markdown', () {
      final blocks = parseDocMarkdown(
        '## Kop\n\n- **vet** punt\n\n| a | b |\n|---|---|\n| 1 | 2 |',
      );
      for (final block in blocks) {
        final again = parseDocMarkdown(block.toMarkdown()).single;
        expect(again.toJson(), block.toJson());
      }
    });

    test('splits bold and italic runs', () {
      final runs = parseInline('een **vet** en *schuin* woord');
      expect(runs.map((r) => r.text), [
        'een ',
        'vet',
        ' en ',
        'schuin',
        ' woord',
      ]);
      expect(runs[1].bold, isTrue);
      expect(runs[3].italic, isTrue);
    });
  });

  group('editing', () {
    test('append, insert, replace and delete report what changed', () {
      final doc = OfficeDocument(OfficeKind.docx);
      var focus = doc.edit(action: 'append', content: '# A\n\nB');
      expect(doc.blocks.length, 2);
      expect((focus.start, focus.end), (0, 1));

      focus = doc.edit(action: 'insert', index: 1, content: 'Tussen');
      expect(doc.blocks[1].text, 'Tussen');
      expect(focus.activity, OfficeActivity.writing);

      doc.edit(action: 'replace', index: 2, content: 'Nieuw');
      expect(doc.blocks.last.text, 'Nieuw');

      focus = doc.edit(action: 'delete', index: 0);
      expect(focus.activity, OfficeActivity.deleting);
      expect(doc.blocks.map((b) => b.text), ['Tussen', 'Nieuw']);
    });

    test('rejects out-of-range indices and empty content', () {
      final doc = OfficeDocument(OfficeKind.docx);
      expect(
        () => doc.edit(action: 'replace', index: 0, content: 'x'),
        throwsFormatException,
      );
      expect(
        () => doc.edit(action: 'append', content: '  '),
        throwsFormatException,
      );
    });

    test('slides split on --- with a cover slide first', () {
      final doc = OfficeDocument(OfficeKind.pptx);
      doc.edit(
        action: 'append',
        content: '''
# Cyberdreiging 2026
## Notitie aan de RvB
---
# Kernboodschap
- Bellen en downloaden
  - Odido, Allianz
Losse regel
''',
      );
      expect(doc.slides.length, 2);
      expect(doc.slides[0].subtitle, 'Notitie aan de RvB');
      expect(doc.slides[1].bullets.map((b) => (b.text, b.level)), [
        ('Bellen en downloaden', 0),
        ('Odido, Allianz', 1),
        ('Losse regel', 0),
      ]);
    });

    test('cells land at their A1 position and grow the sheet', () {
      final doc = OfficeDocument(OfficeKind.xlsx);
      final focus = doc.writeCells(
        sheetName: 'Budget',
        cell: 'B2',
        values: [
          ['Item', 'Bedrag'],
          ['Huur', '950'],
          ['Totaal', '=SUM(C3:C3)+50'],
        ],
      );
      final sheet = doc.sheets.single;
      expect(sheet.cell(1, 1), 'Item');
      expect(sheet.cell(3, 2), '=SUM(C3:C3)+50');
      expect(focus.cellStart, (1, 1));
      expect(focus.cellEnd, (3, 2));
      expect(focus.coversCell(2, 2), isTrue);
      expect(focus.coversCell(0, 0), isFalse);
      expect(displayCellValue(sheet, sheet.cell(3, 2)), '1000');
    });
  });

  group('formulas', () {
    final sheet = OfficeSheet('S', [
      ['1', '2', '3'],
      ['=A1+B1*C1', '=AVERAGE(A1:C1)', '=MAX(A1:C1)-MIN(A1:C1)'],
      ['=COUNT(A1:C2)', '=A2/0', '=HYPERLINK("x")'],
    ]);

    test('evaluates the supported subset', () {
      expect(evaluateSheetFormula(sheet, sheet.cell(1, 0)), 7);
      expect(evaluateSheetFormula(sheet, sheet.cell(1, 1)), 2);
      expect(evaluateSheetFormula(sheet, sheet.cell(1, 2)), 2);
      expect(evaluateSheetFormula(sheet, sheet.cell(2, 0)), 6);
    });

    test('leaves what it cannot compute as the formula text', () {
      expect(displayCellValue(sheet, sheet.cell(2, 1)), '=A2/0');
      expect(displayCellValue(sheet, sheet.cell(2, 2)), '=HYPERLINK("x")');
    });

    test('a self-reference does not recurse forever', () {
      final loop = OfficeSheet('L', [
        ['=A1+1'],
      ]);
      expect(evaluateSheetFormula(loop, '=A1+1'), isNull);
    });
  });

  group('export', () {
    void expectWellFormed(Map<String, String> parts) {
      for (final entry in parts.entries) {
        expect(
          () => XmlDocument.parse(entry.value),
          returnsNormally,
          reason: entry.key,
        );
      }
    }

    void expectRelationshipsResolve(Map<String, String> parts) {
      for (final entry in parts.entries.where((e) => e.key.endsWith('.rels'))) {
        final base = entry.key.replaceFirst(RegExp(r'_rels/[^/]*\.rels$'), '');
        for (final rel in XmlDocument.parse(
          entry.value,
        ).findAllElements('Relationship')) {
          final segments = '$base${rel.getAttribute('Target')}'.split('/');
          final resolved = <String>[];
          for (final s in segments) {
            if (s == '..') {
              resolved.removeLast();
            } else if (s.isNotEmpty) {
              resolved.add(s);
            }
          }
          expect(
            parts.containsKey(resolved.join('/')),
            isTrue,
            reason: '${entry.key} → ${rel.getAttribute('Target')}',
          );
        }
      }
      final types = XmlDocument.parse(parts['[Content_Types].xml']!);
      for (final override in types.findAllElements('Override')) {
        expect(
          parts.containsKey(override.getAttribute('PartName')!.substring(1)),
          isTrue,
        );
      }
    }

    test('docx holds every part, well formed, with escaped text', () {
      final doc = OfficeDocument(OfficeKind.docx, title: 'R&D <2026>')
        ..edit(
          action: 'append',
          content:
              '# Titel & "quotes"\n\n1. een\n2. twee\n\nTekst\n\n1. opnieuw\n\n| a | b |\n|---|---|\n| <x> | 2 |',
        );
      final parts = _unzip(exportOfficeDocument(doc));
      expect(
        parts.keys,
        containsAll([
          '[Content_Types].xml',
          '_rels/.rels',
          'word/document.xml',
          'word/styles.xml',
          'word/numbering.xml',
          'docProps/core.xml',
        ]),
      );
      expectWellFormed(parts);
      expectRelationshipsResolve(parts);
      final body = parts['word/document.xml']!;
      expect(body, contains('Titel &amp; &quot;quotes&quot;'));
      expect(body, contains('w:numId w:val="2"'));
      expect(
        body,
        contains('w:numId w:val="3"'),
        reason: 'second list restarts',
      );
      expect(parts['word/numbering.xml'], contains('w:numId="3"'));
    });

    test('pptx has one slide part per slide plus master, layout and theme', () {
      final doc = OfficeDocument(OfficeKind.pptx)
        ..edit(
          action: 'append',
          content: '# Cover\n---\n# Twee\n- punt\n---\n# Drie\n- punt',
        );
      final parts = _unzip(exportOfficeDocument(doc));
      expectWellFormed(parts);
      expectRelationshipsResolve(parts);
      for (var i = 1; i <= 3; i++) {
        expect(parts.containsKey('ppt/slides/slide$i.xml'), isTrue);
      }
      expect(
        XmlDocument.parse(
          parts['ppt/presentation.xml']!,
        ).findAllElements('p:sldId').length,
        3,
      );
    });

    test(
      'xlsx writes numbers, inline text and formulas with cached values',
      () {
        final doc = OfficeDocument(OfficeKind.xlsx)
          ..writeCells(
            sheetName: 'Data',
            cell: 'A1',
            values: [
              ['Naam', 'Waarde'],
              ['x', '2.5'],
              ['y', '=B2*2'],
            ],
          );
        final parts = _unzip(exportOfficeDocument(doc));
        expectWellFormed(parts);
        expectRelationshipsResolve(parts);
        final sheet = parts['xl/worksheets/sheet1.xml']!;
        expect(sheet, contains('<c r="B2"><v>2.5</v></c>'));
        expect(sheet, contains('<f>B2*2</f><v>5</v>'));
        expect(sheet, contains('t="inlineStr"'));
        expect(
          sheet,
          contains('state="frozen"'),
          reason: 'header row stays put',
        );
        expect(parts['xl/workbook.xml'], contains('name="Data"'));
      },
    );

    test('an empty document still exports a valid file', () {
      for (final kind in OfficeKind.values) {
        final parts = _unzip(
          exportOfficeDocument(OfficeDocument(kind, title: 'Leeg')),
        );
        expectWellFormed(parts);
        expectRelationshipsResolve(parts);
      }
    });
  });

  test('documents survive their JSON sidecar', () {
    final doc = OfficeDocument(OfficeKind.pptx, title: 'T')
      ..edit(action: 'append', content: '# A\n## B\n- c\n  - d');
    final again = OfficeDocument.fromJson(jsonDecode(jsonEncode(doc.toJson())));
    expect(again.toJson(), doc.toJson());
  });

  test('cell names convert both ways', () {
    expect(cellName(0, 0), 'A1');
    expect(cellName(9, 27), 'AB10');
    expect(parseCellName('AB10'), (9, 27));
    expect(parseCellName('\$C\$3'), (2, 2));
    expect(parseCellName('A0'), isNull);
    expect(safeSheetName('Q1/Q2: [plan]'), 'Q1 Q2   plan');
  });
}
