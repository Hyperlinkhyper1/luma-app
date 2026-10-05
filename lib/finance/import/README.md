# Bank statement imports

Finance → Transactions → Import data opens the bank picker, reads the selected
local file, and passes entries to the existing review dialog. Each entry is saved
only when the user chooses **Add & next**. No banking API or PSD2 provider is used.

| Bank | Supported transaction export |
| --- | --- |
| BUUT | PDF (existing parser) |
| ING | XLSX or CSV (existing parser) |
| ABN AMRO | Tab-separated TXT/TAB, eight columns without a header |
| Rabobank | CSV transaction overview with column headers |
| bunq | CSV account statement, English or Dutch headers, EUR account |
| SNS | CSV transaction overview, headers or the 17-column layout |
| Knab | CSV from Search and download, including the KNAB EXPORT preamble |

CSV handles comma, semicolon and tab delimiters, quoted descriptions, escaped
quotes and multiline fields. Text decoding supports UTF-8 (with or without BOM),
UTF-16 with BOM, and legacy Windows-1252. Dates are checked as calendar dates;
amounts are parsed as integer cents. The new parsers reject malformed rows with
the row number and reject non-EUR bookings, since Finance records use euros.
Zero-value status records do not create transactions. Transfers are presented
as income or expense for review, as in the existing import flow. Re-importing a
file does not automatically deduplicate transactions.

## Format references

- [ABN AMRO export options](https://www.abnamro.nl/nl/prive/betalen/bij-en-afschrijvingen/downloaden.html)
  and [parser author's anonymized TAB examples](https://github.com/denilsonsa/abn-amro-statement-parser/blob/main/TXT_SAMPLE.TAB).
- [Rabobank format documentation](https://www.rabobank.nl/bedrijven/service/online-bankieren/informatie-over-bestandsformaten).
- [bunq statement export](https://help.bunq.com/en-ie/articles/how-do-i-export-a-bank-statement).
- [SNS transaction CSV field specification](https://www.snsbank.nl/particulier/support/download-tonen-op-pagina/uitleg-van-je-transactieoverzicht-in-mijn-sns.html).
- [Knab export instructions](https://www.knab.nl/contact/veelgestelde-vragen/hoe-maak-ik-een-spaardoel-aan)
  and [Picqer's Knab CSV example](https://github.com/picqer/knab-to-xero/blob/master/example.csv).

Tests use synthetic statements based on these layouts; no customer statements
are included for the five new banks. Live bank-account exports remain a separate
manual check.
