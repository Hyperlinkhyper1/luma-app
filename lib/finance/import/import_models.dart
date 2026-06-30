/// A parsed transaction entry from a bank statement, before it is mapped to
/// the app's [FinanceTransaction] schema.
class ParsedBankEntry {
  ParsedBankEntry({
    required this.date,
    required this.description,
    this.iban,
    this.bic,
    this.merchantName,
    required this.isIncome,
    required this.amountCents,
    this.categorySuggestion,
  });

  final DateTime date;
  final String description;
  final String? iban;
  final String? bic;
  final String? merchantName;
  final bool isIncome;
  final int amountCents;
  final String? categorySuggestion;

  /// Human-readable summary of the transaction type.
  String get typeLabel => isIncome ? 'Income' : 'Expense';

  ParsedBankEntry copyWith({
    DateTime? date,
    String? description,
    String? iban,
    String? bic,
    String? merchantName,
    bool? isIncome,
    int? amountCents,
    String? categorySuggestion,
  }) {
    return ParsedBankEntry(
      date: date ?? this.date,
      description: description ?? this.description,
      iban: iban ?? this.iban,
      bic: bic ?? this.bic,
      merchantName: merchantName ?? this.merchantName,
      isIncome: isIncome ?? this.isIncome,
      amountCents: amountCents ?? this.amountCents,
      categorySuggestion: categorySuggestion ?? this.categorySuggestion,
    );
  }
}

/// Describes a supported bank and the file type it expects.
class SupportedBank {
  const SupportedBank({
    required this.id,
    required this.name,
    required this.allowedExtensions,
    required this.icon,
  });

  final String id;
  final String name;

  /// File extensions (without the leading dot) this bank's export can use.
  /// The first entry is treated as the primary one for display.
  final List<String> allowedExtensions;
  final String icon; // emoji or simple identifier

  /// Human-readable description of the accepted file types, e.g. ".xlsx or .csv".
  String get fileTypeLabel =>
      allowedExtensions.map((e) => '.$e').join(' or ');
}

const supportedBanks = [
  SupportedBank(
    id: 'buut',
    name: 'BUUT',
    allowedExtensions: ['pdf'],
    icon: '🏦',
  ),
  SupportedBank(
    id: 'ing',
    name: 'ING',
    allowedExtensions: ['xlsx', 'csv'],
    icon: '🦁',
  ),
];
