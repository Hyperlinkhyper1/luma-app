import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
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
  final t = L.of(context);
  final result = await _showLumaDialog<bool>(
    context,
    title: prompt.changed
        ? t.sftpHostKeyChangedTitle
        : t.sftpHostKeyUnknownTitle,
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
                ? t.sftpHostKeyChangedBody(prompt.host)
                : t.sftpHostKeyUnknownBody(prompt.host),
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
              label: t.sftpPreviouslyTrusted,
              fingerprint: prompt.previousFingerprint!,
              danger: true,
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              LumaGhostButton(label: t.commonCancel, onTap: () => close(false)),
              const SizedBox(width: 10),
              LumaPrimaryButton(
                label: prompt.changed
                    ? t.sftpTrustNewKey
                    : t.sftpTrustAndConnect,
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
  final t = L.of(context);
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
                labelText: t.commonPassword,
                suffixIcon: IconButton(
                  tooltip: obscure ? t.sftpShow : t.sftpHide,
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
                label: t.sftpRememberForSite,
                subtitle: t.sftpEncryptedLocalNote,
                onChanged: (value) => setState(() => save = value),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                LumaGhostButton(label: t.commonCancel, onTap: () => close(null)),
                const SizedBox(width: 10),
                LumaPrimaryButton(
                  label: t.sftpConnect,
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

/// What the user filled in to connect to a luma device found on the network.
typedef QuickConnectAnswer = ({int port, String secret, bool save});

/// Connects to a device picked from the network list: the address is already
/// known, the port is filled in from the advertisement but can be changed,
/// and the pairing password has to be typed — discovery never supplies it.
Future<QuickConnectAnswer?> promptQuickConnect(
  BuildContext context, {
  required String deviceName,
  required String address,
  required int port,
}) {
  final t = L.of(context);
  final portController = TextEditingController(text: '$port');
  final secretController = TextEditingController();
  var obscure = true;
  var save = false;
  String? error;

  return _showLumaDialog<QuickConnectAnswer>(
    context,
    title: t.sftpConnectToDevice(deviceName),
    icon: Icons.devices_rounded,
    body: (context, close) {
      final luma = context.luma;
      return StatefulBuilder(
        builder: (context, setState) {
          void submit() {
            final typedPort = int.tryParse(portController.text.trim());
            if (typedPort == null || typedPort < 1 || typedPort > 65535) {
              setState(() => error = t.sftpPortRangeError);
              return;
            }
            if (secretController.text.trim().isEmpty) {
              setState(() => error = t.sftpPairingPasswordRequired(deviceName));
              return;
            }
            close((port: typedPort, secret: secretController.text, save: save));
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.sftpQuickConnectFound(address),
                style: TextStyle(color: luma.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: portController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(color: luma.textPrimary, fontSize: 14),
                decoration: InputDecoration(labelText: t.sftpPortLabel),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: secretController,
                autofocus: true,
                obscureText: obscure,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => submit(),
                style: TextStyle(color: luma.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: t.sftpPairingPasswordLabel,
                  suffixIcon: IconButton(
                    tooltip: obscure ? t.sftpShow : t.sftpHide,
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
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: TextStyle(color: luma.danger, fontSize: 12),
                ),
              ],
              const SizedBox(height: 6),
              _CheckRow(
                value: save,
                label: t.sftpRememberDevicePassword,
                subtitle: t.sftpEncryptedLocalNote,
                onChanged: (value) => setState(() => save = value),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  LumaGhostButton(label: t.commonCancel, onTap: () => close(null)),
                  const SizedBox(width: 10),
                  LumaPrimaryButton(
                    label: t.sftpConnect,
                    icon: Icons.link_rounded,
                    onTap: submit,
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

/// One-line text prompt — new folder names, renames.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  required IconData icon,
  String initial = '',
  String? confirmLabel,
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
      final t = L.of(context);
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
              LumaGhostButton(label: t.commonCancel, onTap: () => close(null)),
              const SizedBox(width: 10),
              LumaPrimaryButton(
                label: confirmLabel ?? t.commonSave,
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
  final t = L.of(context);
  final result = await _showLumaDialog<bool>(
    context,
    title: names.length == 1
        ? t.sftpDeleteOneTitle(names.first)
        : t.sftpDeleteManyTitle(names.length),
    icon: Icons.delete_forever_rounded,
    iconColor: context.luma.danger,
    body: (context, close) {
      final luma = context.luma;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            remote ? t.sftpDeleteRemoteWarning : t.sftpDeleteLocalWarning,
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
              LumaGhostButton(label: t.commonCancel, onTap: () => close(false)),
              const SizedBox(width: 10),
              LumaPrimaryButton(
                label: t.commonDelete,
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
  final t = L.of(context);
  final controller = TextEditingController(
    text: current == null ? '644' : current.toRadixString(8).padLeft(3, '0'),
  );

  return _showLumaDialog<int>(
    context,
    title: t.sftpPermissionsTitle(name),
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
                decoration: InputDecoration(
                  labelText: t.sftpPermissionsMode,
                  helperText: t.sftpPermissionsHelper,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                parsed == null
                    ? t.sftpPermissionsInvalid
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
                  LumaGhostButton(label: t.commonCancel, onTap: () => close(null)),
                  const SizedBox(width: 10),
                  LumaPrimaryButton(
                    label: t.commonApply,
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
