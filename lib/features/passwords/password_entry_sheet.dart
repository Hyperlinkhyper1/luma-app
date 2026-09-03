import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

import '../../app/widgets.dart';
import '../../storage/storage_guard.dart';
import '../../theme/luma_theme.dart';
import 'breach_check.dart';
import 'password_repository.dart';
import 'totp.dart';

/// Opens the add/edit dialog. Pass [existing] to edit; omit it to add.
Future<void> showPasswordEntrySheet(
  BuildContext context, {
  required PasswordRepository repo,
  PasswordRecord? existing,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: context.luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: _PasswordEntryForm(repo: repo, existing: existing),
      ),
    ),
  );
}

class _PasswordEntryForm extends StatefulWidget {
  const _PasswordEntryForm({required this.repo, this.existing});
  final PasswordRepository repo;
  final PasswordRecord? existing;

  @override
  State<_PasswordEntryForm> createState() => _PasswordEntryFormState();
}

class _PasswordEntryFormState extends State<_PasswordEntryForm> {
  late final _service = TextEditingController(text: widget.existing?.service);
  late final _email = TextEditingController(text: widget.existing?.email);
  late final _password = TextEditingController(text: widget.existing?.password);
  late final _username = TextEditingController(text: widget.existing?.username);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _info = TextEditingController(text: widget.existing?.info);
  late final _icon = TextEditingController(text: widget.existing?.icon);
  late final _totpSecret =
      TextEditingController(text: widget.existing?.totpSecret);

  bool _obscure = true;
  bool _saving = false;
  String? _error;
  bool _breachAcknowledged = false;
  BreachChecker? _breachChecker;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    BreachChecker.load().then((checker) {
      if (mounted) setState(() => _breachChecker = checker);
    });
  }

  @override
  void dispose() {
    _service.dispose();
    _email.dispose();
    _password.dispose();
    _username.dispose();
    _phone.dispose();
    _info.dispose();
    _icon.dispose();
    _totpSecret.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final service = _service.text.trim();
    final email = _email.text.trim();
    final password = _password.text;

    if (service.isEmpty) {
      setState(() => _error = 'Enter the service name.');
      return;
    }
    if (email.isEmpty) {
      setState(() => _error = 'Enter the email.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Enter the password.');
      return;
    }
    if (!_breachAcknowledged && (_breachChecker?.isCommon(password) ?? false)) {
      final proceed = await _confirmBreachedPassword();
      if (!mounted) return;
      if (!proceed) return;
      setState(() => _breachAcknowledged = true);
    }
    final totpSecret = _totpSecret.text.trim();
    if (totpSecret.isNotEmpty && Totp.currentCode(totpSecret) == null) {
      setState(() => _error =
          'That doesn\'t look like a valid 2FA secret (should be base32, '
          'e.g. JBSWY3DPEHPK3PXP).');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final draft = PasswordDraft(
      service: service,
      email: email,
      password: password,
      username: _username.text,
      phone: _phone.text,
      info: _info.text,
      icon: _icon.text,
      totpSecret: _totpSecret.text,
    );

    try {
      if (_isEditing) {
        await widget.repo.update(widget.existing!.id, draft);
      } else {
        await widget.repo.add(draft);
      }
    } on StorageLimitExceededException catch (e) {
      if (mounted) setState(() {
        _saving = false;
        _error = '$e';
      });
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirmBreachedPassword() async {
    final luma = context.luma;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: luma.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: luma.border),
        ),
        title: Text('Weak password', style: TextStyle(color: luma.textPrimary)),
        content: Text(
          'This password is on a list of extremely common or previously '
          'breached passwords. Anyone with that list could guess it. Use '
          'the generate button for a strong one, or save it anyway.',
          style: TextStyle(color: luma.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                Text('Save anyway', style: TextStyle(color: luma.danger)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _generatePassword() {
    const lower = 'abcdefghijklmnopqrstuvwxyz';
    const upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const digits = '0123456789';
    const symbols = '!@#\$%^&*()-_=+[]{}?';
    const all = lower + upper + digits + symbols;
    final random = Random.secure();

    final chars = <String>[
      lower[random.nextInt(lower.length)],
      upper[random.nextInt(upper.length)],
      digits[random.nextInt(digits.length)],
      symbols[random.nextInt(symbols.length)],
    ];
    for (var i = chars.length; i < 18; i++) {
      chars.add(all[random.nextInt(all.length)]);
    }
    chars.shuffle(random);

    setState(() {
      _password.text = chars.join();
      _obscure = false;
    });
  }

  Future<void> _pickIconImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final bytes = await File(path).readAsBytes();
        
        // Resize image
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final resized = img.copyResize(decoded, width: 64, height: 64);
          final encoded = img.encodePng(resized);
          final base64String = base64Encode(encoded);
          setState(() {
            _icon.text = 'data:image/png;base64,$base64String';
          });
        }
      }
    } catch (e) {
      setState(() => _error = 'Failed to pick image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.all(22),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Edit credential' : 'New credential',
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _FieldLabel('Service *'),
            TextField(
              controller: _service,
              autofocus: true,
              style: TextStyle(color: luma.textPrimary),
              decoration: pwInputDecoration(luma, hint: 'e.g. Netflix'),
            ),
            const SizedBox(height: 14),
            _FieldLabel('Icon (Optional)'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _icon,
                    style: TextStyle(color: luma.textPrimary),
                    decoration: pwInputDecoration(luma, hint: 'e.g. 🍿'),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Upload PNG',
                  child: IconButton(
                    icon: Icon(Icons.image_rounded, color: luma.textSecondary),
                    onPressed: _pickIconImage,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _FieldLabel('Email *'),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: luma.textPrimary),
              decoration: pwInputDecoration(luma, hint: 'name@example.com'),
            ),
            const SizedBox(height: 14),
            _FieldLabel('Password *'),
            TextField(
              controller: _password,
              obscureText: _obscure,
              style: TextStyle(color: luma.textPrimary),
              decoration: pwInputDecoration(
                luma,
                hint: 'Password',
                suffix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: 'Generate random password',
                      child: IconButton(
                        icon: Icon(
                          Icons.autorenew_rounded,
                          size: 18,
                          color: luma.textSecondary,
                        ),
                        onPressed: _generatePassword,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        size: 18,
                        color: luma.textSecondary,
                      ),
                      tooltip: _obscure ? 'Show' : 'Hide',
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ],
                ),
              ),
              onChanged: (_) {
                if (_breachAcknowledged) {
                  setState(() => _breachAcknowledged = false);
                }
              },
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 14),
            _FieldLabel('Username (optional)'),
            TextField(
              controller: _username,
              style: TextStyle(color: luma.textPrimary),
              decoration: pwInputDecoration(luma, hint: 'e.g. ayden31'),
            ),
            const SizedBox(height: 14),
            _FieldLabel('Phone number (optional)'),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: luma.textPrimary),
              decoration: pwInputDecoration(luma, hint: 'e.g. +31 6 1234 5678'),
            ),
            const SizedBox(height: 14),
            _FieldLabel('Info (optional)'),
            TextField(
              controller: _info,
              maxLines: 3,
              minLines: 2,
              style: TextStyle(color: luma.textPrimary),
              decoration: pwInputDecoration(
                luma,
                hint: 'Security question, recovery codes, notes…',
              ),
            ),
            const SizedBox(height: 14),
            _FieldLabel('2FA secret (optional)'),
            TextField(
              controller: _totpSecret,
              style: TextStyle(
                  color: luma.textPrimary, fontFamily: 'monospace'),
              decoration: pwInputDecoration(
                luma,
                hint: 'Base32 key from the "manual setup" QR fallback',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: luma.danger, fontSize: 13)),
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
                  label: _isEditing ? 'Save changes' : 'Add credential',
                  icon: Icons.check_rounded,
                  loading: _saving,
                  onTap: _save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared input styling for the password forms, mirroring the finance sheet.
InputDecoration pwInputDecoration(
  LumaPalette luma, {
  String? hint,
  Widget? suffix,
}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: TextStyle(color: luma.textMuted),
    suffixIcon: suffix,
    filled: true,
    fillColor: luma.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: border(luma.border),
    focusedBorder: border(luma.accent),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
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
