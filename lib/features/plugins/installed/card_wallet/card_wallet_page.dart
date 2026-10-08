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
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'card_formats.dart';
import 'card_wallet_nfc.dart';
import 'card_wallet_platform.dart';
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
    final t = L.of(context);
    final repo = CardWalletScope.of(context);
    final canManage = CardWalletPlatform.canManageCards;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => _showCardEditor(context, repo),
              backgroundColor: luma.accent,
              foregroundColor: luma.onAccent,
              tooltip: t.cardWalletAddCard,
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
      body: SingleChildScrollView(
        // Extra bottom padding so the last card clears the floating button.
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: StreamData<List<WalletCardRecord>>(
              stream: repo.watchAll(),
              builder: (context, cards) {
                if (cards.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: LumaEmptyState(
                      icon: Icons.wallet_rounded,
                      title: t.cardWalletNoCardsTitle,
                      subtitle: canManage
                          ? t.cardWalletNoCardsSubtitle
                          : CardWalletPlatform.readOnlyNotice,
                      action: canManage
                          ? LumaPrimaryButton(
                              label: t.cardWalletAddCard,
                              icon: Icons.add_rounded,
                              onTap: () => _showCardEditor(context, repo),
                            )
                          : null,
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
                        onTap: () => _showCardDetail(context, repo, cards[i]),
                      ),
                    ],
                    if (!canManage) ...[
                      const SizedBox(height: 20),
                      const _ReadOnlyNote(),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Footer shown on the desktop builds, which can present cards but not make
/// them — see [CardWalletPlatform].
class _ReadOnlyNote extends StatelessWidget {
  const _ReadOnlyNote();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.smartphone_rounded, color: luma.textMuted, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              CardWalletPlatform.readOnlyNotice,
              style: TextStyle(
                color: luma.textMuted,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
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
    final t = L.of(context);
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
              _tilePreview(card, t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tilePreview(WalletCardRecord card, L t) {
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
              t.cardWalletTapToScan,
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
      final t = L.of(dialogContext);
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
                      tooltip: t.commonDelete,
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
                    if (CardWalletPlatform.canManageCards) ...[
                      LumaGhostButton(
                        label: t.commonEdit,
                        icon: Icons.edit_rounded,
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          _showCardEditor(context, repo, existing: card);
                        },
                      ),
                      const SizedBox(width: 10),
                    ],
                    LumaPrimaryButton(
                      label: t.commonDone,
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
    final t = L.of(context);
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
                ? Text(t.cardWalletNoCodeToShow,
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
                          t.cardWalletValueNotValidFor(card.format.label),
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
              label: t.commonCopy,
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
    final t = L.of(context);
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
                  card.code.isEmpty ? t.cardWalletEmptyTag : card.code,
                  style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              LumaGhostButton(
                label: t.commonCopy,
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
                t.cardWalletEmulationNote,
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
          _error = L.of(context).cardWalletScanUnexpectedError('$e');
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
    final t = L.of(context);
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
                  ? t.cardWalletCouldntScan
                  : (_scanning
                      ? t.cardWalletReadyToScan
                      : t.cardWalletScanATag),
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? t.cardWalletHoldFlat,
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textMuted, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: LumaGhostButton(
                    label: t.commonCancel,
                    expand: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: LumaPrimaryButton(
                      label: t.commonTryAgain,
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
    final t = L.of(context);
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
              t.cardWalletScanBarcodeTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.cardWalletScanBarcodeHint,
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
              label: t.commonCancel,
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

  /// While on, the format follows whatever [detectCardFormat] makes of the
  /// value. Turned off by anything the user picks by hand in Advanced. New
  /// cards start automatic; editing an existing one leaves its stored format
  /// alone until the user asks for detection.
  late bool _autoFormat;
  CardFormatGuess? _guess;
  bool _advancedOpen = false;
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
    _autoFormat = e == null;
    _guess = detectCardFormat(_code.text);
    if (_autoFormat && _guess != null) _format = _guess!.format;
    _code.addListener(_onCodeChanged);
  }

  /// Turns detection back on — and applies it straight away, so the format
  /// catches up with whatever is already in the field.
  void _setAutoFormat(bool value) {
    setState(() {
      _autoFormat = value;
      _error = null;
      if (value) {
        final guess = detectCardFormat(_code.text);
        _guess = guess;
        if (guess != null) _format = guess.format;
      }
    });
  }

  /// Re-reads the value on every keystroke: the preview always refreshes, and
  /// while [_autoFormat] is on the symbology follows along.
  void _onCodeChanged() {
    final guess = detectCardFormat(_code.text);
    setState(() {
      _guess = guess;
      if (_autoFormat && guess != null) {
        _format = guess.format;
        _error = null;
      }
    });
  }

  @override
  void dispose() {
    _code.removeListener(_onCodeChanged);
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
    final t = L.of(context);
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
      SnackBar(
        content: Text(
          t.cardWalletScannedTag(_nfcSourceLabel(t, result.source)),
        ),
      ),
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
    final picked = await FilePicker.pickFiles(type: FileType.image);
    final path = (picked != null && picked.files.isNotEmpty)
        ? picked.files.first.path
        : null;
    if (path == null || !mounted) return;
    final t = L.of(context);
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final result = await CardWalletScanner.scanImage(path);
      if (!mounted) return;
      if (result == null) {
        setState(() => _error = t.cardWalletNoCodeInImage);
        return;
      }
      _applyScan(result);
    } catch (e) {
      if (mounted) {
        setState(() => _error = t.cardWalletImageReadFailed('$e'));
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Applies a decoded barcode: fills the value and picks the format. The
  /// scanner read the real symbology off the code, so it wins over detection;
  /// when it reports one luma can't render (Code 93, MaxiCode…), the value
  /// still lands and [_onCodeChanged] has already inferred a carrier for it.
  void _applyScan(BarcodeScanResult result) {
    _code.text = result.value;
    setState(() {
      if (result.format != null) _format = result.format!;
      _error = null;
    });
    final t = L.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.cardWalletScannedFormat(_format.label))),
    );
  }

  Future<void> _save() async {
    final t = L.of(context);
    final name = _name.text.trim();
    final code = _code.text.trim();
    if (name.isEmpty) {
      setState(() => _error = t.cardWalletNameRequired);
      return;
    }
    if (code.isEmpty) {
      setState(() => _error = _format.isNfc
          ? t.cardWalletEnterNfcData
          : t.cardWalletEnterCardNumber);
      return;
    }
    // Only reachable with a hand-picked format: detection never returns one
    // the encoder rejects.
    if (!_format.accepts(code)) {
      setState(() {
        _advancedOpen = true;
        _error = t.cardWalletCantEncodeAs(_format.label);
      });
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
          _error = t.cardWalletSaveFailed('$e');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final editing = widget.existing != null;
    final t = L.of(context);
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
                editing ? t.cardWalletEditCard : t.cardWalletAddCard,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _label(luma, t.commonName),
              const SizedBox(height: 6),
              TextField(
                controller: _name,
                autofocus: !editing,
                style: TextStyle(color: luma.textPrimary),
                decoration: _dec(luma, hint: t.cardWalletNameHintExample),
              ),
              const SizedBox(height: 14),
              _label(luma, t.cardWalletCategoryOptional),
              const SizedBox(height: 6),
              TextField(
                controller: _category,
                style: TextStyle(color: luma.textPrimary),
                decoration: _dec(luma, hint: t.cardWalletCategoryHint),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _label(
                      luma,
                      _format.isNfc
                          ? t.cardWalletNfcTagData
                          : t.cardWalletCardNumberLabel,
                    ),
                  ),
                  if (_format.isNfc && CardWalletNfc.isSupported)
                    LumaGhostButton(
                      label: t.cardWalletScanTag,
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
                          label: t.cardWalletScan,
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
                          label: t.cardWalletFromImage,
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
                            ? t.cardWalletNfcHintScanOrPaste
                            : t.cardWalletNfcHintPaste)
                        : ((CardWalletScanner.cameraSupported ||
                                CardWalletScanner.imageSupported)
                            ? t.cardWalletCodeHintScan
                            : t.cardWalletCodeHint)),
              ),
              const SizedBox(height: 10),
              _FormatStatus(
                format: _format,
                guess: _guess,
                auto: _autoFormat,
                onOpenAdvanced: () => setState(() => _advancedOpen = true),
              ),
              const SizedBox(height: 14),
              _CodePreview(format: _format, code: _code.text.trim()),
              const SizedBox(height: 16),
              _label(luma, t.commonColor),
              const SizedBox(height: 8),
              _ColorPicker(
                selected: _color,
                onSelect: (c) => setState(() => _color = c),
              ),
              const SizedBox(height: 14),
              _label(luma, t.cardWalletNotesOptional),
              const SizedBox(height: 6),
              TextField(
                controller: _notes,
                style: TextStyle(color: luma.textPrimary),
                maxLines: 2,
                decoration: _dec(luma, hint: t.cardWalletNotesHint),
              ),
              const SizedBox(height: 18),
              _AdvancedSection(
                open: _advancedOpen,
                onToggle: () => setState(() => _advancedOpen = !_advancedOpen),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AutoDetectSwitch(
                      value: _autoFormat,
                      onChanged: _setAutoFormat,
                    ),
                    const SizedBox(height: 14),
                    _label(luma, t.cardWalletFormat),
                    const SizedBox(height: 6),
                    _FormatDropdown(
                      value: _format,
                      onChanged: (f) => setState(() {
                        _format = f;
                        _autoFormat = false;
                        _error = null;
                      }),
                    ),
                  ],
                ),
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
                    label: t.commonCancel,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  LumaPrimaryButton(
                    label: editing ? t.commonSave : t.cardWalletAddCard,
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

/// The one-line answer to "what did luma make of this?", sitting under the
/// value field: which format is in play, whether it was recognized or chosen,
/// and a way through to Advanced.
class _FormatStatus extends StatelessWidget {
  const _FormatStatus({
    required this.format,
    required this.guess,
    required this.auto,
    required this.onOpenAdvanced,
  });

  final CardFormat format;
  final CardFormatGuess? guess;
  final bool auto;
  final VoidCallback onOpenAdvanced;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final recognized = auto && (guess?.confident ?? false);
    final waiting = auto && guess == null;
    final icon = !auto
        ? Icons.tune_rounded
        : (recognized ? Icons.auto_awesome_rounded : Icons.edit_note_rounded);
    final color = recognized ? luma.success : luma.textMuted;
    final String text;
    if (!auto) {
      text = t.cardWalletDetectionOff(format.label);
    } else if (waiting) {
      text = t.cardWalletStatusWaiting;
    } else if (recognized) {
      text = t.cardWalletRecognizedAs(format.label);
    } else {
      text = t.cardWalletNoStandardMatch(format.label);
    }
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 12.5),
          ),
        ),
        const SizedBox(width: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onOpenAdvanced,
            child: Text(
              t.cardWalletChange,
              style: TextStyle(
                color: luma.accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Collapsed-by-default disclosure at the bottom of the editor holding the
/// manual format controls. Everything above it works without ever opening it.
class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection({
    required this.open,
    required this.onToggle,
    required this.child,
  });

  final bool open;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Container(
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, size: 16, color: luma.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.cardWalletAdvanced,
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: luma.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: child,
            ),
        ],
      ),
    );
  }
}

/// The switch that hands the format back to [detectCardFormat].
class _AutoDetectSwitch extends StatelessWidget {
  const _AutoDetectSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.cardWalletAutoDetect,
                style: TextStyle(color: luma.textPrimary, fontSize: 13.5),
              ),
              const SizedBox(height: 2),
              Text(
                t.cardWalletAutoDetectHint,
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: luma.onAccent,
          activeTrackColor: luma.accent,
          inactiveThumbColor: luma.textSecondary,
          inactiveTrackColor: luma.surfaceHover,
        ),
      ],
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
    final t = L.of(context);
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
              code.isEmpty ? t.cardWalletFormatNfc : t.cardWalletNfcTagReady,
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
            ? Text(t.cardWalletPreviewHere,
                style: const TextStyle(color: Colors.black38, fontSize: 12))
            : BarcodeWidget(
                barcode: barcode,
                data: code,
                drawText: !is2d,
                color: Colors.black,
                backgroundColor: Colors.white,
                style: const TextStyle(color: Colors.black, fontSize: 12),
                errorBuilder: (context, _) => Text(
                  t.cardWalletNotValidYet(format.label),
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
  final t = L.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: luma.surface,
      title: Text(t.cardWalletDeleteTitle,
          style: TextStyle(color: luma.textPrimary)),
      content: Text(
        t.cardWalletDeleteBody,
        style: TextStyle(color: luma.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(t.commonCancel,
              style: TextStyle(color: luma.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(t.commonDelete, style: TextStyle(color: luma.danger)),
        ),
      ],
    ),
  );
  return result ?? false;
}

void _copy(BuildContext context, String value) {
  Clipboard.setData(ClipboardData(text: value));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(L.of(context).commonCopiedToClipboard)),
  );
}

String _nfcSourceLabel(L t, NfcScanSource source) => switch (source) {
      NfcScanSource.mifareClassic => 'MIFARE Classic',
      NfcScanSource.mifareUltralight => 'MIFARE Ultralight',
      NfcScanSource.ndefRecord => t.cardWalletSourceNdef,
      NfcScanSource.tagUid => t.cardWalletSourceTagUid,
    };

/// Shifts [c] lighter (positive [amount]) or darker (negative) in HSL space.
Color _shade(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}
