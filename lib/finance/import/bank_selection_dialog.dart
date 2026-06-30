import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../data/database.dart';
import '../finance_repository.dart';
import '../../theme/luma_theme.dart';
import 'buut_parser.dart';
import 'ing_parser.dart';
import 'import_models.dart';
import 'import_review_dialog.dart';

/// First step of the import flow: pick a supported bank, then pick the file.
///
/// The bank-selection dialog only parses the file and returns the parsed
/// entries via [Navigator.pop]. The review dialog is then opened from this
/// function using the caller's [context] — which outlives the popped dialog —
/// so we never touch a disposed [State]'s context across the transition.
Future<void> showImportFlow(
  BuildContext context, {
  required FinanceRepository repo,
  required List<Pot> pots,
  required List<Category> categories,
  required List<Merchant> merchants,
}) async {
  final entries = await showDialog<List<ParsedBankEntry>>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: context.luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: const _BankSelectionBody(),
      ),
    ),
  );

  if (entries == null || entries.isEmpty) return;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: dialogContext.luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          // Clamp so a minimized window (height 0) can't produce a negative
          // constraint, which would throw during layout.
          maxHeight:
              (MediaQuery.of(dialogContext).size.height - 48).clamp(240.0, 760.0),
        ),
        child: ImportReviewDialog(
          repo: repo,
          entries: entries,
          pots: pots,
          categories: categories,
          merchants: merchants,
        ),
      ),
    ),
  );
}

class _BankSelectionBody extends StatefulWidget {
  const _BankSelectionBody();

  @override
  State<_BankSelectionBody> createState() => _BankSelectionBodyState();
}

class _BankSelectionBodyState extends State<_BankSelectionBody> {
  bool _picking = false;
  String? _error;

  Future<void> _pickFile(SupportedBank bank) async {
    setState(() {
      _picking = true;
      _error = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: bank.allowedExtensions,
        dialogTitle: 'Select ${bank.name} statement',
      );

      if (result == null || result.files.single.path == null) {
        setState(() => _picking = false);
        return;
      }

      final path = result.files.single.path!;
      List<ParsedBankEntry> entries;

      switch (bank.id) {
        case 'buut':
          entries = await BuutParser.parseFile(path);
          break;
        case 'ing':
          entries = await IngParser.parseFile(path);
          break;
        default:
          throw UnsupportedError('Bank ${bank.name} is not yet implemented.');
      }

      if (entries.isEmpty) {
        setState(() {
          _picking = false;
          _error = 'No transactions found in the selected file.';
        });
        return;
      }

      if (!mounted) return;
      // Hand the parsed entries back to showImportFlow, which opens the review
      // dialog using the caller's (still-mounted) context.
      Navigator.of(context).pop(entries);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _error = 'Failed to read file: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Import data',
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select your bank to import transactions from a statement file.',
            style: TextStyle(color: luma.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: supportedBanks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final bank = supportedBanks[i];
                return _BankTile(
                  bank: bank,
                  onTap: _picking ? null : () => _pickFile(bank),
                );
              },
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: luma.danger, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          if (_picking) ...[
            const SizedBox(height: 12),
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              LumaGhostButton(
                label: 'Cancel',
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BankTile extends StatelessWidget {
  const _BankTile({required this.bank, required this.onTap});
  final SupportedBank bank;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: luma.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: luma.border),
          ),
          child: Row(
            children: [
              Text(bank.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bank.name,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${bank.fileTypeLabel} file',
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: luma.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
