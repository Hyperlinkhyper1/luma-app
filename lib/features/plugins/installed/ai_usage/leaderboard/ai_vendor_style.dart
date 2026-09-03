import 'package:flutter/material.dart';

/// One fixed, vivid colour per vendor — used everywhere a model's provider
/// needs to be told apart at a glance (the graph's dots, the compare radar,
/// news badges): a colour tied to the *brand*, not to draw order, so the
/// same vendor is always the same colour across every chart in the app.
///
/// Deliberately saturated rather than pastel — a scatter of 300 dots needs
/// real contrast between series to be readable, and softened tones wash
/// together at that density.
const Map<String, Color> kVendorColors = {
  'anthropic': Color(0xFFF97316),
  'openai': Color(0xFF22C55E),
  'google': Color(0xFF3B82F6),
  'x-ai': Color(0xFF06B6D4),
  'z-ai': Color(0xFFD946EF),
  'qwen': Color(0xFF8B5CF6),
  'deepseek': Color(0xFF6366F1),
  'meta': Color(0xFF14B8A6),
  'meta-llama': Color(0xFF14B8A6),
  'moonshotai': Color(0xFFEF4444),
  'mistralai': Color(0xFFEAB308),
  'nvidia': Color(0xFF84CC16),
  'minimax': Color(0xFFF43F5E),
};

/// Fallback for a vendor key the map doesn't know about — should only ever
/// come up if the server's own allowlist and this one drift apart.
const Color kVendorColorFallback = Color(0xFF9CA3AF);

Color vendorColor(String vendor) => kVendorColors[vendor] ?? kVendorColorFallback;

/// One or two letters standing in for a vendor's logo, since no official
/// brand marks are bundled here (see the "Correct Brand Logos" rule — better
/// to have no logo than a misused one). Picked to actually read as the
/// brand, not just the first letter blindly.
const Map<String, String> kVendorInitials = {
  'anthropic': 'A',
  'openai': 'AI',
  'google': 'G',
  'x-ai': 'X',
  'z-ai': 'Z',
  'qwen': 'Qw',
  'deepseek': 'DS',
  'meta': 'M',
  'meta-llama': 'M',
  'moonshotai': 'MK',
  'mistralai': 'Mi',
  'nvidia': 'N',
  'minimax': 'MM',
};

String vendorInitials(String vendor) =>
    kVendorInitials[vendor] ?? (vendor.isEmpty ? '?' : vendor[0].toUpperCase());

/// Maps a news item's `source` display name (e.g. `"Google DeepMind"`) back
/// to a vendor key from [kVendorColors], for badges on the news rail.
/// `"Hugging Face"` isn't one of the 12 model vendors — it's a hub, not a
/// lab — so it gets its own identity below rather than borrowing one.
const Map<String, String> kNewsSourceVendor = {
  'OpenAI': 'openai',
  'Google AI': 'google',
  'Google DeepMind': 'google',
  'Qwen': 'qwen',
  'DeepSeek': 'deepseek',
};

const Color kHuggingFaceColor = Color(0xFFFFD21E);

/// The colour a news card's badge should use for [source].
Color newsSourceColor(String source) => source == 'Hugging Face'
    ? kHuggingFaceColor
    : vendorColor(kNewsSourceVendor[source] ?? '');

String newsSourceInitials(String source) => source == 'Hugging Face'
    ? 'HF'
    : vendorInitials(kNewsSourceVendor[source] ?? source);

/// A small coloured badge standing in for a vendor's logo — a filled circle
/// with initials, coloured via [vendorColor]. Used on news cards and
/// anywhere else a model's provider needs a compact visual mark.
class VendorBadge extends StatelessWidget {
  const VendorBadge({
    super.key,
    required this.vendor,
    required this.vendorName,
    this.size = 28,
  });

  final String vendor;
  final String vendorName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = vendorColor(vendor);
    return Tooltip(
      message: vendorName,
      child: Semantics(
        label: vendorName,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(
            vendorInitials(vendor),
            style: TextStyle(
              color: color,
              fontSize: size * 0.36,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
