import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:mobile_scanner/mobile_scanner.dart';

import 'card_formats.dart';

/// A barcode read off the camera or an image: its raw value and the wallet
/// [CardFormat] it maps to (null when it's a symbology luma doesn't render).
class BarcodeScanResult {
  const BarcodeScanResult({required this.value, this.format});

  final String value;
  final CardFormat? format;
}

/// Reads a card's barcode / QR code from the camera or a picked screenshot so
/// the number and symbology are filled in automatically instead of typed and
/// chosen by hand. Backed by mobile_scanner (ML Kit / Vision), which drives
/// the camera on Android, iOS and macOS and decodes images on the same.
class CardWalletScanner {
  const CardWalletScanner._();

  static bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _isMacOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  /// Whether a live camera scan is available here.
  static bool get cameraSupported => _isMobile || _isMacOS;

  /// Whether decoding a picked image / screenshot is available here.
  static bool get imageSupported => _isMobile || _isMacOS;

  /// Decodes the first barcode found in the image at [path], or null if the
  /// image holds no readable code.
  static Future<BarcodeScanResult?> scanImage(String path) async {
    final controller = MobileScannerController();
    try {
      final capture = await controller.analyzeImage(path);
      if (capture == null) return null;
      for (final barcode in capture.barcodes) {
        final value = barcode.rawValue;
        if (value != null && value.isNotEmpty) {
          return BarcodeScanResult(
            value: value,
            format: mapFormat(barcode.format),
          );
        }
      }
      return null;
    } finally {
      await controller.dispose();
    }
  }

  /// Maps a scanner [BarcodeFormat] onto the wallet's [CardFormat]. Returns
  /// null for symbologies luma can't regenerate (e.g. Code 93, MaxiCode), so
  /// the caller keeps the value but leaves the format for the user to pick.
  static CardFormat? mapFormat(BarcodeFormat format) => switch (format) {
        BarcodeFormat.qrCode => CardFormat.qr,
        BarcodeFormat.microQrCode => CardFormat.qr,
        BarcodeFormat.code128 => CardFormat.code128,
        BarcodeFormat.ean13 => CardFormat.ean13,
        BarcodeFormat.ean8 => CardFormat.ean8,
        BarcodeFormat.upcA => CardFormat.upcA,
        BarcodeFormat.upcE => CardFormat.upcE,
        BarcodeFormat.code39 => CardFormat.code39,
        BarcodeFormat.itf => CardFormat.itf,
        BarcodeFormat.codabar => CardFormat.codabar,
        BarcodeFormat.pdf417 => CardFormat.pdf417,
        BarcodeFormat.aztec => CardFormat.aztec,
        BarcodeFormat.dataMatrix => CardFormat.dataMatrix,
        _ => null,
      };
}
