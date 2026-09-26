import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
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
                      'Smart Home',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  if (repo.paired)
                    IconButton(
                      tooltip: 'Refresh lights',
                      onPressed: repo.busy ? null : repo.refresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Control IKEA lamps through your DIRIGERA hub on this network.',
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
                        const Text('No IKEA lamps found'),
                        const SizedBox(height: 6),
                        Text(
                          'Add a lamp in the IKEA Home smart app, then refresh here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: palette.textSecondary),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Text(
                    '${repo.lights.length} ${repo.lights.length == 1 ? 'lamp' : 'lamps'}',
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
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect a DIRIGERA hub',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure this device and the hub are on the same home network.',
            style: TextStyle(color: palette.textSecondary),
          ),
          const SizedBox(height: 18),
          if (!repo.pairingStarted) ...[
            if (repo.discovering) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 10),
              const Text('Looking for DIRIGERA hubs…'),
            ] else ...[
              if (repo.discoveredHubs.isNotEmpty) ...[
                Text(
                  'Hubs found',
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
                  'No hub found. Check that DIRIGERA is powered on and this device is on the same home network.',
                  style: TextStyle(color: palette.textSecondary),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: repo.busy ? null : repo.discoverHubs,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Find my hub'),
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
                    ? 'Hide manual address'
                    : 'Enter IP address manually',
              ),
            ),
            if (_showManualAddress) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _host,
                enabled: !repo.busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Hub IP address',
                  hintText: '192.168.1.20',
                  prefixIcon: Icon(Icons.router_rounded),
                ),
                onSubmitted: repo.busy ? null : repo.beginPairing,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: repo.busy
                    ? null
                    : () => repo.beginPairing(_host.text),
                icon: const Icon(Icons.link_rounded),
                label: const Text('Start pairing'),
              ),
            ],
          ] else ...[
            Text(
              'Press the action button on the bottom of the DIRIGERA hub.',
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: repo.busy ? null : repo.completePairing,
              icon: const Icon(Icons.check_rounded),
              label: const Text('I pressed the button'),
            ),
            const SizedBox(height: 8),
            Text(
              'If pairing expires, start again.',
              style: TextStyle(color: palette.textSecondary),
            ),
            TextButton(
              onPressed: repo.busy ? null : () => repo.beginPairing(_host.text),
              child: const Text('Start again'),
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
    return LumaCard(
      child: Row(
        children: [
          Icon(Icons.router_rounded, color: palette.success),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DIRIGERA connected',
                  style: TextStyle(fontWeight: FontWeight.w600),
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
            child: const Text('Disconnect'),
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
                          ? (light.room ?? 'IKEA lamp')
                          : 'Offline',
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
            Text('Brightness  ${_brightness.round()}%'),
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
            Text('White temperature  ${_temperature.round()} K'),
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
            const Text('Color'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _colorButton('Red', Colors.red, 0, enabled),
                _colorButton('Orange', Colors.orange, 30, enabled),
                _colorButton('Green', Colors.green, 120, enabled),
                _colorButton('Blue', Colors.blue, 240, enabled),
                _colorButton('Purple', Colors.purple, 280, enabled),
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
