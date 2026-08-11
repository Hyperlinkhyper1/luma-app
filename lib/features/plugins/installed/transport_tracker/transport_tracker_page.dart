import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import '../_shared/windows_webview.dart';
import 'ais_key_store.dart';
import 'ais_stream_client.dart';
import 'vessel.dart';

/// Live ship tracking on a real-world map — MarineTraffic/VesselFinder,
/// inside luma. The map itself (MapLibre GL, bundled as
/// `assets/transport_tracker/index.html`) runs in an embedded WebView, same
/// as Subway Builder; everything else (vessel list, detail card, settings)
/// is native Flutter layered on top. AIS data comes straight from
/// aisstream.io over a plain WebSocket, using the user's own free API key —
/// this never touches a luma server.
class TransportTrackerPage extends StatefulWidget {
  const TransportTrackerPage({super.key});

  @override
  State<TransportTrackerPage> createState() => _TransportTrackerPageState();
}

typedef _Bounds = ({double south, double west, double north, double east});

class _TransportTrackerPageState extends State<TransportTrackerPage> {
  WebviewController? _windowsController;
  InAppWebViewController? _inAppController;
  StreamSubscription? _windowsMsgSub;
  bool _loading = true;

  final _client = AisStreamClient();
  StreamSubscription<AisConnectionState>? _stateSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<VesselPatch>? _patchSub;
  Timer? _tickTimer;
  Timer? _boundsDebounce;
  Timer? _loadingFallback;

  final _vessels = <int, Vessel>{};
  bool _dirty = false;
  int? _selectedMmsi;
  _Bounds? _bounds;
  bool _tracking = false;
  AisConnectionState _connState = AisConnectionState.idle;

  String? _apiKey;
  late final Future<void> _keyLoad = _loadKey();

  @override
  void initState() {
    super.initState();
    _stateSub = _client.state.listen((s) {
      if (!mounted) return;
      setState(() {
        _connState = s;
        if (s == AisConnectionState.closed || s == AisConnectionState.error) {
          _tracking = false;
        }
      });
    });
    _errorSub = _client.errors.listen((msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    });
    _patchSub = _client.patches.listen((patch) {
      final existing = _vessels[patch.mmsi];
      _vessels[patch.mmsi] =
          existing == null ? Vessel.fromPatch(patch) : existing.mergedWith(patch);
      _dirty = true;
    });
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  /// The HTML document loading (`onLoaded`/`onLoadStop`) just means the page
  /// executed — the map itself only reports ready once MapLibre's 'load'
  /// event fires (`_onBridgeEvent('mapReady', ...)`), which needs the style
  /// JSON to be fetched over the network. If that never happens (e.g. no
  /// internet), fall back after a while instead of spinning forever.
  void _armLoadingFallback() {
    _loadingFallback?.cancel();
    _loadingFallback = Timer(const Duration(seconds: 15), () {
      if (mounted && _loading) setState(() => _loading = false);
    });
  }

  Future<void> _loadKey() async {
    final store = await AisKeyStore.load();
    final key = await store.readKey();
    if (!mounted) return;
    setState(() => _apiKey = key);
  }

  void _onTick() {
    final now = DateTime.now();
    final before = _vessels.length;
    _vessels.removeWhere(
        (_, v) => now.difference(v.lastUpdate) > const Duration(minutes: 8));
    if (_vessels.length != before && _selectedMmsi != null &&
        !_vessels.containsKey(_selectedMmsi)) {
      _selectedMmsi = null;
    }
    if (_dirty || _vessels.length != before) {
      _pushVessels();
      _dirty = false;
    }
    if (mounted) setState(() {});
  }

  void _pushVessels() {
    final features = _vessels.values
        .map((v) => v.toGeoJsonFeature(selected: v.mmsi == _selectedMmsi))
        .toList();
    final fc = jsonEncode({'type': 'FeatureCollection', 'features': features});
    _evalJs('window.TT && TT.updateVessels($fc)');
  }

  Future<void> _evalJs(String script) async {
    try {
      if (Platform.isWindows) {
        await _windowsController?.executeScript(script);
      } else {
        await _inAppController?.evaluateJavascript(source: script);
      }
    } catch (_) {
      // Webview not attached yet, or navigated away — safe to drop.
    }
  }

  // ---- Bridge: JS -> Dart -------------------------------------------

  void _onBridgeEvent(String name, List args) {
    switch (name) {
      case 'mapReady':
        if (mounted) setState(() => _loading = false);
        break;
      case 'boundsChanged':
        if (args.length < 4) return;
        _bounds = (
          south: (args[0] as num).toDouble(),
          west: (args[1] as num).toDouble(),
          north: (args[2] as num).toDouble(),
          east: (args[3] as num).toDouble(),
        );
        if (mounted) setState(() {});
        if (_tracking) _scheduleBoundsUpdate();
        break;
      case 'vesselClicked':
        if (args.isEmpty) return;
        final mmsi = (args[0] as num).toInt();
        if (!mounted || !_vessels.containsKey(mmsi)) return;
        setState(() => _selectedMmsi = mmsi);
        _pushVessels();
        break;
    }
  }

  void _onWindowsController(WebviewController controller) {
    _windowsController = controller;
    _windowsMsgSub = controller.webMessage.listen((raw) {
      Map<String, dynamic> msg;
      try {
        msg = raw is String
            ? jsonDecode(raw) as Map<String, dynamic>
            : Map<String, dynamic>.from(raw as Map);
      } catch (_) {
        return;
      }
      final name = msg['name'] as String? ?? '';
      final args = (msg['args'] as List?) ?? const [];
      _onBridgeEvent(name, args);
    });
  }

  // ---- Live tracking --------------------------------------------------

  /// AISStream allows updating a live connection's bounding box on the fly
  /// (throttled to roughly once a second), so panning the map while tracking
  /// just re-subscribes instead of tearing down the socket.
  void _scheduleBoundsUpdate() {
    _boundsDebounce?.cancel();
    _boundsDebounce = Timer(const Duration(milliseconds: 1300), () {
      final bounds = _bounds;
      final key = _apiKey;
      if (bounds == null || key == null || !_tracking) return;
      _client.updateBoundingBox(
        apiKey: key,
        box: AisBoundingBox(
          south: bounds.south,
          west: bounds.west,
          north: bounds.north,
          east: bounds.east,
        ),
      );
    });
  }

  Future<void> _toggleTracking() async {
    if (_tracking) {
      await _client.disconnect();
      if (mounted) setState(() => _tracking = false);
      return;
    }
    final key = _apiKey;
    if (key == null || key.isEmpty) {
      await _openSettings();
      return;
    }
    final bounds = _bounds;
    if (bounds == null) return;
    setState(() => _tracking = true);
    await _client.connect(
      apiKey: key,
      box: AisBoundingBox(
        south: bounds.south,
        west: bounds.west,
        north: bounds.north,
        east: bounds.east,
      ),
    );
  }

  void _selectVessel(int mmsi) {
    final v = _vessels[mmsi];
    if (v == null) return;
    setState(() => _selectedMmsi = mmsi);
    _pushVessels();
    _evalJs('TT.flyTo(${v.latitude}, ${v.longitude}, 12)');
  }

  Future<void> _openSettings() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _ApiKeyDialog(),
    );
    if (saved == true) await _loadKey();
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isLinux) {
      return const Center(
        child: LumaEmptyState(
          icon: Icons.directions_boat_outlined,
          title: 'Not available on Linux',
          subtitle: 'Transport Tracker requires an embedded WebView that is '
              'not yet supported on this platform.',
        ),
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 700;
      return Stack(
        children: [
          Positioned.fill(
            child: Platform.isWindows
                ? WindowsWebview(
                    fileUrl: Uri.file(
                      windowsAssetPath('assets/transport_tracker/index.html'),
                    ).toString(),
                    onController: _onWindowsController,
                    onLoaded: _armLoadingFallback,
                  )
                : InAppWebView(
                    initialFile: 'assets/transport_tracker/index.html',
                    initialSettings: InAppWebViewSettings(
                      transparentBackground: true,
                      supportZoom: false,
                    ),
                    onWebViewCreated: (controller) {
                      _inAppController = controller;
                      controller.addJavaScriptHandler(
                        handlerName: 'tt_bridge',
                        callback: (args) async {
                          final name = args[0] as String;
                          final callArgs =
                              (args.length > 1 ? args[1] : const []) as List;
                          _onBridgeEvent(name, callArgs);
                          return null;
                        },
                      );
                    },
                    onLoadStop: (controller, url) => _armLoadingFallback(),
                  ),
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (!_loading) _TopBar(
            // On phone the app overlays its own floating back button in the
            // top-left corner (this plugin is full-screen/"immersive" there
            // — see AppShell._phoneImmersivePlugins), so the status pill
            // needs extra clearance to not sit under it.
            leftInset: wide ? 12 : 56,
            connState: _connState,
            tracking: _tracking,
            canTrack: _bounds != null,
            onToggleTracking: _toggleTracking,
            onOpenSettings: _openSettings,
          ),
          if (!_loading)
            Positioned(
              top: 66,
              right: 12,
              bottom: 12,
              width: wide ? 300 : null,
              left: wide ? null : 12,
              child: FutureBuilder<void>(
                future: _keyLoad,
                builder: (context, _) => _SidePanel(
                  vessels: _vessels,
                  selectedMmsi: _selectedMmsi,
                  hasApiKey: _apiKey != null && _apiKey!.isNotEmpty,
                  onSelect: _selectVessel,
                  onDeselect: () {
                    setState(() => _selectedMmsi = null);
                    _pushVessels();
                  },
                  onOpenSettings: _openSettings,
                ),
              ),
            ),
        ],
      );
    });
  }

  @override
  void dispose() {
    _boundsDebounce?.cancel();
    _loadingFallback?.cancel();
    _tickTimer?.cancel();
    _stateSub?.cancel();
    _errorSub?.cancel();
    _patchSub?.cancel();
    _client.dispose();
    _windowsMsgSub?.cancel();
    _windowsController?.dispose();
    _inAppController?.dispose();
    super.dispose();
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.leftInset,
    required this.connState,
    required this.tracking,
    required this.canTrack,
    required this.onToggleTracking,
    required this.onOpenSettings,
  });

  final double leftInset;
  final AisConnectionState connState;
  final bool tracking;
  final bool canTrack;
  final VoidCallback onToggleTracking;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    // The status/track pills sit in a Wrap so a long status label on a
    // narrow phone drops to a second line instead of overflowing (there's
    // no scroll region to bail out into up here); settings stays pinned to
    // the trailing edge via the outer Row regardless of how that wraps.
    return Positioned(
      top: 12,
      left: leftInset,
      right: 12,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Glass(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: switch (connState) {
                            AisConnectionState.live => luma.success,
                            AisConnectionState.connecting => luma.accent,
                            AisConnectionState.error => luma.danger,
                            _ => luma.textMuted,
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        switch (connState) {
                          AisConnectionState.live => 'Live',
                          AisConnectionState.connecting => 'Connecting…',
                          AisConnectionState.error => 'Connection error',
                          AisConnectionState.closed => 'Stopped',
                          AisConnectionState.idle => 'Idle',
                        },
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _Glass(
                  onTap: canTrack ? onToggleTracking : null,
                  accent: tracking,
                  tooltip: canTrack
                      ? (tracking
                          ? 'Stop the live AIS feed'
                          : 'Start a live AIS feed for the area on screen')
                      : 'Waiting for the map to finish loading',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tracking
                            ? Icons.stop_circle_outlined
                            : Icons.play_circle_outline_rounded,
                        size: 16,
                        color: tracking ? luma.onAccent : luma.textPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tracking ? 'Stop tracking' : 'Track this view',
                        style: TextStyle(
                          color: tracking ? luma.onAccent : luma.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Glass(
            onTap: onOpenSettings,
            tooltip: 'AISStream.io API key settings',
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.settings_outlined, size: 16, color: luma.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// A translucent "glass" chip, matching the floating-control look used
/// elsewhere for map overlays (see Subway Builder's `#mapctl`). Always at
/// least 44×44 so it meets the platform touch-target minimum even where the
/// visible pill is smaller (e.g. the icon-only settings button).
class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.onTap,
    this.accent = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.tooltip,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool accent;
  final EdgeInsetsGeometry padding;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final pill = Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: padding,
      decoration: BoxDecoration(
        color: accent ? luma.accent : luma.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent ? luma.accent : luma.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(child: child),
    );
    if (onTap == null) return pill;
    final button = Material(
      type: MaterialType.transparency,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: pill,
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.vessels,
    required this.selectedMmsi,
    required this.hasApiKey,
    required this.onSelect,
    required this.onDeselect,
    required this.onOpenSettings,
  });

  final Map<int, Vessel> vessels;
  final int? selectedMmsi;
  final bool hasApiKey;
  final ValueChanged<int> onSelect;
  final VoidCallback onDeselect;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final selected =
        selectedMmsi != null ? vessels[selectedMmsi] : null;
    return Container(
      decoration: BoxDecoration(
        color: luma.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: luma.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      // Crossfade rather than snap between the list and detail views —
      // this is a real navigation state change, not a static redraw.
      child: AnimatedSwitcher(
        duration: WidgetsBinding
                .instance.platformDispatcher.accessibilityFeatures.disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: selected != null
            ? _VesselDetail(
                key: ValueKey('detail-${selected.mmsi}'),
                vessel: selected,
                onBack: onDeselect,
              )
            : _VesselList(
                key: const ValueKey('list'),
                vessels: vessels,
                hasApiKey: hasApiKey,
                onSelect: onSelect,
                onOpenSettings: onOpenSettings,
              ),
      ),
    );
  }
}

class _VesselList extends StatelessWidget {
  const _VesselList({
    super.key,
    required this.vessels,
    required this.hasApiKey,
    required this.onSelect,
    required this.onOpenSettings,
  });

  final Map<int, Vessel> vessels;
  final bool hasApiKey;
  final ValueChanged<int> onSelect;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final sorted = vessels.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Row(
            children: [
              Icon(Icons.directions_boat_rounded, size: 16, color: luma.accent),
              const SizedBox(width: 8),
              Text(
                'Vessels (${vessels.length})',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (!hasApiKey)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: _KeyPrompt(onOpenSettings: onOpenSettings),
          ),
        Expanded(
          child: sorted.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    hasApiKey
                        ? 'No vessels yet. Press "Track this view" to start '
                            'the live feed for the area on screen.'
                        : 'Add a free AISStream.io API key to see live ships.',
                    style: TextStyle(color: luma.textMuted, fontSize: 12.5, height: 1.4),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 2),
                  itemBuilder: (context, i) {
                    final v = sorted[i];
                    return _VesselRow(vessel: v, onTap: () => onSelect(v.mmsi));
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: _CategoryLegend(),
        ),
      ],
    );
  }
}

class _KeyPrompt extends StatelessWidget {
  const _KeyPrompt({required this.onOpenSettings});
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Material(
      color: luma.accentSubtle,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenSettings,
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: luma.accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.key_rounded, size: 16, color: luma.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add your free API key',
                  style: TextStyle(
                    color: luma.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 16, color: luma.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _VesselRow extends StatelessWidget {
  const _VesselRow({required this.vessel, required this.onTap});
  final Vessel vessel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: vessel.category.color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vessel.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      vessel.category.label,
                      style: TextStyle(color: luma.textMuted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              if (vessel.sog != null)
                Text(
                  '${vessel.sog!.toStringAsFixed(1)} kn',
                  style: TextStyle(color: luma.textSecondary, fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryLegend extends StatelessWidget {
  const _CategoryLegend();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    const shown = [
      VesselCategory.cargo,
      VesselCategory.tanker,
      VesselCategory.passenger,
      VesselCategory.fishing,
      VesselCategory.pleasureCraft,
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        for (final c in shown)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: c.color),
              ),
              const SizedBox(width: 4),
              Text(c.label, style: TextStyle(color: luma.textMuted, fontSize: 10)),
            ],
          ),
      ],
    );
  }
}

class _VesselDetail extends StatelessWidget {
  const _VesselDetail({super.key, required this.vessel, required this.onBack});
  final Vessel vessel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, size: 18, color: luma.textSecondary),
                onPressed: onBack,
                tooltip: 'Back to vessel list',
              ),
              Expanded(
                child: Text(
                  vessel.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: vessel.category.color),
                ),
                const SizedBox(width: 6),
                Text(vessel.category.label,
                    style: TextStyle(color: luma.textMuted, fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Divider(color: luma.border, height: 1),
          const SizedBox(height: 10),
          _DetailRow(label: 'MMSI', value: '${vessel.mmsi}'),
          if (vessel.imo != null) _DetailRow(label: 'IMO', value: '${vessel.imo}'),
          if (vessel.callSign != null)
            _DetailRow(label: 'Call sign', value: vessel.callSign!),
          _DetailRow(
            label: 'Speed',
            value: vessel.sog != null
                ? '${vessel.sog!.toStringAsFixed(1)} kn'
                : '—',
          ),
          _DetailRow(
            label: 'Course',
            value: vessel.cog != null ? '${vessel.cog!.toStringAsFixed(0)}°' : '—',
          ),
          if (vessel.trueHeading != null)
            _DetailRow(label: 'Heading', value: '${vessel.trueHeading}°'),
          _DetailRow(label: 'Status', value: navStatusLabel(vessel.navStatus)),
          if (vessel.destination != null)
            _DetailRow(label: 'Destination', value: vessel.destination!),
          if (vessel.draught != null)
            _DetailRow(
                label: 'Draught', value: '${vessel.draught!.toStringAsFixed(1)} m'),
          _DetailRow(
            label: 'Position',
            value:
                '${vessel.latitude.toStringAsFixed(4)}, ${vessel.longitude.toStringAsFixed(4)}',
          ),
          _DetailRow(label: 'Last report', value: _relativeTime(vessel.lastUpdate)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(label,
                style: TextStyle(color: luma.textMuted, fontSize: 11.5)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _relativeTime(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  return '${diff.inHours}h ago';
}

/// The AISStream.io API key entry dialog — mirrors the AI Assistant's
/// per-provider key management UI (see `AiSettingsSection`).
class _ApiKeyDialog extends StatefulWidget {
  const _ApiKeyDialog();

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  bool _testing = false;
  String? _savedMasked;
  late final Future<void> _load = _loadSavedKey();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSavedKey() async {
    final store = await AisKeyStore.load();
    final key = await store.readKey();
    if (!mounted) return;
    setState(() => _savedMasked = key == null ? null : _mask(key));
  }

  static String _mask(String key) {
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 4)}••••${key.substring(key.length - 4)}';
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    setState(() => _saving = true);
    final store = await AisKeyStore.load();
    await store.saveKey(value);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
  }

  Future<void> _testConnection() async {
    final typed = _controller.text.trim();
    String? key = typed.isNotEmpty ? typed : null;
    if (key == null) {
      final store = await AisKeyStore.load();
      key = await store.readKey();
    }
    if (key == null || key.isEmpty) {
      _showSnack('Enter an API key first.');
      return;
    }
    setState(() => _testing = true);
    final error = await AisStreamClient.testKey(key);
    if (!mounted) return;
    setState(() => _testing = false);
    _showSnack(error ?? 'Connection works.');
  }

  Future<void> _clear() async {
    final store = await AisKeyStore.load();
    await store.clearKey();
    if (!mounted) return;
    setState(() => _savedMasked = null);
    _showSnack('API key removed.');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Dialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: luma.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<void>(
          future: _load,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_boat_rounded, color: luma.accent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'AISStream.io API key',
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => launchUrl(
                    Uri.parse('https://aisstream.io'),
                    mode: LaunchMode.externalApplication,
                  ),
                  mouseCursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Get a free key at aisstream.io — sign in, then copy '
                      'your API key from the dashboard.',
                      style: TextStyle(
                        color: luma.accent,
                        fontSize: 12,
                        height: 1.4,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_savedMasked != null) ...[
                Row(
                  children: [
                    Icon(Icons.key_rounded, size: 16, color: luma.accent),
                    const SizedBox(width: 8),
                    Text(_savedMasked!,
                        style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _controller,
                obscureText: _obscure,
                style: TextStyle(color: luma.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _savedMasked != null
                      ? 'Enter a new key to replace it'
                      : 'Paste your API key',
                  hintStyle: TextStyle(color: luma.textMuted),
                  filled: true,
                  fillColor: luma.background,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: luma.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: luma.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: luma.accent),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      color: luma.textMuted,
                    ),
                    tooltip: _obscure ? 'Show key' : 'Hide key',
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Stored locally on this device only, encrypted at rest. Sent '
                'directly to aisstream.io when tracking — never to any luma '
                'server.',
                style: TextStyle(color: luma.textMuted, fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  LumaPrimaryButton(
                    label: 'Save',
                    icon: Icons.save_rounded,
                    loading: _saving,
                    onTap: _save,
                  ),
                  LumaGhostButton(
                    label: 'Test connection',
                    icon: Icons.wifi_tethering_rounded,
                    onTap: _testing ? null : _testConnection,
                  ),
                  if (_savedMasked != null)
                    LumaGhostButton(
                      label: 'Remove key',
                      icon: Icons.delete_outline_rounded,
                      onTap: _clear,
                    ),
                  LumaGhostButton(
                    label: 'Close',
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
