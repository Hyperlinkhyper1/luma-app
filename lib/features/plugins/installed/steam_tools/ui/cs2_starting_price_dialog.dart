import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';

/// What the dialog hands back: the grade to track it as, and the cost basis
/// gain/loss will be measured from.
class Cs2StartingPriceResult {
  const Cs2StartingPriceResult({required this.wear, required this.priceCents});

  final String? wear;
  final int priceCents;
}

/// Prompts for a starting price — and, when tracking hasn't started yet,
/// which wear/grade it applies to — before a listing starts being watched
/// or an existing baseline is changed.
///
/// Grade only shows up here as a selector the first time: once a listing is
/// tracked, its wear *is* the listing (see `cs2MarketHashName`), so editing
/// the baseline later shows the grade as a fixed fact instead of a control.
Future<Cs2StartingPriceResult?> showCs2StartingPriceDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<String> wears,
  required String? wear,
  required bool wearEditable,
  int? suggestedCents,
}) =>
    showDialog<Cs2StartingPriceResult>(
      context: context,
      builder: (_) => _Cs2StartingPriceDialog(
        title: title,
        subtitle: subtitle,
        wears: wears,
        initialWear: wear,
        wearEditable: wearEditable,
        suggestedCents: suggestedCents,
      ),
    );

class _Cs2StartingPriceDialog extends StatefulWidget {
  const _Cs2StartingPriceDialog({
    required this.title,
    required this.subtitle,
    required this.wears,
    required this.initialWear,
    required this.wearEditable,
    required this.suggestedCents,
  });

  final String title;
  final String subtitle;
  final List<String> wears;
  final String? initialWear;
  final bool wearEditable;
  final int? suggestedCents;

  @override
  State<_Cs2StartingPriceDialog> createState() =>
      _Cs2StartingPriceDialogState();
}

class _Cs2StartingPriceDialogState extends State<_Cs2StartingPriceDialog> {
  late String? _wear = widget.initialWear;
  late final _priceController = TextEditingController(
    text: widget.suggestedCents == null
        ? ''
        : (widget.suggestedCents! / 100).toStringAsFixed(2),
  );
  final _priceFocus = FocusNode();
  String? _priceError;

  @override
  void dispose() {
    _priceController.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _priceController.text.trim().replaceAll(',', '.');
    final value = double.tryParse(raw);
    if (raw.isEmpty || value == null || value < 0) {
      setState(() => _priceError = 'Enter a valid price.');
      _priceFocus.requestFocus();
      return;
    }
    Navigator.of(context).pop(Cs2StartingPriceResult(
      wear: _wear,
      priceCents: (value * 100).round(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    return Dialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: luma.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LumaIconBadge(
                    icon: Icons.flag_rounded,
                    color: luma.accent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style:
                              TextStyle(color: luma.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.wearEditable && widget.wears.length > 1) ...[
                const SizedBox(height: 20),
                _Field(
                  label: 'Grade',
                  helper: 'Wear and price are set together — they can\'t be '
                      'changed independently once tracking starts.',
                  child: LumaSegmentedTabs(
                    tabs: widget.wears,
                    selectedIndex: _wear == null
                        ? 0
                        : widget.wears.indexOf(_wear!).clamp(
                            0, widget.wears.length - 1),
                    onSelect: (i) => setState(() => _wear = widget.wears[i]),
                    scrollable: true,
                  ),
                ),
              ] else if (!widget.wearEditable && widget.initialWear != null) ...[
                const SizedBox(height: 16),
                _Field(
                  label: 'Grade',
                  helper: 'Fixed — this baseline belongs to that exact '
                      'listing.',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: luma.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: luma.border),
                    ),
                    child: Text(
                      widget.initialWear!,
                      style: TextStyle(color: luma.textPrimary, fontSize: 13),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _Field(
                label: 'Starting price',
                helper: 'What you paid, or the price to measure gain and '
                    'loss from — not fetched from Steam.',
                error: _priceError,
                child: TextField(
                  controller: _priceController,
                  focusNode: _priceFocus,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: TextStyle(color: luma.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixText: r'$ ',
                    prefixStyle:
                        TextStyle(color: luma.textSecondary, fontSize: 15),
                    hintText: '0.00',
                    hintStyle: TextStyle(color: luma.textMuted, fontSize: 15),
                    filled: true,
                    fillColor: luma.background,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: _priceError != null
                              ? luma.danger
                              : luma.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: _priceError != null
                              ? luma.danger
                              : luma.accent),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: luma.border),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                  onChanged: (_) {
                    if (_priceError != null) {
                      setState(() => _priceError = null);
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  LumaPrimaryButton(
                    label: 'Save',
                    icon: Icons.check_rounded,
                    onTap: _submit,
                  ),
                  LumaGhostButton(
                    label: 'Cancel',
                    onTap: () => Navigator.of(context).pop(),
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.helper,
    required this.child,
    this.error,
  });

  final String label;
  final String helper;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(helper, style: TextStyle(color: luma.textMuted, fontSize: 11.5)),
        const SizedBox(height: 8),
        child,
        if (error case final message?) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 14, color: luma.danger),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: luma.danger, fontSize: 11.5),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
