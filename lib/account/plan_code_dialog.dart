import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/luma_theme.dart';
import 'plan.dart';

/// Prompts for the access code that unlocks [plan]. Returns the entered
/// code, or null if the user cancelled.
Future<String?> showPlanCodeDialog(BuildContext context, {required Plan plan}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PlanCodeDialog(plan: plan),
  );
}

class _PlanCodeDialog extends StatefulWidget {
  const _PlanCodeDialog({required this.plan});
  final Plan plan;

  @override
  State<_PlanCodeDialog> createState() => _PlanCodeDialogState();
}

class _PlanCodeDialogState extends State<_PlanCodeDialog> {
  final _controller = TextEditingController();
  String? _error;

  void _submit() {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = L.of(context).planCodeEnterCode);
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        t.planCodeUnlockTitle(widget.plan.name),
        style: TextStyle(
            color: luma.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.planCodeBody(widget.plan.name),
            style: TextStyle(color: luma.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            style: TextStyle(color: luma.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: t.planCodeHint,
              hintStyle: TextStyle(color: luma.textMuted),
              errorText: _error,
              errorStyle: TextStyle(color: luma.danger),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: luma.border),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: luma.accent),
                borderRadius: BorderRadius.circular(12),
              ),
              errorBorder: OutlineInputBorder(
                borderSide: BorderSide(color: luma.danger),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: BorderSide(color: luma.danger),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.commonCancel, style: TextStyle(color: luma.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: luma.accent,
            foregroundColor: luma.surface,
          ),
          onPressed: _submit,
          child: Text(t.planCodeUnlockButton),
        ),
      ],
    );
  }
}
