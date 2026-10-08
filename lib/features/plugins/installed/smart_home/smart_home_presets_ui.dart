import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'smart_home_preset.dart';
import 'smart_home_repository.dart';
import 'smart_light.dart';

class SmartHomePresetsSection extends StatelessWidget {
  const SmartHomePresetsSection({super.key, required this.repository});

  final SmartHomeRepository repository;

  Future<void> _edit(BuildContext context, [SmartHomePreset? preset]) async {
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _PresetEditorDialog(repository: repository, preset: preset),
    );
  }

  Future<void> _activate(BuildContext context, SmartHomePreset preset) async {
    await repository.activatePreset(preset);
    if (!context.mounted || repository.error != null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(L.of(context).smartHomePresetApplied(preset.name)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.luma;
    final t = L.of(context);
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: palette.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.smartHomePresetsTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: repository.busy || repository.lights.isEmpty
                    ? null
                    : () => _edit(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(t.smartHomeNewPreset),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (repository.presets.isEmpty)
            Text(
              t.smartHomePresetsEmpty,
              style: TextStyle(color: palette.textSecondary),
            )
          else ...[
            Text(
              t.smartHomePresetsTapHint,
              style: TextStyle(color: palette.textSecondary),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in repository.presets)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: repository.busy
                            ? null
                            : () => _activate(context, preset),
                        icon: repository.activatingPresetId == preset.id
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow_rounded),
                        label: Text(preset.name),
                      ),
                      IconButton(
                        tooltip: t.smartHomeEditPreset(preset.name),
                        onPressed: repository.busy
                            ? null
                            : () => _edit(context, preset),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PresetEditorDialog extends StatefulWidget {
  const _PresetEditorDialog({required this.repository, this.preset});

  final SmartHomeRepository repository;
  final SmartHomePreset? preset;

  @override
  State<_PresetEditorDialog> createState() => _PresetEditorDialogState();
}

class _PresetEditorDialogState extends State<_PresetEditorDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.preset?.name ?? '',
  );
  late final Map<String, PresetLightSetting> _selected = _initialSelection();
  bool _saving = false;
  String? _error;

  Map<String, PresetLightSetting> _initialSelection() {
    final available = {
      for (final light in widget.repository.lights) light.id: light,
    };
    return {
      for (final setting
          in widget.preset?.lights ?? const <PresetLightSetting>[])
        if (available[setting.lightId] case final light?)
          setting.lightId: PresetLightSetting(
            lightId: setting.lightId,
            brightness: light.canDim
                ? (setting.brightness ?? light.lightLevel ?? 100).clamp(1, 100)
                : null,
            hue: light.canSetColor
                ? (setting.hue ?? light.colorHue ?? 30).clamp(0, 359)
                : null,
            saturation: light.canSetColor
                ? (setting.saturation ?? light.colorSaturation ?? 1)
                      .clamp(0, 1)
                      .toDouble()
                : null,
          ),
    };
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  PresetLightSetting _defaultSetting(SmartLight light) => PresetLightSetting(
    lightId: light.id,
    brightness: light.canDim ? (light.lightLevel ?? 100).clamp(1, 100) : null,
    hue: light.canSetColor ? (light.colorHue ?? 30).clamp(0, 359) : null,
    saturation: light.canSetColor
        ? (light.colorSaturation ?? 1).clamp(0, 1).toDouble()
        : null,
  );

  void _update(
    SmartLight light, {
    int? brightness,
    int? hue,
    double? saturation,
  }) {
    final previous = _selected[light.id] ?? _defaultSetting(light);
    setState(() {
      _selected[light.id] = PresetLightSetting(
        lightId: light.id,
        brightness: brightness ?? previous.brightness,
        hue: hue ?? previous.hue,
        saturation: saturation ?? previous.saturation,
      );
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.repository.savePreset(
      id: widget.preset?.id,
      name: _name.text,
      lights: _selected.values.toList(),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error =
            widget.repository.error ?? L.of(context).smartHomeCouldNotSavePreset;
      });
    }
  }

  Future<void> _delete() async {
    final preset = widget.preset;
    if (preset == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L.of(context).smartHomeDeletePresetTitle),
        content: Text(L.of(context).smartHomeDeletePresetBody(preset.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(L.of(context).commonDelete),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _saving = true);
    final deleted = await widget.repository.deletePreset(preset.id);
    if (!mounted) return;
    if (deleted) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error =
            widget.repository.error ??
            L.of(context).smartHomeCouldNotDeletePreset;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lights = widget.repository.lights
        .where((light) => light.canToggle)
        .toList();
    final palette = context.luma;
    final t = L.of(context);
    return AlertDialog(
      title: Text(
        widget.preset == null
            ? t.smartHomeNewPresetTitle
            : t.smartHomeEditPresetTitle,
      ),
      content: SizedBox(
        width: 560,
        height: math.min(MediaQuery.sizeOf(context).height * 0.62, 600),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                maxLength: 60,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: t.smartHomePresetNameLabel,
                  hintText: t.smartHomePresetNameHint,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t.smartHomeChooseLamps,
                style: TextStyle(color: palette.textSecondary),
              ),
              const SizedBox(height: 8),
              for (final light in lights) _lightEditor(light),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: palette.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (widget.preset != null)
          TextButton(
            onPressed: _saving ? null : _delete,
            child: Text(t.commonDelete, style: TextStyle(color: palette.danger)),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(t.commonCancel),
        ),
        FilledButton(
          onPressed: _saving || _name.text.trim().isEmpty || _selected.isEmpty
              ? null
              : _save,
          child: Text(
            _saving ? t.smartHomeSavingPreset : t.smartHomeSavePreset,
          ),
        ),
      ],
    );
  }

  Widget _lightEditor(SmartLight light) {
    final setting = _selected[light.id];
    final palette = context.luma;
    final t = L.of(context);
    final hue = setting?.hue ?? 30;
    final saturation = setting?.saturation ?? 1;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            value: setting != null,
            title: Text(light.name),
            subtitle: Text(
              light.isReachable ? (light.room ?? t.smartHomeIkeaLamp) : t.smartHomeOffline,
            ),
            onChanged: _saving
                ? null
                : (selected) => setState(() {
                    if (selected == true) {
                      _selected[light.id] = _defaultSetting(light);
                    } else {
                      _selected.remove(light.id);
                    }
                  }),
          ),
          if (setting != null) ...[
            if (light.canDim) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  t.smartHomeBrightnessPercent(setting.brightness ?? 100),
                ),
              ),
              Slider(
                min: 1,
                max: 100,
                value: (setting.brightness ?? 100).toDouble(),
                onChanged: _saving
                    ? null
                    : (value) => _update(light, brightness: value.round()),
              ),
            ],
            if (light.canSetColor) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(t.commonColor),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: HSVColor.fromAHSV(
                        1,
                        hue.toDouble(),
                        saturation,
                        1,
                      ).toColor(),
                    ),
                    const Spacer(),
                    Text(
                      '$hue°',
                      style: TextStyle(color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
              Slider(
                min: 0,
                max: 359,
                value: hue.toDouble(),
                onChanged: _saving
                    ? null
                    : (value) => _update(light, hue: value.round()),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  t.smartHomeColorIntensityPercent((saturation * 100).round()),
                ),
              ),
              Slider(
                min: 0,
                max: 1,
                value: saturation,
                onChanged: _saving
                    ? null
                    : (value) => _update(light, saturation: value),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  t.smartHomeNoColorSupport,
                  style: TextStyle(color: palette.textSecondary),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
