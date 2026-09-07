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

  /// Whether this format can actually encode [value]. NFC stores the payload
  /// verbatim, so it accepts anything; every barcode runs the encoder's own
  /// checks (charset, length, check digit).
  bool accepts(String value) => barcode?.isValid(value) ?? true;

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

/// What [detectCardFormat] made of a value.
class CardFormatGuess {
  const CardFormatGuess(this.format, {required this.confident});

  final CardFormat format;

  /// True when the value's own structure identified it — a verified check
  /// digit or a symbology-specific character set. False for the catch-all
  /// carriers ([CardFormat.code128], [CardFormat.qr]) picked because nothing
  /// more specific fits; those encode almost anything, so they're a safe
  /// default rather than a recognition.
  final bool confident;
}

/// Longest value still worth putting in a 1D barcode. Past this the strip is
/// too wide to scan reliably off a screen, so a matrix code wins.
const _maxLinearLength = 48;

final _digitsOnly = RegExp(r'^\d+$');
final _printableAscii = RegExp(r'^[\x20-\x7E]+$');
final _urlScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://');
final _upcEPrefix = RegExp(r'^[01]');
final _code39Charset = RegExp(r'^[0-9A-Z\-. $/+%]+$');

/// Payload prefixes that only ever appear inside a QR code.
const _qrPayloadPrefixes = <String>[
  'mailto:',
  'tel:',
  'sms:',
  'smsto:',
  'geo:',
  'wifi:',
  'begin:v',
  'otpauth:',
  'bitcoin:',
];

/// Works out which symbology [value] belongs to, so the editor can fill the
/// format in instead of asking. Returns null for a blank value.
///
/// Ordered strictest first: a check-digit-verified EAN/UPC beats a generic
/// numeric string, and a symbology-specific character set beats the catch-all
/// carriers. Every candidate is put through the real encoder before it's
/// returned, so a guess never produces a card that won't render.
///
/// Two formats are deliberately never guessed. [CardFormat.nfc] is a tag, not
/// something a typed value implies. [CardFormat.codabar] can only be told
/// apart by its A–D start/stop letters, which this app's Codabar encoder adds
/// itself and refuses in the data — so it stays a manual choice, and a value
/// carrying those letters is served by Code 39, which encodes them verbatim.
CardFormatGuess? detectCardFormat(String value) {
  final data = value.trim();
  if (data.isEmpty) return null;

  if (_isQrPayload(data)) {
    return const CardFormatGuess(CardFormat.qr, confident: true);
  }

  // Past this width a 1D strip stops scanning reliably off a screen, whatever
  // its character set says.
  if (data.length > _maxLinearLength) {
    return const CardFormatGuess(CardFormat.qr, confident: false);
  }

  if (_digitsOnly.hasMatch(data)) {
    final numeric = _detectNumeric(data);
    if (numeric != null) return CardFormatGuess(numeric, confident: true);
  } else if (_code39Charset.hasMatch(data) &&
      CardFormat.code39.accepts(data)) {
    return const CardFormatGuess(CardFormat.code39, confident: true);
  }

  // Nothing identified it. Code 128 carries any printable ASCII densely, so
  // it's the safe default; if even that refuses the value, a QR code fits.
  if (CardFormat.code128.accepts(data)) {
    return const CardFormatGuess(CardFormat.code128, confident: false);
  }
  return const CardFormatGuess(CardFormat.qr, confident: false);
}

/// True for values no 1D barcode can carry: a URI, a structured payload of the
/// kind only QR codes hold, or text that leaves printable ASCII.
bool _isQrPayload(String data) {
  if (_urlScheme.hasMatch(data)) return true;
  final lower = data.toLowerCase();
  if (_qrPayloadPrefixes.any(lower.startsWith)) return true;
  return !_printableAscii.hasMatch(data);
}

/// Identifies the retail numeric symbologies by length plus check digit. A
/// number that fails its family's checksum is deliberately *not* claimed —
/// the encoders treat a short value as "checksum omitted" and would append a
/// digit, silently changing what the till reads.
CardFormat? _detectNumeric(String data) {
  final length = data.length;

  if (length == 8) {
    // An 8-digit code starting 0 or 1 is UPC-E, whose check digit is computed
    // over the expanded UPC-A — let the encoder arbitrate before EAN-8.
    if (_upcEPrefix.hasMatch(data) && CardFormat.upcE.accepts(data)) {
      return CardFormat.upcE;
    }
    if (_mod10Ok(data) && CardFormat.ean8.accepts(data)) {
      return CardFormat.ean8;
    }
  }
  if (length == 12 && _mod10Ok(data) && CardFormat.upcA.accepts(data)) {
    return CardFormat.upcA;
  }
  if (length == 13 && _mod10Ok(data) && CardFormat.ean13.accepts(data)) {
    return CardFormat.ean13;
  }
  if (length == 14 && _mod10Ok(data) && CardFormat.itf.accepts(data)) {
    return CardFormat.itf;
  }
  return null;
}

/// Verifies the trailing mod-10 check digit shared by EAN-8, EAN-13, UPC-A and
/// ITF-14: weights alternate 3 and 1 from the digit before the check digit
/// backwards.
bool _mod10Ok(String data) {
  final body = data.substring(0, data.length - 1);
  var sum = 0;
  var position = body.length;
  for (final unit in body.codeUnits) {
    sum += (unit - 0x30) * (position.isEven ? 1 : 3);
    position--;
  }
  final expected = sum % 10 == 0 ? 0 : 10 - (sum % 10);
  return data.codeUnitAt(data.length - 1) - 0x30 == expected;
}
