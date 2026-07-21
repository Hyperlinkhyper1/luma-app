import 'dart:async';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Hide mobile_scanner's Barcode: barcode_widget already exports a Barcode type
// used here for rendering (Barcode.qrCode()). We only need the scanner widget,
// controller and BarcodeCapture, so the collision is avoided cleanly.
import 'package:mobile_scanner/mobile_scanner.dart' hide Barcode;

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'card_formats.dart';
import 'card_wallet_nfc.dart';
import 'card_wallet_repository.dart';
import 'card_wallet_scanner.dart';
import 'card_wallet_scope.dart';

/// Accent colors offered when creating a card. Kept vivid so the wallet grid
/// stays easy to scan at a glance.
const _cardColors = <int>[
  0xFF7C5AD9,
  0xFF2F80ED,
  0xFF00B8A9,
  0xFF12A372,
  0xFFF5A623,
  0xFFE5484D,
  0xFFF25F9C,
  0xFF9B51E0,
  0xFF5D6470,
  0xFF1F2430,
];

/// The Card Wallet plugin: store loyalty/membership passes and present them
/// again — regenerate a card's barcode to scan at the till, or keep an NFC
/// tag's payload on hand. Not secret data, so there's no PIN gate.
class CardWalletPage extends StatelessWidget {
  const CardWalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = CardWalletScope.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LumaCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your cards',
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add a loyalty or membership pass, then present its '
                            'barcode at the till — or keep an NFC tag handy.',
                            style: TextStyle(color: luma.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    LumaPrimaryButton(
                      label: 'Add card',
                      icon: Icons.add_rounded,
                      onTap: () => _showCardEditor(context, repo),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              StreamData<List<WalletCardRecord>>(
                stream: repo.watchAll(),
                builder: (context, cards) {
                  if (cards.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: LumaEmptyState(
                        icon: Icons.wallet_rounded,
                        title: 'No cards yet',
                        subtitle:
                            'Add your first loyalty or membership card and it '
                            'shows up here, ready to scan.',
                        action: LumaPrimaryButton(
                          label: 'Add card',
                          icon: Icons.add_rounded,
                          onTap: () => _showCardEditor(context, repo),
                        ),
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(height: 16),
                        _CardTile(
                          card: cards[i],
                          onTap: () =>
                              _showCardDetail(context, repo, cards[i]),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A Stocard-style pass in the wallet grid: a colored card face with the name,
/// category, and a small preview of the code it holds.
class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.onTap});
  final WalletCardRecord card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final base = Color(card.color);
    final dark = _shade(base, -0.14);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 158,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, dark],
            ),
            boxShadow: [
              BoxShadow(
                color: base.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      card.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    card.format.isNfc
                        ? Icons.nfc_rounded
                        : Icons.qr_code_2_rounded,
                    color: Colors.white.withValues(alpha: 0.85),
                    size: 20,
                  ),
                ],
              ),
              if (card.category != null && card.category!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  card.category!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const Spacer(),
              _tilePreview(card),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tilePreview(WalletCardRecord card) {
    if (card.format.isNfc) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.contactless_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              'Tap to scan',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    final barcode = card.format.barcode;
    if (barcode == null || card.code.isEmpty) {
      return const SizedBox.shrink();
    }
    final preview = BarcodeWidget(
      barcode: barcode,
      data: card.code,
      drawText: false,
      color: Colors.black,
      backgroundColor: Colors.white,
      errorBuilder: (context, _) => Center(
        child: Text(
          card.code,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.black54, fontSize: 11),
        ),
      ),
    );
    // Matrix codes are square, so give them a small square chip; 1D barcodes
    // stretch across the full tile width as a strip.
    if (card.format.is2d) {
      return Container(
        width: 42,
        height: 42,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: preview,
      );
    }
    return Container(
      height: 40,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: preview,
    );
  }
}

/// Full "present this card" view — a big, high-contrast barcode a checkout
/// scanner can read, or the NFC tag's payload with a QR fallback.
void _showCardDetail(
  BuildContext context,
  CardWalletRepository repo,
  WalletCardRecord card,
) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final luma = dialogContext.luma;
      return Dialog(
        backgroundColor: luma.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    LumaIconBadge(
                      icon: card.format.isNfc
                          ? Icons.nfc_rounded
                          : Icons.qr_code_2_rounded,
                      color: Color(card.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.name,
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            [
                              if (card.category != null &&
                                  card.category!.isNotEmpty)
                                card.category!,
                              card.format.label,
                            ].join(' · '),
                            style:
                                TextStyle(color: luma.textMuted, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (card.format.isNfc)
                  _NfcPresent(card: card)
                else
                  _BarcodePresent(card: card),
                if (card.notes != null && card.notes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: luma.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: luma.border),
                    ),
                    child: Text(
                      card.notes!,
                      style: TextStyle(color: luma.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Delete',
                      icon: Icon(Icons.delete_outline_rounded,
                          color: luma.textMuted),
                      onPressed: () async {
                        final confirmed = await _confirmDelete(dialogContext);
                        if (confirmed) {
                          await repo.delete(card.id);
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        }
                      },
                    ),
                    const Spacer(),
                    LumaGhostButton(
                      label: 'Edit',
                      icon: Icons.edit_rounded,
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        _showCardEditor(context, repo, existing: card);
                      },
                    ),
                    const SizedBox(width: 10),
                    LumaPrimaryButton(
                      label: 'Done',
                      onTap: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// The white, high-contrast barcode block plus the copyable raw value.
class _BarcodePresent extends StatelessWidget {
  const _BarcodePresent({required this.card});
  final WalletCardRecord card;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final barcode = card.format.barcode;
    final is2d = card.format.is2d;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: barcode == null || card.code.isEmpty
                ? const Text('No code to show',
                    style: TextStyle(color: Colors.black54))
                : SizedBox(
                    height: is2d ? 220 : 130,
                    width: is2d ? 220 : double.infinity,
                    child: BarcodeWidget(
                      barcode: barcode,
                      data: card.code,
                      drawText: !is2d,
                      color: Colors.black,
                      backgroundColor: Colors.white,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      errorBuilder: (context, _) => Center(
                        child: Text(
                          "This value isn't valid for ${card.format.label}.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                card.code,
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            LumaGhostButton(
              label: 'Copy',
              icon: Icons.copy_rounded,
              onTap: () => _copy(context, card.code),
            ),
          ],
        ),
      ],
    );
  }
}

/// NFC tag payload: shown for copy plus a QR fallback so a phone camera can
/// still ingest it. Live tap-to-scan emulation is a mobile-only capability.
class _NfcPresent extends StatelessWidget {
  const _NfcPresent({required this.card});
  final WalletCardRecord card;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (card.code.isNotEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: BarcodeWidget(
                barcode: Barcode.qrCode(),
                data: card.code,
                width: 200,
                height: 200,
                color: Colors.black,
                backgroundColor: Colors.white,
                errorBuilder: (context, _) => const SizedBox(
                  width: 200,
                  height: 200,
                  child: Center(
                    child: Icon(Icons.nfc_rounded,
                        color: Colors.black38, size: 48),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: luma.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: luma.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SelectableText(
                  card.code.isEmpty ? '(empty tag)' : card.code,
                  style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              LumaGhostButton(
                label: 'Copy',
                icon: Icons.copy_rounded,
                onTap: () => _copy(context, card.code),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: luma.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tap-to-scan emulation runs on the luma mobile app. On this '
                'device you can copy the tag data or scan the QR above.',
                style: TextStyle(color: luma.textMuted, fontSize: 12, height: 1.3),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Bottom sheet that runs a live NFC read: prompts the user to hold their card
/// to the phone, then pops with the tag's payload (or shows the reason it
/// couldn't, with a Retry).
class _NfcScanSheet extends StatefulWidget {
  const _NfcScanSheet();

  @override
  State<_NfcScanSheet> createState() => _NfcScanSheetState();
}

class _NfcScanSheetState extends State<_NfcScanSheet> {
  bool _scanning = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final result = await CardWalletNfc.scan();
      if (mounted) Navigator.of(context).pop(result);
    } on NfcScanException catch (e) {
      if (mounted) {
        setState(() {
          _scanning = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _scanning = false;
          _error = 'Something went wrong while scanning. ($e)';
        });
      }
    }
  }

  @override
  void dispose() {
    // Make sure the reader session is closed if the sheet is dismissed mid-scan.
    CardWalletNfc.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: luma.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: luma.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            _ScanPulse(active: _scanning, error: _error != null),
            const SizedBox(height: 22),
            Text(
              _error != null
                  ? "Couldn't scan"
                  : (_scanning ? 'Ready to scan' : 'Scan a tag'),
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ??
                  'Hold your card flat against the back of your phone and keep '
                      'it still — larger cards take a second to read.',
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textMuted, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: LumaGhostButton(
                    label: 'Cancel',
                    expand: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: LumaPrimaryButton(
                      label: 'Try again',
                      icon: Icons.refresh_rounded,
                      expand: true,
                      onTap: _start,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A soft pulsing contactless glyph shown while a scan is in progress; turns
/// into a static error glyph when a read fails.
class _ScanPulse extends StatefulWidget {
  const _ScanPulse({required this.active, required this.error});
  final bool active;
  final bool error;

  @override
  State<_ScanPulse> createState() => _ScanPulseState();
}

class _ScanPulseState extends State<_ScanPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final accent = widget.error ? luma.danger : luma.accent;
    return SizedBox(
      width: 108,
      height: 108,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.active && !widget.error)
                Container(
                  width: 60 + 48 * t,
                  height: 60 + 48 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: (1 - t) * 0.28),
                  ),
                ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.16),
                ),
                child: Icon(
                  widget.error
                      ? Icons.error_outline_rounded
                      : Icons.contactless_rounded,
                  color: accent,
                  size: 32,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Bottom sheet holding a live camera preview; pops with the first barcode it
/// reads (value + detected format).
class _BarcodeCameraSheet extends StatefulWidget {
  const _BarcodeCameraSheet();

  @override
  State<_BarcodeCameraSheet> createState() => _BarcodeCameraSheetState();
}

class _BarcodeCameraSheetState extends State<_BarcodeCameraSheet> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    // When a controller is supplied we own its lifecycle; start it ourselves.
    // Guarded so it's harmless if the widget already started it.
    unawaited(_startCamera());
  }

  Future<void> _startCamera() async {
    try {
      await _controller.start();
    } catch (_) {
      // Already started, or no camera available — the preview handles the rest.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(
          BarcodeScanResult(
            value: value,
            format: CardWalletScanner.mapFormat(barcode.format),
          ),
        );
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: luma.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: luma.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Scan a barcode',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Point the camera at the card’s barcode or QR code.',
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 300,
                child: MobileScanner(
                  controller: _controller,
                  fit: BoxFit.cover,
                  onDetect: _onDetect,
                ),
              ),
            ),
            const SizedBox(height: 16),
            LumaGhostButton(
              label: 'Cancel',
              expand: true,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add / edit sheet. When [existing] is null this creates a new card;
/// otherwise it edits that card in place.
void _showCardEditor(
  BuildContext context,
  CardWalletRepository repo, {
  WalletCardRecord? existing,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => _CardEditorDialog(repo: repo, existing: existing),
  );
}

class _CardEditorDialog extends StatefulWidget {
  const _CardEditorDialog({required this.repo, this.existing});
  final CardWalletRepository repo;
  final WalletCardRecord? existing;

  @override
  State<_CardEditorDialog> createState() => _CardEditorDialogState();
}

class _CardEditorDialogState extends State<_CardEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _code;
  late final TextEditingController _notes;
  late CardFormat _format;
  late int _color;
  bool _saving = false;
  bool _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _category = TextEditingController(text: e?.category ?? '');
    _code = TextEditingController(text: e?.code ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _format = e?.format ?? CardFormat.code128;
    _color = e?.color ?? _cardColors.first;
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _code.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Opens the tap-to-scan sheet and, if a tag is read, drops its payload into
  /// the code field.
  Future<void> _scanNfc() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final result = await showModalBottomSheet<NfcScanResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _NfcScanSheet(),
    );
    if (!mounted) return;
    setState(() => _scanning = false);
    if (result == null) return;
    _code.text = result.payload;
    setState(() {});
    messenger.showSnackBar(
      SnackBar(content: Text('Scanned tag (${result.source})')),
    );
  }

  /// Opens the live camera scanner and drops the first barcode it reads into
  /// the value field, switching the format to match the symbology.
  Future<void> _scanCamera() async {
    final result = await showModalBottomSheet<BarcodeScanResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _BarcodeCameraSheet(),
    );
    if (!mounted || result == null) return;
    _applyScan(result);
  }

  /// Lets the user pick a screenshot / photo and decodes any barcode in it.
  Future<void> _scanImage() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = (picked != null && picked.files.isNotEmpty)
        ? picked.files.first.path
        : null;
    if (path == null || !mounted) return;
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final result = await CardWalletScanner.scanImage(path);
      if (!mounted) return;
      if (result == null) {
        setState(() => _error = 'No barcode or QR code found in that image.');
        return;
      }
      _applyScan(result);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not read that image. ($e)');
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Applies a decoded barcode: fills the value and, when the symbology is one
  /// luma can render, selects the matching format automatically.
  void _applyScan(BarcodeScanResult result) {
    _code.text = result.value;
    setState(() {
      if (result.format != null) _format = result.format!;
      _error = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.format != null
              ? 'Scanned ${result.format!.label}'
              : 'Scanned code',
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final code = _code.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the card a name.');
      return;
    }
    if (code.isEmpty) {
      setState(() => _error = _format.isNfc
          ? 'Enter the NFC tag data.'
          : 'Enter the card number / barcode value.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final category = _category.text.trim();
    final notes = _notes.text.trim();
    try {
      if (widget.existing == null) {
        await widget.repo.add(
          name: name,
          code: code,
          format: _format,
          color: _color,
          category: category.isEmpty ? null : category,
          notes: notes.isEmpty ? null : notes,
        );
      } else {
        await widget.repo.update(
          widget.existing!.id,
          name: name,
          code: code,
          format: _format,
          color: _color,
          category: category.isEmpty ? null : category,
          notes: notes.isEmpty ? null : notes,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the card. ($e)';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final editing = widget.existing != null;
    return Dialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                editing ? 'Edit card' : 'Add card',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _label(luma, 'Name'),
              const SizedBox(height: 6),
              TextField(
                controller: _name,
                autofocus: !editing,
                style: TextStyle(color: luma.textPrimary),
                decoration: _dec(luma, hint: 'Albert Heijn Bonuskaart'),
              ),
              const SizedBox(height: 14),
              _label(luma, 'Category (optional)'),
              const SizedBox(height: 6),
              TextField(
                controller: _category,
                style: TextStyle(color: luma.textPrimary),
                decoration: _dec(luma, hint: 'Loyalty, Membership, Transit…'),
              ),
              const SizedBox(height: 14),
              _label(luma, 'Format'),
              const SizedBox(height: 6),
              _FormatDropdown(
                value: _format,
                onChanged: (f) => setState(() {
                  _format = f;
                  _error = null;
                }),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _label(
                      luma,
                      _format.isNfc
                          ? 'NFC tag data'
                          : 'Card number / barcode value',
                    ),
                  ),
                  if (_format.isNfc && CardWalletNfc.isSupported)
                    LumaGhostButton(
                      label: 'Scan tag',
                      icon: Icons.contactless_rounded,
                      onTap: _scanning ? null : _scanNfc,
                    ),
                ],
              ),
              if (!_format.isNfc &&
                  (CardWalletScanner.cameraSupported ||
                      CardWalletScanner.imageSupported)) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (CardWalletScanner.cameraSupported)
                      Expanded(
                        child: LumaGhostButton(
                          label: 'Scan',
                          icon: Icons.qr_code_scanner_rounded,
                          expand: true,
                          onTap: _scanning ? null : _scanCamera,
                        ),
                      ),
                    if (CardWalletScanner.cameraSupported &&
                        CardWalletScanner.imageSupported)
                      const SizedBox(width: 10),
                    if (CardWalletScanner.imageSupported)
                      Expanded(
                        child: LumaGhostButton(
                          label: 'From image',
                          icon: Icons.image_outlined,
                          expand: true,
                          onTap: _scanning ? null : _scanImage,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              TextField(
                controller: _code,
                style: TextStyle(color: luma.textPrimary),
                maxLines: _format.isNfc ? 3 : 1,
                decoration: _dec(luma,
                    hint: _format.isNfc
                        ? (CardWalletNfc.isSupported
                            ? 'Tap “Scan tag”, or paste it (text or hex)'
                            : 'Paste the tag payload (text or hex)')
                        : ((CardWalletScanner.cameraSupported ||
                                CardWalletScanner.imageSupported)
                            ? 'Scan it in above, or type it — e.g. 2601234567890'
                            : 'e.g. 2601234567890')),
              ),
              const SizedBox(height: 14),
              _CodePreview(format: _format, code: _code.text.trim()),
              const SizedBox(height: 16),
              _label(luma, 'Color'),
              const SizedBox(height: 8),
              _ColorPicker(
                selected: _color,
                onSelect: (c) => setState(() => _color = c),
              ),
              const SizedBox(height: 14),
              _label(luma, 'Notes (optional)'),
              const SizedBox(height: 6),
              TextField(
                controller: _notes,
                style: TextStyle(color: luma.textPrimary),
                maxLines: 2,
                decoration: _dec(luma, hint: 'PIN, member since, anything handy'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(color: luma.danger, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  LumaGhostButton(
                    label: 'Cancel',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  LumaPrimaryButton(
                    label: editing ? 'Save' : 'Add card',
                    loading: _saving,
                    onTap: _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live preview of the code as-typed, so you can see the barcode "mimic" the
/// pass before saving.
class _CodePreview extends StatelessWidget {
  const _CodePreview({required this.format, required this.code});
  final CardFormat format;
  final String code;

  @override
  Widget build(BuildContext context) {
    if (format.isNfc) {
      return Container(
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.nfc_rounded, color: Colors.black54, size: 26),
            const SizedBox(height: 4),
            Text(
              code.isEmpty ? 'NFC tag' : 'NFC tag ready',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      );
    }
    final barcode = format.barcode!;
    final is2d = format.is2d;
    return Container(
      height: is2d ? 150 : 84,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: code.isEmpty
            ? const Text('Preview appears here',
                style: TextStyle(color: Colors.black38, fontSize: 12))
            : BarcodeWidget(
                barcode: barcode,
                data: code,
                drawText: !is2d,
                color: Colors.black,
                backgroundColor: Colors.white,
                style: const TextStyle(color: Colors.black, fontSize: 12),
                errorBuilder: (context, _) => Text(
                  "Not valid for ${format.label} yet",
                  style: const TextStyle(color: Colors.black38, fontSize: 12),
                ),
              ),
      ),
    );
  }
}

class _FormatDropdown extends StatelessWidget {
  const _FormatDropdown({required this.value, required this.onChanged});
  final CardFormat value;
  final ValueChanged<CardFormat> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CardFormat>(
          value: value,
          isExpanded: true,
          dropdownColor: luma.surface,
          borderRadius: BorderRadius.circular(12),
          icon: Icon(Icons.expand_more_rounded, color: luma.textSecondary),
          style: TextStyle(color: luma.textPrimary, fontSize: 14),
          items: [
            for (final f in CardFormat.values)
              DropdownMenuItem(
                value: f,
                child: Row(
                  children: [
                    Icon(
                      f.isNfc ? Icons.nfc_rounded : Icons.qr_code_2_rounded,
                      size: 16,
                      color: luma.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Text(f.label),
                  ],
                ),
              ),
          ],
          onChanged: (f) {
            if (f != null) onChanged(f);
          },
        ),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in _cardColors)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onSelect(c),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c == selected ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: c == selected
                      ? [
                          BoxShadow(
                            color: Color(c).withValues(alpha: 0.6),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: c == selected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 18)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

Widget _label(LumaPalette luma, String text) => Text(
      text,
      style: TextStyle(
        color: luma.textSecondary,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    );

InputDecoration _dec(LumaPalette luma, {String? hint}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: TextStyle(color: luma.textMuted, fontSize: 13),
    filled: true,
    fillColor: luma.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: border(luma.border),
    focusedBorder: border(luma.accent),
  );
}

Future<bool> _confirmDelete(BuildContext context) async {
  final luma = context.luma;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: luma.surface,
      title: Text('Delete card?', style: TextStyle(color: luma.textPrimary)),
      content: Text(
        'This removes the card from your wallet on this device.',
        style: TextStyle(color: luma.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('Delete', style: TextStyle(color: luma.danger)),
        ),
      ],
    ),
  );
  return result ?? false;
}

void _copy(BuildContext context, String value) {
  Clipboard.setData(ClipboardData(text: value));
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Copied to clipboard')),
  );
}

/// Shifts [c] lighter (positive [amount]) or darker (negative) in HSL space.
Color _shade(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}
