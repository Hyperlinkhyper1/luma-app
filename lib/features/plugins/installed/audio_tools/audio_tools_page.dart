import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'audio_tools_repository.dart';
import 'audio_tools_scope.dart';
import 'audio_types.dart';
import 'eq.dart';
import 'system_eq.dart';

const _vbCableUrl = 'https://vb-audio.com/Cable/';
const _micPrivacyUrl = 'ms-settings:privacy-microphone';

/// Audio Tools: runs the microphone through a parametric equalizer and plays
/// the result into any output device. Pointed at a virtual cable, that
/// output becomes a microphone Discord (or OBS, or a game) can pick — a
/// voice changer.
class AudioToolsPage extends StatelessWidget {
  const AudioToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AudioToolsScope.of(context);
    final t = L.of(context);

    if (!repo.supported) {
      return LumaEmptyState(
        icon: Icons.desktop_windows_outlined,
        title: t.audioToolsWindowsOnly,
        subtitle: t.audioToolsWindowsOnlyBody,
      );
    }

    final phone = context.isPhoneWidth;
    return ListView(
      padding: EdgeInsets.all(phone ? 14 : 24),
      children: [
        _Header(repo: repo),
        if (repo.error != null) ...[
          const SizedBox(height: 16),
          _ErrorBanner(repo: repo),
        ],
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final routing = _RoutingCard(repo: repo);
            final Widget discord = repo.systemEqAvailable
                ? _SystemEqCard(repo: repo)
                : _DiscordCard(repo: repo);
            if (constraints.maxWidth < 860) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [routing, const SizedBox(height: 16), discord],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: routing),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: discord),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        _EqualizerCard(repo: repo),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.repo});
  final AudioToolsRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                t.audioToolsTitle,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _StatusPill(live: repo.running),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          t.audioToolsSubtitle,
          style: TextStyle(color: luma.textSecondary, fontSize: 13.5),
        ),
      ],
    );
    final button = LumaPrimaryButton(
      label: repo.running ? t.audioToolsStop : t.audioToolsStart,
      icon: Icons.power_settings_new_rounded,
      loading: repo.starting,
      onTap: repo.starting ? null : repo.toggle,
    );

    if (context.isPhoneWidth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [title, const SizedBox(height: 12), button],
      );
    }
    return Row(
      children: [
        LumaIconBadge(icon: Icons.graphic_eq_rounded, color: luma.accent),
        const SizedBox(width: 14),
        Expanded(child: title),
        const SizedBox(width: 16),
        button,
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.live});
  final bool live;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final color = live ? luma.success : luma.textMuted;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(context.lumaDecor.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            live ? t.audioToolsLive : t.audioToolsOff,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.repo});
  final AudioToolsRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final error = repo.error!;
    final message = switch (error) {
      AudioEngineError.deviceMissing => t.audioToolsErrDeviceMissing,
      AudioEngineError.deviceInUse => t.audioToolsErrDeviceInUse,
      AudioEngineError.deviceLost => t.audioToolsErrDeviceLost,
      AudioEngineError.micBlocked => t.audioToolsErrMicBlocked,
      AudioEngineError.failed => t.audioToolsErrFailed,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: luma.danger.withValues(alpha: 0.12),
        borderRadius: context.lumaDecor.cardBorderRadius,
        border: Border.all(color: luma.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: luma.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: luma.textPrimary, fontSize: 13.5),
            ),
          ),
          if (error == AudioEngineError.micBlocked)
            TextButton(
              onPressed: () => launchUrl(Uri.parse(_micPrivacyUrl)),
              child: Text(t.audioToolsOpenSettings),
            ),
          IconButton(
            tooltip: t.audioToolsDismiss,
            icon: Icon(Icons.close_rounded, color: luma.textSecondary),
            onPressed: repo.clearError,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _RoutingCard extends StatelessWidget {
  const _RoutingCard({required this.repo});
  final AudioToolsRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final devices = repo.devices;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            t.audioToolsRouting,
            trailing: IconButton(
              tooltip: t.audioToolsRefreshDevices,
              onPressed: repo.refreshingDevices ? null : repo.refreshDevices,
              icon: Icon(Icons.refresh_rounded, color: luma.textSecondary),
            ),
          ),
          const SizedBox(height: 8),
          _DevicePicker(
            icon: Icons.mic_rounded,
            label: t.audioToolsMicrophone,
            devices: devices.inputs,
            defaultId: devices.defaultInputId,
            value: repo.inputId,
            onChanged: repo.setInput,
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<AudioLevels>(
            valueListenable: repo.levels,
            builder: (context, l, _) => _LevelMeter(value: l.input),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Icon(
              Icons.south_rounded,
              color: repo.running ? luma.accent : luma.textMuted,
              size: 20,
            ),
          ),
          _DevicePicker(
            icon: Icons.speaker_rounded,
            label: t.audioToolsSendTo,
            devices: devices.outputs,
            defaultId: devices.defaultOutputId,
            value: repo.outputId,
            onChanged: repo.setOutput,
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<AudioLevels>(
            valueListenable: repo.levels,
            builder: (context, l, _) => _LevelMeter(value: l.output),
          ),
          if (!repo.outputIsVirtualCable && devices.outputs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: luma.warning, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t.audioToolsNotACable,
                    style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          _ToggleRow(
            title: t.audioToolsHearMyself,
            subtitle: t.audioToolsHearMyselfBody,
            value: repo.monitor,
            onChanged: repo.setMonitor,
          ),
          _ToggleRow(
            title: t.audioToolsBypass,
            subtitle: t.audioToolsBypassBody,
            value: repo.bypass,
            onChanged: repo.setBypass,
          ),
          _ToggleRow(
            title: t.audioToolsAutoStart,
            subtitle: t.audioToolsAutoStartBody,
            value: repo.autoStart,
            onChanged: repo.setAutoStart,
          ),
        ],
      ),
    );
  }
}

class _DevicePicker extends StatelessWidget {
  const _DevicePicker({
    required this.icon,
    required this.label,
    required this.devices,
    required this.defaultId,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final List<AudioDevice> devices;
  final String? defaultId;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    String? defaultName;
    for (final d in devices) {
      if (d.id == defaultId) defaultName = d.name;
    }
    final selected = devices.any((d) => d.id == value) ? value : null;
    final textStyle = TextStyle(color: luma.textPrimary, fontSize: 13.5);

    return DropdownButtonFormField<String?>(
      initialValue: selected,
      key: ValueKey('$label-$selected-${devices.length}'),
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: luma.textSecondary),
      ),
      dropdownColor: luma.surface,
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(
            defaultName == null
                ? t.audioToolsWindowsDefaultPlain
                : t.audioToolsWindowsDefault(defaultName),
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
        for (final d in devices)
          DropdownMenuItem<String?>(
            value: d.id,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    d.name,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                ),
                if (d.isVirtualCable) ...[
                  const SizedBox(width: 8),
                  _Tag(t.audioToolsVirtualCableTag),
                ],
              ],
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: luma.accentSubtle,
        borderRadius: BorderRadius.circular(context.lumaDecor.pillRadius),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: luma.accent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A peak meter on a -60..0 dBFS scale, green through amber to red.
class _LevelMeter extends StatelessWidget {
  const _LevelMeter({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final db = value <= 0 ? -60.0 : 20 * math.log(value) / math.ln10;
    final fill = ((db + 60) / 60).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: luma.border.withValues(alpha: 0.6)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fill,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [luma.success, luma.warning, luma.danger],
                    stops: const [0.0, 0.8, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: luma.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _DiscordCard extends StatelessWidget {
  const _DiscordCard({required this.repo});
  final AudioToolsRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final cable = repo.devices.virtualCableOutput;
    AudioDevice? cableMic;
    for (final d in repo.devices.inputs) {
      if (d.isVirtualCable) cableMic = d;
    }
    final bodyStyle = TextStyle(color: luma.textSecondary, fontSize: 13);

    if (cable == null) {
      return LumaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(t.audioToolsCableMissingTitle),
            const SizedBox(height: 8),
            Text(t.audioToolsCableMissingBody, style: bodyStyle),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                LumaPrimaryButton(
                  label: t.audioToolsGetCable,
                  icon: Icons.open_in_new_rounded,
                  onTap: () => launchUrl(Uri.parse(_vbCableUrl)),
                ),
                LumaGhostButton(
                  label: t.audioToolsInstalledCheck,
                  icon: Icons.refresh_rounded,
                  onTap: repo.refreshDevices,
                ),
              ],
            ),
          ],
        ),
      );
    }

    final selected = repo.outputId == cable.id;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            t.audioToolsDiscordTitle,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: luma.success, size: 16),
                const SizedBox(width: 4),
                Text(
                  t.audioToolsCableFound,
                  style: TextStyle(color: luma.success, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Step(
            number: 1,
            done: selected,
            text: t.audioToolsStepSendTo(cable.name),
            action: selected
                ? null
                : TextButton(
                    onPressed: () => repo.setOutput(cable.id),
                    child: Text(t.audioToolsUseCable),
                  ),
          ),
          _Step(
            number: 2,
            text: t.audioToolsStepDiscord(cableMic?.name ?? 'CABLE Output'),
          ),
          _Step(number: 3, done: repo.running, text: t.audioToolsStepStart),
        ],
      ),
    );
  }
}

/// The no-extra-software route into Discord: luma's EQ installed on the
/// microphone inside Windows, so every app recording from it hears the
/// curve. Shown instead of [_DiscordCard] on builds that ship the APO.
class _SystemEqCard extends StatelessWidget {
  const _SystemEqCard({required this.repo});
  final AudioToolsRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final mic = repo.resolvedInput;
    final micName = mic?.name ?? '';
    final status = repo.systemEqStatus;
    final on = repo.systemEqOnInput;
    final bodyStyle = TextStyle(color: luma.textSecondary, fontSize: 13);

    final children = <Widget>[];
    if (mic == null) {
      children.add(Text(t.audioToolsSystemNoMic, style: bodyStyle));
    } else if (!on) {
      children
        ..add(Text(t.audioToolsSystemBody(micName), style: bodyStyle))
        ..add(const SizedBox(height: 16))
        ..add(
          Align(
            alignment: Alignment.centerLeft,
            child: LumaPrimaryButton(
              label: t.audioToolsSystemEnable,
              icon: Icons.admin_panel_settings_outlined,
              loading: repo.systemEqBusy,
              onTap: repo.systemEqBusy ? null : repo.enableSystemEq,
            ),
          ),
        );
    } else {
      children
        ..add(
          _ToggleRow(
            title: t.audioToolsSystemEveryApp,
            subtitle: t.audioToolsSystemEveryAppBody,
            value: !repo.systemEqPaused,
            onChanged: (v) => repo.setSystemEqPaused(!v),
          ),
        )
        ..add(const SizedBox(height: 8))
        ..add(Text(t.audioToolsSystemDiscordHint(micName), style: bodyStyle));
      if (!status.current) {
        children
          ..add(const SizedBox(height: 12))
          ..add(
            _Notice(
              icon: Icons.system_update_alt_rounded,
              color: luma.warning,
              text: t.audioToolsSystemOutdated,
              action: TextButton(
                onPressed: repo.systemEqBusy ? null : repo.updateSystemEq,
                child: Text(t.audioToolsSystemUpdate),
              ),
            ),
          );
      }
      children
        ..add(const SizedBox(height: 16))
        ..add(
          Align(
            alignment: Alignment.centerLeft,
            child: LumaGhostButton(
              label: t.audioToolsSystemRemove,
              icon: Icons.settings_backup_restore_rounded,
              onTap: repo.systemEqBusy ? null : repo.disableSystemEq,
            ),
          ),
        );
    }

    final result = repo.systemEqResult;
    if (result != null) {
      children
        ..add(const SizedBox(height: 12))
        ..add(
          _Notice(
            icon: result.succeeded
                ? Icons.restart_alt_rounded
                : Icons.info_outline_rounded,
            color: result.succeeded ? luma.warning : luma.danger,
            text: switch (result) {
              SystemEqResult.restartNeeded => t.audioToolsSystemRestart,
              SystemEqResult.cancelled => t.audioToolsSystemCancelled,
              SystemEqResult.noDevice => t.audioToolsSystemNoDevice,
              SystemEqResult.incompatible => t.audioToolsSystemIncompatible,
              SystemEqResult.micNotRecording => t.audioToolsSystemMicSilent,
              SystemEqResult.missing => t.audioToolsSystemMissing,
              SystemEqResult.failed ||
              SystemEqResult.ok => t.audioToolsSystemFailed,
            },
          ),
        );
    }

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            t.audioToolsSystemTitle,
            trailing: on
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        repo.systemEqPaused
                            ? Icons.pause_circle_outline_rounded
                            : Icons.check_circle_rounded,
                        color: repo.systemEqPaused
                            ? luma.textMuted
                            : luma.success,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          repo.systemEqPaused
                              ? t.audioToolsSystemPaused
                              : t.audioToolsSystemActive(micName),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: repo.systemEqPaused
                                ? luma.textMuted
                                : luma.success,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  )
                : null,
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.text,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
          ),
        ),
        ?action,
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.text,
    this.done = false,
    this.action,
  });

  final int number;
  final String text;
  final bool done;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? luma.success : luma.accentSubtle,
              shape: BoxShape.circle,
            ),
            child: done
                ? Icon(Icons.check_rounded, size: 14, color: luma.onAccent)
                : Text(
                    '$number',
                    style: TextStyle(
                      color: luma.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: TextStyle(color: luma.textPrimary, fontSize: 13),
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _EqualizerCard extends StatefulWidget {
  const _EqualizerCard({required this.repo});
  final AudioToolsRepository repo;

  @override
  State<_EqualizerCard> createState() => _EqualizerCardState();
}

class _EqualizerCardState extends State<_EqualizerCard> {
  int _selected = 4;

  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    final luma = context.luma;
    final t = L.of(context);
    final eq = repo.eq;
    final selected = _selected.clamp(0, eq.bands.length - 1);
    final active = repo.activePreset;

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            t.audioToolsEqualizer,
            trailing: LumaGhostButton(
              label: t.audioToolsReset,
              icon: Icons.restart_alt_rounded,
              onTap: active == EqPreset.flat
                  ? null
                  : () => repo.applyPreset(EqPreset.flat),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in EqPreset.values)
                ChoiceChip(
                  label: Text(_presetName(t, p)),
                  selected: active == p,
                  onSelected: (_) => repo.applyPreset(p),
                ),
              if (active == null)
                ChoiceChip(
                  label: Text(t.audioToolsPresetCustom),
                  selected: true,
                  onSelected: (_) {},
                ),
            ],
          ),
          const SizedBox(height: 14),
          _EqGraph(
            eq: eq,
            selected: selected,
            bypass: repo.bypass,
            onSelect: (i) => setState(() => _selected = i),
            onBandChanged: repo.setBand,
          ),
          const SizedBox(height: 6),
          Text(
            t.audioToolsEqHint,
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          _BandEditor(
            index: selected,
            band: eq.bands[selected],
            bandCount: eq.bands.length,
            onSelect: (i) => setState(() => _selected = i),
            onChanged: (b) => repo.setBand(selected, b),
          ),
          const SizedBox(height: 4),
          _LabeledSlider(
            label: t.audioToolsPreamp,
            valueText: _formatDb(eq.preampDb),
            value: eq.preampDb,
            min: -kEqMaxGainDb,
            max: 12,
            onChanged: repo.setPreamp,
          ),
        ],
      ),
    );
  }
}

String _presetName(L t, EqPreset p) => switch (p) {
  EqPreset.flat => t.audioToolsPresetFlat,
  EqPreset.clear => t.audioToolsPresetClear,
  EqPreset.deep => t.audioToolsPresetDeep,
  EqPreset.radio => t.audioToolsPresetRadio,
  EqPreset.telephone => t.audioToolsPresetTelephone,
  EqPreset.megaphone => t.audioToolsPresetMegaphone,
  EqPreset.muffled => t.audioToolsPresetMuffled,
  EqPreset.tiny => t.audioToolsPresetTiny,
};

String _typeName(L t, EqBandType type) => switch (type) {
  EqBandType.highPass => t.audioToolsTypeHighPass,
  EqBandType.lowShelf => t.audioToolsTypeLowShelf,
  EqBandType.peak => t.audioToolsTypePeak,
  EqBandType.highShelf => t.audioToolsTypeHighShelf,
  EqBandType.lowPass => t.audioToolsTypeLowPass,
};

String _formatHz(double f) {
  if (f < 1000) return '${f.round()} Hz';
  return '${(f / 1000).toStringAsFixed(f < 10000 ? 1 : 0)} kHz';
}

String _formatDb(double db) =>
    '${db > 0 ? '+' : ''}${db.toStringAsFixed(1)} dB';

class _BandEditor extends StatelessWidget {
  const _BandEditor({
    required this.index,
    required this.band,
    required this.bandCount,
    required this.onSelect,
    required this.onChanged,
  });

  final int index;
  final EqBand band;
  final int bandCount;
  final ValueChanged<int> onSelect;
  final ValueChanged<EqBand> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final logMin = math.log(kEqMinHz);
    final logMax = math.log(kEqMaxHz);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (var i = 0; i < bandCount; i++)
                  ButtonSegment(value: i, label: Text('${i + 1}')),
              ],
              selected: {index},
              onSelectionChanged: (s) => onSelect(s.first),
            ),
            DropdownButton<EqBandType>(
              value: band.type,
              dropdownColor: luma.surface,
              underline: const SizedBox.shrink(),
              style: TextStyle(color: luma.textPrimary, fontSize: 13.5),
              items: [
                for (final type in EqBandType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(_typeName(t, type)),
                  ),
              ],
              onChanged: (type) {
                if (type != null) onChanged(band.copyWith(type: type));
              },
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.audioToolsBandOn,
                  style: TextStyle(color: luma.textSecondary, fontSize: 13),
                ),
                Switch(
                  value: band.enabled,
                  onChanged: (v) => onChanged(band.copyWith(enabled: v)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        _LabeledSlider(
          label: t.audioToolsFrequency,
          valueText: _formatHz(band.frequency),
          value: math.log(band.frequency),
          min: logMin,
          max: logMax,
          onChanged: (v) =>
              onChanged(band.copyWith(frequency: math.exp(v), enabled: true)),
        ),
        if (band.usesGain)
          _LabeledSlider(
            label: t.audioToolsGain,
            valueText: _formatDb(band.gainDb),
            value: band.gainDb,
            min: -kEqMaxGainDb,
            max: kEqMaxGainDb,
            onChanged: (v) => onChanged(
              band.copyWith(gainDb: (v * 2).roundToDouble() / 2, enabled: true),
            ),
          ),
        _LabeledSlider(
          label: t.audioToolsWidth,
          valueText: band.q.toStringAsFixed(2),
          value: band.q,
          min: kEqMinQ,
          max: kEqMaxQ,
          onChanged: (v) => onChanged(band.copyWith(q: v)),
        ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(color: luma.textSecondary, fontSize: 13),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 72,
          child: Text(
            valueText,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// The frequency-response graph with one draggable handle per band.
/// Horizontal drag moves the frequency, vertical drag the gain, and the
/// scroll wheel over the graph narrows or widens the selected band.
class _EqGraph extends StatefulWidget {
  const _EqGraph({
    required this.eq,
    required this.selected,
    required this.bypass,
    required this.onSelect,
    required this.onBandChanged,
  });

  final EqSettings eq;
  final int selected;
  final bool bypass;
  final ValueChanged<int> onSelect;
  final void Function(int index, EqBand band) onBandChanged;

  @override
  State<_EqGraph> createState() => _EqGraphState();
}

class _EqGraphState extends State<_EqGraph> {
  static const double _height = 240;
  int? _dragging;

  int? _hit(Offset p, Size size) {
    int? best;
    var bestDist = 26.0;
    for (var i = 0; i < widget.eq.bands.length; i++) {
      final d = (_EqGeometry(size).handle(widget.eq.bands[i]) - p).distance;
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  void _drag(Offset p, Size size) {
    final i = _dragging;
    if (i == null) return;
    final g = _EqGeometry(size);
    final band = widget.eq.bands[i];
    widget.onBandChanged(
      i,
      band.copyWith(
        frequency: g.freqAt(p.dx),
        gainDb: band.usesGain
            ? (g.dbAt(p.dy) * 2).roundToDouble() / 2
            : band.gainDb,
        enabled: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, _height);
        return Listener(
          onPointerSignal: (event) {
            if (event is! PointerScrollEvent) return;
            final band = widget.eq.bands[widget.selected];
            final factor = event.scrollDelta.dy > 0 ? 1 / 1.1 : 1.1;
            widget.onBandChanged(
              widget.selected,
              band.copyWith(q: band.q * factor),
            );
          },
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              TapGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                    TapGestureRecognizer.new,
                    (r) => r.onTapDown = (d) {
                      final hit = _hit(d.localPosition, size);
                      if (hit != null) widget.onSelect(hit);
                    },
                  ),
              _HandlePanRecognizer:
                  GestureRecognizerFactoryWithHandlers<_HandlePanRecognizer>(
                    _HandlePanRecognizer.new,
                    (r) => r
                      ..hitsHandle = ((p) => _hit(p, size) != null)
                      ..onStart = (d) {
                        final hit = _hit(d.localPosition, size);
                        if (hit == null) return;
                        widget.onSelect(hit);
                        setState(() => _dragging = hit);
                      }
                      ..onUpdate = ((d) => _drag(d.localPosition, size))
                      ..onEnd = ((_) => setState(() => _dragging = null))
                      ..onCancel = (() => setState(() => _dragging = null)),
                  ),
            },
            child: MouseRegion(
              cursor: _dragging != null
                  ? SystemMouseCursors.grabbing
                  : SystemMouseCursors.grab,
              child: CustomPaint(
                size: size,
                painter: _EqPainter(
                  eq: widget.eq,
                  selected: widget.selected,
                  dimmed: widget.bypass,
                  accent: luma.accent,
                  grid: luma.border,
                  label: luma.textMuted,
                  surface: luma.surface,
                  onAccent: luma.onAccent,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A pan that claims the pointer the moment it lands on a handle, so the
/// page's scroll view can't win the arena and scroll instead of dragging.
/// Pointers that miss every handle compete normally and still scroll.
class _HandlePanRecognizer extends PanGestureRecognizer {
  _HandlePanRecognizer();

  bool Function(Offset local) hitsHandle = (_) => false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    if (hitsHandle(event.localPosition)) {
      resolve(GestureDisposition.accepted);
    }
  }
}

/// Maps between graph pixels and frequency/gain.
class _EqGeometry {
  _EqGeometry(this.size);

  final Size size;
  final double left = 34;
  final double bottom = 20;
  final double top = 10;
  static const double range = kEqMaxGainDb;
  static final double _logSpan = math.log(kEqMaxHz / kEqMinHz);

  double get width => size.width - left - 8;
  double get height => size.height - bottom - top;

  double x(double f) => left + width * math.log(f / kEqMinHz) / _logSpan;
  double y(double db) => top + height / 2 - db / range * (height / 2);
  double freqAt(double px) =>
      kEqMinHz * math.exp(((px - left) / width).clamp(0.0, 1.0) * _logSpan);
  double dbAt(double py) =>
      ((top + height / 2 - py) / (height / 2) * range).clamp(-range, range);

  Offset handle(EqBand b) =>
      Offset(x(b.frequency), y(b.usesGain ? b.gainDb : 0));
}

class _EqPainter extends CustomPainter {
  _EqPainter({
    required this.eq,
    required this.selected,
    required this.dimmed,
    required this.accent,
    required this.grid,
    required this.label,
    required this.surface,
    required this.onAccent,
  });

  final EqSettings eq;
  final int selected;
  final bool dimmed;
  final Color accent;
  final Color grid;
  final Color label;
  final Color surface;
  final Color onAccent;

  static const _gridHz = [
    50.0,
    100.0,
    200.0,
    500.0,
    1000.0,
    2000.0,
    5000.0,
    10000.0,
  ];
  static const _gridDb = [-24.0, -12.0, 0.0, 12.0, 24.0];

  @override
  void paint(Canvas canvas, Size size) {
    final g = _EqGeometry(size);
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;

    for (final db in _gridDb) {
      final y = g.y(db);
      canvas.drawLine(
        Offset(g.left, y),
        Offset(g.left + g.width, y),
        gridPaint..color = db == 0 ? grid : grid.withValues(alpha: 0.5),
      );
      _text(
        canvas,
        '${db > 0 ? '+' : ''}${db.round()}',
        Offset(0, y - 7),
        30,
        TextAlign.right,
      );
    }
    for (final f in _gridHz) {
      final x = g.x(f);
      canvas.drawLine(
        Offset(x, g.top),
        Offset(x, g.top + g.height),
        gridPaint..color = grid.withValues(alpha: 0.5),
      );
      _text(
        canvas,
        f < 1000 ? '${f.round()}' : '${(f / 1000).round()}k',
        Offset(x - 20, g.top + g.height + 4),
        40,
        TextAlign.center,
      );
    }

    final curve = Path();
    final fill = Path()..moveTo(g.left, g.y(0));
    const steps = 220;
    for (var i = 0; i <= steps; i++) {
      final px = g.left + g.width * i / steps;
      final db = eq.responseDb(g.freqAt(px), 48000).clamp(-30.0, 30.0);
      final py = g.y(db).clamp(0.0, size.height);
      if (i == 0) {
        curve.moveTo(px, py);
      } else {
        curve.lineTo(px, py);
      }
      fill.lineTo(px, py);
    }
    fill
      ..lineTo(g.left + g.width, g.y(0))
      ..close();

    final color = dimmed ? label : accent;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(g.left, 0, g.width, size.height));
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.14));
    canvas.drawPath(
      curve,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    for (var i = 0; i < eq.bands.length; i++) {
      final band = eq.bands[i];
      final c = g.handle(band);
      final isSelected = i == selected;
      final r = isSelected ? 11.0 : 9.0;
      if (isSelected) {
        canvas.drawCircle(
          c,
          r + 5,
          Paint()..color = color.withValues(alpha: 0.2),
        );
      }
      canvas.drawCircle(c, r, Paint()..color = band.enabled ? color : surface);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = band.enabled ? color : label
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      _text(
        canvas,
        '${i + 1}',
        Offset(c.dx - r, c.dy - 7),
        r * 2,
        TextAlign.center,
        color: band.enabled ? onAccent : label,
        bold: true,
      );
    }
  }

  void _text(
    Canvas canvas,
    String s,
    Offset at,
    double width,
    TextAlign align, {
    Color? color,
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color ?? label,
          fontSize: 10.5,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: width, maxWidth: width);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_EqPainter old) =>
      old.eq != eq ||
      old.selected != selected ||
      old.dimmed != dimmed ||
      old.accent != accent ||
      old.grid != grid ||
      old.surface != surface;
}
