import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/luma_theme.dart';

Future<String?> showPinDialog(BuildContext context, {required String title}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PinDialog(title: title),
  );
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title});
  final String title;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _controller = TextEditingController();
  String? _error;

  void _submit() {
    final pin = _controller.text;
    if (pin.length != 8) {
      setState(() => _error = 'PIN must be exactly 8 digits.');
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.title,
        style: TextStyle(color: luma.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 8,
            style: TextStyle(color: luma.textPrimary, letterSpacing: 8, fontSize: 24),
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
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
          child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: luma.accent,
            foregroundColor: luma.surface,
          ),
          onPressed: _submit,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
