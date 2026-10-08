import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/luma_theme.dart';

/// Opens [child] in the standard finance editor dialog shell.
Future<T?> showFinanceDialog<T>(
  BuildContext context,
  Widget child, {
  double maxWidth = 440,
}) {
  return showDialog<T>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: context.luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    ),
  );
}

/// Title, scrollable body and Cancel / confirm buttons for an editor dialog.
class FinanceDialogScaffold extends StatelessWidget {
  const FinanceDialogScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.confirmLabel,
    required this.onConfirm,
    this.error,
    this.saving = false,
    this.leading,
  });

  final String title;
  final List<Widget> children;
  final String confirmLabel;
  final VoidCallback? onConfirm;
  final String? error;
  final bool saving;

  /// Optional button pinned to the left of the action row (e.g. Delete).
  final Widget? leading;

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
            title,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: TextStyle(color: luma.danger, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              ?leading,
              const Spacer(),
              LumaGhostButton(
                label: L.of(context).commonCancel,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 10),
              LumaPrimaryButton(
                label: confirmLabel,
                icon: Icons.check_rounded,
                loading: saving,
                onTap: onConfirm,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A labelled text field in the finance editors' style.
class FinanceField extends StatelessWidget {
  const FinanceField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.prefix,
    this.suffix,
    this.number = false,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? prefix;
  final String? suffix;
  final bool number;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinanceLabel(label),
        TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: TextStyle(color: luma.textPrimary),
          decoration: financeInputDecoration(
            luma,
            hint: hint,
            prefix: prefix,
            suffix: suffix,
          ),
        ),
      ],
    );
  }
}

InputDecoration financeInputDecoration(
  LumaPalette luma, {
  String? hint,
  String? prefix,
  String? suffix,
}) {
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: TextStyle(color: luma.textMuted),
    prefixText: prefix,
    prefixStyle: TextStyle(color: luma.textSecondary),
    suffixText: suffix,
    suffixStyle: TextStyle(color: luma.textSecondary),
    filled: true,
    fillColor: luma.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: luma.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: luma.accent),
    ),
  );
}

class FinanceLabel extends StatelessWidget {
  const FinanceLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        color: context.luma.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// A tappable date box that opens the date picker; [onClear] adds a clear
/// button for optional dates.
class FinanceDateField extends StatelessWidget {
  const FinanceDateField({
    super.key,
    required this.label,
    required this.date,
    required this.onChanged,
    this.placeholder,
    this.onClear,
    this.firstDate,
  });

  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onChanged;
  final String? placeholder;
  final VoidCallback? onClear;
  final DateTime? firstDate;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinanceLabel(label),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? now,
              firstDate: firstDate ?? DateTime(now.year - 30),
              lastDate: DateTime(now.year + 50),
            );
            if (picked != null) onChanged(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: luma.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: luma.border),
            ),
            child: Row(
              children: [
                Icon(Icons.event_rounded, size: 18, color: luma.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    date == null
                        ? placeholder ?? L.of(context).financePickDate
                        : longDate(date!),
                    style: TextStyle(
                      color: date == null ? luma.textMuted : luma.textPrimary,
                    ),
                  ),
                ),
                if (date != null && onClear != null)
                  InkWell(
                    onTap: onClear,
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: luma.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A checkbox row with a one-line explanation.
class FinanceCheckRow extends StatelessWidget {
  const FinanceCheckRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Checkbox(
            value: value,
            activeColor: luma.accent,
            onChanged: (v) => onChanged(v ?? false),
          ),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: luma.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// A red confirm dialog; resolves true when the user confirms.
Future<bool> confirmFinanceDelete(
  BuildContext context,
  String title,
  String message,
) async {
  final luma = context.luma;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: luma.surface,
      title: Text(title, style: TextStyle(color: luma.textPrimary)),
      content: Text(message, style: TextStyle(color: luma.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(
            L.of(context).commonCancel,
            style: TextStyle(color: luma.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(
            L.of(context).commonDelete,
            style: TextStyle(color: luma.danger),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// "27 Sep 2026".
String longDate(DateTime d) => DateFormat('d MMM y').format(d);

/// "27 Sep".
String shortDate(DateTime d) => DateFormat('d MMM').format(d);

/// "Sep 2026".
String monthYear(DateTime d) => DateFormat('MMM y').format(d);
