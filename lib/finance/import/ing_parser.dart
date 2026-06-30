import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'import_models.dart';

/// Parses an ING transaction export into [ParsedBankEntry] rows.
///
/// ING lets you download your transactions as either an Excel (`.xlsx`) or a
/// CSV file from "Mijn ING". Both share the same column layout:
///
///   Datum | Naam / Omschrijving | Rekening | Tegenrekening | Code |
///   Af Bij | Bedrag (EUR) | Mutatiesoort | Mededelingen | Saldo na mutatie | Tag
///
/// We map columns by their header text (not position) so the parser keeps
/// working if ING reorders or adds columns.
class IngParser {
  IngParser._();

  static Future<List<ParsedBankEntry>> parseFile(String path) async {
    final lower = path.toLowerCase();
    final List<List<String>> rows;
    if (lower.endsWith('.csv')) {
      rows = _readCsv(await File(path).readAsString(encoding: utf8));
    } else {
      rows = _readXlsx(await File(path).readAsBytes());
    }
    return _rowsToEntries(rows);
  }

  // ---- Row extraction --------------------------------------------------------

  /// Turns a header + data rows table into entries.
  static List<ParsedBankEntry> _rowsToEntries(List<List<String>> rows) {
    if (rows.isEmpty) return [];

    // Locate the header row (the first row containing "Datum").
    int headerIdx = -1;
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].any((c) => c.trim().toLowerCase() == 'datum')) {
        headerIdx = i;
        break;
      }
    }
    if (headerIdx == -1) return [];

    final header = rows[headerIdx].map((c) => c.trim().toLowerCase()).toList();
    int col(String name) => header.indexOf(name.toLowerCase());

    final iDate = col('Datum');
    final iName = col('Naam / Omschrijving');
    final iCounter = col('Tegenrekening');
    final iAfBij = col('Af Bij');
    final iAmount = col('Bedrag (EUR)');
    final iType = col('Mutatiesoort');
    final iMemo = col('Mededelingen');

    if (iDate == -1 || iAfBij == -1 || iAmount == -1) return [];

    String cell(List<String> row, int idx) =>
        (idx >= 0 && idx < row.length) ? row[idx].trim() : '';

    final entries = <ParsedBankEntry>[];
    for (var i = headerIdx + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((c) => c.trim().isEmpty)) continue;

      final date = _parseDate(cell(row, iDate));
      if (date == null) continue;

      final amountCents = _parseAmount(cell(row, iAmount));
      if (amountCents == null || amountCents <= 0) continue;

      final isIncome = cell(row, iAfBij).toLowerCase().startsWith('bij');
      final name = cell(row, iName);
      final memo = cell(row, iMemo);
      final type = cell(row, iType);
      final iban = _cleanIban(cell(row, iCounter));

      // Description: prefer the memo (it carries the real detail), fall back to
      // the name or the transaction type.
      final descParts = <String>[
        if (name.isNotEmpty && name != '{naam/omschrijving}') name,
        if (memo.isNotEmpty) memo,
      ];
      var description = descParts.join(' — ');
      if (description.isEmpty) description = type.isNotEmpty ? type : 'ING transaction';

      // Merchant: the counterparty name, taken from the "Naam:" field in the
      // memo when present, otherwise the name column.
      final merchantName = _extractMerchantName(memo) ??
          (name.isNotEmpty && name != '{naam/omschrijving}' ? name : null);

      entries.add(ParsedBankEntry(
        date: date,
        description: description,
        iban: iban,
        merchantName: merchantName,
        isIncome: isIncome,
        amountCents: amountCents,
        categorySuggestion: _guessCategory('$name $memo $type'),
      ));
    }

    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  // ---- XLSX reading ----------------------------------------------------------

  /// Minimal `.xlsx` reader: an xlsx is a zip of XML parts. We read the shared
  /// strings table and the first worksheet that looks like the statement.
  static List<List<String>> _readXlsx(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? find(String name) {
      for (final f in archive.files) {
        if (f.name == name) return f;
      }
      return null;
    }

    String content(ArchiveFile f) => utf8.decode(f.content as List<int>);

    // Shared strings.
    final sharedStrings = <String>[];
    final sst = find('xl/sharedStrings.xml');
    if (sst != null) {
      final doc = XmlDocument.parse(content(sst));
      for (final si in doc.findAllElements('si')) {
        // A string item may be split across multiple <t> runs.
        final buf = StringBuffer();
        for (final t in si.findAllElements('t')) {
          buf.write(t.innerText);
        }
        sharedStrings.add(buf.toString());
      }
    }

    // Gather all worksheet parts and pick the one containing the header.
    final sheetFiles = archive.files
        .where((f) =>
            f.name.startsWith('xl/worksheets/') && f.name.endsWith('.xml'))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    List<List<String>> best = [];
    for (final f in sheetFiles) {
      final rows = _parseWorksheet(content(f), sharedStrings);
      final hasHeader =
          rows.any((r) => r.any((c) => c.trim().toLowerCase() == 'datum'));
      if (hasHeader) return rows;
      if (rows.length > best.length) best = rows;
    }
    return best;
  }

  static List<List<String>> _parseWorksheet(
      String xml, List<String> sharedStrings) {
    final doc = XmlDocument.parse(xml);
    final rows = <List<String>>[];

    for (final rowEl in doc.findAllElements('row')) {
      final cells = <String>[];
      for (final c in rowEl.findElements('c')) {
        final ref = c.getAttribute('r'); // e.g. "C5"
        final colIdx = ref == null ? cells.length : _colIndex(ref);

        // Pad sparse cells so column alignment is preserved.
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
      rows.add(cells);
    }
    return rows;
  }

  /// Converts a cell reference like "AB12" to a zero-based column index.
  static int _colIndex(String ref) {
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

  // ---- CSV reading -----------------------------------------------------------

  /// Parses ING's CSV (`;`-separated, `"`-quoted) into rows.
  static List<List<String>> _readCsv(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;

    void endField() {
      row.add(field.toString());
      field.clear();
    }

    void endRow() {
      endField();
      rows.add(row);
      row = <String>[];
    }

    final chars = text.split('');
    for (var i = 0; i < chars.length; i++) {
      final ch = chars[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < chars.length && chars[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else {
        switch (ch) {
          case '"':
            inQuotes = true;
            break;
          case ';':
          case ',':
            // ING uses ';'; tolerate ',' too as long as it's a separator.
            endField();
            break;
          case '\r':
            break;
          case '\n':
            endRow();
            break;
          default:
            field.write(ch);
        }
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) endRow();
    return rows;
  }

  // ---- Field parsing ---------------------------------------------------------

  /// ING dates are `YYYYMMDD` (e.g. 20260531), sometimes formatted as a number.
  static DateTime? _parseDate(String raw) {
    final s = raw.trim().replaceAll('-', '').replaceAll('/', '');
    if (s.length == 8) {
      final year = int.tryParse(s.substring(0, 4));
      final month = int.tryParse(s.substring(4, 6));
      final day = int.tryParse(s.substring(6, 8));
      if (year != null && month != null && day != null) {
        try {
          return DateTime(year, month, day);
        } catch (_) {}
      }
    }
    return null;
  }

  /// Parses an amount that may be Dutch-formatted ("1.234,56") or already a
  /// plain number ("1234.56" / "1.01"). Always positive — direction comes from
  /// the "Af Bij" column.
  static int? _parseAmount(String raw) {
    var s = raw.replaceAll('€', '').replaceAll(' ', '').trim();
    if (s.isEmpty) return null;
    s = s.replaceAll('+', '').replaceAll('-', '');

    final commaIdx = s.lastIndexOf(',');
    final dotIdx = s.lastIndexOf('.');
    if (commaIdx != -1 && dotIdx != -1) {
      if (commaIdx > dotIdx) {
        // 1.234,56 -> dot = thousands, comma = decimal.
        s = s.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // 1,234.56 -> comma = thousands.
        s = s.replaceAll(',', '');
      }
    } else if (commaIdx != -1) {
      // Only a comma: it's the decimal separator (Dutch).
      s = s.replaceAll(',', '.');
    }

    final value = double.tryParse(s);
    if (value == null) return null;
    return (value * 100).round();
  }

  static String? _cleanIban(String raw) {
    final s = raw.replaceAll(' ', '').trim();
    return s.isEmpty ? null : s;
  }

  /// ING memos start with `Naam: <counterparty> Omschrijving: ...`.
  static String? _extractMerchantName(String memo) {
    final match = RegExp(r'Naam:\s*(.+?)(?:\s+(?:Omschrijving|IBAN|Kenmerk):|$)')
        .firstMatch(memo);
    final name = match?.group(1)?.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }

  static String? _guessCategory(String text) {
    final lower = text.toLowerCase();

    bool has(List<String> keys) => keys.any(lower.contains);

    if (has([
      'albert heijn',
      'jumbo',
      'lidl',
      'aldi',
      'plus ',
      'picnic',
      'dirk',
      'hoogvliet',
      'supermarkt',
    ])) {
      return 'Groceries';
    }
    if (has(['mcdonald', 'kfc', 'domino', 'starbucks', 'thuisbezorgd', 'uber eats', 'restaurant', 'cafe', 'café'])) {
      return 'Eating out';
    }
    if (has(['eneco', 'vattenfall', 'essent', 'greenchoice', 'oasen', 'water', 'energie', 'berkman'])) {
      return 'Utilities';
    }
    if (has(['kpn', 'youfone', 'vodafone', 'odido', 't-mobile', 'ziggo', 'spotify', 'netflix', 'disney'])) {
      return 'Subscriptions';
    }
    if (has(['vgz', 'zilveren kruis', 'cz ', 'menzis', 'zorgverzekeraar', 'apotheek', 'podotherapie', 'hans anders', 'tandarts', 'huisarts'])) {
      return 'Health & care';
    }
    if (has(['woonpartners', 'huur', 'hypotheek', 'vve ', 'woningcorporatie'])) {
      return 'Housing';
    }
    if (has(['ns ', 'ns-', 'ov-chipkaart', 'ovpay', 'shell', 'bp ', 'esso', 'tango', 'tankstation', 'q-park', 'parking'])) {
      return 'Transport';
    }
    if (has(['action', 'hema', 'bol.com', 'coolblue', 'mediamarkt', 'ikea'])) {
      return 'Shopping';
    }
    if (has(['steam', 'valve', 'playstation', 'xbox', 'nintendo', 'pathe', 'pathé', 'cinema', 'bioscoop'])) {
      return 'Entertainment';
    }
    if (has(['h&m', 'zara', 'nike', 'zalando', 'primark', 'uniqlo', 'kleding'])) {
      return 'Clothing';
    }
    return null;
  }
}
