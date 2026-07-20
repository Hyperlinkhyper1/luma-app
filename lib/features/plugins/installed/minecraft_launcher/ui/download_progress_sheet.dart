import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../data/minecraft_launcher_database.dart';
import '../logic/game_process_manager.dart';
import '../logic/instance_launch_orchestrator.dart';

class _ProgressState {
  _ProgressState(this.status, this.fraction);
  final String status;
  final double? fraction;
}

/// Runs [InstanceLaunchOrchestrator.prepareAndLaunch] while showing a
/// non-dismissible progress dialog (first-launch downloads can take a
/// while), closing automatically once the game process has started or the
/// attempt fails. Returns null (after showing the error in a snackbar) on
/// failure.
Future<GameProcessHandle?> showDownloadProgressAndLaunch(
  BuildContext context, {
  required McInstance instance,
  required McAccount account,
}) async {
  final notifier = ValueNotifier<_ProgressState>(_ProgressState('Starting…', null));
  final navigator = Navigator.of(context);

  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _DownloadProgressDialog(notifier: notifier, instanceName: instance.name),
  ));

  try {
    final handle = await InstanceLaunchOrchestrator.prepareAndLaunch(
      instance: instance,
      account: account,
      onStatus: (status, fraction) => notifier.value = _ProgressState(status, fraction),
    );
    if (navigator.canPop()) navigator.pop();
    return handle;
  } catch (e) {
    if (navigator.canPop()) navigator.pop();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    return null;
  }
  // The notifier is deliberately not disposed here: the dialog is still
  // fading out and its ValueListenableBuilder would unsubscribe from a
  // disposed notifier. It's unreferenced after this frame and GC'd.
}

class _DownloadProgressDialog extends StatelessWidget {
  const _DownloadProgressDialog({required this.notifier, required this.instanceName});
  final ValueNotifier<_ProgressState> notifier;
  final String instanceName;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AlertDialog(
      title: Text('Starting $instanceName'),
      content: SizedBox(
        width: 380,
        child: ValueListenableBuilder<_ProgressState>(
          valueListenable: notifier,
          builder: (context, state, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.status, style: TextStyle(color: luma.textPrimary, fontSize: 14)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.fraction,
                    minHeight: 6,
                    backgroundColor: luma.border,
                    valueColor: AlwaysStoppedAnimation(luma.accent),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
