import 'dart:typed_data';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'quiz_export.dart';
import 'quiz_bank.dart';

Future<Uint8List> renderQuizPdf(QuizExport export) async {
  final writer = _QuizPdfWriter(export);
  try {
    writer.build();
    return Uint8List.fromList(await writer.document.save());
  } finally {
    writer.document.dispose();
  }
}

class _QuizPdfWriter {
  _QuizPdfWriter(this.export) {
    document.pageSettings.size = PdfPageSize.a4;
    document.pageSettings.margins.all = 44;
  }
  final QuizExport export;
  final document = PdfDocument();
  final font = PdfStandardFont(PdfFontFamily.helvetica, 11);
  final bold = PdfStandardFont(
    PdfFontFamily.helvetica,
    11,
    style: PdfFontStyle.bold,
  );
  final heading = PdfStandardFont(
    PdfFontFamily.helvetica,
    18,
    style: PdfFontStyle.bold,
  );
  final small = PdfStandardFont(PdfFontFamily.helvetica, 9);
  late PdfPage page;
  double y = 0;
  double get width => page.getClientSize().width;
  double get bottom => page.getClientSize().height - 30;
  String section = 'Opgaven';

  String clean(String value) => value
      .replaceAll('−', '-')
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('→', '->')
      .replaceAll('…', '...')
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll('≠', '!=')
      .replaceAll('≤', '<=')
      .replaceAll('≥', '>=');

  void newPage() {
    page = document.pages.add();
    page.graphics.drawString(
      'LUMA SCHOOL  |  $section',
      small,
      bounds: Rect.fromLTWH(0, 0, width, 15),
    );
    page.graphics.drawLine(
      PdfPen(PdfColor(180, 180, 180)),
      const Offset(0, 21),
      Offset(width, 21),
    );
    y = 35;
  }

  void ensure(double height) {
    if (y + height > bottom) newPage();
  }

  List<String> lines(String value, PdfFont face, double available) {
    final result = <String>[];
    for (final paragraph in clean(value).split('\n')) {
      var line = '';
      final words = <String>[];
      for (final word in paragraph.split(' ')) {
        var piece = '';
        for (final rune in word.runes) {
          final char = String.fromCharCode(rune);
          if (piece.isNotEmpty &&
              face.measureString('$piece$char').width > available) {
            words.add(piece);
            piece = '';
          }
          piece += char;
        }
        words.add(piece);
      }
      for (final word in words) {
        final next = line.isEmpty ? word : '$line $word';
        if (face.measureString(next).width > available && line.isNotEmpty) {
          result.add(line);
          line = word;
        } else {
          line = next;
        }
      }
      result.add(line);
    }
    return result;
  }

  void text(
    String value, {
    PdfFont? face,
    double indent = 0,
    double after = 6,
  }) {
    final f = face ?? font;
    final height = f.size + 5;
    for (final line in lines(value, f, width - indent)) {
      ensure(height);
      page.graphics.drawString(
        line,
        f,
        bounds: Rect.fromLTWH(indent, y, width - indent, height),
      );
      y += height;
    }
    y += after;
  }

  double textHeight(String value, {PdfFont? face, double indent = 0}) {
    final f = face ?? font;
    return lines(value, f, width - indent).length * (f.size + 5) + 6;
  }

  void table(QuizTable table) {
    final cellWidth = width / table.headers.length;
    for (final row in [table.headers, ...table.rows]) {
      final isHeader = identical(row, table.headers);
      final f = isHeader ? bold : font;
      final height = row
          .map((c) => lines(c, f, cellWidth - 12).length * 16 + 12)
          .reduce((a, b) => a > b ? a : b)
          .toDouble();
      ensure(height);
      for (var i = 0; i < row.length; i++) {
        page.graphics.drawRectangle(
          pen: PdfPen(PdfColor(160, 160, 160)),
          bounds: Rect.fromLTWH(i * cellWidth, y, cellWidth, height),
        );
        page.graphics.drawString(
          clean(row[i]),
          f,
          bounds: Rect.fromLTWH(
            i * cellWidth + 6,
            y + 6,
            cellWidth - 12,
            height - 8,
          ),
        );
      }
      y += height;
    }
    y += 10;
  }

  void bars(QuizBars chart) {
    ensure(35 + chart.values.length * 26);
    text('${chart.title} (${chart.unit})', face: bold);
    final max = chart.values.reduce((a, b) => a > b ? a : b);
    for (var i = 0; i < chart.values.length; i++) {
      page.graphics.drawString(
        clean(chart.labels[i]),
        small,
        bounds: Rect.fromLTWH(0, y, 85, 20),
      );
      final length = (width - 125) * chart.values[i] / max;
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(95, 105, 120)),
        bounds: Rect.fromLTWH(90, y, length, 15),
      );
      page.graphics.drawString(
        '${chart.values[i]}',
        small,
        bounds: Rect.fromLTWH(95 + length, y, 35, 20),
      );
      y += 26;
    }
    y += 8;
  }

  void question(QuizQuestion q, int number, String subject, int? passage) {
    final label =
        'Vraag $number - $subject${passage == null ? '' : ' - Tekst $passage'}';
    var height = textHeight(label, face: bold) + textHeight(q.prompt) + 16;
    for (final option in q.options) {
      height += textHeight(option, indent: 24);
    }
    if (q.isOpen) height += export.writingSpace ? 60 : 32;
    if (q.table != null) height += (q.table!.rows.length + 1) * 40 + 10;
    if (q.bars != null) height += 45 + q.bars!.values.length * 26;
    ensure(height.clamp(0, bottom - 35));
    text(label, face: bold);
    text(q.prompt);
    if (q.table != null) table(q.table!);
    if (q.bars != null) bars(q.bars!);
    if (q.isOpen) {
      ensure(export.writingSpace ? 60 : 32);
      text(
        'Antwoord: .....................................${q.unit == null ? '' : ' ${q.unit}'}',
      );
      if (export.writingSpace) {
        page.graphics.drawLine(
          PdfPen(PdfColor(190, 190, 190)),
          Offset(0, y + 20),
          Offset(width, y + 20),
        );
        y += 32;
      }
    } else {
      for (var i = 0; i < q.options.length; i++) {
        ensure(textHeight(q.options[i], indent: 24));
        page.graphics.drawRectangle(
          pen: PdfPen(PdfColor(70, 70, 70)),
          bounds: Rect.fromLTWH(1, y + 3, 9, 9),
        );
        text(
          '${String.fromCharCode(65 + i)}. ${q.options[i]}${q.unit == null ? '' : ' ${q.unit}'}',
          indent: 18,
        );
      }
    }
    y += 14;
  }

  void build() {
    newPage();
    text(export.title, face: heading);
    text(
      '${export.count} vragen | ${export.mixed ? 'Vakken gemengd' : 'Per vak'}',
    );
    text(
      'Naam: ........................................  Datum: ........................',
    );
    text(
      'Lees elke opdracht goed. Kruis het antwoord aan of vul het gevraagde antwoord in. Bij meerdere antwoorden staat in de opdracht hoeveel je er kiest.',
    );
    text(
      'Eigen oefenmateriaal. Geen officiële IEP-toets of schooladvies.',
      face: small,
      after: 16,
    );
    var number = 0;
    var passageNumber = 0;
    String? subject;
    for (final block in export.blocks) {
      if (!export.mixed && subject != block.subject.id) {
        if (subject != null) newPage();
        ensure(60);
        text(block.subject.name, face: heading);
        subject = block.subject.id;
      }
      final passage = block.questions.first.passage;
      if (passage != null) {
        passageNumber++;
        ensure(110);
        text('Tekst $passageNumber', face: bold);
        text(passage, after: 16);
      }
      for (final q in block.questions) {
        question(
          q,
          ++number,
          block.subject.name,
          passage == null ? null : passageNumber,
        );
      }
    }
    if (export.answers) {
      section = 'Antwoordblad';
      newPage();
      text('Antwoorden', face: heading);
      text('Voor het nakijken. Houd dit antwoordblad apart van de opgaven.');
      number = 0;
      for (final block in export.blocks) {
        for (final q in block.questions) {
          final letter = q.isOpen
              ? ''
              : q.input == QuizInput.multiple
              ? '${q.correctIndices.map((i) => String.fromCharCode(65 + i)).join(' + ')}. '
              : '${String.fromCharCode(65 + q.answerIndex)}. ';
          final answer =
              '${++number}. $letter${q.answer}${q.unit == null ? '' : ' ${q.unit}'}';
          ensure(
            textHeight(answer, face: bold) +
                (export.explanations ? textHeight(q.explanation ?? '') : 0),
          );
          text(answer, face: bold);
          if (export.explanations && q.explanation != null) {
            text(q.explanation!);
          }
          y += 8;
        }
      }
    }
    for (var i = 0; i < document.pages.count; i++) {
      final p = document.pages[i];
      p.graphics.drawString(
        'Pagina ${i + 1} van ${document.pages.count}',
        small,
        bounds: Rect.fromLTWH(0, p.getClientSize().height - 15, width, 15),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
    }
  }
}
