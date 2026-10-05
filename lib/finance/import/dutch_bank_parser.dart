import 'dart:io';

import 'import_models.dart';
import 'statement_text.dart';

/// Local file exports from ABN AMRO, Rabobank, bunq, SNS and Knab.
class DutchBankParser {
  DutchBankParser._();

  static Future<List<ParsedBankEntry>> parseFile(
    String bankId,
    String path,
  ) async {
    return parseText(
      bankId,
      StatementText.decode(await File(path).readAsBytes()),
    );
  }

  static List<ParsedBankEntry> parseText(String bankId, String text) {
    if (bankId == 'abn_amro') return _abn(text);
    final format = switch (bankId) {
      'rabobank' => const _CsvFormat(
        dates: ['Datum', 'Date'],
        amounts: ['Bedrag', 'Amount'],
        accounts: ['IBAN/BBAN'],
        currencies: ['Munt', 'Currency'],
        names: ['Naam tegenpartij', 'Name counterparty'],
        counterparties: [
          'Tegenrekening IBAN/BBAN',
          'Tegenrekening IBAN',
          'Counterparty IBAN/BBAN',
        ],
        bics: ['BIC tegenpartij', 'BIC counterparty'],
        descriptions: [
          'Omschrijving-1',
          'Omschrijving-2',
          'Omschrijving-3',
          'Omschrijving',
          'Description-1',
          'Description-2',
          'Description-3',
        ],
      ),
      'bunq' => const _CsvFormat(
        dates: ['Date', 'Datum'],
        amounts: ['Amount', 'Bedrag'],
        accounts: ['Account', 'Rekening'],
        currencies: ['Currency', 'Valuta'],
        names: ['Name', 'Naam'],
        counterparties: ['Counterparty', 'Tegenrekening'],
        descriptions: ['Description', 'Omschrijving'],
      ),
      'sns' => const _CsvFormat(
        dates: ['Datum'],
        amounts: ['Bedrag bij/af'],
        accounts: ['Je rekening'],
        currencies: ['Valuta boeking'],
        names: ['Naam'],
        counterparties: ['Van / naar'],
        descriptions: ['Omschrijving', 'Betalingskenmerk'],
        categories: ['Categorie'],
      ),
      'knab' => const _CsvFormat(
        dates: ['Transactiedatum'],
        amounts: ['Bedrag'],
        accounts: ['Rekeningnummer'],
        currencies: ['Valutacode'],
        directions: ['CreditDebet'],
        names: ['Tegenrekeninghouder'],
        counterparties: ['Tegenrekeningnummer'],
        descriptions: ['Omschrijving'],
      ),
      _ => throw UnsupportedError('Unsupported bank: $bankId.'),
    };
    final rows = StatementText.rows(text);
    if (rows.every((r) => r.every((c) => c.trim().isEmpty))) return [];
    var headerIndex = rows.indexWhere(format.matches);
    if (headerIndex < 0 && bankId == 'sns') {
      // SNS also exports the documented 17-column layout without a header.
      final first = rows.firstWhere((r) => r.any((c) => c.trim().isNotEmpty));
      if (first.length == 17 && StatementText.date(first[0]) != null) {
        rows.insert(0, [
          'Datum',
          'Je rekening',
          'Van / naar',
          'Naam',
          'Valuta saldo',
          'Saldo voor boeking',
          'Valuta boeking',
          'Bedrag bij/af',
          'Verwerkingsdatum',
          'Valutadatum',
          'Code',
          'Type',
          'Volgnummer',
          'Betalingskenmerk',
          'Omschrijving',
          'Afschriftnummer',
          'Categorie',
        ]);
        headerIndex = 0;
      }
    }
    if (headerIndex < 0) {
      throw const FormatException(
        'Unrecognized statement columns. Select the bank’s transaction export in the listed format.',
      );
    }
    final header = rows[headerIndex].map(_normalize).toList();
    int column(List<String> names) {
      for (final name in names) {
        final index = header.indexOf(_normalize(name));
        if (index >= 0) return index;
      }
      return -1;
    }

    final dateColumn = column(format.dates);
    final amountColumn = column(format.amounts);
    final currencyColumn = column(format.currencies);
    final directionColumn = column(format.directions);
    if ((bankId != 'bunq' && currencyColumn < 0) ||
        (format.directions.isNotEmpty && directionColumn < 0)) {
      throw const FormatException('Missing currency or debit/credit column.');
    }
    final entries = <ParsedBankEntry>[];
    for (var i = headerIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((c) => c.trim().isEmpty)) continue;
      String cell(int index) =>
          index >= 0 && index < row.length ? row[index].trim() : '';
      try {
        if (row.length != header.length) {
          throw const FormatException(
            'Column count does not match the header.',
          );
        }
        final currency = cell(currencyColumn);
        if (currencyColumn >= 0) _requireEuro(currency);
        final date = StatementText.date(cell(dateColumn));
        final amount = StatementText.cents(cell(amountColumn));
        if (date == null) {
          throw const FormatException('Invalid transaction date.');
        }
        if (amount == null) {
          throw const FormatException('Invalid transaction amount.');
        }
        var income = amount > 0;
        if (directionColumn >= 0) {
          income = switch (cell(directionColumn).toLowerCase()) {
            'c' || 'credit' || 'bij' => true,
            'd' || 'debet' || 'debit' || 'af' => false,
            _ => throw const FormatException('Unknown debit/credit value.'),
          };
          if (amount < 0 && income) {
            throw const FormatException(
              'Amount conflicts with debit/credit value.',
            );
          }
        }
        if (amount == 0) continue;
        final name = cell(column(format.names));
        final parts = [
          if (name.isNotEmpty) name,
          for (final name in format.descriptions)
            if (cell(column([name])).isNotEmpty) cell(column([name])),
        ];
        entries.add(
          ParsedBankEntry(
            date: date,
            description: parts.isEmpty ? 'Bank transaction' : parts.join(' — '),
            merchantName: _optional(name),
            iban: _optional(
              cell(column(format.counterparties)).replaceAll(' ', ''),
            ),
            bic: _optional(cell(column(format.bics))),
            isIncome: income,
            amountCents: amount.abs(),
            categorySuggestion: _optional(cell(column(format.categories))),
          ),
        );
      } on FormatException catch (e) {
        throw FormatException('Row ${i + 1}: ${e.message}');
      }
    }
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  static List<ParsedBankEntry> _abn(String text) {
    final rows = StatementText.rows(text, delimiter: '\t');
    final entries = <ParsedBankEntry>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((c) => c.trim().isEmpty)) continue;
      try {
        if (row.length != 8) {
          throw const FormatException(
            'Expected the 8-column ABN AMRO TXT/TAB export.',
          );
        }
        _requireEuro(row[1].trim());
        final date = StatementText.date(row[2]);
        final amount = StatementText.cents(row[6]);
        if (date == null) {
          throw const FormatException('Invalid transaction date.');
        }
        if (amount == null) {
          throw const FormatException('Invalid transaction amount.');
        }
        if (amount == 0) continue;
        final description = row[7].trim();
        String? tagged(String tag, String label) {
          final slash = RegExp(
            '/$tag/(.*?)(?=/[A-Z]+/|\$)',
          ).firstMatch(description);
          final labelled = RegExp(
            '$label:\\s*(.*?)(?=\\s*(?:IBAN|BIC|Naam|Omschrijving|Kenmerk|Machtiging|Voor):|\$)',
          ).firstMatch(description);
          return _optional((slash ?? labelled)?.group(1)?.trim() ?? '');
        }

        entries.add(
          ParsedBankEntry(
            date: date,
            description: description.isEmpty
                ? 'ABN AMRO transaction'
                : description,
            iban: tagged('IBAN', 'IBAN')?.replaceAll(' ', ''),
            bic: tagged('BIC', 'BIC'),
            merchantName: tagged('NAME', 'Naam'),
            isIncome: amount > 0,
            amountCents: amount.abs(),
          ),
        );
      } on FormatException catch (e) {
        throw FormatException('Row ${i + 1}: ${e.message}');
      }
    }
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  static String _normalize(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  static String? _optional(String s) => s.isEmpty ? null : s;
  static void _requireEuro(String currency) {
    if (currency.toUpperCase() != 'EUR') {
      throw const FormatException(
        'Only EUR statements can be imported into Finance.',
      );
    }
  }
}

class _CsvFormat {
  const _CsvFormat({
    required this.dates,
    required this.amounts,
    required this.accounts,
    required this.currencies,
    required this.names,
    required this.counterparties,
    required this.descriptions,
    this.bics = const [],
    this.directions = const [],
    this.categories = const [],
  });

  final List<String> dates;
  final List<String> amounts;
  final List<String> accounts;
  final List<String> currencies;
  final List<String> names;
  final List<String> counterparties;
  final List<String> descriptions;
  final List<String> bics;
  final List<String> directions;
  final List<String> categories;

  bool matches(List<String> row) {
    final header = row.map(DutchBankParser._normalize).toSet();
    bool has(List<String> names) =>
        names.any((name) => header.contains(DutchBankParser._normalize(name)));
    return has(dates) && has(amounts) && has(accounts) && has(counterparties);
  }
}
