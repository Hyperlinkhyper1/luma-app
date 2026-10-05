import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/finance/import/bank_statement_importer.dart';
import 'package:luma/finance/import/dutch_bank_parser.dart';
import 'package:luma/finance/import/import_models.dart';
import 'package:luma/finance/import/statement_text.dart';

import 'support/bank_statements.dart';

void main() {
  late Directory temp;
  setUp(
    () async =>
        temp = await Directory.systemTemp.createTemp('luma-bank-import-'),
  );
  tearDown(() async => temp.delete(recursive: true));

  test('catalog includes all seven banks', () {
    expect(supportedBanks.map((b) => b.id), [
      'buut',
      'ing',
      'abn_amro',
      'rabobank',
      'bunq',
      'sns',
      'knab',
    ]);
  });

  for (final fixture in bankStatements.entries) {
    test(
      '${fixture.key} file preserves both transactions and their fields',
      () async {
        final bank = supportedBanks.singleWhere((b) => b.id == fixture.key);
        final file = File(
          '${temp.path}/statement.${bank.allowedExtensions.first}',
        );
        await file.writeAsString('\uFEFF${fixture.value}');
        final entries = await BankStatementImporter.parseFile(bank, file.path);
        expect(entries.length, 2);
        final income = entries[0];
        final expense = entries[1];
        expect(income.date, DateTime(2026, 10, 5));
        expect(income.isIncome, isTrue);
        expect(income.amountCents, 250000);
        expect(income.merchantName, 'Example Employer');
        expect(income.iban, 'NL00TEST0000000002');
        expect(income.description, contains('Salary'));
        expect(expense.date, DateTime(2026, 10, 4));
        expect(expense.isIncome, isFalse);
        expect(expense.amountCents, 123456);
        expect(expense.merchantName, 'Café Example');
        expect(expense.iban, 'NL00TEST0000000001');
        expect(expense.description, contains('Invoice 42'));
        if (fixture.key == 'rabobank') {
          expect(expense.bic, 'TESTNL2A');
          expect(
            expense.description,
            contains('Part two, details — Part three'),
          );
        }
        if (fixture.key == 'bunq') {
          expect(
            expense.description,
            contains('line one\nline two with "quotes"'),
          );
        }
        if (fixture.key == 'sns') {
          expect(expense.categorySuggestion, 'Groceries');
        }
      },
    );
  }

  test('SNS headerless export uses the documented field order', () {
    final text = bankStatements['sns']!;
    final entries = DutchBankParser.parseText(
      'sns',
      text.substring(text.indexOf('\n') + 1),
    );
    expect(entries.map((e) => e.amountCents), [250000, 123456]);
    expect(entries.last.merchantName, 'Café Example');
    expect(entries.last.categorySuggestion, 'Groceries');
  });

  test('maps reordered columns and accepts bunq UK/US numbers', () {
    final entries = DutchBankParser.parseText(
      'bunq',
      'Description,Name,Counterparty,Account,Amount,Date\r\n'
          'Coffee,Café Example,NL00TEST0000000001,NL00TEST0000000000,"-1,234.56",2026-10-04\r\n',
    );
    expect(entries.single.amountCents, 123456);
    expect(entries.single.isIncome, isFalse);
    expect(entries.single.date, DateTime(2026, 10, 4));
  });

  test('reads Windows-1252 and UTF-16 exports without losing names', () async {
    final bank = supportedBanks.singleWhere((b) => b.id == 'knab');
    final cp1252 = File('${temp.path}/legacy.csv');
    await cp1252.writeAsBytes(
      latin1.encode(
        bankStatements['knab']!.replaceAll('Salary', 'Salary\u0092'),
      ),
    );
    final legacy = await BankStatementImporter.parseFile(bank, cp1252.path);
    expect(legacy.last.merchantName, 'Café Example');
    expect(legacy.first.description, contains('Salary’'));
    for (final little in [true, false]) {
      final file = File('${temp.path}/utf16.csv');
      await file.writeAsBytes([
        if (little) ...[0xff, 0xfe] else ...[0xfe, 0xff],
        for (final c in bankStatements['knab']!.codeUnits)
          if (little) ...[c & 255, c >> 8] else ...[c >> 8, c & 255],
      ]);
      expect(
        (await BankStatementImporter.parseFile(
          bank,
          file.path,
        )).last.merchantName,
        'Café Example',
      );
    }
  });

  test('invalid transaction aborts the file with a row number', () {
    final invalid = bankStatements['bunq']!.replaceFirst(
      '2500,00',
      'not money',
    );
    expect(
      () => DutchBankParser.parseText('bunq', invalid),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Row 3'),
        ),
      ),
    );
    expect(
      () => DutchBankParser.parseText(
        'knab',
        bankStatements['knab']!.replaceFirst('04-10-2026', '31-02-2026'),
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Invalid transaction date'),
        ),
      ),
    );
  });

  test('rejects non-EUR bookings, wrong bank and missing required columns', () {
    for (final id in ['abn_amro', 'rabobank', 'sns', 'knab']) {
      expect(
        () => DutchBankParser.parseText(
          id,
          bankStatements[id]!.replaceAll('EUR', 'USD'),
        ),
        throwsFormatException,
      );
    }
    expect(
      () => DutchBankParser.parseText(
        'bunq',
        'Date;Amount;Account;Counterparty;Name;Description;Currency\n'
            '2026-10-04;-10;own;other;Example;Coffee;USD\n',
      ),
      throwsFormatException,
    );
    expect(
      () => DutchBankParser.parseText('rabobank', bankStatements['knab']!),
      throwsFormatException,
    );
    expect(
      () => DutchBankParser.parseText(
        'knab',
        bankStatements['knab']!.replaceAll('CreditDebet', 'Unknown'),
      ),
      throwsFormatException,
    );
  });

  test('rejects unknown directions and malformed CSV', () {
    expect(
      () => DutchBankParser.parseText(
        'knab',
        bankStatements['knab']!.replaceFirst('"D"', '"X"'),
      ),
      throwsFormatException,
    );
    expect(
      () => DutchBankParser.parseText(
        'bunq',
        '${bankStatements['bunq']}"unfinished',
      ),
      throwsFormatException,
    );
    expect(
      () => DutchBankParser.parseText(
        'bunq',
        '${bankStatements['bunq']}2026-10-06;-1;own\n',
      ),
      throwsFormatException,
    );
  });

  test('empty exports and zero-value records do not create entries', () {
    for (final id in bankStatements.keys) {
      expect(DutchBankParser.parseText(id, '\n'), isEmpty);
    }
    expect(
      DutchBankParser.parseText(
        'bunq',
        'Date;Amount;Account;Counterparty;Name;Description\n'
            '2026-10-04;0,00;own;other;Example;Status\n',
      ),
      isEmpty,
    );
  });

  test('file dispatcher enforces the bank file extensions', () async {
    final bank = supportedBanks.singleWhere((b) => b.id == 'abn_amro');
    expect(
      () => BankStatementImporter.parseFile(bank, '${temp.path}/statement.pdf'),
      throwsFormatException,
    );
    final txt = File('${temp.path}/statement.TXT');
    await txt.writeAsString(bankStatements['abn_amro']!);
    expect(await BankStatementImporter.parseFile(bank, txt.path), hasLength(2));
  });

  test('description punctuation cannot change a semicolon delimiter', () {
    final entries = DutchBankParser.parseText(
      'bunq',
      'Date;Amount;Account;Counterparty;Name;Description\n'
          '2026-10-04;-1,23;own;other;Example;One, two, three, four, five, six, seven, eight\n',
    );
    expect(entries.single.amountCents, 123);
    expect(entries.single.description, contains('seven, eight'));
  });

  test('exact cents and calendar validation reject malformed values', () {
    expect(StatementText.cents('0.29'), 29);
    expect(StatementText.cents('-0,01'), -1);
    expect(StatementText.cents('NaN'), isNull);
    expect(StatementText.cents('1.234'), isNull);
    expect(StatementText.cents('1..234,56'), isNull);
    expect(StatementText.cents('9223372036854775807'), isNull);
    expect(StatementText.date('2026-02-30'), isNull);
    expect(StatementText.date('2024-02-29'), DateTime(2024, 2, 29));
  });

  test(
    'ING semicolon CSV keeps unquoted decimal commas in their field',
    () async {
      final file = File('${temp.path}/ing.csv');
      await file.writeAsString(
        'Datum;Naam / Omschrijving;Rekening;Tegenrekening;Code;Af Bij;Bedrag (EUR);Mutatiesoort;Mededelingen\n'
        '20261004;Café Example;own;other;BA;Af;12,34;Payment;Coffee\n',
      );
      final bank = supportedBanks.singleWhere((b) => b.id == 'ing');
      final entry = (await BankStatementImporter.parseFile(
        bank,
        file.path,
      )).single;
      expect(entry.amountCents, 1234);
      expect(entry.isIncome, isFalse);
      expect(entry.description, contains('Coffee'));
    },
  );
}
