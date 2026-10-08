import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../../l10n/current_l.dart';
import 'bingo_card.dart';

class BingoCardExport {
  const BingoCardExport._();

  /// Writes up to four cards per PDF page in a two-by-two grid.
  static Future<String?> save(int count) async {
    final cards = BingoCard.generateMany(count, Random.secure());
    final document = PdfDocument();
    document.pageSettings
      ..size = PdfPageSize.a4
      ..margins.all = 20;
    try {
      const gap = 18.0;
      for (var start = 0; start < cards.length; start += 4) {
        final page = document.pages.add();
        final bounds = page.getClientSize();
        final cellWidth = (bounds.width - gap) / 2;
        final cellHeight = (bounds.height - gap) / 2;
        for (var slot = 0; slot < 4 && start + slot < cards.length; slot++) {
          final cardIndex = start + slot;
          final image = PdfBitmap(
            await render(cards[cardIndex], cardIndex + 1),
          );
          final scale = min(cellWidth / image.width, cellHeight / image.height);
          final width = image.width * scale;
          final height = image.height * scale;
          final column = slot % 2;
          final row = slot ~/ 2;
          final cellLeft = column * (cellWidth + gap);
          final cellTop = row * (cellHeight + gap);
          page.graphics.drawImage(
            image,
            Rect.fromLTWH(
              cellLeft + (cellWidth - width) / 2,
              cellTop + (cellHeight - height) / 2,
              width,
              height,
            ),
          );
        }
      }
      final bytes = Uint8List.fromList(await document.save());
      final path = await FilePicker.saveFile(
        dialogTitle: currentL.bingoExportSaveTitle,
        fileName: 'bingo-cards-$count.pdf',
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: Platform.isAndroid || Platform.isIOS ? bytes : null,
      );
      if (path == null) return null;
      if (Platform.isAndroid || Platform.isIOS) return path;
      final output = path.toLowerCase().endsWith('.pdf') ? path : '$path.pdf';
      await File(output).writeAsBytes(bytes, flush: true);
      return output;
    } finally {
      document.dispose();
    }
  }

  static Future<Uint8List> render(BingoCard card, int number) async {
    const width = 900.0;
    const height = 1060.0;
    final t = currentL;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    final ink = const Color(0xFF202636);
    final teal = const Color(0xFF1B8F95);

    _text(
      canvas,
      'BINGO',
      450,
      85,
      72,
      Colors.white,
      weight: FontWeight.w900,
      background: teal,
      box: const Rect.fromLTWH(60, 32, 780, 112),
    );
    _text(
      canvas,
      t.bingoExportCardNumber(number.toString().padLeft(3, '0')),
      450,
      195,
      28,
      ink,
      weight: FontWeight.w700,
    );
    _text(
      canvas,
      t.bingoExportInstructions,
      450,
      241,
      23,
      const Color(0xFF647083),
    );

    const left = 60.0;
    const top = 294.0;
    const cell = 156.0;
    const letters = 'BINGO';
    for (var column = 0; column < 5; column++) {
      final x = left + column * cell;
      canvas.drawRect(Rect.fromLTWH(x, top, cell, 90), Paint()..color = teal);
      _text(
        canvas,
        letters[column],
        x + cell / 2,
        top + 45,
        57,
        Colors.white,
        weight: FontWeight.w900,
      );
      for (var row = 0; row < 5; row++) {
        final y = top + 90 + row * 112;
        final isFree = column == 2 && row == 2;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cell, 112),
          Paint()
            ..color = isFree
                ? const Color(0xFFDBF2F0)
                : (row.isEven ? Colors.white : const Color(0xFFF4F7F8)),
        );
        _text(
          canvas,
          isFree ? t.bingoExportFree : '${card.columns[column][row]}',
          x + cell / 2,
          y + 56,
          isFree ? 27 : 48,
          ink,
          weight: FontWeight.w800,
        );
      }
    }
    final grid = Paint()
      ..color = const Color(0xFFB6CCD0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var column = 0; column <= 5; column++) {
      final x = left + column * cell;
      canvas.drawLine(Offset(x, top), Offset(x, top + 650), grid);
    }
    for (var row = 0; row <= 5; row++) {
      final y = top + 90 + row * 112;
      canvas.drawLine(Offset(left, y), Offset(left + 780, y), grid);
    }
    _text(
      canvas,
      t.bingoExportFooter,
      450,
      1002,
      20,
      const Color(0xFF647083),
      weight: FontWeight.w600,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    picture.dispose();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError(t.bingoExportEncodeFailed);
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  static void _text(
    Canvas canvas,
    String value,
    double x,
    double y,
    double size,
    Color color, {
    FontWeight weight = FontWeight.normal,
    Color? background,
    Rect? box,
  }) {
    if (background != null && box != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(18)),
        Paint()..color = background,
      );
    }
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(color: color, fontSize: size, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(x - painter.width / 2, y - painter.height / 2),
    );
    painter.dispose();
  }
}
