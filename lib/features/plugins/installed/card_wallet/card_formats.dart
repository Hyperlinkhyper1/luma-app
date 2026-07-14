import 'package:barcode_widget/barcode_widget.dart';

/// The kinds of code a wallet card can present. Most are 1D/2D barcodes a
/// checkout scanner reads; [nfc] is a stored tag payload shown for copy and
/// QR-fallback — live tap-to-scan emulation is a mobile-only capability (see
/// the card's present view), so on desktop the payload is display-only.
enum CardFormat {
  code128,
  qr,
  ean13,
  ean8,
  upcA,
  upcE,
  code39,
  itf,
  codabar,
  pdf417,
  aztec,
  dataMatrix,
  nfc,
}

extension CardFormatX on CardFormat {
  /// Human-readable name shown in the format picker and on the present view.
  String get label => switch (this) {
        CardFormat.code128 => 'Code 128',
        CardFormat.qr => 'QR code',
        CardFormat.ean13 => 'EAN-13',
        CardFormat.ean8 => 'EAN-8',
        CardFormat.upcA => 'UPC-A',
        CardFormat.upcE => 'UPC-E',
        CardFormat.code39 => 'Code 39',
        CardFormat.itf => 'ITF',
        CardFormat.codabar => 'Codabar',
        CardFormat.pdf417 => 'PDF417',
        CardFormat.aztec => 'Aztec',
        CardFormat.dataMatrix => 'Data Matrix',
        CardFormat.nfc => 'NFC tag',
      };

  bool get isNfc => this == CardFormat.nfc;

  /// True for square matrix symbologies (rendered as a square rather than a
  /// wide strip) — used to pick sensible display proportions.
  bool get is2d =>
      this == CardFormat.qr ||
      this == CardFormat.aztec ||
      this == CardFormat.dataMatrix;

  /// The `barcode` package encoder for this format, or null for [nfc], which
  /// has no barcode representation of its own.
  Barcode? get barcode => switch (this) {
        CardFormat.code128 => Barcode.code128(),
        CardFormat.qr => Barcode.qrCode(),
        CardFormat.ean13 => Barcode.ean13(),
        CardFormat.ean8 => Barcode.ean8(),
        CardFormat.upcA => Barcode.upcA(),
        CardFormat.upcE => Barcode.upcE(),
        CardFormat.code39 => Barcode.code39(),
        CardFormat.itf => Barcode.itf(),
        CardFormat.codabar => Barcode.codabar(),
        CardFormat.pdf417 => Barcode.pdf417(),
        CardFormat.aztec => Barcode.aztec(),
        CardFormat.dataMatrix => Barcode.dataMatrix(),
        CardFormat.nfc => null,
      };
}

/// Resolves a stored format key (the enum's [Enum.name]) back to a
/// [CardFormat], falling back to Code 128 for unknown/legacy values.
CardFormat cardFormatFromKey(String? key) => CardFormat.values.firstWhere(
      (f) => f.name == key,
      orElse: () => CardFormat.code128,
    );
