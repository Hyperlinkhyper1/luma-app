import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/card_wallet/card_formats.dart';

CardFormat? _format(String value) => detectCardFormat(value)?.format;

bool _confident(String value) => detectCardFormat(value)?.confident ?? false;

void main() {
  group('detectCardFormat', () {
    test('has nothing to say about a blank value', () {
      expect(detectCardFormat(''), isNull);
      expect(detectCardFormat('   '), isNull);
    });

    test('recognises the retail numeric symbologies by check digit', () {
      expect(_format('4006381333931'), CardFormat.ean13);
      expect(_format('036000291452'), CardFormat.upcA);
      expect(_format('96385074'), CardFormat.ean8);
      expect(_format('15400141288763'), CardFormat.itf);
      expect(_confident('4006381333931'), isTrue);
    });

    test('reads an 8-digit code starting with 0 as UPC-E, not EAN-8', () {
      expect(_format('01234565'), CardFormat.upcE);
    });

    test('falls back to Code 128 when a checksum does not verify', () {
      // One digit off a valid EAN-13. Claiming EAN-13 here would make the
      // encoder treat the value as "checksum omitted" and append a digit,
      // changing what the till reads.
      expect(_format('4006381333930'), CardFormat.code128);
      expect(_confident('4006381333930'), isFalse);
    });

    test('leaves an arbitrary membership number on Code 128', () {
      expect(_format('7501234567890123'), CardFormat.code128);
      expect(_format('123456'), CardFormat.code128);
    });

    test('picks Code 39 for its own character set', () {
      expect(_format('MEMBER-1234'), CardFormat.code39);
      expect(_confident('MEMBER-1234'), isTrue);
    });

    test('sends lowercase to Code 128, which Code 39 cannot encode', () {
      expect(_format('member-1234'), CardFormat.code128);
    });

    test('puts URIs and structured payloads in a QR code', () {
      expect(_format('https://luma.app/cards/42'), CardFormat.qr);
      expect(_format('mailto:hi@luma.app'), CardFormat.qr);
      expect(_format('WIFI:S:home;T:WPA;P:secret;;'), CardFormat.qr);
      expect(_confident('https://luma.app/cards/42'), isTrue);
    });

    test('puts anything too wide for a strip in a QR code', () {
      expect(_format('A' * 80), CardFormat.qr);
      expect(_confident('A' * 80), isFalse);
    });

    test('ignores surrounding whitespace', () {
      expect(_format('  4006381333931 '), CardFormat.ean13);
    });

    test('never guesses NFC or Codabar', () {
      const values = [
        '4006381333931',
        'A123456B',
        '1234-5678',
        'member card',
        'https://luma.app',
      ];
      for (final value in values) {
        expect(_format(value), isNot(CardFormat.nfc), reason: value);
        expect(_format(value), isNot(CardFormat.codabar), reason: value);
      }
    });

    test('only ever suggests a format that can encode the value', () {
      const values = [
        '4006381333931',
        '036000291452',
        '96385074',
        '01234565',
        '15400141288763',
        'MEMBER-1234',
        'member-1234',
        '7501234567890123',
        'https://luma.app/cards/42',
        'A123456B',
      ];
      for (final value in values) {
        final guess = detectCardFormat(value)!;
        expect(guess.format.accepts(value), isTrue, reason: value);
      }
    });
  });

  group('CardFormat.accepts', () {
    test('rejects a value the encoder would refuse', () {
      expect(CardFormat.ean13.accepts('4006381333930'), isFalse);
      expect(CardFormat.ean13.accepts('not a number'), isFalse);
    });

    test('accepts a well-formed value', () {
      expect(CardFormat.ean13.accepts('4006381333931'), isTrue);
    });

    test('takes anything for an NFC tag, which has no encoder', () {
      expect(CardFormat.nfc.accepts('04:a2:24:1b'), isTrue);
    });
  });
}
