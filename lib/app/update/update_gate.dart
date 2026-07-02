import 'package:flutter/material.dart';

import 'app_version.dart';
import 'update_service.dart';

/// Runs a background update check and, if a newer release exists, prompts the
/// user to install it. Call once after the app has settled (e.g. when the
/// splash finishes). Safe to call on dev builds — it no-ops there.
Future<void> checkAndPromptForUpdate(BuildContext context) async {
  if (!AppVersion.isReleaseBuild) return;

  final service = UpdateService();
  final info = await service.checkForUpdate();
  if (info == null || !context.mounted) return;

  final wantsUpdate = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: Text('Update available — ${info.version}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 320),
        child: SingleChildScrollView(
          child: Text(
            info.notes.isEmpty
                ? 'A newer version of luma is ready to install.\n\n'
                    'You are on ${AppVersion.current}.'
                : info.notes,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Install & restart'),
        ),
      ],
    ),
  );

  if (wantsUpdate != true || !context.mounted) return;

  await _runInstall(context, service, info);
}

/// Shows a non-dismissible progress dialog while the update downloads. On
/// success the app relaunches (this process exits inside [applyUpdate]); on
/// failure the dialog closes and a message is shown.
Future<void> _runInstall(
  BuildContext context,
  UpdateService service,
  UpdateInfo info,
) async {
  final progress = ValueNotifier<double>(0);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Downloading update'),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, value, child) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: value == 0 ? null : value),
              const SizedBox(height: 12),
              Text(value == 0
                  ? 'Starting…'
                  : '${(value * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ),
      ),
    ),
  );

  final ok = await service.applyUpdate(
    info,
    onProgress: (p) => progress.value = p,
  );

  // If applyUpdate succeeded it called exit(0) and we never get here. Reaching
  // this point means it failed to hand off.
  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update failed. Please try again later.')),
      );
    }
  }
}
