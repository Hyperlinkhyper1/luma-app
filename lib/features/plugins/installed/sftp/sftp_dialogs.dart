import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'sftp_paths.dart';
import 'sftp_session.dart';

/// A secret the user typed, plus whether they asked luma to remember it.
typedef SecretAnswer = ({String secret, bool save});

/// Wraps [child] in the dialog chrome every prompt here shares.
Future<T?> _showLumaDialog<T>(
  BuildContext context, {
  required String title,
  required IconData icon,
  required Widget Function(BuildContext context, void Function(T?) close) body,
  Color? iconColor,
}) {
  final luma = context.luma;
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: luma.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LumaIconBadge(
                    icon: icon,
                    color: iconColor ?? luma.accent,
                    size: 34,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              body(context, (value) => Navigator.of(context).pop(value)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The fingerprint check. Shown before any credential is sent, because on an
/// unknown key that is the only moment the user can still say no.
Future<bool> showHostKeyDialog(
  BuildContext context,
  SftpHostKeyPrompt prompt,
) async {
  final result = await _showLumaDialog<bool>(
    context,
    title: prompt.changed
        ? 'This server\'s key has changed'
        : 'Unknown server key',
    icon: prompt.changed
        ? Icons.gpp_maybe_rounded
        : Icons.vpn_key_off_rounded,
    iconColor: prompt.changed ? context.luma.danger : context.luma.accent,
    body: (context, close) {
      final luma = context.luma;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prompt.changed
                ? 'A different key was trusted for ${prompt.host} before. '
                    'Either the server was rebuilt, or something is '
                    'impersonating it. Do not continue unless you know the '
                    'server changed.'
                : 'luma has never connected to ${prompt.host} before. Check '
                    'the fingerprint against the one on the server, then '
                    'decide whether to trust it.',
            style: TextStyle(color: luma.textSecondary, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 14),
          _FingerprintBox(
            label: '${prompt.keyType} · ${prompt.host}:${prompt.port}',
            fingerprint: prompt.fingerprint,
          ),
          if (prompt.previousFingerprint != null) ...[
            const SizedBox(height: 8),
            _FingerprintBox(
              label: 'Previously trusted',
              fingerprint: prompt.previousFingerprint!,
              danger: true,
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              LumaGhostButton(label: 'Cancel', onTap: () => close(false)),
              const SizedBox(width: 10),
              LumaPrimaryButton(
                label: prompt.changed ? 'Trust the new key' : 'Trust and connect',
                icon: Icons.verified_user_rounded,
                onTap: () => close(true),
              ),
            ],
          ),
        ],
      );
    },
  );
  return result ?? false;
}

class _FingerprintBox extends StatelessWidget {
  const _FingerprintBox({
    required this.label,
    required this.fingerprint,
    this.danger = false,
  });

  final String label;
  final String fingerprint;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: danger ? luma.danger : luma.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: luma.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 6),
          SelectableText(
            fingerprint,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks for a password or a key passphrase, with the "remember it" tick that
/// decides whether it is ever written to disk.
Future<SecretAnswer?> promptSecret(
  BuildContext context, {
  required String title,
  required String message,
  required bool offerSave,
  bool initialSave = false,
}) {
  final controller = TextEditingController();
  var obscure = true;
  var save = initialSave;

  return _showLumaDialog<SecretAnswer>(
    context,
    title: title,
    icon: Icons.password_rounded,
    body: (context, close) {
      final luma = context.luma;
      void submit() => close((secret: controller.text, save: save));
      return StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(color: luma.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: obscure,
              onSubmitted: (_) => submit(),
              style: TextStyle(color: luma.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  tooltip: obscure ? 'Show' : 'Hide',
                  icon: Icon(
                    obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 18,
                  ),
                  onPressed: () => setState(() => obscure = !obscure),
                ),
              ),
            ),
            if (offerSave) ...[
              const SizedBox(height: 6),
              _CheckRow(
                value: save,
                label: 'Remember it for this site',
                subtitle: 'Encrypted on this device. Never uploaded anywhere.',
                onChanged: (value) => setState(() => save = value),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                LumaGhostButton(label: 'Cancel', onTap: () => close(null)),
                const SizedBox(width: 10),
                LumaPrimaryButton(
                  label: 'Connect',
                  icon: Icons.link_rounded,
                  onTap: submit,
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

/// One-line text prompt — new folder names, renames.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  required IconData icon,
  String initial = '',
  String confirmLabel = 'Save',
}) {
  final controller = TextEditingController(text: initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: initial.length,
    );

  return _showLumaDialog<String>(
    context,
    title: title,
    icon: icon,
    body: (context, close) {
      final luma = context.luma;
      void submit() {
        final value = controller.text.trim();
        if (value.isEmpty) return;
        close(value);
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            onSubmitted: (_) => submit(),
            inputFormatters: [
              // '/' would silently move the file somewhere else instead of
              // renaming it.
              FilteringTextInputFormatter.deny(RegExp(r'[/\\]')),
            ],
            style: TextStyle(color: luma.textPrimary, fontSize: 14),
            decoration: InputDecoration(labelText: label),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              LumaGhostButton(label: 'Cancel', onTap: () => close(null)),
              const SizedBox(width: 10),
              LumaPrimaryButton(
                label: confirmLabel,
                icon: Icons.check_rounded,
                onTap: submit,
              ),
            ],
          ),
        ],
      );
    },
  );
}

/// Confirms a delete, naming what is about to go.
Future<bool> confirmDelete(
  BuildContext context, {
  required List<String> names,
  required bool remote,
  String? extraWarning,
}) async {
  final result = await _showLumaDialog<bool>(
    context,
    title: names.length == 1 ? 'Delete ${names.first}?' : 'Delete ${names.length} items?',
    icon: Icons.delete_forever_rounded,
    iconColor: context.luma.danger,
    body: (context, close) {
      final luma = context.luma;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            remote
                ? 'This deletes them on the server. Folders go with everything '
                    'inside them, and there is no undo.'
                : 'This deletes them on this device. There is no undo.',
            style: TextStyle(color: luma.textSecondary, fontSize: 13, height: 1.45),
          ),
          if (extraWarning != null) ...[
            const SizedBox(height: 8),
            Text(
              extraWarning,
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
          if (names.length > 1) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: luma.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: luma.border),
              ),
              child: SingleChildScrollView(
                child: Text(
                  names.join('\n'),
                  style: TextStyle(color: luma.textSecondary, fontSize: 12),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              LumaGhostButton(label: 'Cancel', onTap: () => close(false)),
              const SizedBox(width: 10),
              LumaPrimaryButton(
                label: 'Delete',
                icon: Icons.delete_outline_rounded,
                onTap: () => close(true),
              ),
            ],
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Edits a remote file's POSIX permissions, in either notation.
Future<int?> promptPermissions(
  BuildContext context, {
  required String name,
  int? current,
}) {
  final controller = TextEditingController(
    text: current == null ? '644' : current.toRadixString(8).padLeft(3, '0'),
  );

  return _showLumaDialog<int>(
    context,
    title: 'Permissions for $name',
    icon: Icons.lock_outline_rounded,
    body: (context, close) {
      final luma = context.luma;
      return StatefulBuilder(
        builder: (context, setState) {
          final parsed = parsePermissions(controller.text);
          void submit() {
            final mode = parsePermissions(controller.text);
            if (mode != null) close(mode);
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => submit(),
                style: TextStyle(color: luma.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Mode',
                  helperText: 'Octal (755) or symbolic (rwxr-xr-x)',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                parsed == null
                    ? 'Not a valid mode.'
                    : '${parsed.toRadixString(8).padLeft(3, '0')} · '
                        '${formatPermissions(parsed)}',
                style: TextStyle(
                  color: parsed == null ? luma.danger : luma.textSecondary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  LumaGhostButton(label: 'Cancel', onTap: () => close(null)),
                  const SizedBox(width: 10),
                  LumaPrimaryButton(
                    label: 'Apply',
                    icon: Icons.check_rounded,
                    onTap: parsed == null ? null : submit,
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}

/// Checkbox + label + explanation, used by the prompts and the site editor.
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.value,
    required this.label,
    required this.onChanged,
    this.subtitle,
  });

  final bool value;
  final String label;
  final String? subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: (next) => onChanged(next ?? false),
                activeColor: luma.accent,
                checkColor: luma.onAccent,
                side: BorderSide(color: luma.border, width: 1.5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: luma.textPrimary, fontSize: 13),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: TextStyle(color: luma.textMuted, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Exposed so the site editor can use the same checkbox row as the prompts.
class SftpCheckRow extends StatelessWidget {
  const SftpCheckRow({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.subtitle,
  });

  final bool value;
  final String label;
  final String? subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => _CheckRow(
        value: value,
        label: label,
        subtitle: subtitle,
        onChanged: onChanged,
      );
}
