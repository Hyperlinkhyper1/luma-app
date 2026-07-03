import 'dart:io';

import 'package:flutter/material.dart';

import '../../theme/luma_theme.dart';
import 'app_version.dart';
import 'update_service.dart';
import 'updating_screen.dart';

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

/// Shows a full-screen, non-dismissible "Updating luma" experience while the
/// installer downloads. It is guaranteed to stay up for a minimum of ~6s
/// (see [UpdatingScreen]) so the update always feels like a deliberate,
/// polished step rather than a flash of a dialog. On success the app
/// relaunches (this process exits once the installer is handed off); on
/// failure the screen closes and a message is shown.
Future<void> _runInstall(
  BuildContext context,
  UpdateService service,
  UpdateInfo info,
) async {
  final progress = ValueNotifier<double>(0);
  String? installerPath;
  final downloadDone = service
      .downloadInstaller(info, onProgress: (p) => progress.value = p)
      .then((path) {
    installerPath = path;
    return path != null;
  });

  final accent = context.luma.accent;

  await Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => PopScope(
        canPop: false,
        child: UpdatingScreen(
          currentVersion: AppVersion.current,
          newVersion: info.version,
          progress: progress,
          downloadDone: downloadDone,
          accent: accent,
          onFinished: (_) => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );

  final ok = await downloadDone;
  if (ok && installerPath != null && await service.launchInstaller(installerPath!)) {
    exit(0);
  }

  // Reaching here means either the download or the installer hand-off
  // failed — see update.log (next to the app databases, in the app support
  // directory) for the underlying exception.
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Update failed. Please try again later.')),
    );
  }
}
