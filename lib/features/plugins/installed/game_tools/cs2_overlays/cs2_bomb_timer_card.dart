import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import 'cs2_bomb_timer_service.dart';
import 'cs2_overlay_widgets.dart';

/// The bomb timer overlay: install the game-state config once, start it,
/// and the fuse counts down on top of the game from the moment of the plant.
/// The same countdown shows here, so it can be checked without the game.
class Cs2BombTimerCard extends StatefulWidget {
  const Cs2BombTimerCard({super.key});

  @override
  State<Cs2BombTimerCard> createState() => _Cs2BombTimerCardState();
}

class _Cs2BombTimerCardState extends State<Cs2BombTimerCard> {
  final _service = Cs2BombTimerService.instance;
  final _fuse = TextEditingController();
  bool? _installed;
  bool _checked = false;
  bool _installing = false;
  String? _installError;
  String? _startError;

  /// Re-reads the "connected to CS2" state while running, since silence
  /// from the game has no event of its own.
  Timer? _connectionCheck;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onService);
    _load();
    _syncConnectionCheck();
  }

  Future<void> _load() async {
    final options = await _service.loadOptions();
    final installed = await _service.configInstalled();
    if (!mounted) return;
    setState(() {
      _fuse.text = '${options.fuseSeconds}';
      _installed = installed;
      _checked = true;
    });
  }

  void _onService() {
    _syncConnectionCheck();
    if (mounted) setState(() {});
  }

  void _syncConnectionCheck() {
    if (_service.running && _connectionCheck == null) {
      _connectionCheck = Timer.periodic(
        const Duration(seconds: 10),
        (_) => mounted ? setState(() {}) : null,
      );
    } else if (!_service.running) {
      _connectionCheck?.cancel();
      _connectionCheck = null;
    }
  }

  @override
  void dispose() {
    _service.removeListener(_onService);
    _connectionCheck?.cancel();
    _fuse.dispose();
    super.dispose();
  }

  Future<void> _install() async {
    setState(() {
      _installing = true;
      _installError = null;
    });
    final error = await _service.installConfig();
    final installed = await _service.configInstalled();
    if (!mounted) return;
    setState(() {
      _installing = false;
      _installed = installed;
      _installError = error;
    });
  }

  Future<void> _start() async {
    final t = L.of(context);
    final options = _service.options;
    final fuse = int.tryParse(_fuse.text);
    if (options != null && fuse != null && fuse != options.fuseSeconds) {
      await _service.updateOptions(
        options.copyWith(fuseSeconds: fuse.clamp(10, 120)),
      );
    }
    final error = await _service.start(
      Cs2BombOverlayLabels(
        kitOnly: t.cs2BombKitOnly,
        tooLate: t.cs2BombTooLate,
        defused: t.cs2BombDefused,
        exploded: t.cs2BombExploded,
        preview: t.cs2BombTitle,
        move: t.cs2BombDragHint,
      ),
    );
    if (mounted) setState(() => _startError = error);
  }

  Future<void> _resetPosition() async {
    final options = _service.options;
    if (options == null) return;
    await _service.updateOptions(
      options.copyWith(overlayX: () => null, overlayY: () => null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final running = _service.running;

    return Cs2OverlayCard(
      icon: Icons.timer_outlined,
      title: t.cs2BombTitle,
      description: t.cs2BombDescription,
      running: running,
      action: running
          ? LumaPrimaryButton(
              label: t.cs2BombStop,
              icon: Icons.stop_rounded,
              onTap: _service.stop,
            )
          : LumaPrimaryButton(
              label: t.cs2BombStart,
              icon: Icons.play_arrow_rounded,
              loading: _service.starting,
              onTap: _checked && !_service.starting ? _start : null,
            ),
      children: [
        const SizedBox(height: 16),
        Text(
          t.cs2BombSetupStep,
          style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        if (_checked) _installRow(t, luma),
        if (_installError case final error?) ...[
          const SizedBox(height: 8),
          Text(
            error == 'not_found'
                ? t.cs2BombCs2Missing
                : t.cs2BombInstallFailed(error),
            style: TextStyle(color: luma.danger, fontSize: 12.5),
          ),
        ],
        if (_startError case final error?) ...[
          const SizedBox(height: 8),
          Text(
            error == 'port_in_use'
                ? t.cs2BombPortInUse(kCs2GsiPort)
                : t.cs2BombStartFailed(error),
            style: TextStyle(color: luma.danger, fontSize: 12.5),
          ),
        ],
        if (running) ...[
          const SizedBox(height: 14),
          _LiveTimer(service: _service),
          const SizedBox(height: 10),
          Cs2StatusLine(
            ok: _service.gameConnected,
            text: _service.gameConnected
                ? t.cs2BombConnected
                : t.cs2BombWaiting,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              LumaGhostButton(
                label: t.cs2BombTry,
                icon: Icons.play_circle_outline_rounded,
                onTap: _service.remaining == null
                    ? _service.simulatePlant
                    : null,
              ),
              LumaGhostButton(
                label: t.cs2BombMove,
                icon: Icons.open_with_rounded,
                onTap: _service.showPreview,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            t.cs2BombRunningHint,
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
        Divider(color: luma.border, height: 16),
        Cs2Disclosure(
          title: t.cs2TrOptionsTitle,
          child: _optionsPanel(t, luma),
        ),
      ],
    );
  }

  Widget _installRow(L t, LumaPalette luma) {
    final installed = _installed;
    final button = installed == true
        ? TextButton(
            onPressed: _installing ? null : _install,
            child: Text(t.cs2BombReinstall),
          )
        : LumaGhostButton(
            label: t.cs2BombInstall,
            icon: Icons.download_done_rounded,
            onTap: _installing || installed == null ? null : _install,
          );
    return Cs2StatusLine(
      ok: installed == true,
      text: switch (installed) {
        true => t.cs2BombInstalled,
        false => t.cs2BombNotInstalled,
        null => t.cs2BombCs2Missing,
      },
      trailing: installed == null ? null : button,
    );
  }

  Widget _optionsPanel(L t, LumaPalette luma) {
    final hasPosition =
        _service.options?.overlayX != null ||
        _service.options?.overlayY != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 240,
          child: TextField(
            controller: _fuse,
            enabled: !_service.running,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(color: luma.textPrimary, fontSize: 14),
            decoration: cs2FieldDecoration(t.cs2BombFuse, luma),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          t.cs2BombFuseHint,
          style: TextStyle(color: luma.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        LumaGhostButton(
          label: t.cs2BombResetPosition,
          icon: Icons.restart_alt_rounded,
          onTap: hasPosition && !_service.running ? _resetPosition : null,
        ),
        const SizedBox(height: 10),
        Text(
          t.cs2BombHowItWorks,
          style: TextStyle(color: luma.textMuted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}

/// The in-app copy of the overlay: the seconds left in the overlay's colors,
/// what that means for a defuse, and the fuse draining underneath.
class _LiveTimer extends StatelessWidget {
  const _LiveTimer({required this.service});

  final Cs2BombTimerService service;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final left = service.remaining;
    final fuse = service.options?.fuseSeconds ?? kCs2DefaultFuseSeconds;

    final String number;
    final String caption;
    final Color color;
    if (left == null) {
      number = '—';
      color = luma.textMuted;
      caption = switch (service.lastEvent) {
        Cs2BombEvent.defused => t.cs2BombDefused,
        Cs2BombEvent.exploded => t.cs2BombExploded,
        _ => t.cs2BombIdle,
      };
    } else {
      number = '${(left.inMilliseconds / 1000).ceil()}';
      final urgency = cs2BombUrgency(left);
      color = switch (urgency) {
        Cs2BombUrgency.anyone => luma.textPrimary,
        Cs2BombUrgency.kitOnly => luma.warning,
        Cs2BombUrgency.tooLate => luma.danger,
      };
      caption = switch (urgency) {
        Cs2BombUrgency.anyone => t.cs2BombAnyone,
        Cs2BombUrgency.kitOnly => t.cs2BombKitOnly,
        Cs2BombUrgency.tooLate => t.cs2BombTooLate,
      };
    }
    final fraction = left == null
        ? 0.0
        : (left.inMilliseconds / (fuse * 1000)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  number,
                  style: TextStyle(
                    color: color,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'C4',
                      style: TextStyle(
                        color: luma.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      caption,
                      style: TextStyle(
                        color: left == null ? luma.textSecondary : color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              color: color,
              backgroundColor: luma.border,
            ),
          ),
        ],
      ),
    );
  }
}
