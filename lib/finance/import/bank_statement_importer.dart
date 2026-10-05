import 'buut_parser.dart';
import 'dutch_bank_parser.dart';
import 'import_models.dart';
import 'ing_parser.dart';

/// One dispatch path for the bank picker and file-import tests.
class BankStatementImporter {
  BankStatementImporter._();

  static Future<List<ParsedBankEntry>> parseFile(
    SupportedBank bank,
    String path,
  ) {
    final extension = path.split('.').last.toLowerCase();
    if (!bank.allowedExtensions.contains(extension)) {
      throw FormatException(
        'Select a ${bank.fileTypeLabel} export from ${bank.name}.',
      );
    }
    return switch (bank.id) {
      'buut' => BuutParser.parseFile(path),
      'ing' => IngParser.parseFile(path),
      'abn_amro' ||
      'rabobank' ||
      'bunq' ||
      'sns' ||
      'knab' => DutchBankParser.parseFile(bank.id, path),
      _ => throw UnsupportedError('Bank ${bank.name} is not yet implemented.'),
    };
  }
}
