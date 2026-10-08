import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'smart_home_repository.dart';
import 'smart_home_presets_ui.dart';
import 'smart_home_scope.dart';
import 'smart_light.dart';

class SmartHomePage extends StatefulWidget {
  const SmartHomePage({super.key});

  @override
  State<SmartHomePage> createState() => _SmartHomePageState();
}

class _SmartHomePageState extends State<SmartHomePage> {
  final _host = TextEditingController();
  bool _autoDiscoveryStarted = false;
  bool _showManualAddress = false;

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = SmartHomeScope.of(context);
    if (!repo.loading && !repo.paired && !_autoDiscoveryStarted) {
      _autoDiscoveryStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) repo.discoverHubs();
      });
    }
    final palette = context.luma;
    final t = L.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_rounded,
                    color: palette.accent,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.pluginNameSmartHome,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  if (repo.paired)
                    IconButton(
                      tooltip: t.smartHomeRefreshLights,
                      onPressed: repo.busy ? null : repo.refresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                t.smartHomeSubtitle,
                style: TextStyle(color: palette.textSecondary),
              ),
              const SizedBox(height: 24),
              if (repo.error != null) ...[
                LumaCard(
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: palette.danger),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          repo.error!,
                          style: TextStyle(color: palette.danger),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (repo.loading)
                const Center(child: CircularProgressIndicator())
              else if (!repo.paired)
                _pairingCard(repo)
              else ...[
                SmartHomePresetsSection(repository: repo),
                const SizedBox(height: 18),
                _connectionCard(repo),
                const SizedBox(height: 22),
                if (repo.lights.isEmpty && repo.busy)
                  const Center(child: CircularProgressIndicator())
                else if (repo.lights.isEmpty)
                  LumaCard(
                    child: Column(
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 42,
                          color: palette.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(t.smartHomeNoLampsFound),
                        const SizedBox(height: 6),
                        Text(
                          t.smartHomeAddLampHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: palette.textSecondary),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Text(
                    t.smartHomeLampsCount(repo.lights.length),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  for (final light in repo.lights) ...[
                    _LightCard(
                      key: ValueKey(light.id),
                      light: light,
                      repo: repo,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pairingCard(SmartHomeRepository repo) {
    final palette = context.luma;
    final t = L.of(context);
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.smartHomeConnectHub,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            t.smartHomeSameNetworkHint,
            style: TextStyle(color: palette.textSecondary),
          ),
          const SizedBox(height: 18),
          if (!repo.pairingStarted) ...[
            if (repo.discovering) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 10),
              Text(t.smartHomeLookingForHubs),
            ] else ...[
              if (repo.discoveredHubs.isNotEmpty) ...[
                Text(
                  t.smartHomeHubsFound,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final hub in repo.discoveredHubs)
                  Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.hub_rounded),
                      title: Text(hub.name),
                      subtitle: Text(hub.host),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      enabled: !repo.busy,
                      onTap: () {
                        _host.text = hub.host;
                        repo.beginPairing(hub.host);
                      },
                    ),
                  ),
              ] else if (repo.discoveryAttempted && repo.error == null)
                Text(
                  t.smartHomeNoHubFound,
                  style: TextStyle(color: palette.textSecondary),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: repo.busy ? null : repo.discoverHubs,
                icon: const Icon(Icons.search_rounded),
                label: Text(t.smartHomeFindMyHub),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: repo.busy
                  ? null
                  : () => setState(
                      () => _showManualAddress = !_showManualAddress,
                    ),
              child: Text(
                _showManualAddress
                    ? t.smartHomeHideManualAddress
                    : t.smartHomeEnterIpManually,
              ),
            ),
            if (_showManualAddress) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _host,
                enabled: !repo.busy,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: t.smartHomeHubIpAddress,
                  hintText: '192.168.1.20',
                  prefixIcon: const Icon(Icons.router_rounded),
                ),
                onSubmitted: repo.busy ? null : repo.beginPairing,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: repo.busy
                    ? null
                    : () => repo.beginPairing(_host.text),
                icon: const Icon(Icons.link_rounded),
                label: Text(t.smartHomeStartPairing),
              ),
            ],
          ] else ...[
            Text(
              t.smartHomePressHubButton,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: repo.busy ? null : repo.completePairing,
              icon: const Icon(Icons.check_rounded),
              label: Text(t.smartHomePressedButton),
            ),
            const SizedBox(height: 8),
            Text(
              t.smartHomePairingExpires,
              style: TextStyle(color: palette.textSecondary),
            ),
            TextButton(
              onPressed: repo.busy ? null : () => repo.beginPairing(_host.text),
              child: Text(t.smartHomeStartAgain),
            ),
          ],
          if (repo.busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _connectionCard(SmartHomeRepository repo) {
    final palette = context.luma;
    final t = L.of(context);
    return LumaCard(
      child: Row(
        children: [
          Icon(Icons.router_rounded, color: palette.success),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.smartHomeConnected,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  repo.host ?? '',
                  style: TextStyle(color: palette.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: repo.busy ? null : repo.disconnect,
            child: Text(t.smartHomeDisconnect),
          ),
        ],
      ),
    );
  }
}

class _LightCard extends StatefulWidget {
  const _LightCard({super.key, required this.light, required this.repo});

  final SmartLight light;
  final SmartHomeRepository repo;

  @override
  State<_LightCard> createState() => _LightCardState();
}

class _LightCardState extends State<_LightCard> {
  late double _brightness = (widget.light.lightLevel ?? 100)
      .clamp(1, 100)
      .toDouble();
  late double _temperature =
      (widget.light.colorTemperature ??
              widget.light.colorTemperatureMin ??
              2700)
          .toDouble();

  @override
  void didUpdateWidget(covariant _LightCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.light != widget.light) {
      _brightness = (widget.light.lightLevel ?? 100).clamp(1, 100).toDouble();
      _temperature =
          (widget.light.colorTemperature ??
                  widget.light.colorTemperatureMin ??
                  2700)
              .toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final light = widget.light;
    final palette = context.luma;
    final t = L.of(context);
    final enabled = light.isReachable && !widget.repo.busy;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                light.isOn
                    ? Icons.lightbulb_rounded
                    : Icons.lightbulb_outline_rounded,
                color: light.isOn ? palette.warning : palette.textMuted,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      light.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      light.isReachable
                          ? (light.room ?? t.smartHomeIkeaLamp)
                          : t.smartHomeOffline,
                      style: TextStyle(color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
              if (widget.repo.isBusy(light.id))
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (light.canToggle)
                Switch(
                  value: light.isOn,
                  onChanged: enabled
                      ? (value) => widget.repo.setOn(light, value)
                      : null,
                ),
            ],
          ),
          if (light.canDim) ...[
            const SizedBox(height: 12),
            Text(t.smartHomeBrightnessPercent(_brightness.round())),
            Slider(
              min: 1,
              max: 100,
              value: _brightness.clamp(1, 100),
              onChanged: enabled
                  ? (value) => setState(() => _brightness = value)
                  : null,
              onChangeEnd: enabled
                  ? (value) => widget.repo.setBrightness(light, value.round())
                  : null,
            ),
          ],
          if (light.canSetTemperature) ...[
            const SizedBox(height: 8),
            Text(t.smartHomeWhiteTemperatureKelvin(_temperature.round())),
            Slider(
              min: light.colorTemperatureMax!.toDouble(),
              max: light.colorTemperatureMin!.toDouble(),
              value: _temperature
                  .clamp(light.colorTemperatureMax!, light.colorTemperatureMin!)
                  .toDouble(),
              onChanged: enabled
                  ? (value) => setState(() => _temperature = value)
                  : null,
              onChangeEnd: enabled
                  ? (value) => widget.repo.setTemperature(light, value.round())
                  : null,
            ),
          ],
          if (light.canSetColor) ...[
            const SizedBox(height: 8),
            Text(t.commonColor),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _colorButton(t.smartHomeColorRed, Colors.red, 0, enabled),
                _colorButton(
                  t.smartHomeColorOrange,
                  Colors.orange,
                  30,
                  enabled,
                ),
                _colorButton(
                  t.smartHomeColorGreen,
                  Colors.green,
                  120,
                  enabled,
                ),
                _colorButton(t.smartHomeColorBlue, Colors.blue, 240, enabled),
                _colorButton(
                  t.smartHomeColorPurple,
                  Colors.purple,
                  280,
                  enabled,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _colorButton(String label, Color color, int hue, bool enabled) =>
      Tooltip(
        message: label,
        child: IconButton.filledTonal(
          onPressed: enabled
              ? () => widget.repo.setColor(widget.light, hue, 1)
              : null,
          icon: Icon(Icons.circle, color: color),
        ),
      );
}
