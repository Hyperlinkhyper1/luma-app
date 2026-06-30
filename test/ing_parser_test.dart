import 'package:flutter_test/flutter_test.dart';
import 'package:luma/finance/import/ing_parser.dart';

void main() {
  test('parses the real ING xlsx sample', () async {
    final entries = await IngParser.parseFile('test/ing_sample.xlsx');

    // The sample has 56 transaction rows.
    expect(entries, isNotEmpty);
    expect(entries.length, 56);

    // Sorted newest-first.
    for (var i = 1; i < entries.length; i++) {
      expect(entries[i - 1].date.isAfter(entries[i].date) ||
          entries[i - 1].date.isAtSameMomentAs(entries[i].date), isTrue);
    }

    // All amounts in the censored sample are 1.01 EUR = 101 cents.
    expect(entries.every((e) => e.amountCents == 101), isTrue);

    // "Af" rows are expenses, "Bij" rows are income; the sample has both.
    expect(entries.any((e) => e.isIncome), isTrue);
    expect(entries.any((e) => !e.isIncome), isTrue);

    // Counterparty IBANs are captured where present.
    expect(entries.any((e) => e.iban != null && e.iban!.startsWith('NL')), isTrue);

    // Merchant name extracted from the "Naam:" field in the memo.
    expect(
      entries.any((e) => e.merchantName == 'Action Zwembad Enz'),
      isTrue,
    );

    // Category guessing works on known NL billers.
    expect(
      entries.any((e) => e.categorySuggestion == 'Health & care'),
      isTrue,
    );
  });
}
