import 'dart:io';

import 'package:flutter/material.dart';

import '../../theme/luma_theme.dart';
import 'app_version.dart';
import 'update_service.dart';
import 'updating_screen.dart';

/// Runs a background update check and, if a newer release exists, prompts the
/// user to install it. Call once after the app has settled (e.g. when the
/// splash finishes). Safe to call on dev builds — it no-ops there.
///
/// [announceIfUpToDate] shows a snackbar when no update is found. It defaults
/// to off for the silent boot-time check, but a manual "Check for updates"
/// action (see Settings > About) should pass true so the tap gets visible
/// feedback either way — useful on Android, where resuming the app from the
/// recent-apps switcher doesn't re-run this boot-time check at all; only a
/// fresh cold launch does.
Future<void> checkAndPromptForUpdate(
  BuildContext context, {
  bool announceIfUpToDate = false,
}) async {
  if (!AppVersion.isReleaseBuild) {
    if (announceIfUpToDate && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Updates aren\'t available on dev builds.')),
      );
    }
    return;
  }

  final service = UpdateService();
  final info = await service.checkForUpdate();
  if (!context.mounted) return;
  if (info == null) {
    if (announceIfUpToDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('luma is up to date (${AppVersion.current}).')),
      );
    }
    return;
  }

  final wantsUpdate = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: Text('Update available — ${info.version}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 380),
        child: SingleChildScrollView(
          child: info.notes.isEmpty
              ? Text(
                  'A newer version of luma is ready to install.\n\n'
                  'You are on ${AppVersion.current}.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "You're on ${AppVersion.current}. What's new in ${info.version}:",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(ctx).textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._changelogWidgets(ctx, info.notes),
                  ],
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

/// Renders GitHub release notes (the changelog) as a compact, readable list
/// instead of a raw dump of markdown: `#` headings become bold lines, `*`/`-`
/// items become real bullets, and markdown link/emphasis syntax is stripped
/// so URLs and `**` markers don't clutter the text.
List<Widget> _changelogWidgets(BuildContext context, String notes) {
  final baseColor = Theme.of(context).textTheme.bodyMedium?.color;
  final widgets = <Widget>[];
  for (final rawLine in notes.split('\n')) {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty) {
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 8));
      continue;
    }
    if (trimmed.startsWith('#')) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Text(
          _stripInlineMarkdown(trimmed.replaceFirst(RegExp(r'^#+\s*'), '')),
          style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 14.5, color: baseColor),
        ),
      ));
      continue;
    }
    final bullet = RegExp(r'^[-*]\s+(.*)').firstMatch(trimmed);
    if (bullet != null) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(left: 2, top: 2, bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•  ', style: TextStyle(color: baseColor, height: 1.4)),
            Expanded(
              child: Text(
                _stripInlineMarkdown(bullet.group(1)!),
                style: TextStyle(color: baseColor, height: 1.4, fontSize: 13.5),
              ),
            ),
          ],
        ),
      ));
      continue;
    }
    widgets.add(Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        _stripInlineMarkdown(trimmed),
        style: TextStyle(color: baseColor, height: 1.4, fontSize: 13.5),
      ),
    ));
  }
  return widgets;
}

String _stripInlineMarkdown(String s) => s
    .replaceAllMapped(RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), (m) => m.group(1)!)
    .replaceAll(RegExp(r'\*\*|__|`'), '');

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
  if (ok &&
      installerPath != null &&
      await service.launchInstaller(installerPath!)) {
    // Windows relaunches the app itself once the silent installer finishes,
    // so this process needs to get out of its way. Android instead just
    // opened the system installer's own confirmation screen on top of us —
    // this process must keep running until the user taps "Install" there.
    if (Platform.isWindows) exit(0);
    return;
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
