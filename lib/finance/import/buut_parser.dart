import 'dart:io';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'import_models.dart';

/// Parses a BUUT bank-statement PDF into [ParsedBankEntry] rows.
class BuutParser {
  BuutParser._();

  static Future<List<ParsedBankEntry>> parseFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      return _parseText(text);
    } finally {
      document.dispose();
    }
  }

  static List<ParsedBankEntry> _parseText(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final entries = <ParsedBankEntry>[];
    final datePattern = RegExp(r'^(\d{2}-\d{2}-\d{4})');

    String? currentDateStr;
    final currentBlock = <String>[];

    void flushEntry() {
      if (currentDateStr != null && currentBlock.isNotEmpty) {
        final entry = _parseTransactionBlock(currentDateStr, currentBlock.join('\n'));
        if (entry != null) entries.add(entry);
      }
    }

    for (final line in lines) {
      final dateMatch = datePattern.firstMatch(line);
      if (dateMatch != null) {
        flushEntry();
        currentDateStr = dateMatch.group(1);
        final remainder = line.substring(dateMatch.end).trim();
        currentBlock.clear();
        if (remainder.isNotEmpty) currentBlock.add(remainder);
      } else {
        currentBlock.add(line);
      }
    }
    flushEntry();

    // Deduplicate and sort newest first.
    final seen = <String>{};
    final deduped = <ParsedBankEntry>[];
    for (final e in entries) {
      final key =
          '${e.date.millisecondsSinceEpoch}_${e.description}_${e.amountCents}_${e.isIncome}';
      if (seen.add(key)) deduped.add(e);
    }
    deduped.sort((a, b) => b.date.compareTo(a.date));
    return deduped;
  }

  static ParsedBankEntry? _parseTransactionBlock(String dateStr, String block) {
    final date = _parseDate(dateStr);
    if (date == null) return null;

    final amountResult = _extractAmount(block);
    if (amountResult == null) return null;
    final (amountCents, isIncome) = amountResult;

    // Strip the amount and long numeric IDs from the description for cleanliness.
    var description = block
        .replaceAll(RegExp(r'€\s*[0-9.,]+'), '')
        .replaceAll(RegExp(r'\b\d{15,}\b'), '')
        .replaceAll(RegExp(r'\b\d{9,}\s+\d{9,}\b'), '')
        .replaceAll(RegExp(r'Terminal:\s*\S+'), '')
        .replaceAll(RegExp(r'Card PAN:\s*[*\s]+\d{4}'), '')
        .trim();

    // Collapse multiple blank lines.
    description = description.replaceAll(RegExp(r'\n+'), '\n').trim();

    if (description.isEmpty) return null;

    final (iban, bic) = _extractIbanBic(block);
    final merchantName = _extractMerchantName(block);
    final categorySuggestion = _guessCategory(block);

    return ParsedBankEntry(
      date: date,
      description: description,
      iban: iban,
      bic: bic,
      merchantName: merchantName,
      isIncome: isIncome,
      amountCents: amountCents,
      categorySuggestion: categorySuggestion,
    );
  }

  static DateTime? _parseDate(String raw) {
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  static (int amountCents, bool isIncome)? _extractAmount(String text) {
    int? parseAmountString(String s) {
      s = s.replaceAll('€', '').replaceAll(' ', '').trim();
      if (s.isEmpty) return null;

      final commaIdx = s.lastIndexOf(',');
      final dotIdx = s.lastIndexOf('.');

      if (commaIdx != -1 && dotIdx != -1) {
        if (commaIdx > dotIdx) {
          s = s.replaceAll('.', '').replaceAll(',', '.');
        } else {
          s = s.replaceAll(',', '');
        }
      } else if (commaIdx != -1) {
        if (commaIdx == s.length - 3) {
          s = s.replaceAll(',', '.');
        } else {
          s = s.replaceAll(',', '');
        }
      } else if (dotIdx != -1) {
        if (dotIdx == s.length - 3) {
          // keep decimal dot
        } else {
          s = s.replaceAll('.', '');
        }
      }

      final value = double.tryParse(s);
      if (value == null) return null;
      return (value * 100).round();
    }

    // Primary: look for €-prefixed amounts.
    final euroMatches = RegExp(r'€\s*([0-9.,]+)').allMatches(text);
    for (final match in euroMatches) {
      final amount = parseAmountString(match.group(1)!);
      if (amount != null && amount > 0 && amount < 10000000) {
        return (amount, _isIncome(text));
      }
    }

    // Fallback: any number with exactly 2 decimal places.
    final fallbackMatches =
        RegExp(r'([0-9]{1,3}(?:[.,][0-9]{3})*[.,][0-9]{2})').allMatches(text);
    for (final match in fallbackMatches) {
      final amount = parseAmountString(match.group(1)!);
      if (amount != null && amount > 0 && amount < 10000000) {
        return (amount, _isIncome(text));
      }
    }

    return null;
  }

  static bool _isIncome(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('sepa in') || lower.contains('bij')) return true;
    if (lower.contains('sepa out') || lower.contains('af')) return false;
    if (lower.contains('card purchase') || lower.contains('sepa ideal')) {
      return false;
    }
    return false;
  }

  static (String? iban, String? bic) _extractIbanBic(String description) {
    String? iban;
    String? bic;

    final ibanMatch = RegExp(
            r'IBAN[:\s]+([A-Z]{2}\d{2}[A-Z0-9]{4}\d{7}(?:[A-Z0-9]?){0,16})')
        .firstMatch(description);
    if (ibanMatch != null) iban = ibanMatch.group(1);

    final bicMatch = RegExp(
            r'BIC[:\s]+([A-Z]{6}[A-Z0-9]{2}(?:[A-Z0-9]{3})?)')
        .firstMatch(description);
    if (bicMatch != null) bic = bicMatch.group(1);

    return (iban, bic);
  }

  static String? _extractMerchantName(String description) {
    final cardMatch =
        RegExp(r'Card Purchase\s+-\s+(.+?)(?:\n|$)').firstMatch(description);
    if (cardMatch != null) return cardMatch.group(1)?.trim();

    final idealMatch =
        RegExp(r'SEPA iDEAL\s+-\s+(.+?)(?:\n|$)').firstMatch(description);
    if (idealMatch != null) return idealMatch.group(1)?.trim();

    final sepaMatch =
        RegExp(r'SEPA (?:In|Out)\s+-\s+(.+?)(?:\n|$)').firstMatch(description);
    if (sepaMatch != null) {
      final name = sepaMatch.group(1)?.trim();
      if (name != null && name.length > 1 && !name.startsWith('S.')) {
        return name;
      }
    }

    return null;
  }

  static String? _guessCategory(String description) {
    final lower = description.toLowerCase();
    if (lower.contains('jumbo') ||
        lower.contains('supermarkt') ||
        lower.contains('hoogvliet')) {
      return 'Groceries';
    }
    if (lower.contains('tikkie')) return 'Transfers';
    if (lower.contains('steam') ||
        lower.contains('valve') ||
        lower.contains('game')) {
      return 'Entertainment';
    }
    if (lower.contains('cinema') || lower.contains('movie')) {
      return 'Entertainment';
    }
    if (lower.contains('mcdonald') || lower.contains('restaurant')) {
      return 'Food & Drink';
    }
    if (lower.contains('spotify') || lower.contains('netflix')) {
      return 'Subscriptions';
    }
    return null;
  }
}
